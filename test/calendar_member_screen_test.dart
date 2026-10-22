import 'support/fake_calendar_repository.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_member_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/liturgical_models.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_repository.dart';
import 'package:harmonia_mobile/features/calendar/presentation/liturgical_event_detail_screen.dart';
import 'package:harmonia_mobile/features/calendar/presentation/rehearsal_detail_screen.dart';
import 'package:harmonia_mobile/features/calendar/presentation/participation_prompt.dart';
import 'package:harmonia_mobile/features/music/data/music_repository.dart';

import 'calendar_member_api_test.dart' show id, eventDetailJson, rehearsalJson;

class MemberScreenRepository extends MockCalendarRepositoryImpl {
  final eventResponses = <Completer<MemberEventDetail>>[];
  bool defer = false;
  bool failRehearsal = false;
  int writes = 0;
  @override
  Future<MemberEventDetail> getEventDetail(String eventId) {
    if (defer) {
      final response = Completer<MemberEventDetail>();
      eventResponses.add(response);
      return response.future;
    }
    return Future.value(MemberEventDetail.fromJson(eventDetailJson(eventId)));
  }

  @override
  Future<MemberRehearsalDetail> getRehearsalDetail(String id) async {
    if (failRehearsal) throw const NetworkException();
    return MemberRehearsalDetail.fromJson(rehearsalJson());
  }
}

class EpochCalendarRepository extends MockCalendarRepositoryImpl {
  final MemberScreenRepository source;
  EpochCalendarRepository(this.source);
  @override
  Future<MemberEventDetail> getEventDetail(String id) =>
      source.getEventDetail(id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('vi');
  });
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'event detail response from an old session cannot replace the next account',
    () async {
      final session = SessionManager(SecureStorageService());
      final repository = MemberScreenRepository()..defer = true;
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          calendarRepositoryProvider.overrideWith((ref) {
            ref.watch(sessionManagerProvider.select((s) => s.sessionEpoch));
            return EpochCalendarRepository(repository);
          }),
        ],
      );
      final subscription = container.listen(eventDetailProvider(id), (_, _) {});
      addTearDown(() {
        subscription.close();
        container.dispose();
        session.dispose();
      });
      container.read(eventDetailProvider(id));
      await Future<void>.delayed(Duration.zero);
      await session.endSession();
      await session.markAuthenticated();
      container.read(eventDetailProvider(id));
      await Future<void>.delayed(Duration.zero);
      expect(repository.eventResponses.length, 2);
      final latest = eventDetailJson(id)..['title'] = 'Account B event';
      repository.eventResponses[1].complete(MemberEventDetail.fromJson(latest));
      await Future<void>.delayed(Duration.zero);
      final previous = eventDetailJson(id)..['title'] = 'Account A event';
      repository.eventResponses[0].complete(
        MemberEventDetail.fromJson(previous),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(eventDetailProvider(id)).requireValue.event.title,
        'Account B event',
      );
    },
  );
  test(
    'a GET snapshot from before PUT cannot restore the invited state',
    () async {
      final session = SessionManager(SecureStorageService());
      final repository = DelayedScheduleRepository();
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          calendarRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() {
        container.dispose();
        session.dispose();
      });
      container.read(calendarNotifierProvider);
      final write = container
          .read(calendarNotifierProvider.notifier)
          .setParticipation(id, ParticipationStatus.confirmed);
      await write;
      repository.oldSnapshot.complete([repository.invited]);
      await Future<void>.delayed(Duration.zero);
      final event = container
          .read(calendarNotifierProvider)
          .requireValue
          .single;
      expect(event.participationStatus, ParticipationStatus.confirmed);
      expect(event.canRespond, isFalse);
    },
  );

  testWidgets(
    'rehearsal detail shows own attendance and sorted songs independently of upcoming schedule',
    (tester) async {
      final repo = MemberScreenRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [calendarRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: RehearsalDetailScreen(rehearsalId: 'reh-a'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Điểm danh: Có mặt'), findsOneWidget);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('First')).dy,
        lessThan(tester.getTopLeft(find.text('Second')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'rehearsal network error is retryable and never rendered as no record',
    (tester) async {
      final repo = MemberScreenRepository()..failRehearsal = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [calendarRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: RehearsalDetailScreen(rehearsalId: 'reh-a'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Điểm danh: Có mặt'), findsNothing);
      repo.failRehearsal = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Điểm danh: Có mặt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('no invitation prevents the confirmation dialog and write', (
    tester,
  ) async {
    final detail = MemberEventDetail.fromJson(eventDetailJson(id));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showParticipationPrompt(
                  context,
                  ref,
                  detail.event,
                  detail.event.participationStatus,
                ),
                child: const Text('Respond'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Respond'));
    await tester.pumpAndSettle();
    expect(
      find.text('Bạn chưa được mời tham gia sự kiện này.'),
      findsOneWidget,
    );
    expect(find.text('Gửi phản hồi'), findsNothing);
  });
  testWidgets(
    'event detail does not require membership in the upcoming event list',
    (tester) async {
      final repo = MemberScreenRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calendarRepositoryProvider.overrideWithValue(repo),
            eventApprovedSongListProvider(id).overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            home: LiturgicalEventDetailScreen(eventId: id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Published event'), findsOneWidget);
      expect(find.text('Sự kiện không có trong lịch sắp tới'), findsNothing);
      expect(find.text('Phân công của bạn'), findsOneWidget);
      expect(find.text('Test song'), findsOneWidget);
      final yesButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Có mặt'),
      );
      expect(yesButton.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}

class DelayedScheduleRepository extends MockCalendarRepositoryImpl {
  final oldSnapshot = Completer<List<LiturgicalEvent>>();
  int calls = 0;
  final invited = MemberEventDetail.fromJson(eventDetailJson(id)).event
      .copyWith(
        participationStatus: ParticipationStatus.invited,
        canRespond: true,
      );
  @override
  Future<List<LiturgicalEvent>> getEvents() {
    calls++;
    return calls == 1
        ? oldSnapshot.future
        : Future.value([
            invited.copyWith(
              participationStatus: ParticipationStatus.confirmed,
              canRespond: false,
            ),
          ]);
  }

  @override
  Future<void> updateParticipation(
    String id,
    ParticipationStatus status,
  ) async {}
}
