import 'dart:async' hide TimeoutException;
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/app/theme/app_theme.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/errors/error_messages.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/practice/data/practice_models.dart';
import 'package:harmonia_mobile/features/practice/data/practice_repository.dart';
import 'package:harmonia_mobile/features/practice/presentation/practice_detail_screen.dart';
import 'package:harmonia_mobile/features/practice/presentation/practice_submission_detail_screen.dart';

class RecordingRepository extends MockPracticeRepositoryImpl {
  Object? uploadError;
  Object? assignmentError;
  bool assignmentMissing = false;
  PracticeAssignment assignment = recordingAssignment();
  Completer<PracticeAssignment?>? assignmentPending;
  void Function()? onUpload;
  int uploads = 0;
  int detailCalls = 0;
  int assignmentCalls = 0;

  @override
  Future<PracticeAssignment?> getAssignmentDetail(String id) async {
    assignmentCalls++;
    if (assignmentError case final error?) throw error;
    if (assignmentMissing) return null;
    if (assignmentPending case final pending?) return pending.future;
    return assignment;
  }

  @override
  Future<PracticeSubmissionDetail?> getMySubmissionDetail(String id) async {
    detailCalls++;
    return PracticeSubmissionDetail(
      id: id,
      practiceAssignmentId: 'record-test',
      attemptNo: 1,
      submittedAt: DateTime(2026, 10, 16),
      status: 'Submitted',
      durationSeconds: 3,
      audioUrl: 'https://private.test/audio?token=revision-$detailCalls',
    );
  }

  @override
  Future<void> submitRecording({
    required String assignmentId,
    required String audioPath,
    required int durationSeconds,
  }) async {
    uploads++;
    onUpload?.call();
    if (uploadError case final error?) throw error;
  }

  @override
  Future<PagedList<PracticeSubmissionDetail>> getMySubmissionsPaged({
    String? assignmentId,
    int pageNumber = 1,
    int pageSize = 20,
  }) async => const PagedList(
    items: [],
    pageNumber: 1,
    pageSize: 20,
    totalCount: 0,
    totalPages: 0,
    hasPreviousPage: false,
    hasNextPage: false,
  );
}

PracticeAssignment recordingAssignment({
  bool? canSubmit = true,
  String? reason,
  bool isOverdue = false,
  PracticeStatus status = PracticeStatus.pending,
}) => PracticeAssignment(
  id: 'record-test',
  title: 'Bài tập kiểm thử',
  songTitle: 'Bài hát kiểm thử',
  instruction: 'Hướng dẫn kiểm thử',
  dueDate: isOverdue ? DateTime(2000) : DateTime(2030),
  vocalPart: 'Soprano',
  status: status,
  isOverdue: isOverdue,
  canSubmit: canSubmit,
  cannotSubmitReason: reason,
);

class RecordingSession extends SessionManager {
  RecordingSession() : super(SecureStorageService());
  int epoch = 0;
  @override
  int get sessionEpoch => epoch;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  const codec = StandardMethodCodec();
  late Directory temp;
  late RecordingRepository repository;
  late RecordingSession session;
  late List<String> recordCalls;
  late List<String> playerCalls;
  String? recordingPath;
  String? playerId;
  bool failPlayback = false;
  bool failPlayerStop = false;
  bool permissionGranted = true;
  Completer<Map<int, int>>? permissionPending;
  Completer<void>? playbackPending;

  void mock(String channel, Future<Object?> Function(MethodCall) handler) {
    messenger.setMockMethodCallHandler(MethodChannel(channel), handler);
  }

  void audioEvent(Map<String, Object> event) {
    binding.channelBuffers.push(
      'xyz.luan/audioplayers/events/$playerId',
      codec.encodeSuccessEnvelope(event),
      (_) {},
    );
  }

  setUp(() {
    temp = Directory.systemTemp.createTempSync('harmonia-recording-test-');
    repository = RecordingRepository();
    session = RecordingSession();
    addTearDown(session.dispose);
    recordCalls = [];
    playerCalls = [];
    recordingPath = null;
    playerId = null;
    failPlayback = false;
    failPlayerStop = false;
    permissionGranted = true;
    permissionPending = null;
    playbackPending = null;
    // Font metrics are irrelevant to audio flow tests; avoid network fetching.
    final fontAssets = {
      for (final weight in [
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
      ])
        'fonts/PlusJakartaSans-$weight.ttf': [
          {'asset': 'fonts/PlusJakartaSans-$weight.ttf'},
        ],
    };
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = const StringCodec().decodeMessage(message)!;
      if (key == 'AssetManifest.bin') {
        return const StandardMessageCodec().encodeMessage(fontAssets);
      }
      if (key.startsWith('fonts/PlusJakartaSans-')) return ByteData(0);
      return null;
    });
    mock('flutter.baseflow.com/permissions/methods', (call) async {
      if (call.method == 'requestPermissions') {
        return permissionPending?.future ?? {7: permissionGranted ? 1 : 0};
      }
      return 1;
    });
    mock('plugins.flutter.io/path_provider', (_) async => temp.path);
    mock('com.llfbandit.record/messages', (call) async {
      recordCalls.add(call.method);
      final args = call.arguments as Map?;
      if (call.method == 'create') {
        mock(
          'com.llfbandit.record/events/${args!['recorderId']}',
          (_) async => null,
        );
      }
      if (call.method == 'hasPermission') return true;
      if (call.method == 'start') {
        recordingPath = args!['path'] as String;
        File(recordingPath!).writeAsBytesSync(List.filled(64, 1));
      }
      if (call.method == 'stop') return recordingPath;
      return null;
    });
    mock('xyz.luan/audioplayers.global', (_) async => null);
    mock('xyz.luan/audioplayers.global/events', (_) async => null);
    mock('xyz.luan/audioplayers', (call) async {
      playerCalls.add(call.method);
      if (call.method == 'create') {
        playerId = (call.arguments as Map)['playerId'] as String;
        mock('xyz.luan/audioplayers/events/$playerId', (_) async => null);
      }
      if (call.method == 'setSourceUrl') {
        audioEvent({'event': 'audio.onPrepared', 'value': true});
        if (playbackPending != null) await playbackPending!.future;
        if (failPlayback) {
          throw PlatformException(
            code: 'decode',
            message: 'private://audio?token=secret',
          );
        }
      }
      if (call.method == 'stop' && failPlayerStop) {
        throw PlatformException(
          code: 'stop',
          message: 'private://audio?token=secret',
        );
      }
      if (call.method == 'getDuration' || call.method == 'getCurrentPosition') {
        return 1000;
      }
      return null;
    });
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<void> open(
    WidgetTester tester, {
    Widget? screen,
    Object? detailError,
    PracticeSubmissionDetail? submission,
    bool overrideSubmission = true,
    PracticeStatus assignmentStatus = PracticeStatus.pending,
    bool? canSubmit = true,
    String? reason,
    bool isOverdue = false,
    bool useAppTheme = false,
  }) async {
    repository.assignment = recordingAssignment(
      canSubmit: assignmentStatus == PracticeStatus.passed ? false : canSubmit,
      reason: assignmentStatus == PracticeStatus.passed
          ? 'PRACTICE_SUBMISSION_ALREADY_PASSED'
          : reason,
      isOverdue: isOverdue,
      status: assignmentStatus,
    );
    await tester.runAsync(() => AudioPlayer.global.ensureInitialized());
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(() async {
      failPlayerStop = false;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceRepositoryProvider.overrideWithValue(repository),
          sessionManagerProvider.overrideWithValue(session),
          practiceDetailProvider('record-test').overrideWith((ref) async {
            if (detailError != null) throw detailError;
            return repository.getAssignmentDetail('record-test');
          }),
          if (screen != null && overrideSubmission)
            mySubmissionDetailProvider('submission-test')
                .overrideWith((ref) async {
                  if (detailError != null) throw detailError;
                  return submission;
                }),
        ],
        child: MaterialApp(
          theme: useAppTheme ? AppTheme.lightTheme : null,
          home: const Scaffold(body: Text('Entry')),
          initialRoute: '/record',
          routes: {
            '/record': (_) =>
                screen ??
                const PracticeDetailScreen(assignmentId: 'record-test'),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    final mic = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == 'Bắt đầu thu âm',
    );
    await tester.ensureVisible(mic);
    await tester.tap(mic);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> draft(WidgetTester tester) async {
    await start(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Dừng thu âm',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bản thu nháp'), findsOneWidget);
  }

  Future<void> close(WidgetTester tester) async {
    failPlayerStop = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets('backgrounding stops recording and retains a draft', (
    tester,
  ) async {
    await open(tester);
    await start(tester);
    expect(find.text('Đang thu âm...'), findsOneWidget);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(recordCalls, contains('stop'));
    expect(find.text('Bản thu nháp'), findsOneWidget);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await close(tester);
  });

  testWidgets('microphone denial never starts recorder', (tester) async {
    permissionGranted = false;
    await open(tester);
    await start(tester);
    expect(recordCalls, isNot(contains('start')));
    expect(
      find.text('Ứng dụng cần quyền Micro để thực hiện thu âm bài tập.'),
      findsOneWidget,
    );
    await close(tester);
  });

  testWidgets('passed assignment cannot start a new recording', (tester) async {
    await open(tester, assignmentStatus: PracticeStatus.passed);
    await start(tester);
    expect(recordCalls, isNot(contains('start')));
    expect(
      find.text('Bài tập này đã đạt yêu cầu, không thể nộp lại.'),
      findsOneWidget,
    );
    await close(tester);
  });

  for (final reason in [
    'PRACTICE_SUBMISSION_PAST_DUE',
    'FUTURE_REASON_PRIVATE_DETAIL',
    null,
  ]) {
    testWidgets('server denial blocks microphone: $reason', (tester) async {
      await open(tester, canSubmit: false, reason: reason, isOverdue: true);
      await start(tester);
      expect(recordCalls, isNot(contains('start')));
      expect(
        find.text(
          reason == 'PRACTICE_SUBMISSION_PAST_DUE'
              ? 'Bài tập đã quá hạn nộp.'
              : 'Hiện bạn chưa được phép nộp bản thu cho bài tập này.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('FUTURE_REASON_PRIVATE_DETAIL'), findsNothing);
      await close(tester);
    });
  }

  testWidgets('missing capability blocks recording with reload guidance', (
    tester,
  ) async {
    await open(tester, canSubmit: null);
    await start(tester);
    expect(recordCalls, isNot(contains('start')));
    expect(
      find.text('Chưa xác minh được quyền nộp bản thu. Vui lòng tải lại.'),
      findsOneWidget,
    );
    repository.assignment = recordingAssignment();
    await tester.tap(find.byTooltip('Tải lại bài tập'));
    await tester.pumpAndSettle();
    await start(tester);
    expect(recordCalls, contains('start'));
    await close(tester);
  });

  testWidgets('server permits an overdue recording and submission', (
    tester,
  ) async {
    await open(tester, isOverdue: true);
    await draft(tester);
    final callsBeforeSubmit = repository.assignmentCalls;
    final submit = find.text('Nộp bản thu cho Ca trưởng');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(repository.assignmentCalls, greaterThan(callsBeforeSubmit));
    expect(repository.uploads, 1);
    expect(find.text('Đã nộp bản thu thành công!'), findsOneWidget);
    await close(tester);
  });

  testWidgets('permission revoked during mic dialog prevents recording', (
    tester,
  ) async {
    permissionPending = Completer<Map<int, int>>();
    await open(tester);
    await start(tester);
    repository.assignment = recordingAssignment(
      canSubmit: false,
      reason: 'PRACTICE_SUBMISSION_ALREADY_PASSED',
    );
    ProviderScope.containerOf(tester.element(find.byType(PracticeDetailScreen)))
        .invalidate(practiceDetailProvider('record-test'));
    await tester.pumpAndSettle();
    permissionPending!.complete({7: 1});
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(recordCalls, isNot(contains('start')));
    await close(tester);
  });

  testWidgets('revoked permission preserves draft and blocks stale submit', (
    tester,
  ) async {
    await open(tester);
    await draft(tester);
    repository.assignment = recordingAssignment(
      canSubmit: false,
      reason: 'PRACTICE_SUBMISSION_ALREADY_PASSED',
      status: PracticeStatus.passed,
    );
    final submit = find.text('Nộp bản thu cho Ca trưởng');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(repository.uploads, 0);
    expect(File(recordingPath!).existsSync(), isTrue);
    expect(find.text('Bản thu nháp'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.ancestor(of: submit, matching: find.byType(ElevatedButton)),
          )
          .onPressed,
      isNull,
    );
    final play = find.widgetWithIcon(IconButton, Icons.play_arrow_rounded);
    await tester.ensureVisible(play);
    await tester.tap(play);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(playerCalls, contains('setSourceUrl'));
    await close(tester);
  });

  testWidgets('preflight failure keeps draft and reload allows retry', (
    tester,
  ) async {
    await open(tester);
    await draft(tester);
    repository.assignmentError = const TimeoutException();
    final submit = find.text('Nộp bản thu cho Ca trưởng');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(repository.uploads, 0);
    expect(File(recordingPath!).existsSync(), isTrue);
    expect(find.text('Bản thu nháp'), findsOneWidget);
    repository.assignmentError = null;
    await tester.tap(find.byTooltip('Tải lại bài tập'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(repository.uploads, 1);
    await close(tester);
  });

  testWidgets('session change during preflight never uploads old draft', (
    tester,
  ) async {
    await open(tester);
    await draft(tester);
    repository.assignmentPending = Completer<PracticeAssignment?>();
    final submit = find.text('Nộp bản thu cho Ca trưởng');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    session.epoch++;
    repository.assignmentPending!.complete(repository.assignment);
    await tester.pumpAndSettle();
    expect(repository.uploads, 0);
    expect(find.text('Đã nộp bản thu thành công!'), findsNothing);
    expect(File(recordingPath!).existsSync(), isTrue);
    await close(tester);
  });

  testWidgets(
    'server rejection after preflight refreshes permission and keeps draft',
    (tester) async {
      await open(tester);
      await draft(tester);
      repository.onUpload = () {
        repository.assignment = recordingAssignment(
          canSubmit: false,
          reason: 'PRACTICE_SUBMISSION_PAST_DUE',
        );
      };
      repository.uploadError = const ConflictException(
        code: 'PRACTICE_SUBMISSION_PAST_DUE',
      );
      final submit = find.text('Nộp bản thu cho Ca trưởng');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(repository.uploads, 1);
      expect(find.text('Bài tập đã quá hạn nộp.'), findsWidgets);
      expect(File(recordingPath!).existsSync(), isTrue);
      expect(find.text('Bản thu nháp'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.ancestor(of: submit, matching: find.byType(ElevatedButton)),
            )
            .onPressed,
        isNull,
      );
      await close(tester);
    },
  );

  testWidgets('permission result after leaving screen never starts recorder', (
    tester,
  ) async {
    permissionPending = Completer<Map<int, int>>();
    await open(tester);
    await start(tester);
    await close(tester);
    permissionPending!.complete({7: 1});
    await tester.pumpAndSettle();
    expect(recordCalls, isNot(contains('start')));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing assignment after preflight keeps draft controls accessible',
    (tester) async {
      await open(tester);
      await draft(tester);
      repository.assignmentMissing = true;
      final submit = find.text('Nộp bản thu cho Ca trưởng');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(repository.uploads, 0);
      expect(File(recordingPath!).existsSync(), isTrue);
      expect(find.text('Bản thu nháp'), findsOneWidget);
      expect(find.byTooltip('Tải lại bài tập'), findsOneWidget);
      expect(find.text('Bỏ bản nháp'), findsOneWidget);
      final play = find.widgetWithIcon(IconButton, Icons.play_arrow_rounded);
      await tester.ensureVisible(play);
      await tester.tap(play);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(playerCalls, contains('setSourceUrl'));
      await close(tester);
    },
  );

  testWidgets('revoked permission never prevents stopping active recording', (
    tester,
  ) async {
    await open(tester);
    await start(tester);
    repository.assignment = recordingAssignment(
      canSubmit: false,
      reason: 'PRACTICE_SUBMISSION_PAST_DUE',
    );
    ProviderScope.containerOf(tester.element(find.byType(PracticeDetailScreen)))
        .invalidate(practiceDetailProvider('record-test'));
    await tester.pump();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Dừng thu âm',
      ),
    );
    await tester.pumpAndSettle();
    expect(recordCalls, contains('stop'));
    expect(find.text('Bản thu nháp'), findsOneWidget);
    await close(tester);
  });

  testWidgets('preview failure keeps draft and hides technical details', (
    tester,
  ) async {
    await open(tester);
    await draft(tester);
    failPlayback = true;
    final play = find.widgetWithIcon(IconButton, Icons.play_arrow_rounded);
    await tester.ensureVisible(play);
    await tester.tap(play);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.text('Không thể nghe lại bản thu. Bản nháp vẫn được giữ lại.'),
      findsOneWidget,
    );
    expect(find.text('Bản thu nháp'), findsOneWidget);
    expect(find.textContaining('private://'), findsNothing);
    await close(tester);
  });

  testWidgets('draft controls fit the production button theme', (tester) async {
    await open(tester, useAppTheme: true);
    tester.view.physicalSize = const Size(393, 852);
    await tester.pumpAndSettle();
    await draft(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Thu lại'), findsOneWidget);
    expect(find.text('Nộp bản thu cho Ca trưởng'), findsOneWidget);
    repository.assignment = recordingAssignment(
      canSubmit: false,
      reason: 'PRACTICE_SUBMISSION_PAST_DUE',
    );
    ProviderScope.containerOf(tester.element(find.byType(PracticeDetailScreen)))
        .invalidate(practiceDetailProvider('record-test'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Bỏ bản nháp'), findsOneWidget);
    await close(tester);
  });

  testWidgets('preview finishing preparation in background stays paused', (
    tester,
  ) async {
    await open(tester);
    await draft(tester);
    playbackPending = Completer<void>();
    final play = find.widgetWithIcon(IconButton, Icons.play_arrow_rounded);
    await tester.ensureVisible(play);
    await tester.tap(play);
    await tester.pump(const Duration(milliseconds: 100));
    expect(playerCalls, contains('setSourceUrl'));
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    playbackPending!.complete();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(playerCalls, contains('pause'));
    expect(find.widgetWithIcon(IconButton, Icons.pause_rounded), findsNothing);
    await close(tester);
  });

  testWidgets('failed upload keeps draft and allows retry', (tester) async {
    repository.uploadError = const ServerException(
      code: 'EXTERNAL_STORAGE_FAILED',
    );
    await open(tester);
    await draft(tester);
    final submit = find.text('Nộp bản thu cho Ca trưởng');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(repository.uploads, 1);
    expect(File(recordingPath!).existsSync(), isTrue);
    expect(find.text('Bản thu nháp'), findsOneWidget);
    expect(find.text('Đã nộp bản thu thành công!'), findsNothing);
    await tester.tap(submit);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(repository.uploads, 2);
    await close(tester);
  });

  testWidgets('leaving a draft requires confirmation and cancel preserves it', (
    tester,
  ) async {
    await open(tester);
    await draft(tester);
    await tester.runAsync(() => binding.handlePopRoute());
    await tester.pumpAndSettle();
    expect(find.text('Bỏ bản thu nháp?'), findsOneWidget);
    await tester.tap(find.text('Ở lại'));
    await tester.pumpAndSettle();
    expect(find.text('Bản thu nháp'), findsOneWidget);
    expect(File(recordingPath!).existsSync(), isTrue);
    await tester.runAsync(() => binding.handlePopRoute());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Bỏ bản thu'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Entry'), findsOneWidget);
    expect(File(recordingPath!).existsSync(), isFalse);
    await close(tester);
  });

  testWidgets('player stop failure releases submit state and preserves draft', (
    tester,
  ) async {
    await open(tester);
    await draft(tester);
    final play = find.widgetWithIcon(IconButton, Icons.play_arrow_rounded);
    await tester.ensureVisible(play);
    await tester.tap(play);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(playerCalls, contains('setSourceUrl'));
    expect(
      find.widgetWithIcon(IconButton, Icons.pause_rounded),
      findsOneWidget,
    );
    failPlayerStop = true;
    final submit = find.text('Nộp bản thu cho Ca trưởng');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.text('Đang gửi bản thu...'), findsNothing);
    expect(find.text('Bản thu nháp'), findsOneWidget);
    expect(repository.uploads, 0);
    await close(tester);
  });

  for (final submission in [false, true]) {
    testWidgets(
      '${submission ? 'submission' : 'assignment'} load error hides raw exception',
      (tester) async {
        await open(
          tester,
          detailError: Exception('https://private.test/audio?token=secret'),
          screen: submission
              ? const PracticeSubmissionDetailScreen(
                  submissionId: 'submission-test',
                )
              : null,
        );
        expect(find.textContaining('token=secret'), findsNothing);
        expect(find.text('Thử lại'), findsOneWidget);
        await close(tester);
      },
    );
  }

  for (final status in ['Submitted', 'Passed', 'NeedsRevision']) {
    testWidgets('submission $status shows the correct feedback state', (
      tester,
    ) async {
      await open(
        tester,
        screen: const PracticeSubmissionDetailScreen(
          submissionId: 'submission-test',
        ),
        submission: PracticeSubmissionDetail(
          id: 'submission-test',
          practiceAssignmentId: 'record-test',
          attemptNo: 2,
          submittedAt: DateTime(2026, 10, 16),
          status: status,
          durationSeconds: 3,
          feedbacks: status == 'Submitted'
              ? []
              : [
                  PracticeFeedbackItem(
                    id: 'feedback',
                    result: status,
                    comment: 'Nhận xét kiểm thử',
                    reviewerName: 'Ca trưởng kiểm thử',
                  ),
                ],
        ),
      );
      expect(
        find.text(
          status == 'Passed'
              ? 'Đạt yêu cầu'
              : status == 'NeedsRevision'
              ? 'Cần luyện thêm'
              : 'Đã nộp • Chờ chấm',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Nhận xét kiểm thử'),
        status == 'Submitted' ? findsNothing : findsOneWidget,
      );
      await close(tester);
    });
  }

  testWidgets('each playback retry fetches a fresh URL and hides SDK errors', (
    tester,
  ) async {
    failPlayback = true;
    await open(
      tester,
      screen: const PracticeSubmissionDetailScreen(
        submissionId: 'submission-test',
      ),
      overrideSubmission: false,
    );
    expect(repository.detailCalls, 1);
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.play_arrow_rounded),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(repository.detailCalls, 2 + attempt);
      expect(find.textContaining('token='), findsNothing);
      expect(tester.takeException(), isNull);
    }
    expect(
      find.text(
        'Không thể phát bản thu. Vui lòng thử lại để lấy liên kết mới.',
      ),
      findsWidgets,
    );
    await close(tester);
  });

  test('storage failure is translated without the server detail', () {
    expect(
      ErrorMessages.forException(
        const ServerException(
          code: 'EXTERNAL_STORAGE_FAILED',
          message: 'Cloudinary provider detail',
        ),
      ),
      'Dịch vụ lưu trữ đang gặp sự cố. Vui lòng thử lại sau.',
    );
  });
}
