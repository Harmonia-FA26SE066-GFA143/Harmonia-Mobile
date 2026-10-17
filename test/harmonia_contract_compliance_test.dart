import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/network/api_client.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/auth/data/auth_api_service.dart';
import 'package:harmonia_mobile/features/auth/data/auth_dto.dart';
import 'package:harmonia_mobile/features/auth/data/auth_repository.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_api_service.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_member_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_repository.dart';
import 'package:harmonia_mobile/features/calendar/data/liturgical_models.dart';
import 'package:harmonia_mobile/features/music/data/music_api_service.dart';
import 'package:harmonia_mobile/features/music/data/music_dto.dart';
import 'package:harmonia_mobile/features/music/data/music_repository.dart';
import 'package:harmonia_mobile/features/practice/data/practice_api_service.dart';
import 'package:harmonia_mobile/features/practice/data/practice_repository.dart';

class FakeSecureStorageService extends SecureStorageService {
  final Map<String, String> storage = {};

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String expiresAt,
  }) async {
    storage['harmonia_access_token'] = accessToken;
    storage['harmonia_refresh_token'] = refreshToken;
    storage['harmonia_expires_at'] = expiresAt;
  }

  @override
  Future<void> saveUser({
    required String id,
    required String email,
    required String roleName,
    String? fullName,
  }) async {
    storage['harmonia_user_id'] = id;
    storage['harmonia_user_email'] = email;
    storage['harmonia_user_role'] = roleName;
  }

  @override
  Future<void> savePasswordChangeRequired(bool required) async {
    storage['harmonia_is_password_change_required'] = required
        ? 'true'
        : 'false';
  }

  @override
  Future<bool> isPasswordChangeRequired() async {
    return storage['harmonia_is_password_change_required'] == 'true';
  }

  @override
  Future<String?> getAccessToken() async => storage['harmonia_access_token'];
  @override
  Future<String?> getRefreshToken() async => storage['harmonia_refresh_token'];
  @override
  Future<String?> getUserRole() async => storage['harmonia_user_role'];

  @override
  Future<void> clearAll() async => storage.clear();
}

class FakeApiClient extends ApiClient {
  FakeApiClient()
    : super(
        storage: FakeSecureStorageService(),
        sessionManager: SessionManager(FakeSecureStorageService()),
        customDio: Dio(),
      );
}

class FakeAuthApiService extends AuthApiService {
  FakeAuthApiService() : super(FakeApiClient());

  @override
  Future<void> changePassword(ChangePasswordRequest request) async {
    // Simulates successful password change on server
  }
}

class FakeCalendarApiService extends CalendarApiService {
  @override
  Future<List<MyParticipation>> getMyParticipations() async => [
    MyParticipation(
      participationId: 'invitation-1',
      eventId: 'event-1',
      status: ParticipationStatus.invited,
      requestedAt: DateTime.utc(2026, 10, 15),
      canRespond: true,
    ),
  ];
  FakeCalendarApiService() : super(FakeApiClient());

  @override
  Future<ParticipationReply> respondParticipation(
    String id,
    ParticipationStatus status, {
    int? expectedSessionEpoch,
  }) async => throw const ForbiddenException();

  @override
  Future<List<Map<String, dynamic>>> getUpcomingRehearsals() async {
    return [
      {
        'id': 'rehearsal-1',
        'startTime': '2026-10-15T01:00:00Z',
        'endTime': '2026-10-15T03:00:00Z',
        'locationName': 'Nhà nguyện',
        'note': 'Luyện bè Soprano',
        'songs': [
          {'songTitle': 'Kinh Hòa Bình'},
        ],
      },
    ];
  }
}

class FakePracticeApiService extends PracticeApiService {
  FakePracticeApiService() : super(FakeApiClient());

  @override
  Future<Map<String, dynamic>> getMyAssignments({
    bool? isOpen,
    String? status,
    bool? hasSubmission,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    return {
      'items': [
        {
          'id': 'practice-1',
          'title': 'Luyện bài Kinh Hòa Bình',
          'instruction': 'Hát đúng cao độ và nốt ngân dài ở điệp khúc.',
          'dueDate': '2026-10-20T12:00:00Z',
          'latestSubmissionStatus': 'Pending',
        },
      ],
    };
  }
}

class FakeMusicApiService extends MusicApiService {
  String? lastEventIdCalled;

  FakeMusicApiService() : super(FakeApiClient());

  @override
  Future<SongListDto?> getApprovedSongListForEvent(String eventId) async {
    lastEventIdCalled = eventId;
    return SongListDto(
      id: 'songlist-1',
      eventId: eventId,
      version: 1,
      status: 'Approved',
      items: [
        const SongListItemDto(
          id: 'item-1',
          songId: 'song-101',
          songTitle: 'Tán Tụng Hồng Ân',
          slotId: 'slot-1',
          slotName: 'Ca nhập lễ',
          displayOrder: 1,
          note: 'Hát cả cộng đoàn',
        ),
      ],
    );
  }
}

void main() {
  group('Backend Contract Compliance Tests (Harmonia Review 11/10/2026)', () {
    test(
      '1. Instruction from BE must propagate to PracticeAssignment model',
      () async {
        final fakeApi = FakePracticeApiService();
        final repo = PracticeRepositoryImpl(apiService: fakeApi);

        final assignments = await repo.getAssignments();
        expect(assignments, isNotEmpty);
        final assignment = assignments.first;

        expect(
          assignment.instruction,
          equals('Hát đúng cao độ và nốt ngân dài ở điệp khúc.'),
        );
        // Due date is converted to local
        expect(assignment.dueDate.isUtc, isFalse);
      },
    );

    test('2. Rehearsal UTC timestamps must be converted to local time in timeRange', () async {
      final fakeApi = FakeCalendarApiService();
      final repo = CalendarRepositoryImpl(apiService: fakeApi);

      final rehearsals = await repo.getRehearsals();
      expect(rehearsals, isNotEmpty);
      final rehearsal = rehearsals.first;

      // Local time for 01:00 UTC in UTC+7 (Vietnam) is 08:00
      final expectedLocalHour = DateTime.parse('2026-10-15T01:00:00Z')
          .toLocal()
          .hour;
      final expectedHourString = expectedLocalHour.toString().padLeft(2, '0');

      expect(rehearsal.timeRange.startsWith(expectedHourString), isTrue);
      expect(rehearsal.date.isUtc, isFalse);
    });

    test(
      '3. Rejected participation confirmation must not complete silently',
      () async {
        final fakeApi = FakeCalendarApiService();
        final repo = CalendarRepositoryImpl(apiService: fakeApi);

        expect(
          () => repo.updateParticipation(
            'event-1',
            ParticipationStatus.confirmed,
          ),
          throwsA(isA<ForbiddenException>()),
        );
      },
    );

    test('4. Event song list must call approved endpoint by eventId', () async {
      final fakeApi = FakeMusicApiService();
      final repo = MusicRepositoryImpl(apiService: fakeApi);

      final songs = await repo.getSongListForEvent('evt-999');
      expect(fakeApi.lastEventIdCalled, equals('evt-999'));
      expect(songs, hasLength(1));
      expect(songs.first.title, equals('Tán Tụng Hồng Ân'));
      expect(songs.first.slotName, equals('Ca nhập lễ'));
    });

    test(
      '5. Password change revokes session and ends local authentication',
      () async {
        final fakeStorage = FakeSecureStorageService();
        final sessionManager = SessionManager(fakeStorage);
        final fakeAuthApi = FakeAuthApiService();
        final authRepo = AuthRepositoryImpl(
          apiService: fakeAuthApi,
          storage: fakeStorage,
          sessionManager: sessionManager,
        );

        sessionManager.markAuthenticated(role: 'ChoirMember');
        expect(sessionManager.isAuthenticated, isTrue);

        await authRepo.changePassword(
          currentPassword: 'OldPassword123!',
          newPassword: 'NewPassword123!',
        );

        expect(sessionManager.isAuthenticated, isFalse);
        expect(sessionManager.status, equals(AuthStatus.unauthenticated));
      },
    );

    test('6. Password change required flag is persisted and tracked in SessionManager', () async {
      final fakeStorage = FakeSecureStorageService();
      final sessionManager = SessionManager(fakeStorage);

      sessionManager.markAuthenticated(
        role: 'ChoirMember',
        isPasswordChangeRequired: true,
      );
      expect(sessionManager.isPasswordChangeRequired, isTrue);

      final storedFlag = await fakeStorage.isPasswordChangeRequired();
      expect(storedFlag, isTrue);

      // Re-initialize session restores the flag
      final restoredSession = SessionManager(fakeStorage);
      await fakeStorage.saveTokens(
        accessToken: 'valid-token',
        refreshToken: 'valid-refresh',
        expiresAt: '2026-10-15T00:00:00Z',
      );
      await fakeStorage.saveUser(
        id: 'u-1',
        email: 'mem@harmonia.local',
        roleName: 'ChoirMember',
      );
      await restoredSession.initialize();

      expect(restoredSession.isAuthenticated, isTrue);
      expect(restoredSession.isPasswordChangeRequired, isTrue);
    });
  });
}
