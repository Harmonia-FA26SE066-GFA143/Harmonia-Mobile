import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_env.dart';
import '../../../core/errors/app_exceptions.dart';
import 'liturgical_models.dart';
import 'mock_calendar_data.dart';

abstract class CalendarRepository {
  Future<LiturgicalEvent> getUpcomingEvent();
  Future<List<LiturgicalEvent>> getEvents();
  Future<List<RehearsalSession>> getRehearsals();
  Future<void> updateParticipation(String eventId, ParticipationStatus status);
}

class UnintegratedCalendarRepositoryImpl implements CalendarRepository {
  @override
  Future<LiturgicalEvent> getUpcomingEvent() async {
    throw const AppException(
      message: 'Tính năng Lịch phụng vụ chưa có API máy chủ.',
      code: 'FEATURE_UNINTEGRATED',
    );
  }

  @override
  Future<List<LiturgicalEvent>> getEvents() async {
    return const [];
  }

  @override
  Future<List<RehearsalSession>> getRehearsals() async {
    return const [];
  }

  @override
  Future<void> updateParticipation(
    String eventId,
    ParticipationStatus status,
  ) async {
    throw const AppException(
      message: 'Tính năng điểm danh chưa được kết nối máy chủ.',
      code: 'FEATURE_UNINTEGRATED',
    );
  }
}

class MockCalendarRepositoryImpl implements CalendarRepository {
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
    return _events;
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

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  if (AppEnv.useMock) {
    return MockCalendarRepositoryImpl();
  }
  return UnintegratedCalendarRepositoryImpl();
});

class CalendarNotifier extends Notifier<AsyncValue<List<LiturgicalEvent>>> {
  @override
  AsyncValue<List<LiturgicalEvent>> build() {
    loadEvents();
    return const AsyncValue.loading();
  }

  CalendarRepository get _repository => ref.read(calendarRepositoryProvider);

  Future<void> loadEvents() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repository.getEvents();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setParticipation(
    String eventId,
    ParticipationStatus status,
  ) async {
    await _repository.updateParticipation(eventId, status);
    await loadEvents();
  }
}

final calendarNotifierProvider =
    NotifierProvider<CalendarNotifier, AsyncValue<List<LiturgicalEvent>>>(
      CalendarNotifier.new,
    );
