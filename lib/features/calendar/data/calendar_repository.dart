import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_env.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import 'calendar_api_service.dart';
import 'calendar_dto.dart';
import 'calendar_member_dto.dart';
import 'liturgical_models.dart';
import 'mock_calendar_data.dart';

abstract class CalendarRepository {
  Future<MemberEventDetail> getEventDetail(String id);
  Future<MemberRehearsalDetail> getRehearsalDetail(String id);
  Future<List<LiturgicalDay>> getLiturgicalDays(String fromDate, String toDate);
  Future<LiturgicalDay?> getLiturgicalDay(String date);
  Future<PublicAppSettings> getPublicSettings();
  Future<List<RehearsalSong>> getRehearsalSongs(String id);
  Future<LiturgicalEvent> getUpcomingEvent();
  Future<List<LiturgicalEvent>> getEvents();
  Future<List<RehearsalSession>> getRehearsals();
  Future<void> updateParticipation(String eventId, ParticipationStatus status);
}

class CalendarRepositoryImpl implements CalendarRepository {
  final CalendarApiService apiService;

  CalendarRepositoryImpl({required this.apiService});

  @override
  Future<LiturgicalEvent> getUpcomingEvent() async {
    final events = await getEvents();
    if (events.isEmpty) {
      throw const AppException(
        code: 'NO_UPCOMING_EVENT',
        message: 'Không có sự kiện phụng vụ sắp tới.',
      );
    }
    return events.first;
  }

  @override
  Future<List<LiturgicalEvent>> getEvents() async {
    final results = await Future.wait<Object>([
      apiService.getUpcomingEvents(),
      apiService.getMyParticipations(),
      apiService.getMyAssignments(),
    ]);
    final rawList = results[0] as List<Map<String, dynamic>>;
    final participations = {
      for (final item in results[1] as List<MyParticipation>)
        item.eventId: item,
    };
    final assignments = {
      for (final item in results[2] as List<MyAssignedEvent>)
        item.eventId: item.assignments,
    };
    return rawList.map((map) {
      final id = map['id']?.toString() ?? '';
      final title = map['title']?.toString() ?? 'Thánh lễ';
      final location = map['locationName']?.toString() ?? '';
      final eventDateStr = map['eventDate']?.toString();
      final timeStr = map['time']?.toString() ?? '';
      final parsedDate = eventDateStr != null
          ? DateTime.tryParse(eventDateStr)
          : null;

      return LiturgicalEvent(
        id: id,
        title: title,
        categoryName: 'PHỤNG VỤ',
        seasonName: '',
        date:
            parsedDate ??
            (throw const FormatException('Event date is missing.')),
        timeRange: timeStr,
        location: location,
        assignedVocalPart:
            assignments[id]?.map((a) => a.skillName).toSet().join(', ') ?? '',
        participationStatus:
            participations[id]?.status ?? ParticipationStatus.unknown,
        canRespond: participations[id]?.canRespond ?? false,
        cannotRespondReason:
            participations[id]?.cannotRespondReason ??
            (participations[id] == null
                ? 'EVENT_PARTICIPATION_NOT_INVITED'
                : null),
        hasApprovedSongList: false,
      );
    }).toList();
  }

  @override
  Future<List<RehearsalSession>> getRehearsals() async {
    final rawList = await apiService.getUpcomingRehearsals();
    return rawList.map((map) {
      final id = map['id']?.toString() ?? '';
      final location = map['locationName']?.toString() ?? 'Nhà thờ';
      final note = map['note']?.toString();
      final startTimeStr = map['startTime']?.toString();
      final endTimeStr = map['endTime']?.toString();
      final start = startTimeStr != null
          ? DateTime.tryParse(startTimeStr)?.toLocal()
          : null;
      final end = endTimeStr != null
          ? DateTime.tryParse(endTimeStr)?.toLocal()
          : null;

      final songsList =
          (map['songs'] as List?)
              ?.map((s) => s is Map ? s['songTitle']?.toString() ?? '' : '')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [];

      String timeRange = '';
      if (start != null && end != null) {
        timeRange =
            '${DateFormat('HH:mm').format(start)} – ${DateFormat('HH:mm').format(end)}';
      } else if (start != null) {
        timeRange = DateFormat('HH:mm').format(start);
      }

      return RehearsalSession(
        id: id,
        title: note != null && note.isNotEmpty ? note : 'Buổi tập hát',
        date:
            start ??
            (throw const FormatException('Rehearsal start time is missing.')),
        endTime: end,
        timeRange: timeRange,
        location: location,
        contentSummary: songsList.isNotEmpty
            ? songsList.join(', ')
            : 'Tập hát theo lịch',
        attendanceStatus: 'Chưa có dữ liệu điểm danh',
      );
    }).toList();
  }

  @override
  Future<void> updateParticipation(
    String eventId,
    ParticipationStatus status,
  ) async {
    final epoch = apiService.sessionEpoch;
    final invitations = await apiService.getMyParticipations();
    if (apiService.sessionEpoch != epoch) throw const UnauthorizedException();
    final invitation = invitations
        .where((p) => p.eventId == eventId)
        .firstOrNull;
    if (invitation?.canRespond != true) {
      throw ValidationException(
        code:
            invitation?.cannotRespondReason ??
            'EVENT_PARTICIPATION_NOT_INVITED',
        message: 'This invitation cannot be answered.',
      );
    }
    await apiService.respondParticipation(
      eventId,
      status,
      expectedSessionEpoch: epoch,
    );
  }

  @override
  Future<MemberEventDetail> getEventDetail(String id) =>
      apiService.getEventDetail(id);
  @override
  Future<MemberRehearsalDetail> getRehearsalDetail(String id) =>
      apiService.getRehearsalDetail(id);

  @override
  Future<List<LiturgicalDay>> getLiturgicalDays(
    String fromDate,
    String toDate,
  ) async {
    final from = DateTime.parse(fromDate);
    final to = DateTime.parse(toDate);
    if (to.isBefore(from) || to.difference(from).inDays >= 366) {
      throw const ValidationException(
        code: 'REPORT_DATE_RANGE_INVALID',
        message: 'Invalid date range.',
      );
    }
    return apiService.getLiturgicalDays(fromDate, toDate);
  }

  @override
  Future<LiturgicalDay?> getLiturgicalDay(String date) =>
      apiService.getLiturgicalDay(date);
  @override
  Future<PublicAppSettings> getPublicSettings() =>
      apiService.getPublicSettings();
  @override
  Future<List<RehearsalSong>> getRehearsalSongs(String id) =>
      apiService.getRehearsalSongs(id);
}

class MockCalendarRepositoryImpl implements CalendarRepository {
  @override
  Future<MemberEventDetail> getEventDetail(String id) async {
    final event = (await getEvents()).where((e) => e.id == id).firstOrNull;
    if (event == null) {
      throw const NotFoundException(code: 'LITURGICAL_EVENT_NOT_FOUND');
    }
    return MemberEventDetail(
      event: event,
      assignments: const [],
      rehearsals: const [],
    );
  }

  @override
  Future<MemberRehearsalDetail> getRehearsalDetail(String id) async {
    final rehearsal = (await getRehearsals())
        .where((e) => e.id == id)
        .firstOrNull;
    if (rehearsal == null) {
      throw const NotFoundException(code: 'REHEARSAL_NOT_FOUND');
    }
    return MemberRehearsalDetail(rehearsal: rehearsal, songs: const []);
  }

  @override
  Future<List<LiturgicalDay>> getLiturgicalDays(
    String fromDate,
    String toDate,
  ) async => [];
  @override
  Future<LiturgicalDay?> getLiturgicalDay(String date) async => null;
  @override
  Future<PublicAppSettings> getPublicSettings() async =>
      const PublicAppSettings(choirName: 'Harmonia');
  @override
  Future<List<RehearsalSong>> getRehearsalSongs(String id) async => const [];

  List<LiturgicalEvent> _events = List.from(MockCalendarData.events);
  final List<RehearsalSession> _rehearsals = List.from(
    MockCalendarData.rehearsals,
  );

  @override
  Future<LiturgicalEvent> getUpcomingEvent() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _events.first;
  }

  @override
  Future<List<LiturgicalEvent>> getEvents() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _events
        .map(
          (e) => e.copyWith(
            canRespond: e.participationStatus == ParticipationStatus.invited,
          ),
        )
        .toList();
  }

  @override
  Future<List<RehearsalSession>> getRehearsals() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _rehearsals;
  }

  @override
  Future<void> updateParticipation(
    String eventId,
    ParticipationStatus status,
  ) async {
    await Future.delayed(const Duration(milliseconds: 250));
    _events = _events.map((e) {
      if (e.id == eventId) {
        return e.copyWith(participationStatus: status);
      }
      return e;
    }).toList();
  }
}

final calendarApiServiceProvider = Provider<CalendarApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return CalendarApiService(client);
});

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  ref.watch(sessionManagerProvider.select((s) => s.sessionEpoch));
  if (AppEnv.useMock) {
    return MockCalendarRepositoryImpl();
  }
  final apiService = ref.watch(calendarApiServiceProvider);
  return CalendarRepositoryImpl(apiService: apiService);
});

class CalendarNotifier extends Notifier<AsyncValue<List<LiturgicalEvent>>> {
  int _generation = 0;
  final Map<String, Future<void>> _pending = {};

  @override
  AsyncValue<List<LiturgicalEvent>> build() {
    ref.watch(sessionManagerProvider.select((s) => s.sessionEpoch));
    _pending.clear();
    loadEvents();
    return const AsyncValue.loading();
  }

  Future<void> loadEvents() async {
    final generation = ++_generation;
    final session = ref.read(sessionManagerProvider);
    final epoch = session.sessionEpoch;
    state = const AsyncValue.loading();
    try {
      final list = await ref.read(calendarRepositoryProvider).getEvents();
      if (ref.mounted &&
          generation == _generation &&
          epoch == session.sessionEpoch) {
        state = AsyncValue.data(list);
      }
    } catch (error, stack) {
      if (ref.mounted &&
          generation == _generation &&
          epoch == session.sessionEpoch) {
        state = AsyncValue.error(error, stack);
      }
    }
  }

  Future<void> setParticipation(String eventId, ParticipationStatus status) {
    if (_pending.containsKey(eventId)) return _pending[eventId]!;
    final session = ref.read(sessionManagerProvider);
    final epoch = session.sessionEpoch;
    final repository = ref.read(calendarRepositoryProvider);
    late final Future<void> request;
    request = Future<void>.microtask(() async {
      try {
        await repository.updateParticipation(eventId, status);
        if (!ref.mounted || epoch != session.sessionEpoch) return;
        // Keep the acknowledged PUT visible; later reads always use the server.
        final events = state.value;
        if (events != null) {
          state = AsyncValue.data([
            for (final event in events)
              event.id == eventId
                  ? event.copyWith(
                      participationStatus: status,
                      canRespond: false,
                      cannotRespondReason:
                          'EVENT_PARTICIPATION_ALREADY_RESPONDED',
                    )
                  : event,
          ]);
        }
        ref.invalidate(eventDetailProvider(eventId));
        // Start a new generation so a GET started before PUT cannot restore Invited.
        await loadEvents();
      } catch (_) {
        if (ref.mounted && epoch == session.sessionEpoch) {
          ref.invalidate(eventDetailProvider(eventId));
          await loadEvents();
        }
        rethrow;
      } finally {
        if (identical(_pending[eventId], request)) _pending.remove(eventId);
      }
    });
    _pending[eventId] = request;
    return request;
  }
}

final calendarNotifierProvider =
    NotifierProvider<CalendarNotifier, AsyncValue<List<LiturgicalEvent>>>(
      CalendarNotifier.new,
    );

final rehearsalsProvider = FutureProvider<List<RehearsalSession>>((ref) {
  return ref.watch(calendarRepositoryProvider).getRehearsals();
});
final eventDetailProvider = FutureProvider.autoDispose
    .family<MemberEventDetail, String>((ref, id) {
      return ref.watch(calendarRepositoryProvider).getEventDetail(id);
    });
final rehearsalDetailProvider = FutureProvider.autoDispose
    .family<MemberRehearsalDetail, String>((ref, id) {
      return ref.watch(calendarRepositoryProvider).getRehearsalDetail(id);
    });
final publicAppSettingsProvider = FutureProvider<PublicAppSettings>((ref) {
  return ref.watch(calendarRepositoryProvider).getPublicSettings();
});
final liturgicalDayProvider = FutureProvider.autoDispose
    .family<LiturgicalDay?, String>((ref, date) {
      return ref.watch(calendarRepositoryProvider).getLiturgicalDay(date);
    });
typedef LiturgicalDateRange = ({String fromDate, String toDate});
final liturgicalDaysProvider = FutureProvider.autoDispose
    .family<List<LiturgicalDay>, LiturgicalDateRange>((ref, range) {
      return ref
          .watch(calendarRepositoryProvider)
          .getLiturgicalDays(range.fromDate, range.toDate);
    });
final rehearsalSongsProvider = FutureProvider.autoDispose
    .family<List<RehearsalSong>, String>((ref, id) {
      return ref.watch(calendarRepositoryProvider).getRehearsalSongs(id);
    });
