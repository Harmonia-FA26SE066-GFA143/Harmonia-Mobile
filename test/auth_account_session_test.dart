import 'support/fake_profile_repository.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harmonia_mobile/app/router/splash_screen.dart';
import 'package:harmonia_mobile/app/router/app_router.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/network/api_client.dart';
import 'package:harmonia_mobile/core/network/auth_interceptor.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/auth/data/auth_api_service.dart';
import 'package:harmonia_mobile/features/auth/data/auth_dto.dart';
import 'package:harmonia_mobile/features/auth/data/auth_repository.dart';
import 'package:harmonia_mobile/features/auth/presentation/auth_notifier.dart';
import 'package:harmonia_mobile/features/profile/data/profile_repository.dart';
import 'package:harmonia_mobile/features/music/data/music_api_service.dart';
import 'package:harmonia_mobile/features/staff_workspace/data/staff_workspace_repository.dart';
import 'package:harmonia_mobile/features/profile/presentation/profile_screen.dart';

UserDto account({
  String id = 'member-a',
  String role = 'ChoirMember',
  bool active = true,
  bool passwordRequired = false,
}) => UserDto(
  id: id,
  email: '$id@example.test',
  fullName: 'Tên mới từ máy chủ',
  roleName: role,
  isActive: active,
  isPasswordChangeRequired: passwordRequired,
);

// Keep widget tests on one fake clock; the secure-storage adapter is tested separately.
class AccountMemoryStorage extends SecureStorageService {
  final values = <String, String>{};
  bool passwordRequired = false;
  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String expiresAt,
  }) async {
    values.addAll({
      'access': accessToken,
      'refresh': refreshToken,
      'expires': expiresAt,
    });
  }

  @override
  Future<void> saveUser({
    required String id,
    required String email,
    required String roleName,
    String? fullName,
  }) async {
    values.addAll({
      'id': id,
      'email': email,
      'role': roleName,
      'name': ?fullName,
    });
  }

  @override
  Future<String?> getAccessToken() async => values['access'];
  @override
  Future<String?> getRefreshToken() async => values['refresh'];
  @override
  Future<String?> getExpiresAt() async => values['expires'];
  @override
  Future<String?> getUserId() async => values['id'];
  @override
  Future<String?> getUserEmail() async => values['email'];
  @override
  Future<String?> getUserRole() async => values['role'];
  @override
  Future<String?> getUserFullName() async => values['name'];
  @override
  Future<void> savePasswordChangeRequired(bool required) async {
    passwordRequired = required;
  }

  @override
  Future<bool> isPasswordChangeRequired() async => passwordRequired;
  @override
  Future<void> clearAll() async {
    values.clear();
    passwordRequired = false;
  }
}

class AccountApi extends AuthApiService {
  AccountApi(SecureStorageService storage, SessionManager session)
    : super(
        ApiClient(storage: storage, sessionManager: session, customDio: Dio()),
      );

  LoginResponse? loginResponse;
  Future<UserDto> Function()? meHandler;

  @override
  Future<LoginResponse> login(LoginRequest request) async => loginResponse!;
  Future<void> Function()? logoutHandler;
  Future<void> Function()? currentDeviceLogoutHandler;
  int meCalls = 0;
  int logoutCalls = 0;
  int currentDeviceLogoutCalls = 0;

  @override
  Future<UserDto> getMe({int? expectedSessionEpoch}) async {
    meCalls++;
    return meHandler == null ? account() : await meHandler!();
  }

  @override
  Future<void> logoutAll({int? expectedSessionEpoch}) async {
    logoutCalls++;
    await logoutHandler?.call();
  }

  @override
  Future<void> logout(String refreshToken, {String? accessToken}) async {
    currentDeviceLogoutCalls++;
    await currentDeviceLogoutHandler?.call();
  }
}

class AccountAdapter implements HttpClientAdapter {
  AccountAdapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

class UnavailableProfileRepository extends MockProfileRepositoryImpl {
  @override
  Future<MemberProfileDto> getProfile() async => throw const ServerException();
}

ResponseBody jsonResponse(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SecureStorageService storage;
  late SessionManager session;
  late AccountApi api;
  late AuthRepositoryImpl repository;
  late ProviderContainer container;

  setUp(() {
    storage = AccountMemoryStorage();
    session = SessionManager(storage);
    api = AccountApi(storage, session);
    repository = AuthRepositoryImpl(
      apiService: api,
      storage: storage,
      sessionManager: session,
    );
    container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        sessionManagerProvider.overrideWithValue(session),
        authRepositoryProvider.overrideWithValue(repository),
        profileRepositoryProvider.overrideWithValue(
          MockProfileRepositoryImpl(),
        ),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    session.dispose();
  });

  void replaceOverrides({AuthRepository? auth, ProfileRepository? profile}) {
    container.updateOverrides([
      secureStorageServiceProvider.overrideWithValue(storage),
      sessionManagerProvider.overrideWithValue(session),
      authRepositoryProvider.overrideWithValue(auth ?? repository),
      profileRepositoryProvider.overrideWithValue(
        profile ?? MockProfileRepositoryImpl(),
      ),
    ]);
  }

  Future<void> saveAccount({
    String id = 'member-a',
    bool authenticate = true,
  }) async {
    await storage.saveTokens(
      accessToken: 'access-$id',
      refreshToken: 'refresh-$id',
      expiresAt: '2030-01-01T00:00:00Z',
    );
    await storage.saveUser(
      id: id,
      email: '$id@example.test',
      roleName: 'ChoirMember',
      fullName: 'Tên cũ',
    );
    if (authenticate) await session.markAuthenticated(role: 'ChoirMember');
  }

  for (final role in MobileRole.values) {
    test(
      'password login and account restoration use ${role.wireName}',
      () async {
        final user = account(role: role.wireName);
        api.loginResponse = LoginResponse(
          accessToken: 'login-access',
          accessTokenExpiresAt: '2030-01-01T00:00:00Z',
          refreshToken: 'login-refresh',
          user: user,
        );
        await repository.login(email: user.email, password: 'test-password');
        expect(session.role, role);
        expect(await storage.getUserRole(), role.wireName);

        await session.initialize(verifyAccount: true);
        expect(session.status, AuthStatus.restoring);
        api.meHandler = () async => user;
        expect(
          await container.read(authNotifierProvider.notifier).restoreSession(),
          isTrue,
        );
        expect(session.status, AuthStatus.authenticated);
        expect(session.role, role);
      },
    );
  }

  test(
    'restoration rejects a cached token with a different verified role',
    () async {
      await saveAccount(authenticate: false);
      api.meHandler = () async => account(role: 'ParishPriest');

      expect(
        await container.read(authNotifierProvider.notifier).restoreSession(),
        isFalse,
      );
      expect(session.status, AuthStatus.unauthenticated);
      expect(await storage.getAccessToken(), isNull);
    },
  );

  test(
    'a role change in an active session requires signing in again',
    () async {
      await saveAccount();
      api.meHandler = () async => account(role: 'ChoirDirector');

      expect(
        await container
            .read(authNotifierProvider.notifier)
            .synchronizeAccount(),
        isFalse,
      );
      expect(session.status, AuthStatus.unauthenticated);
      expect(session.role, isNull);
      expect(await storage.getAccessToken(), isNull);
    },
  );

  test('staff publishes, submits and reviews the same event before member approval is visible', () async {
    var approved = false;
    final methods = <String>[];
    final dio = Dio()
      ..httpClientAdapter = AccountAdapter((request) {
        methods.add('${request.method} ${request.path}');
        switch (request.path) {
          case '/api/liturgical-events':
            expect(request.method, 'POST');
            expect(request.data, containsPair('choirIds', ['lead', 'second']));
            expect(request.data, containsPair('leadChoirId', 'lead'));
            expect(request.data, containsPair('time', '06:00:00'));
            return jsonResponse(200, {'id': 'event'});
          case '/api/liturgical-events/event/choirs/lead/substitute-director':
            expect(request.data, {
              'directorId': 'substitute',
              'reason': 'Ca trưởng vắng',
            });
            return jsonResponse(200, []);
          case '/api/liturgical-events/event/publish':
            return jsonResponse(200, {'status': 'Published'});
          case '/api/song-lists':
            expect(request.data, {
              'eventId': 'event',
              'items': [
                {
                  'songId': 'song',
                  'slotId': 'slot',
                  'displayOrder': 1,
                  'note': null,
                },
              ],
            });
            return jsonResponse(200, {
              'id': 'proposal',
              'eventId': 'event',
              'status': 'Draft',
            });
          case '/api/song-lists/proposal/submit':
            return jsonResponse(200, {'status': 'Submitted'});
          case '/api/song-lists/proposal/review':
            expect(request.data, {'decision': 'Approve', 'notes': null});
            approved = true;
            return jsonResponse(200, {'status': 'Approved'});
          case '/api/song-lists/event/event/approved':
            return approved
                ? jsonResponse(200, {
                    'id': 'proposal',
                    'eventId': 'event',
                    'status': 'Approved',
                    'items': [
                      {'songTitle': 'Bài nhập lễ'},
                    ],
                  })
                : jsonResponse(404, {'code': 'SONG_LIST_NOT_FOUND'});
          default:
            fail('Unexpected request: ${request.path}');
        }
      });
    final client = ApiClient(
      storage: storage,
      sessionManager: session,
      customDio: dio,
    );
    addTearDown(dio.close);
    Future<StaffWorkspaceRepository> signedInAs(MobileRole role) async {
      if (session.isAuthenticated) await session.endSession();
      await session.markAuthenticated(role: role.wireName);
      return StaffWorkspaceRepository(client, session.sessionEpoch);
    }

    final priest = await signedInAs(MobileRole.parishPriest);
    final event = await priest.createEvent((
      date: '2099-11-09',
      time: '06:00:00',
      locationId: 'location',
      massTypeId: 'mass',
      ceremonyTypeId: null,
      seasonId: 'season',
      categoryId: null,
      title: 'Lễ Chúa Nhật',
      requirements: null,
      choirIds: ['lead', 'second'],
      leadChoirId: 'lead',
    ));
    await priest.setSubstitute(event, 'lead', 'substitute', 'Ca trưởng vắng');
    await priest.publish(event);
    final director = await signedInAs(MobileRole.choirDirector);
    final draft = await director.saveProposal(event, null, [
      (songId: 'song', slotId: 'slot', note: null),
    ]);
    await director.submitProposal(draft.id);

    final music = MusicApiService(client);
    await signedInAs(MobileRole.choirMember);
    expect(await music.getApprovedSongListForEvent(event), isNull);
    final reviewer = await signedInAs(MobileRole.parishPriest);
    await reviewer.reviewProposal(draft.id, 'Approve', null);
    await signedInAs(MobileRole.choirMember);
    final result = await music.getApprovedSongListForEvent(event);
    expect(result?.items.single.songTitle, 'Bài nhập lễ');
    expect(methods, [
      'POST /api/liturgical-events',
      'PUT /api/liturgical-events/event/choirs/lead/substitute-director',
      'PATCH /api/liturgical-events/event/publish',
      'POST /api/song-lists',
      'POST /api/song-lists/proposal/submit',
      'GET /api/song-lists/event/event/approved',
      'POST /api/song-lists/proposal/review',
      'GET /api/song-lists/event/event/approved',
    ]);
  });

  test('getMe synchronizes account cache and forced password flag without changing epoch', () async {
    await saveAccount();
    final epoch = session.sessionEpoch;
    api.meHandler = () async => account(passwordRequired: true);
    await repository.getMe();
    expect(await storage.getUserFullName(), 'Tên mới từ máy chủ');
    expect(session.isPasswordChangeRequired, isTrue);
    expect(await storage.isPasswordChangeRequired(), isTrue);
    expect(session.sessionEpoch, epoch);
  });

  for (final rejected in [account(role: 'Admin'), account(active: false)]) {
    test(
      'getMe terminates local session for ${rejected.roleName}/${rejected.isActive}',
      () async {
        await saveAccount();
        api.meHandler = () async => rejected;
        await expectLater(repository.getMe(), throwsA(isA<AppException>()));
        expect(session.isAuthenticated, isFalse);
        expect(await storage.getAccessToken(), isNull);
      },
    );
  }

  test('old getMe response cannot write over the next account', () async {
    await saveAccount();
    final response = Completer<UserDto>();
    api.meHandler = () => response.future;
    final request = repository.getMe();
    final outcome = expectLater(request, throwsA(isA<AppException>()));
    await Future<void>.delayed(Duration.zero);
    await session.endSession();
    await saveAccount(id: 'member-b');
    response.complete(account());
    await outcome;
    expect(await storage.getUserId(), 'member-b');
    expect(await storage.getUserFullName(), 'Tên cũ');
    expect(session.isAuthenticated, isTrue);
  });

  test('logout-all reports failure while still clearing this device', () async {
    await saveAccount();
    api.logoutHandler = () async => throw const NetworkException();
    final result = await repository.logoutAll();
    expect(result, isFalse);
    expect(session.isAuthenticated, isFalse);
    expect(await storage.getAccessToken(), isNull);
  });

  test('logout-all confirms server success and clears this device', () async {
    await saveAccount();
    final result = await repository.logoutAll();
    expect(result, isTrue);
    expect(api.logoutCalls, 1);
    expect(await storage.getRefreshToken(), isNull);
  });

  test(
    'logout-all sends Bearer without a body and accepts empty HTTP 204',
    () async {
      await saveAccount();
      final epoch = session.sessionEpoch;
      var calls = 0;
      final dio = Dio()
        ..httpClientAdapter = AccountAdapter((request) {
          calls++;
          expect(request.method, 'POST');
          expect(request.path, '/api/auth/logout-all');
          expect(request.headers['Authorization'], 'Bearer access-member-a');
          expect(request.extra['expectedSessionEpoch'], epoch);
          expect(request.data, isNull);
          return ResponseBody.fromString('', 204);
        });
      final httpRepository = AuthRepositoryImpl(
        apiService: AuthApiService(
          ApiClient(storage: storage, sessionManager: session, customDio: dio),
        ),
        storage: storage,
        sessionManager: session,
      );
      expect(await httpRepository.logoutAll(), isTrue);
      expect(calls, 1);
      expect(session.isAuthenticated, isFalse);
      expect(await storage.getRefreshToken(), isNull);
      dio.close();
    },
  );

  test('old logout-all completion cannot log out the next account', () async {
    await saveAccount();
    final response = Completer<void>();
    api.logoutHandler = () => response.future;
    final request = repository.logoutAll();
    await Future<void>.delayed(Duration.zero);
    await session.endSession();
    await saveAccount(id: 'member-b');
    response.complete();
    await request;
    expect(session.isAuthenticated, isTrue);
    expect(await storage.getAccessToken(), 'access-member-b');
  });

  test('repeated logout-all submits only one server request', () async {
    await saveAccount();
    final pending = Completer<void>();
    api.logoutHandler = () => pending.future;
    final notifier = container.read(authNotifierProvider.notifier);
    final first = notifier.logoutAll();
    expect(await notifier.logoutAll(), isFalse);
    expect(api.logoutCalls, 1);
    pending.complete();
    expect(await first, isTrue);
    expect(container.read(authNotifierProvider).isLoading, isFalse);
  });

  test(
    'a failed account response after local logout cannot restore user or error',
    () async {
      await saveAccount();
      final pending = Completer<UserDto>();
      api.meHandler = () => pending.future;
      final notifier = container.read(authNotifierProvider.notifier);
      final sync = notifier.synchronizeAccount();
      await session.endSession();
      pending.completeError(const NetworkException());
      expect(await sync, isFalse);
      expect(container.read(authNotifierProvider).user, isNull);
      expect(container.read(authNotifierProvider).errorMessage, isNull);
    },
  );

  for (final refreshStatus in [200, 401, 503]) {
    test(
      'restoration handles expired access and refresh HTTP $refreshStatus',
      () async {
        await saveAccount(authenticate: false);
        final refresh = Dio()
          ..httpClientAdapter = AccountAdapter((options) {
            expect(options.path, '/api/auth/refresh');
            expect(options.data, {'refreshToken': 'refresh-member-a'});
            return jsonResponse(
              refreshStatus,
              refreshStatus == 200
                  ? {
                      'accessToken': 'renewed-access',
                      'refreshToken': 'renewed-refresh',
                      'accessTokenExpiresAt': '2030-01-01T00:00:00Z',
                      'user': account().toJson(),
                    }
                  : {
                      'code': refreshStatus == 401
                          ? 'AUTH_REFRESH_TOKEN_INVALID'
                          : 'SERVER_ERROR',
                      'message': 'Synthetic failure',
                    },
            );
          });
        final dio = Dio()
          ..httpClientAdapter = AccountAdapter((options) {
            expect(options.path, '/api/auth/me');
            return options.headers['Authorization'] == 'Bearer renewed-access'
                ? jsonResponse(200, account().toJson())
                : jsonResponse(401, {'code': 'UNAUTHORIZED'});
          });
        final client = ApiClient(
          storage: storage,
          sessionManager: session,
          customDio: dio,
        );
        dio.interceptors.clear();
        dio.interceptors.add(
          AuthInterceptor(
            storage: storage,
            sessionManager: session,
            dio: dio,
            refreshClient: refresh,
          ),
        );
        final liveRepository = AuthRepositoryImpl(
          apiService: AuthApiService(client),
          storage: storage,
          sessionManager: session,
        );
        replaceOverrides(auth: liveRepository);
        final restored = await container
            .read(authNotifierProvider.notifier)
            .restoreSession();
        expect(restored, refreshStatus == 200);
        expect(
          session.status.name,
          refreshStatus == 200
              ? 'authenticated'
              : refreshStatus == 401
              ? 'unauthenticated'
              : 'restoring',
        );
        expect(
          await storage.getAccessToken(),
          refreshStatus == 200
              ? 'renewed-access'
              : refreshStatus == 401
              ? null
              : 'access-member-a',
        );
        dio.close();
        refresh.close();
      },
    );
  }

  test(
    'a refresh with a different role ends the session before retrying',
    () async {
      await saveAccount();
      final requests = <String>[];
      final dio = Dio()
        ..httpClientAdapter = AccountAdapter((request) {
          requests.add(request.path);
          return jsonResponse(401, {'code': 'UNAUTHORIZED'});
        });
      final refresh = Dio()
        ..httpClientAdapter = AccountAdapter((request) {
          expect(request.path, '/api/auth/refresh');
          return jsonResponse(200, {
            'accessToken': 'renewed-access',
            'accessTokenExpiresAt': '2030-01-01T00:00:00Z',
            'refreshToken': 'renewed-refresh',
            'user': account(role: 'ChoirDirector').toJson(),
          });
        });
      dio.interceptors.add(
        AuthInterceptor(
          storage: storage,
          sessionManager: session,
          dio: dio,
          refreshClient: refresh,
        ),
      );
      addTearDown(() {
        dio.close();
        refresh.close();
      });

      await expectLater(dio.get('/api/auth/me'), throwsA(isA<DioException>()));
      expect(requests, ['/api/auth/me']);
      expect(session.status, AuthStatus.unauthenticated);
      expect(await storage.getAccessToken(), isNull);
    },
  );

  test('malformed account response cannot authenticate restoration', () async {
    await saveAccount(authenticate: false);
    final body = account().toJson()..remove('isActive');
    final dio = Dio()
      ..httpClientAdapter = AccountAdapter((_) => jsonResponse(200, body));
    final client = ApiClient(
      storage: storage,
      sessionManager: session,
      customDio: dio,
    );
    replaceOverrides(
      auth: AuthRepositoryImpl(
        apiService: AuthApiService(client),
        storage: storage,
        sessionManager: session,
      ),
    );
    expect(
      await container.read(authNotifierProvider.notifier).restoreSession(),
      isFalse,
    );
    expect(session.status.name, 'restoring');
    expect(await storage.getAccessToken(), 'access-member-a');
    dio.close();
  });

  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/test',
      routes: [
        GoRoute(path: '/test', builder: (_, _) => screen),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('LOGIN TARGET')),
        ),
        GoRoute(
          path: '/change-password',
          builder: (_, _) => const Scaffold(body: Text('PASSWORD TARGET')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('splash waits for server verification before authenticating', (
    tester,
  ) async {
    await saveAccount(authenticate: false);
    final response = Completer<UserDto>();
    api.meHandler = () => response.future;
    await open(tester, const SplashScreen());
    expect(api.meCalls, 1);
    expect(session.status.name, 'restoring');
    response.complete(account(passwordRequired: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(session.status, AuthStatus.authenticated);
    expect(session.isPasswordChangeRequired, isTrue);
    expect(container.read(authNotifierProvider).user?.id, 'member-a');
  });

  testWidgets('splash network failure keeps tokens and offers retry', (
    tester,
  ) async {
    await saveAccount(authenticate: false);
    api.meHandler = () async => throw const NetworkException();
    await open(tester, const SplashScreen());
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    expect(session.status.name, 'restoring');
    expect(await storage.getAccessToken(), 'access-member-a');
    api.meHandler = () async => account();
    await tester.tap(find.text('Thử lại'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.meCalls, 2);
    expect(session.status, AuthStatus.authenticated);
  });

  testWidgets(
    'production router blocks protected links until account is verified',
    (tester) async {
      await saveAccount(authenticate: false);
      final pending = Completer<UserDto>();
      api.meHandler = () => pending.future;
      final router = container.read(appRouterProvider);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      router.go('/profile');
      await tester.pump(const Duration(milliseconds: 100));
      expect(router.routeInformationProvider.value.uri.path, '/splash');
      pending.complete(account(passwordRequired: true));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/change-password',
      );
    },
  );

  for (final role in [MobileRole.choirDirector, MobileRole.parishPriest]) {
    testWidgets(
      'verified ${role.wireName} opens its tabs and notification target',
      (tester) async {
        final director = role == MobileRole.choirDirector;
        final workspace = director ? '/manage' : '/approvals';
        final label = director ? 'Quản lý' : 'Phê duyệt';
        final referenceType = director ? 'DirectorNote' : 'SongList';
        final detail = director
            ? '/director-note/resource'
            : '/song-list/resource';
        final resource = director
            ? '/api/director-notes/resource'
            : '/api/song-lists/resource';
        final workspaceApi = director
            ? '/api/choirs'
            : '/api/song-lists/pending';
        await saveAccount(authenticate: false);
        await storage.saveUser(
          id: 'staff',
          email: 'staff@example.test',
          roleName: role.wireName,
        );
        api.meHandler = () async => account(id: 'staff', role: role.wireName);
        final eventApi = director
            ? '/api/schedule/events/event'
            : '/api/liturgical-events/event';
        var reviewStatus = 'Submitted';
        final event = {
          'id': 'event',
          'status': director ? 'Published' : 'Draft',
          'title': 'Chương trình kiểm thử',
          'eventDate': '2099-11-09',
          'time': '10:00:00',
          'locationName': 'Nhà thờ chính',
          'specialRequirements': 'Chuẩn bị trước giờ lễ',
        };
        final requests = <String>[];
        final dio = Dio()
          ..httpClientAdapter = AccountAdapter((request) {
            final path = request.path;
            requests.add(path);
            if (path == '/api/liturgical-events') {
              return jsonResponse(200, {
                'items': [event],
              });
            }
            if (path == '/api/member-skills/pending' ||
                path == '/api/practice-submissions') {
              expect(request.queryParameters['pageSize'], 1);
              return jsonResponse(200, {'items': [], 'totalCount': 2});
            }
            if (path == eventApi) return jsonResponse(200, event);
            if (path == '/api/liturgical-events/event/choirs') {
              return jsonResponse(200, [
                {
                  'choirId': 'lead-choir',
                  'name': 'Ca đoàn Cecilia',
                  'isActive': true,
                  'isLead': true,
                  'directorId': 'director',
                  'substituteDirectorId': 'staff',
                },
              ]);
            }
            if (path == '/api/song-lists/resource/review') {
              expect(request.method, 'POST');
              expect(request.data, {'decision': 'Approve', 'notes': null});
              reviewStatus = 'Approved';
              return jsonResponse(200, {});
            }
            if (path == workspaceApi) {
              return jsonResponse(
                200,
                director
                    ? [
                        {'name': 'Ca đoàn Cecilia', 'isActive': true},
                      ]
                    : [
                        {
                          'id': 'resource',
                          'eventId': 'event',
                          'status': 'Submitted',
                          'version': 1,
                        },
                      ],
              );
            }
            if (path == '/api/notifications/unread-count') {
              return jsonResponse(200, 0);
            }
            if (path == '/api/notifications') {
              return jsonResponse(200, {
                'items': [
                  {
                    'id': 'notification',
                    'type': director ? 'DirectorNote' : 'SongListSubmitted',
                    'title': 'Thông báo theo vai trò',
                    'content': 'Thông tin chi tiết',
                    'referenceType': referenceType,
                    'referenceId': 'resource',
                    'createdAt': '2026-11-09T00:00:00Z',
                    'isRead': true,
                  },
                ],
              });
            }
            if (path == resource) {
              return jsonResponse(
                200,
                director
                    ? {
                        'fromUserName': 'Cha xứ',
                        'content': 'Nội dung ghi chú đầy đủ',
                        'sentAt': '2026-11-09T00:00:00Z',
                      }
                    : {
                        'id': 'resource',
                        'eventId': 'event',
                        'status': reviewStatus,
                        'items': [
                          {'id': 'item', 'songTitle': 'Ca nhập lễ'},
                        ],
                      },
              );
            }
            return jsonResponse(404, {'code': 'NOT_FOUND'});
          });
        final roleContainer = ProviderContainer(
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            authRepositoryProvider.overrideWithValue(repository),
            apiClientProvider.overrideWithValue(
              ApiClient(
                storage: storage,
                sessionManager: session,
                customDio: dio,
              ),
            ),
          ],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          roleContainer.dispose();
          dio.close();
        });
        final router = roleContainer.read(appRouterProvider);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: roleContainer,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(session.status, AuthStatus.authenticated);
        expect(router.routeInformationProvider.value.uri.path, '/home');
        expect(find.text(role.label), findsOneWidget);
        if (director) {
          expect(
            find.widgetWithText(ListTile, 'Kỹ năng chờ duyệt'),
            findsOneWidget,
          );
          expect(
            find.widgetWithText(ListTile, 'Bản thu chờ chấm'),
            findsOneWidget,
          );
          expect(find.text('2'), findsNWidgets(2));
        }
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, workspace);
        expect(requests, contains(workspaceApi));
        expect(
          find.text(director ? 'Ca đoàn Cecilia' : 'Danh sách bài hát • Bản 1'),
          findsOneWidget,
        );

        router.go(director ? '/approvals' : '/manage');
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/home');
        router.go('/practice-detail/member-assignment');
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/home');
        expect(requests.any((path) => path.contains('/mine')), isFalse);

        await tester.tap(find.text('Lịch'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chương trình kiểm thử'));
        await tester.pumpAndSettle();
        expect(requests, contains(eventApi));
        expect(find.text('Ghi chú mục vụ & Dặn dò phòng áo'), findsOneWidget);
        expect(
          find.widgetWithText(
            FilledButton,
            director ? 'Đề xuất bài hát' : 'Công bố phụng vụ',
          ),
          findsOneWidget,
        );
        router.pop();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thông báo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Thông báo theo vai trò'));
        await tester.pumpAndSettle();
        expect(
          router.routerDelegate.currentConfiguration.last.matchedLocation,
          detail,
        );
        expect(requests, contains(resource));
        expect(
          find.text(director ? 'Nội dung ghi chú đầy đủ' : 'Ca nhập lễ'),
          findsOneWidget,
        );
        if (!director) {
          final approve = find.widgetWithText(
            FilledButton,
            'Phê duyệt danh sách',
          );
          await tester.ensureVisible(approve);
          await tester.tap(approve);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
          await tester.pumpAndSettle();
          expect(requests, contains('/api/song-lists/resource/review'));
          expect(find.text('Đã duyệt'), findsOneWidget);
        }
      },
    );
  }

  for (final serverWorks in [true, false]) {
    testWidgets(
      'profile current-device logout confirmation server=$serverWorks',
      (tester) async {
        await saveAccount();
        if (!serverWorks) {
          api.currentDeviceLogoutHandler = () async =>
              throw const NetworkException();
        }
        await open(tester, const ProfileScreen());
        await tester.pumpAndSettle();
        expect(find.text('Đăng xuất mọi thiết bị'), findsNothing);
        final action = find.text('Đăng xuất');
        expect(action, findsOneWidget);
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();
        expect(api.logoutCalls, 0);
        expect(api.currentDeviceLogoutCalls, 0);
        await tester.tap(action);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng xuất'));
        await tester.pumpAndSettle();
        expect(api.logoutCalls, 0);
        expect(api.currentDeviceLogoutCalls, 1);
        expect(session.isAuthenticated, isFalse);
        expect(find.text('LOGIN TARGET'), findsOneWidget);
        expect(await storage.getAccessToken(), isNull);
        expect(await storage.getRefreshToken(), isNull);
        expect(container.read(authNotifierProvider).user, isNull);
      },
    );
  }

  testWidgets(
    'current-device logout remains available when profile fails to load',
    (tester) async {
      await saveAccount();
      replaceOverrides(profile: UnavailableProfileRepository());
      await open(tester, const ProfileScreen());
      await tester.pumpAndSettle();
      expect(
        find.text('Không thể tải dữ liệu hồ sơ từ máy chủ.'),
        findsOneWidget,
      );
      expect(find.text('Đăng xuất mọi thiết bị'), findsNothing);
      final action = find.text('Đăng xuất');
      expect(action, findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng xuất'));
      await tester.pumpAndSettle();
      expect(api.logoutCalls, 0);
      expect(api.currentDeviceLogoutCalls, 1);
      expect(find.text('LOGIN TARGET'), findsOneWidget);
    },
  );
}
