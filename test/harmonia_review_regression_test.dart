import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/network/auth_interceptor.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_dto.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_repository.dart';
import 'package:harmonia_mobile/features/notifications/presentation/notification_notifier.dart';
import 'package:harmonia_mobile/features/practice/data/practice_models.dart';
import 'package:harmonia_mobile/features/practice/data/practice_repository.dart';
import 'package:harmonia_mobile/features/profile/data/profile_models.dart';
import 'package:harmonia_mobile/features/profile/data/profile_repository.dart';

class MockNotificationRepoWithFailure implements NotificationRepository {
  final _controller = StreamController<NotificationDto>.broadcast();
  List<NotificationDto> items = [
    NotificationDto(
      id: '00000000-0000-0000-0000-000000000001',
      type: NotificationType.weekPublished,
      title: 'Thông báo lễ',
      content: 'Nội dung thông báo lễ',
      createdAt: DateTime.now(),
      isRead: false,
    ),
  ];
  bool failMarkAll = false;
  int unreadCountOverride = -1;
  bool failUnreadCount = false;
  Completer<void>? markAllCompleter;

  @override
  Stream<NotificationDto> get realtimeNotifications => _controller.stream;

  void emitRealtime(NotificationDto dto) {
    _controller.add(dto);
  }

  @override
  Future<PagedList<NotificationDto>> getNotifications({
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    return PagedList<NotificationDto>(
      items: List.from(items),
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: items.length,
      totalPages: 1,
      hasPreviousPage: false,
      hasNextPage: false,
    );
  }

  @override
  Future<int> getUnreadCount() async {
    if (failUnreadCount) throw Exception('Network offline');
    if (unreadCountOverride >= 0) return unreadCountOverride;
    return items.where((n) => !n.isRead).length;
  }

  @override
  Future<void> markAsRead(String id) async {
    items = items
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
  }

  @override
  Future<void> markAllAsRead() async {
    if (markAllCompleter != null) {
      await markAllCompleter!.future;
    }
    if (failMarkAll) {
      throw Exception('Server error marking all as read');
    }
    items = items.map((n) => n.copyWith(isRead: true)).toList();
  }

  void dispose() {
    _controller.close();
  }
}

class TestErrorHandler extends ErrorInterceptorHandler {
  DioException? error;
  Response? resolvedResponse;
  bool nextCalled = false;
  bool resolveCalled = false;

  @override
  void next(DioException err) {
    error = err;
    nextCalled = true;
  }

  @override
  void resolve(Response response) {
    resolvedResponse = response;
    resolveCalled = true;
  }

  @override
  void reject(DioException err, [bool? tryNext]) {
    error = err;
  }
}

class FakeProfileRepository implements ProfileRepository {
  List<MemberSkill> skills = [];
  bool failNextPage = false;
  int getSkillsPagedCallCount = 0;
  Completer<void>? loadCompleter;

  @override
  Future<PagedList<MemberSkill>> getSkillsPaged({
    String? status,
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    getSkillsPagedCallCount++;
    if (loadCompleter != null) {
      await loadCompleter!.future;
    }
    if (failNextPage && pageNumber > 1) {
      throw Exception('Network error on page $pageNumber');
    }
    List<MemberSkill> filtered = skills;
    if (status != null && status.isNotEmpty) {
      filtered = skills
          .where((s) => s.status.name.toLowerCase() == status.toLowerCase())
          .toList();
    }
    final startIndex = (pageNumber - 1) * pageSize;
    final items = startIndex < filtered.length
        ? filtered.skip(startIndex).take(pageSize).toList()
        : <MemberSkill>[];
    final totalPages = (filtered.length / pageSize).ceil();
    final hasNext = pageNumber < totalPages;
    return PagedList<MemberSkill>(
      items: items,
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: filtered.length,
      totalPages: totalPages > 0 ? totalPages : 1,
      hasPreviousPage: pageNumber > 1,
      hasNextPage: hasNext,
    );
  }

  @override
  Future<List<MemberSkill>> getSkills({
    String? status,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    final paged = await getSkillsPaged(
      status: status,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
    return paged.items;
  }

  @override
  Future<MemberProfileDto> getProfile() => throw UnimplementedError();
  @override
  Future<MemberProfileDto> updateProfile(
    UpdateMyMemberProfileRequest request,
  ) => throw UnimplementedError();
  @override
  Future<MemberSkill?> getSkillById(String id) => throw UnimplementedError();
  @override
  Future<void> declareNewSkill({
    required String skillId,
    String? level,
    String? name,
    String? categoryName,
    String? note,
  }) => throw UnimplementedError();
  @override
  Future<PagedList<ParticipationHistoryDto>> getParticipationHistory({
    String? liturgicalSeasonId,
    String? fromDate,
    String? toDate,
    int pageNumber = 1,
    int pageSize = 20,
  }) => throw UnimplementedError();
}

class FakePracticeRepository implements PracticeRepository {
  List<PracticeSubmissionDetail> submissions = [];
  bool failNextPage = false;
  int getSubmissionsPagedCallCount = 0;
  Completer<void>? loadCompleter;

  @override
  Future<PagedList<PracticeSubmissionDetail>> getMySubmissionsPaged({
    String? assignmentId,
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    getSubmissionsPagedCallCount++;
    if (loadCompleter != null) {
      await loadCompleter!.future;
    }
    if (failNextPage && pageNumber > 1) {
      throw Exception('Network error on page $pageNumber');
    }
    final filtered = assignmentId != null
        ? submissions
              .where((s) => s.practiceAssignmentId == assignmentId)
              .toList()
        : submissions;
    final startIndex = (pageNumber - 1) * pageSize;
    final items = startIndex < filtered.length
        ? filtered.skip(startIndex).take(pageSize).toList()
        : <PracticeSubmissionDetail>[];
    final totalPages = (filtered.length / pageSize).ceil();
    final hasNext = pageNumber < totalPages;
    return PagedList<PracticeSubmissionDetail>(
      items: items,
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: filtered.length,
      totalPages: totalPages > 0 ? totalPages : 1,
      hasPreviousPage: pageNumber > 1,
      hasNextPage: hasNext,
    );
  }

  @override
  Future<List<PracticeSubmissionDetail>> getMySubmissions({
    String? assignmentId,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    final paged = await getMySubmissionsPaged(
      assignmentId: assignmentId,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
    return paged.items;
  }

  @override
  Future<List<PracticeAssignment>> getAssignments({
    bool? isOpen,
    String? status,
    bool? hasSubmission,
    int pageNumber = 1,
    int pageSize = 50,
  }) => throw UnimplementedError();
  @override
  Future<PagedList<PracticeAssignment>> getAssignmentsPaged({
    bool? isOpen,
    String? status,
    bool? hasSubmission,
    int pageNumber = 1,
    int pageSize = 50,
  }) => throw UnimplementedError();
  @override
  Future<PracticeAssignment?> getAssignmentDetail(String id) =>
      throw UnimplementedError();
  @override
  Future<void> submitRecording({
    required String assignmentId,
    required String audioPath,
    required int durationSeconds,
  }) => throw UnimplementedError();
  @override
  Future<PracticeCounts> getMyAssignmentCounts() => throw UnimplementedError();
  @override
  Future<PracticeSubmissionDetail?> getMySubmissionDetail(String id) =>
      throw UnimplementedError();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Mục 2: Cấp độ kỹ năng (Enum, Mapping, WireName, Detail)', () {
    test('SkillLevel wireName and Vietnamese labels map correctly', () {
      expect(SkillLevel.beginner.wireName, 'Beginner');
      expect(SkillLevel.beginner.label, 'Sơ cấp');

      expect(SkillLevel.intermediate.wireName, 'Intermediate');
      expect(SkillLevel.intermediate.label, 'Trung cấp');

      expect(SkillLevel.advanced.wireName, 'Advanced');
      expect(SkillLevel.advanced.label, 'Nâng cao');
    });

    test(
      'SkillLevel.fromWire parses case-insensitively and handles invalid',
      () {
        expect(SkillLevel.fromWire('Beginner'), SkillLevel.beginner);
        expect(SkillLevel.fromWire('intermediate'), SkillLevel.intermediate);
        expect(SkillLevel.fromWire('ADVANCED'), SkillLevel.advanced);
        expect(SkillLevel.fromWire('UnknownLevel'), isNull);
        expect(SkillLevel.fromWire(null), isNull);
      },
    );

    test('MemberSkill.levelLabel handles valid, unknown, and null levels', () {
      final skillValid = MemberSkill(
        id: '00000000-0000-0000-0000-000000000001',
        skillId: '00000000-0000-0000-0000-000000000002',
        name: 'Thanh nhạc',
        categoryName: 'Hát',
        level: 'Intermediate',
        status: SkillApprovalStatus.approved,
      );
      expect(skillValid.levelLabel, 'Trung cấp');

      final skillNull = MemberSkill(
        id: '00000000-0000-0000-0000-000000000003',
        skillId: '00000000-0000-0000-0000-000000000004',
        name: 'Đệm đàn',
        categoryName: 'Nhạc cụ',
        level: null,
        status: SkillApprovalStatus.approved,
      );
      expect(skillNull.levelLabel, 'Chưa xếp');

      final skillUnknown = MemberSkill(
        id: '00000000-0000-0000-0000-000000000005',
        skillId: '00000000-0000-0000-0000-000000000006',
        name: 'Chỉ huy',
        categoryName: 'Điều hành',
        level: 'ExpertLevel',
        status: SkillApprovalStatus.pending,
      );
      expect(skillUnknown.levelLabel, 'Chưa xác định');
    });
  });

  group('Mục 3: Bộ lọc Chưa nộp & hasSubmission', () {
    test(
      'MockPracticeRepositoryImpl filters hasSubmission=false properly',
      () async {
        final repo = MockPracticeRepositoryImpl();

        final notSubmittedList = await repo.getAssignments(
          hasSubmission: false,
        );
        for (final a in notSubmittedList) {
          expect(a.status, PracticeStatus.pending);
        }

        final submittedList = await repo.getAssignments(hasSubmission: true);
        for (final a in submittedList) {
          expect(a.status, isNot(PracticeStatus.pending));
        }
      },
    );

    test(
      'PracticeListNotifier sends hasSubmissionFilter without Pending status',
      () async {
        final repo = MockPracticeRepositoryImpl();
        final container = ProviderContainer(
          overrides: [practiceRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(practiceListNotifierProvider.notifier);
        await notifier.loadAssignments(hasSubmissionFilter: false);

        final state = container
            .read(practiceListNotifierProvider)
            .asData
            ?.value;
        expect(state, isNotNull);
        expect(state!.items.isNotEmpty, isTrue);
        for (final a in state.items) {
          expect(a.status, PracticeStatus.pending);
        }
      },
    );
  });

  group('Mục 4: AuthInterceptor vòng đời & Cách ly phiên', () {
    test('Request from old session A returning 401 does not refresh or corrupt session B', () async {
      final storage = SecureStorageService();
      final sessionManager = SessionManager(storage);

      int refreshCallCount = 0;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/api/auth/refresh')) {
              refreshCallCount++;
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'accessToken': 'new-b-access',
                    'refreshToken': 'new-b-refresh',
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final interceptor = AuthInterceptor(
        storage: storage,
        sessionManager: sessionManager,
        dio: dio,
      );

      // Session A: Login as User A (epoch 1)
      await storage.saveTokens(
        accessToken: 'token-user-a',
        refreshToken: 'refresh-user-a',
        expiresAt: DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      );
      await storage.saveUser(
        id: 'user-a-guid',
        email: 'usera@example.com',
        roleName: 'ChoirMember',
      );
      await sessionManager.initialize();
      expect(sessionManager.sessionEpoch, 1);

      // Request A was dispatched under Session A
      final requestOptionsA = RequestOptions(
        path: '/api/practice-assignments/mine',
        headers: {'Authorization': 'Bearer token-user-a'},
        extra: {'sessionEpoch': 1},
      );

      // User A logs out and User B logs in (epoch 2)
      await storage.clearAll();
      await sessionManager.endSession();
      await storage.saveTokens(
        accessToken: 'token-user-b',
        refreshToken: 'refresh-user-b',
        expiresAt: DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      );
      await storage.saveUser(
        id: 'user-b-guid',
        email: 'userb@example.com',
        roleName: 'ChoirMember',
      );
      await sessionManager.initialize();
      expect(
        sessionManager.sessionEpoch,
        3,
      ); // incremented on endSession and initialize

      // Response for Request A arrives with 401
      final dioExceptionA = DioException(
        requestOptions: requestOptionsA,
        response: Response(requestOptions: requestOptionsA, statusCode: 401),
        type: DioExceptionType.badResponse,
      );

      final handlerA = TestErrorHandler();
      await interceptor.onError(dioExceptionA, handlerA);

      // Refresh for Session B MUST NOT have been triggered by request A
      expect(refreshCallCount, 0);
      expect(handlerA.nextCalled, isTrue);

      // Session B's tokens must remain intact
      final currentAccess = await storage.getAccessToken();
      expect(currentAccess, 'token-user-b');
      expect(sessionManager.isAuthenticated, isTrue);
    });

    test(
      'Temporary network error (timeout/503) does not log out user',
      () async {
        final storage = SecureStorageService();
        final sessionManager = SessionManager(storage);

        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path.contains('/api/auth/refresh')) {
                return handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionTimeout,
                    message: 'Connection timeout',
                  ),
                );
              }
              return handler.next(options);
            },
          ),
        );

        final interceptor = AuthInterceptor(
          storage: storage,
          sessionManager: sessionManager,
          dio: dio,
        );

        await storage.saveTokens(
          accessToken: 'initial-access',
          refreshToken: 'initial-refresh',
          expiresAt: DateTime.now()
              .add(const Duration(hours: 1))
              .toIso8601String(),
        );
        await storage.saveUser(
          id: 'user-initial-guid',
          email: 'user@example.com',
          roleName: 'ChoirMember',
        );
        await sessionManager.initialize();

        final requestOptions = RequestOptions(
          path: '/api/notifications',
          headers: {'Authorization': 'Bearer initial-access'},
          extra: {'sessionEpoch': sessionManager.sessionEpoch},
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          response: Response(requestOptions: requestOptions, statusCode: 401),
          type: DioExceptionType.badResponse,
        );

        final handler = TestErrorHandler();
        await interceptor.onError(dioException, handler);

        // User must still be authenticated despite temporary network failure
        expect(sessionManager.isAuthenticated, isTrue);
        expect(await storage.getAccessToken(), 'initial-access');
      },
    );
  });

  group('Mục 5 & 6: ApiClient stability & Notification rollback double-count', () {
    test('apiClientProvider does not recreate when SessionManager notifies listeners', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final client1 = container.read(apiClientProvider);

      // Notify SessionManager listener (e.g. password change required updated)
      container
          .read(sessionManagerProvider.notifier)
          .markPasswordChangeRequired(false);

      final client2 = container.read(apiClientProvider);

      expect(identical(client1, client2), isTrue);
    });

    test('markAllAsRead failure after pull-to-refresh does NOT double-count unread badge', () async {
      final mockRepo = MockNotificationRepoWithFailure();
      mockRepo.failMarkAll = true;

      final container = ProviderContainer(
        overrides: [notificationRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(() {
        mockRepo.dispose();
        container.dispose();
      });

      // Load initial state: 1 unread notification
      await container.read(notificationNotifierProvider.notifier).refresh();
      expect(container.read(notificationNotifierProvider).unreadCount, 1);

      // User clicks "Mark all as read"
      final markFuture = container
          .read(notificationNotifierProvider.notifier)
          .markAllAsRead();

      // Pull-to-refresh arrives while request is in-flight, receiving unreadCount = 1
      await container.read(notificationNotifierProvider.notifier).refresh();

      // Wait for markAllAsRead to fail and rollback
      await markFuture;

      // Rollback must NOT add duplicate count (result must be 1, not 2)
      final stateAfter = container.read(notificationNotifierProvider);
      expect(stateAfter.unreadCount, 1);
    });
  });

  group('Mục 7: Phân trang & Chống trùng lặp', () {
    test('PracticeListNotifier loadMore increments page on success and deduplicates items', () async {
      final repo = MockPracticeRepositoryImpl();
      final container = ProviderContainer(
        overrides: [practiceRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(practiceListNotifierProvider.notifier);
      await notifier.loadAssignments();

      final stateInitial = container
          .read(practiceListNotifierProvider)
          .asData
          ?.value;
      expect(stateInitial, isNotNull);

      // Call loadMore
      await notifier.loadMore();

      final stateAfter = container
          .read(practiceListNotifierProvider)
          .asData
          ?.value;
      expect(stateAfter, isNotNull);
      // Items must be deduplicated
      final ids = stateAfter!.items.map((i) => i.id).toSet();
      expect(ids.length, stateAfter.items.length);
    });
  });

  group('Nhiệm vụ 1: Cách ly refresh token và trạng thái giữa các phiên đăng nhập', () {
    test('Nhiều 401 cùng phiên chỉ tạo một refresh', () async {
      final storage = SecureStorageService();
      final sessionManager = SessionManager(storage);
      await storage.saveTokens(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        expiresAt: '2099-01-01',
      );
      await storage.saveUser(
        id: 'u1',
        email: 'u1@test.com',
        roleName: 'ChoirMember',
      );
      await sessionManager.initialize();
      final epoch = sessionManager.sessionEpoch;

      int refreshCalls = 0;
      final refreshClient = Dio();
      refreshClient.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.path.contains('/api/auth/refresh')) {
              refreshCalls++;
              await Future.delayed(const Duration(milliseconds: 20));
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'accessToken': 'new-access',
                    'refreshToken': 'new-refresh',
                    'accessTokenExpiresAt': '2099-01-01',
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true},
              ),
            );
          },
        ),
      );

      final interceptor = AuthInterceptor(
        storage: storage,
        sessionManager: sessionManager,
        dio: dio,
        refreshClient: refreshClient,
      );

      final req1 = RequestOptions(
        path: '/api/test/1',
        headers: {'Authorization': 'Bearer old-access'},
        extra: {'sessionEpoch': epoch},
      );
      final req2 = RequestOptions(
        path: '/api/test/2',
        headers: {'Authorization': 'Bearer old-access'},
        extra: {'sessionEpoch': epoch},
      );

      final err1 = DioException(
        requestOptions: req1,
        response: Response(requestOptions: req1, statusCode: 401),
        type: DioExceptionType.badResponse,
      );
      final err2 = DioException(
        requestOptions: req2,
        response: Response(requestOptions: req2, statusCode: 401),
        type: DioExceptionType.badResponse,
      );

      final handler1 = TestErrorHandler();
      final handler2 = TestErrorHandler();

      await Future.wait([
        interceptor.onError(err1, handler1),
        interceptor.onError(err2, handler2),
      ]);

      expect(refreshCalls, 1);
      expect(handler1.resolveCalled, isTrue);
      expect(handler2.resolveCalled, isTrue);
      expect(await storage.getAccessToken(), 'new-access');
    });

    test(
      'Refresh A đang chạy, chuyển sang B, refresh B chạy, A trả về trước B',
      () async {
        final storage = SecureStorageService();
        final sessionManager = SessionManager(storage);

        await storage.saveTokens(
          accessToken: 'token-a',
          refreshToken: 'ref-a',
          expiresAt: '2099-01-01',
        );
        await storage.saveUser(
          id: 'ua',
          email: 'ua@test.com',
          roleName: 'ChoirMember',
        );
        await sessionManager.initialize();
        final epochA = sessionManager.sessionEpoch;

        final completerA = Completer<Response>();
        final completerB = Completer<Response>();

        final refreshClient = Dio();
        refreshClient.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final data = options.data as Map;
              if (data['refreshToken'] == 'ref-a') {
                final resp = await completerA.future;
                return handler.resolve(resp);
              } else if (data['refreshToken'] == 'ref-b') {
                final resp = await completerB.future;
                return handler.resolve(resp);
              }
              return handler.next(options);
            },
          ),
        );

        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'ok': true},
              ),
            ),
          ),
        );

        final interceptor = AuthInterceptor(
          storage: storage,
          sessionManager: sessionManager,
          dio: dio,
          refreshClient: refreshClient,
        );

        final reqA = RequestOptions(
          path: '/api/a',
          headers: {'Authorization': 'Bearer token-a'},
          extra: {'sessionEpoch': epochA},
        );
        final errA = DioException(
          requestOptions: reqA,
          response: Response(requestOptions: reqA, statusCode: 401),
        );
        final handlerA = TestErrorHandler();
        final futureA = interceptor.onError(errA, handlerA);

        // User switches to Session B
        await storage.clearAll();
        await sessionManager.endSession();
        await storage.saveTokens(
          accessToken: 'token-b',
          refreshToken: 'ref-b',
          expiresAt: '2099-01-01',
        );
        await storage.saveUser(
          id: 'ub',
          email: 'ub@test.com',
          roleName: 'ChoirMember',
        );
        await sessionManager.initialize();
        final epochB = sessionManager.sessionEpoch;

        final reqB = RequestOptions(
          path: '/api/b',
          headers: {'Authorization': 'Bearer token-b'},
          extra: {'sessionEpoch': epochB},
        );
        final errB = DioException(
          requestOptions: reqB,
          response: Response(requestOptions: reqB, statusCode: 401),
        );
        final handlerB = TestErrorHandler();
        final futureB = interceptor.onError(errB, handlerB);

        // A returns BEFORE B
        completerA.complete(
          Response(
            requestOptions: RequestOptions(path: '/api/auth/refresh'),
            statusCode: 200,
            data: {
              'accessToken': 'new-token-a',
              'refreshToken': 'new-ref-a',
              'accessTokenExpiresAt': '2099-01-01',
            },
          ),
        );
        await futureA;

        expect(handlerA.nextCalled, isTrue);
        expect(await storage.getAccessToken(), 'token-b');
        expect(sessionManager.isAuthenticated, isTrue);

        // Now B returns
        completerB.complete(
          Response(
            requestOptions: RequestOptions(path: '/api/auth/refresh'),
            statusCode: 200,
            data: {
              'accessToken': 'new-token-b',
              'refreshToken': 'new-ref-b',
              'accessTokenExpiresAt': '2099-01-01',
            },
          ),
        );
        await futureB;

        expect(handlerB.resolveCalled, isTrue);
        expect(await storage.getAccessToken(), 'new-token-b');
        expect(sessionManager.isAuthenticated, isTrue);
      },
    );

    test(
      'Refresh A đang chạy, chuyển sang B, refresh B chạy, B trả về trước A',
      () async {
        final storage = SecureStorageService();
        final sessionManager = SessionManager(storage);

        await storage.saveTokens(
          accessToken: 'token-a',
          refreshToken: 'ref-a',
          expiresAt: '2099-01-01',
        );
        await storage.saveUser(
          id: 'ua',
          email: 'ua@test.com',
          roleName: 'ChoirMember',
        );
        await sessionManager.initialize();
        final epochA = sessionManager.sessionEpoch;

        final completerA = Completer<Response>();
        final completerB = Completer<Response>();

        final refreshClient = Dio();
        refreshClient.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final data = options.data as Map;
              if (data['refreshToken'] == 'ref-a') {
                final resp = await completerA.future;
                return handler.resolve(resp);
              } else if (data['refreshToken'] == 'ref-b') {
                final resp = await completerB.future;
                return handler.resolve(resp);
              }
              return handler.next(options);
            },
          ),
        );

        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'ok': true},
              ),
            ),
          ),
        );

        final interceptor = AuthInterceptor(
          storage: storage,
          sessionManager: sessionManager,
          dio: dio,
          refreshClient: refreshClient,
        );

        final reqA = RequestOptions(
          path: '/api/a',
          headers: {'Authorization': 'Bearer token-a'},
          extra: {'sessionEpoch': epochA},
        );
        final errA = DioException(
          requestOptions: reqA,
          response: Response(requestOptions: reqA, statusCode: 401),
        );
        final handlerA = TestErrorHandler();
        final futureA = interceptor.onError(errA, handlerA);

        // Switch to B
        await storage.clearAll();
        await sessionManager.endSession();
        await storage.saveTokens(
          accessToken: 'token-b',
          refreshToken: 'ref-b',
          expiresAt: '2099-01-01',
        );
        await storage.saveUser(
          id: 'ub',
          email: 'ub@test.com',
          roleName: 'ChoirMember',
        );
        await sessionManager.initialize();
        final epochB = sessionManager.sessionEpoch;

        final reqB = RequestOptions(
          path: '/api/b',
          headers: {'Authorization': 'Bearer token-b'},
          extra: {'sessionEpoch': epochB},
        );
        final errB = DioException(
          requestOptions: reqB,
          response: Response(requestOptions: reqB, statusCode: 401),
        );
        final handlerB = TestErrorHandler();
        final futureB = interceptor.onError(errB, handlerB);

        // B returns BEFORE A
        completerB.complete(
          Response(
            requestOptions: RequestOptions(path: '/api/auth/refresh'),
            statusCode: 200,
            data: {
              'accessToken': 'new-token-b',
              'refreshToken': 'new-ref-b',
              'accessTokenExpiresAt': '2099-01-01',
            },
          ),
        );
        await futureB;

        expect(handlerB.resolveCalled, isTrue);
        expect(await storage.getAccessToken(), 'new-token-b');
        expect(sessionManager.isAuthenticated, isTrue);

        // Now A returns later
        completerA.complete(
          Response(
            requestOptions: RequestOptions(path: '/api/auth/refresh'),
            statusCode: 200,
            data: {
              'accessToken': 'new-token-a',
              'refreshToken': 'new-ref-a',
              'accessTokenExpiresAt': '2099-01-01',
            },
          ),
        );
        await futureA;

        expect(handlerA.nextCalled, isTrue);
        expect(await storage.getAccessToken(), 'new-token-b');
        expect(sessionManager.isAuthenticated, isTrue);
      },
    );

    test('Logout trong lúc refresh', () async {
      final storage = SecureStorageService();
      final sessionManager = SessionManager(storage);

      await storage.saveTokens(
        accessToken: 'token-a',
        refreshToken: 'ref-a',
        expiresAt: '2099-01-01',
      );
      await storage.saveUser(
        id: 'ua',
        email: 'ua@test.com',
        roleName: 'ChoirMember',
      );
      await sessionManager.initialize();
      final epochA = sessionManager.sessionEpoch;

      final completerA = Completer<Response>();
      final refreshClient = Dio();
      refreshClient.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final resp = await completerA.future;
            return handler.resolve(resp);
          },
        ),
      );

      final dio = Dio();
      final interceptor = AuthInterceptor(
        storage: storage,
        sessionManager: sessionManager,
        dio: dio,
        refreshClient: refreshClient,
      );

      final reqA = RequestOptions(
        path: '/api/a',
        headers: {'Authorization': 'Bearer token-a'},
        extra: {'sessionEpoch': epochA},
      );
      final errA = DioException(
        requestOptions: reqA,
        response: Response(requestOptions: reqA, statusCode: 401),
      );
      final handlerA = TestErrorHandler();
      final futureA = interceptor.onError(errA, handlerA);

      await sessionManager.endSession();

      completerA.complete(
        Response(
          requestOptions: RequestOptions(path: '/api/auth/refresh'),
          statusCode: 200,
          data: {'accessToken': 'new-a', 'refreshToken': 'new-ref-a'},
        ),
      );
      await futureA;

      expect(handlerA.nextCalled, isTrue);
      expect(sessionManager.isAuthenticated, isFalse);
      expect(await storage.getAccessToken(), isNull);
    });

    test(
      'A đang lưu flag thì chuyển sang B; flag và token cuối cùng vẫn thuộc B',
      () async {
        final storage = SecureStorageService();
        final sessionManager = SessionManager(storage);

        await sessionManager.markAuthenticated(
          role: 'ChoirMember',
          isPasswordChangeRequired: false,
        );
        expect(sessionManager.sessionEpoch, 1);

        // Session A starts saving flag true
        final writeA = storage.savePasswordChangeRequired(true);

        // Immediate account switch to B
        await sessionManager.endSession();
        await storage.saveTokens(
          accessToken: 'token-b',
          refreshToken: 'ref-b',
          expiresAt: '2099-01-01',
        );
        await sessionManager.markAuthenticated(
          role: 'ChoirMember',
          isPasswordChangeRequired: false,
        );

        await writeA;

        expect(await storage.isPasswordChangeRequired(), isFalse);
        expect(sessionManager.isPasswordChangeRequired, isFalse);
        expect(await storage.getAccessToken(), 'token-b');
      },
    );
  });

  group(
    'Nhiệm vụ 2: Sửa rollback số thông báo chưa đọc khi "Đọc tất cả" thất bại',
    () {
      test(
        'Tổng 25, tải 1 item, read-all thất bại -> unreadCount phục hồi 25',
        () async {
          final mockRepo = MockNotificationRepoWithFailure();
          mockRepo.items = [
            NotificationDto(
              id: 'n-1',
              type: NotificationType.weekPublished,
              title: 'TB 1',
              content: 'Nội dung',
              createdAt: DateTime.now(),
              isRead: false,
            ),
          ];
          mockRepo.unreadCountOverride = 25;
          mockRepo.failMarkAll = true;

          final container = ProviderContainer(
            overrides: [
              notificationRepositoryProvider.overrideWithValue(mockRepo),
            ],
          );
          addTearDown(container.dispose);

          await container
              .read(notificationNotifierProvider.notifier)
              .loadInitial();
          expect(container.read(notificationNotifierProvider).items.length, 1);
          expect(container.read(notificationNotifierProvider).unreadCount, 25);

          await container
              .read(notificationNotifierProvider.notifier)
              .markAllAsRead();

          final state = container.read(notificationNotifierProvider);
          expect(state.unreadCount, 25);
          expect(state.items.first.isRead, isFalse);
        },
      );

      test(
        'Tổng 25, tải 20 item, read-all thất bại -> unreadCount phục hồi 25',
        () async {
          final mockRepo = MockNotificationRepoWithFailure();
          mockRepo.items = List.generate(
            20,
            (i) => NotificationDto(
              id: 'n-$i',
              type: NotificationType.weekPublished,
              title: 'TB $i',
              content: 'Nội dung',
              createdAt: DateTime.now(),
              isRead: false,
            ),
          );
          mockRepo.unreadCountOverride = 25;
          mockRepo.failMarkAll = true;

          final container = ProviderContainer(
            overrides: [
              notificationRepositoryProvider.overrideWithValue(mockRepo),
            ],
          );
          addTearDown(container.dispose);

          await container
              .read(notificationNotifierProvider.notifier)
              .loadInitial();
          expect(container.read(notificationNotifierProvider).items.length, 20);
          expect(container.read(notificationNotifierProvider).unreadCount, 25);

          await container
              .read(notificationNotifierProvider.notifier)
              .markAllAsRead();

          final state = container.read(notificationNotifierProvider);
          expect(state.unreadCount, 25);
          expect(state.items.every((n) => !n.isRead), isTrue);
        },
      );

      test(
        'Refresh danh sách trong lúc read-all chờ rồi read-all thất bại',
        () async {
          final mockRepo = MockNotificationRepoWithFailure();
          mockRepo.unreadCountOverride = 25;
          mockRepo.failMarkAll = true;
          mockRepo.markAllCompleter = Completer<void>();

          final container = ProviderContainer(
            overrides: [
              notificationRepositoryProvider.overrideWithValue(mockRepo),
            ],
          );
          addTearDown(container.dispose);

          await container
              .read(notificationNotifierProvider.notifier)
              .loadInitial();
          expect(container.read(notificationNotifierProvider).unreadCount, 25);

          final markFuture = container
              .read(notificationNotifierProvider.notifier)
              .markAllAsRead();
          expect(container.read(notificationNotifierProvider).unreadCount, 0);

          // Refresh runs during flight
          await container.read(notificationNotifierProvider.notifier).refresh();
          expect(container.read(notificationNotifierProvider).unreadCount, 25);

          // Now markAllAsRead fails
          mockRepo.markAllCompleter!.complete();
          await markFuture;

          expect(container.read(notificationNotifierProvider).unreadCount, 25);
        },
      );

      test('Nhận thông báo mới trong lúc read-all chờ', () async {
        final mockRepo = MockNotificationRepoWithFailure();
        mockRepo.unreadCountOverride = 25;
        mockRepo.failMarkAll = true;
        mockRepo.markAllCompleter = Completer<void>();

        final container = ProviderContainer(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(notificationNotifierProvider.notifier)
            .loadInitial();
        expect(container.read(notificationNotifierProvider).unreadCount, 25);

        final markFuture = container
            .read(notificationNotifierProvider.notifier)
            .markAllAsRead();
        expect(container.read(notificationNotifierProvider).unreadCount, 0);

        final newNotif = NotificationDto(
          id: 'realtime-new',
          type: NotificationType.assignmentNotice,
          title: 'Bài tập mới',
          content: 'Nội dung',
          createdAt: DateTime.now(),
          isRead: false,
        );
        mockRepo.emitRealtime(newNotif);
        await Future.delayed(Duration.zero);

        expect(container.read(notificationNotifierProvider).unreadCount, 1);

        mockRepo.failUnreadCount = true; // Test fallback offline branch
        mockRepo.markAllCompleter!.complete();
        await markFuture;

        final state = container.read(notificationNotifierProvider);
        expect(state.unreadCount, 26);
        expect(state.items.first.id, 'realtime-new');
        expect(state.items.first.isRead, isFalse);
      });

      test('Chuyển phiên khi read-all đang chạy', () async {
        final mockRepo = MockNotificationRepoWithFailure();
        mockRepo.unreadCountOverride = 25;
        mockRepo.failMarkAll = true;
        mockRepo.markAllCompleter = Completer<void>();

        final container = ProviderContainer(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(notificationNotifierProvider.notifier)
            .loadInitial();
        expect(container.read(notificationNotifierProvider).unreadCount, 25);

        final markFuture = container
            .read(notificationNotifierProvider.notifier)
            .markAllAsRead();

        // Account switch / reset
        container.read(notificationNotifierProvider.notifier).reset();
        expect(container.read(notificationNotifierProvider).unreadCount, 0);
        expect(container.read(notificationNotifierProvider).items, isEmpty);

        mockRepo.markAllCompleter!.complete();
        await markFuture;

        expect(container.read(notificationNotifierProvider).unreadCount, 0);
        expect(container.read(notificationNotifierProvider).items, isEmpty);
      });

      test('Read-all thành công', () async {
        final mockRepo = MockNotificationRepoWithFailure();
        mockRepo.unreadCountOverride = 25;
        mockRepo.failMarkAll = false;

        final container = ProviderContainer(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(notificationNotifierProvider.notifier)
            .loadInitial();
        expect(container.read(notificationNotifierProvider).unreadCount, 25);

        await container
            .read(notificationNotifierProvider.notifier)
            .markAllAsRead();

        final state = container.read(notificationNotifierProvider);
        expect(state.unreadCount, 0);
        expect(state.items.every((n) => n.isRead), isTrue);
      });
    },
  );

  group('Nhiệm vụ 3: Hoàn thiện phân trang kỹ năng và lịch sử bản thu', () {
    test('MemberSkillsNotifier: Tải trang 1 rồi trang 2', () async {
      final fakeRepo = FakeProfileRepository();
      fakeRepo.skills = List.generate(
        15,
        (i) => MemberSkill(
          id: 'skill-$i',
          skillId: 'guid-$i',
          name: 'Kỹ năng $i',
          categoryName: 'Thanh nhạc',
          level: 'Beginner',
          status: SkillApprovalStatus.approved,
        ),
      );

      final container = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(memberSkillsNotifierProvider.notifier);
      await notifier.loadInitial();

      var state = container.read(memberSkillsNotifierProvider);
      expect(state.items.length, 10);
      expect(state.pageNumber, 1);
      expect(state.hasNextPage, isTrue);

      await notifier.loadMore();
      state = container.read(memberSkillsNotifierProvider);
      expect(state.items.length, 15);
      expect(state.pageNumber, 2);
      expect(state.hasNextPage, isFalse);
    });

    test('PracticeSubmissionsNotifier: Tải trang 1 rồi trang 2', () async {
      final fakeRepo = FakePracticeRepository();
      fakeRepo.submissions = List.generate(
        15,
        (i) => PracticeSubmissionDetail(
          id: 'sub-$i',
          practiceAssignmentId: 'assign-1',
          attemptNo: i + 1,
          submittedAt: DateTime.now(),
          status: 'Passed',
          durationSeconds: 60,
          feedbacks: const [],
        ),
      );

      final container = ProviderContainer(
        overrides: [practiceRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        practiceSubmissionsNotifierProvider('assign-1').notifier,
      );
      await notifier.loadInitial();

      var state = container.read(
        practiceSubmissionsNotifierProvider('assign-1'),
      );
      expect(state.items.length, 10);
      expect(state.pageNumber, 1);
      expect(state.hasNextPage, isTrue);

      await notifier.loadMore();
      state = container.read(practiceSubmissionsNotifierProvider('assign-1'));
      expect(state.items.length, 15);
      expect(state.pageNumber, 2);
      expect(state.hasNextPage, isFalse);
    });

    test('Trang 2 lỗi rồi retry thành công (MemberSkillsNotifier)', () async {
      final fakeRepo = FakeProfileRepository();
      fakeRepo.skills = List.generate(
        15,
        (i) => MemberSkill(
          id: 'skill-$i',
          skillId: 'guid-$i',
          name: 'Kỹ năng $i',
          categoryName: 'Thanh nhạc',
          level: 'Beginner',
          status: SkillApprovalStatus.approved,
        ),
      );
      fakeRepo.failNextPage = true;

      final container = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(memberSkillsNotifierProvider.notifier);
      await notifier.loadInitial();

      var state = container.read(memberSkillsNotifierProvider);
      expect(state.items.length, 10);

      // Page 2 fails
      await notifier.loadMore();
      state = container.read(memberSkillsNotifierProvider);
      expect(state.items.length, 10); // Preserves existing items!
      expect(state.pageNumber, 1); // Does NOT advance pageNumber!
      expect(state.loadMoreErrorMessage, isNotNull);

      // Retry succeeds
      fakeRepo.failNextPage = false;
      await notifier.loadMore();
      state = container.read(memberSkillsNotifierProvider);
      expect(state.items.length, 15);
      expect(state.pageNumber, 2);
      expect(state.loadMoreErrorMessage, isNull);
    });

    test('Hai trang có ID trùng: khử trùng lặp theo ID', () async {
      final fakeRepo = FakeProfileRepository();
      fakeRepo.skills = [
        ...List.generate(
          10,
          (i) => MemberSkill(
            id: 'skill-$i',
            skillId: 'guid-$i',
            name: 'Kỹ năng $i',
            categoryName: 'Thanh nhạc',
            level: 'Beginner',
            status: SkillApprovalStatus.approved,
          ),
        ),
        // Page 2 repeats skill-0 and has a new skill-10
        MemberSkill(
          id: 'skill-0',
          skillId: 'guid-0',
          name: 'Kỹ năng 0',
          categoryName: 'Thanh nhạc',
          level: 'Beginner',
          status: SkillApprovalStatus.approved,
        ),
        MemberSkill(
          id: 'skill-10',
          skillId: 'guid-10',
          name: 'Kỹ năng 10',
          categoryName: 'Thanh nhạc',
          level: 'Beginner',
          status: SkillApprovalStatus.approved,
        ),
      ];

      final container = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(memberSkillsNotifierProvider.notifier);
      await notifier.loadInitial();

      await notifier.loadMore();
      final state = container.read(memberSkillsNotifierProvider);
      expect(
        state.items.length,
        11,
      ); // 10 unique from page 1 + 1 unique from page 2
      final ids = state.items.map((s) => s.id).toSet();
      expect(ids.length, 11);
    });

    test('Refresh trong lúc tải thêm vô hiệu hóa kết quả request cũ', () async {
      final fakeRepo = FakeProfileRepository();
      fakeRepo.skills = List.generate(
        15,
        (i) => MemberSkill(
          id: 'skill-$i',
          skillId: 'guid-$i',
          name: 'Kỹ năng $i',
          categoryName: 'Thanh nhạc',
          level: 'Beginner',
          status: SkillApprovalStatus.approved,
        ),
      );

      final container = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(memberSkillsNotifierProvider.notifier);
      await notifier.loadInitial();

      fakeRepo.loadCompleter = Completer<void>();
      final loadMoreFuture = notifier.loadMore();

      // Refresh triggered before loadMore finishes
      final oldLoadMoreCompleter = fakeRepo.loadCompleter;
      fakeRepo.loadCompleter = null;
      final refreshFuture = notifier.refresh();
      oldLoadMoreCompleter?.complete();
      await refreshFuture;

      // Old loadMore finishes
      await loadMoreFuture;

      final state = container.read(memberSkillsNotifierProvider);
      // State should reflect refreshed page 1
      expect(state.pageNumber, 1);
      expect(state.items.length, 10);
    });

    test('Đổi bài tập/bộ lọc trong lúc request đang chạy', () async {
      final fakeRepo = FakeProfileRepository();
      fakeRepo.skills = [
        MemberSkill(
          id: 'skill-app',
          skillId: 'g-app',
          name: 'Kỹ năng đã duyệt',
          categoryName: 'Thanh nhạc',
          level: 'Beginner',
          status: SkillApprovalStatus.approved,
        ),
        MemberSkill(
          id: 'skill-pen',
          skillId: 'g-pen',
          name: 'Kỹ năng chờ duyệt',
          categoryName: 'Thanh nhạc',
          level: 'Beginner',
          status: SkillApprovalStatus.pending,
        ),
      ];

      final container = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(memberSkillsNotifierProvider.notifier);

      fakeRepo.loadCompleter = Completer<void>();
      final approvedFuture = notifier.loadInitial(status: 'Approved');

      // User quickly changes filter to Pending
      final oldFilterCompleter = fakeRepo.loadCompleter;
      fakeRepo.loadCompleter = null;
      final pendingFuture = notifier.loadInitial(status: 'Pending');

      oldFilterCompleter?.complete();
      await pendingFuture;
      await approvedFuture;

      final state = container.read(memberSkillsNotifierProvider);
      expect(state.items.length, 1);
      expect(state.items.first.id, 'skill-pen');
    });

    test('Hết dữ liệu không gọi thêm request', () async {
      final fakeRepo = FakeProfileRepository();
      fakeRepo.skills = List.generate(
        3,
        (i) => MemberSkill(
          id: 'skill-$i',
          skillId: 'guid-$i',
          name: 'Kỹ năng $i',
          categoryName: 'Thanh nhạc',
          level: 'Beginner',
          status: SkillApprovalStatus.approved,
        ),
      );

      final container = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(memberSkillsNotifierProvider.notifier);
      await notifier.loadInitial();

      expect(container.read(memberSkillsNotifierProvider).hasNextPage, isFalse);
      final callsBefore = fakeRepo.getSkillsPagedCallCount;

      await notifier.loadMore();
      expect(fakeRepo.getSkillsPagedCallCount, callsBefore);
    });

    test('Chuyển tài khoản không nhận kết quả của phiên cũ', () async {
      final fakeRepo = FakeProfileRepository();
      fakeRepo.skills = List.generate(
        5,
        (i) => MemberSkill(
          id: 'skill-$i',
          skillId: 'guid-$i',
          name: 'Kỹ năng $i',
          categoryName: 'Thanh nhạc',
          level: 'Beginner',
          status: SkillApprovalStatus.approved,
        ),
      );

      final storage = SecureStorageService();
      final sessionManager = SessionManager(storage);
      await sessionManager.markAuthenticated(role: 'ChoirMember');

      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(fakeRepo),
          sessionManagerProvider.overrideWithValue(sessionManager),
        ],
      );
      addTearDown(container.dispose);

      fakeRepo.loadCompleter = Completer<void>();
      final notifier = container.read(memberSkillsNotifierProvider.notifier);
      final loadFuture = notifier.loadInitial();

      // Account switch / logout before request finishes
      await sessionManager.endSession();

      fakeRepo.loadCompleter!.complete();
      await loadFuture;

      final state = container.read(memberSkillsNotifierProvider);
      expect(state.items, isEmpty);
      expect(state.isLoading, isFalse);
    });
  });
}
