import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/network/api_client.dart';
import 'package:harmonia_mobile/core/realtime/signalr_service.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/auth/data/auth_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_api_service.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_repository.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_member_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/liturgical_models.dart';
import 'package:harmonia_mobile/features/lookups/data/lookup_dto.dart';
import 'package:harmonia_mobile/features/music/data/music_dto.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_api_service.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_repository.dart';
import 'package:harmonia_mobile/features/practice/data/practice_api_service.dart';
import 'package:harmonia_mobile/features/practice/data/practice_models.dart';
import 'package:harmonia_mobile/features/practice/data/practice_repository.dart';
import 'package:harmonia_mobile/features/profile/data/member_profile_api_service.dart';
import 'package:harmonia_mobile/features/profile/data/profile_models.dart';
import 'package:harmonia_mobile/features/profile/data/profile_repository.dart';

class FakeCalendarApiService extends CalendarApiService {
  @override
  Future<List<MyParticipation>> getMyParticipations() async => [];
  @override
  Future<List<MyAssignedEvent>> getMyAssignments() async => [];
  FakeCalendarApiService()
    : super(
        ApiClient(
          storage: SecureStorageService(),
          sessionManager: SessionManager(SecureStorageService()),
          customDio: Dio(),
        ),
      );

  @override
  Future<List<Map<String, dynamic>>> getUpcomingEvents() async => [
    {
      'id': 'evt-101',
      'eventDate': '2026-10-15',
      'time': '08:00:00',
      'title': 'Thánh lễ Giáng Sinh',
      'locationName': 'Nhà thờ Chính Tòa',
      'status': 'Published',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> getUpcomingRehearsals({
    String? fromDate,
    String? toDate,
  }) async => [
    {
      'id': 'reh-202',
      'startTime': '2026-10-14T19:00:00Z',
      'endTime': '2026-10-14T21:00:00Z',
      'locationName': 'Phòng tập ca đoàn',
      'note': 'Tập hát lễ Chúa Nhật',
      'songs': [
        {'songId': 's-1', 'songTitle': 'Kinh Hòa Bình', 'displayOrder': 1},
      ],
    },
  ];
}

class FakePracticeApiService extends PracticeApiService {
  String? lastSubmittedId;
  int? lastDuration;

  FakePracticeApiService()
    : super(
        ApiClient(
          storage: SecureStorageService(),
          sessionManager: SessionManager(SecureStorageService()),
          customDio: Dio(),
        ),
      );

  @override
  Future<Map<String, dynamic>> getMyAssignments({
    bool? isOpen,
    String? status,
    bool? hasSubmission,
    int pageNumber = 1,
    int pageSize = 50,
  }) async => {
    'items': [
      {
        'id': 'assign-01',
        'title': 'Thu âm bè Soprano',
        'songTitle': 'Kinh Hòa Bình',
        'description': 'Lấy hơi đúng phách',
        'dueDate': '2026-10-20T12:00:00Z',
        'isOpen': true,
        'latestSubmissionStatus': 'Submitted',
        'isOverdue': false,
      },
    ],
    'totalCount': 1,
  };

  @override
  Future<void> submitRecording({
    required String assignmentId,
    required String filePath,
    required int durationSeconds,
  }) async {
    lastSubmittedId = assignmentId;
    lastDuration = durationSeconds;
  }
}

class FakeMemberProfileApiService extends MemberProfileApiService {
  String? lastDeclaredSkillId;

  FakeMemberProfileApiService()
    : super(
        ApiClient(
          storage: SecureStorageService(),
          sessionManager: SessionManager(SecureStorageService()),
          customDio: Dio(),
        ),
      );

  @override
  Future<PagedList<MemberSkillDto>> getMySkills({
    String? status,
    int pageNumber = 1,
    int pageSize = 50,
  }) async => PagedList<MemberSkillDto>(
    items: [
      MemberSkillDto(
        id: 'ms-01',
        skillId: 'skill-tenor',
        skillName: 'Tenor',
        categoryId: 'cat-vocal',
        categoryName: 'Vocal',
        status: 'Approved',
      ),
      MemberSkillDto.fromJson({
        'id': 'ms-03',
        'skillId': 'skill-bass',
        'skillName': 'Bass',
        'categoryId': 'cat-vocal',
        'categoryName': 'Vocal',
        'status': 'Revoked',
        'revokedAt': '2026-11-18T07:00:00Z',
        'revokeReason': 'Test reason',
      }),
    ],
    pageNumber: pageNumber,
    pageSize: pageSize,
    totalCount: 2,
    totalPages: 1,
    hasPreviousPage: false,
    hasNextPage: false,
  );

  @override
  Future<MemberSkillDto> declareSkill({required String skillId}) async {
    lastDeclaredSkillId = skillId;
    return MemberSkillDto(
      id: 'ms-02',
      skillId: skillId,
      skillName: 'Alto',
      categoryId: 'cat-vocal',
      categoryName: 'Vocal',
      status: 'Pending',
    );
  }
}

class FakeNotificationApiService extends NotificationApiService {
  bool markAllCalled = false;

  FakeNotificationApiService()
    : super(
        ApiClient(
          storage: SecureStorageService(),
          sessionManager: SessionManager(SecureStorageService()),
          customDio: Dio(),
        ),
      );

  @override
  Future<void> markAllAsRead() async {
    markAllCalled = true;
  }
}

void main() {
  group('Backend Contract DTO Tests', () {
    test('MemberProfileDto correctly parses API response', () {
      final json = {
        'id': 'mem-101',
        'fullName': 'Têrêsa Trần Thị Hương',
        'email': 'teresa.huong@harmonia.org',
        'phone': '0901234567',
        'dateOfBirth': '1998-12-25',
        'saintName': 'Têrêsa',
        'gender': 'Female',
        'joinedDate': '2023-01-15T00:00:00Z',
        'status': 'Active',
        'avatarUrl': 'https://storage.harmonia.org/avatars/teresa.png',
        'choirNames': ['Ca đoàn Cecilia', 'Ca đoàn Thánh Gia'],
      };

      final profile = MemberProfileDto.fromJson(json);
      expect(profile.id, 'mem-101');
      expect(profile.fullName, 'Têrêsa Trần Thị Hương');
      expect(profile.email, 'teresa.huong@harmonia.org');
      expect(profile.phone, '0901234567');
      expect(profile.dateOfBirth, '1998-12-25');
      expect(profile.gender, MemberGender.female);
      expect(profile.saintName, 'Têrêsa');
      expect(profile.choirNames, json['choirNames']);
      expect(profile.toJson()['choirNames'], json['choirNames']);
      expect(
        MemberProfileDto.fromJson({...json, 'choirNames': []}).choirNames,
        isEmpty,
      );
      expect(
        MemberProfileDto.fromJson({...json}..remove('choirNames')).choirNames,
        isNull,
      );
      expect(
        MemberProfileDto.fromJson({...json, 'gender': null}).gender,
        isNull,
      );
      expect(
        MemberProfileDto.fromJson({...json}..remove('gender')).gender,
        isNull,
      );
      expect(profile.joinedDate, '2023-01-15T00:00:00Z');
      expect(profile.status, MemberStatus.active);
      expect(
        profile.avatarUrl,
        'https://storage.harmonia.org/avatars/teresa.png',
      );

      final updateReq = UpdateMyMemberProfileRequest(
        fullName: 'Têrêsa Trần Thị Hương (Cập nhật)',
        phone: '0909999888',
        dateOfBirth: '1998-12-25',
        saintName: profile.saintName,
        gender: MemberGender.male,
      );
      final updateJson = updateReq.toJson();
      expect(updateJson['fullName'], 'Têrêsa Trần Thị Hương (Cập nhật)');
      expect(updateJson['phone'], '0909999888');
      expect(updateJson['dateOfBirth'], '1998-12-25');
      expect(updateJson['gender'], 'Male');
      expect(updateJson['saintName'], 'Têrêsa');
      expect(
        const UpdateMyMemberProfileRequest(fullName: 'Ca viên').toJson(),
        isNot(contains('gender')),
      );
    });

    test(
      'LookupItemDto and LiturgicalSlotDto correctly parse lookup responses',
      () {
        final lookupJson = {
          'id': 'lookup-01',
          'name': 'Mùa Thường Niên',
          'description': 'Mùa Thường Niên trong năm phụng vụ',
        };

        final lookup = LookupItemDto.fromJson(lookupJson);
        expect(lookup.id, 'lookup-01');
        expect(lookup.name, 'Mùa Thường Niên');
        expect(lookup.description, 'Mùa Thường Niên trong năm phụng vụ');

        final slotJson = {
          'id': 'slot-01',
          'name': 'Ca Nhập Lễ',
          'defaultOrder': 1,
        };
        final slot = LiturgicalSlotDto.fromJson(slotJson);
        expect(slot.id, 'slot-01');
        expect(slot.name, 'Ca Nhập Lễ');
        expect(slot.defaultOrder, 1);
      },
    );

    test('Song and MusicMaterial DTOs parse correctly', () {
      final songJson = {
        'id': 'song-55',
        'title': 'Kinh Hòa Bình',
        'composer': 'Lm. Kim Long',
        'lyricist': 'Ý thơ Thánh Phanxicô',
        'tempo': 'Andante',
        'notes': 'Hát nhịp nhàng',
      };

      final song = SongDto.fromJson(songJson);
      expect(song.id, 'song-55');
      expect(song.title, 'Kinh Hòa Bình');
      expect(song.composer, 'Lm. Kim Long');
      expect(song.tempo, 'Andante');

      final classificationJson = {
        'songId': 'song-55',
        'liturgicalSeasons': [
          {'id': 'season-01', 'name': 'Thường Niên'},
        ],
        'massTypes': [
          {'id': 'mass-01', 'name': 'Chúa Nhật'},
        ],
        'vocalRequirements': [
          {'skillId': 'vocal-01', 'skillName': 'Soprano', 'isMandatory': true},
        ],
      };
      final classification = SongClassificationDto.fromJson(classificationJson);
      expect(classification.songId, 'song-55');
      expect(classification.liturgicalSeasons.first.name, 'Thường Niên');
      expect(classification.vocalRequirements.first.skillName, 'Soprano');
      expect(classification.vocalRequirements.first.isMandatory, true);

      final materialJson = {
        'id': 'mat-01',
        'songId': 'song-55',
        'materialType': 'SampleAudio',
        'title': 'Bè Soprano Audio',
        'fileName': 'soprano.mp3',
        'fileSizeBytes': 1024000,
        'targetSkillId': 'skill-soprano',
        'targetSkillName': 'Soprano',
        'fileUrl': 'https://example.com/audio/soprano.mp3',
        'createdAt': '2026-01-01T00:00:00Z',
        'learningStatus': 'Learned',
      };
      final material = MusicMaterialDetailDto.fromJson(materialJson);
      expect(material.id, 'mat-01');
      expect(material.materialType, MaterialType.sampleAudio);
      expect(material.targetSkillName, 'Soprano');
      expect(material.learningStatus, LearningStatus.learned);

      const progressReq = UpdateMaterialLearningProgressRequest(
        status: LearningStatus.learned,
      );
      expect(progressReq.toJson()['status'], 'Learned');
    });

    test('Interactive scores decode from both API enum representations', () {
      for (final value in ['InteractiveScore', 4]) {
        final material = MusicMaterialDto.fromJson({'materialType': value});
        expect(material.materialType, MaterialType.interactiveScore);
      }
      expect(MaterialType.fromWire('FutureType'), MaterialType.unknown);
      expect(MaterialType.filterOptions, isNot(contains(MaterialType.unknown)));
    });

    test('Auth extended requests and UserDto serialize properly', () {
      const googleReq = GoogleLoginRequest(
        idToken: 'google-id-token-abc',
        deviceId: 'dev-456',
        platform: 'Android',
      );
      expect(googleReq.toJson()['idToken'], 'google-id-token-abc');
      expect(googleReq.toJson()['platform'], 'Android');

      const changePwReq = ChangePasswordRequest(
        currentPassword: 'OldPassword123!',
        newPassword: 'NewPassword456!',
      );
      expect(changePwReq.toJson()['currentPassword'], 'OldPassword123!');
      expect(changePwReq.toJson()['newPassword'], 'NewPassword456!');

      const forgotPwReq = ForgotPasswordRequest(
        email: 'test@harmonia.org',
        platform: 'iOS',
      );
      expect(forgotPwReq.toJson()['email'], 'test@harmonia.org');
      expect(forgotPwReq.toJson()['platform'], 'iOS');

      const resetPwReq = ResetPasswordRequest(
        token: 'token-xyz',
        newPassword: 'NewPassword789!',
      );
      expect(resetPwReq.toJson()['token'], 'token-xyz');
      expect(resetPwReq.toJson()['newPassword'], 'NewPassword789!');

      final userJson = {
        'id': 'u-101',
        'email': 'ca.vien@harmonia.org',
        'fullName': 'Maria Nguyễn',
        'phone': '0912345678',
        'roleName': 'ChoirMember',
        'isActive': true,
        'isPasswordChangeRequired': false,
      };
      final user = UserDto.fromJson(userJson);
      expect(user.id, 'u-101');
      expect(user.email, 'ca.vien@harmonia.org');
      expect(user.phone, '0912345678');
      expect(user.isActive, true);
      expect(user.isPasswordChangeRequired, false);

      const updateMyUserReq = UpdateMyUserRequest(
        fullName: 'Maria Nguyễn Cập Nhật',
        phone: '0988777666',
      );
      final updateMyUserJson = updateMyUserReq.toJson();
      expect(updateMyUserJson['fullName'], 'Maria Nguyễn Cập Nhật');
      expect(updateMyUserJson['phone'], '0988777666');
    });

    test(
      'CalendarRepositoryImpl maps events and rehearsals from schedule API',
      () async {
        final fakeApi = FakeCalendarApiService();
        final repo = CalendarRepositoryImpl(apiService: fakeApi);

        final events = await repo.getEvents();
        expect(events.length, 1);
        expect(events.first.id, 'evt-101');
        expect(events.first.title, 'Thánh lễ Giáng Sinh');
        expect(events.first.location, 'Nhà thờ Chính Tòa');
        expect(events.first.participationStatus, ParticipationStatus.unknown);

        final rehearsals = await repo.getRehearsals();
        expect(rehearsals.length, 1);
        expect(rehearsals.first.id, 'reh-202');
        expect(rehearsals.first.location, 'Phòng tập ca đoàn');
        expect(rehearsals.first.contentSummary, 'Kinh Hòa Bình');
      },
    );

    test(
      'PracticeRepositoryImpl maps assignments and handles submission',
      () async {
        final fakeApi = FakePracticeApiService();
        final repo = PracticeRepositoryImpl(apiService: fakeApi);

        final assignments = await repo.getAssignments();
        expect(assignments.length, 1);
        expect(assignments.first.id, 'assign-01');
        expect(assignments.first.title, 'Thu âm bè Soprano');
        expect(assignments.first.status, PracticeStatus.submitted);

        await repo.submitRecording(
          assignmentId: 'assign-01',
          audioPath: 'dummy/path/audio.mp3',
          durationSeconds: 120,
        );
        expect(fakeApi.lastSubmittedId, 'assign-01');
        expect(fakeApi.lastDuration, 120);
      },
    );

    test(
      'ProfileRepositoryImpl maps member skills from member-skills API',
      () async {
        final fakeApi = FakeMemberProfileApiService();
        final repo = ProfileRepositoryImpl(apiService: fakeApi);

        final skills = await repo.getSkills();
        expect(skills.length, 2);
        expect(skills.first.name, 'Tenor');
        expect(skills.first.status, SkillApprovalStatus.approved);
        expect(skills.last.status, SkillApprovalStatus.revoked);
        expect(skills.last.revokedAt?.toUtc(), DateTime.utc(2026, 11, 18, 7));
        expect(skills.last.revokeReason, 'Test reason');

        await repo.declareNewSkill(
          skillId: 'skill-alto',
          name: 'skill-alto',
          categoryName: 'Vocal',
        );
        expect(fakeApi.lastDeclaredSkillId, 'skill-alto');
      },
    );

    test(
      'declaring a skill validates its GUID and sends only skillId',
      () async {
        const skillId = 'B063B240-28CB-4F0F-B5DA-E26E7067C5CF';
        final requests = <RequestOptions>[];
        final storage = SecureStorageService();
        final session = SessionManager(storage);
        addTearDown(session.dispose);
        final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
        addTearDown(dio.close);
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {'skillId': skillId, 'status': 'Pending'},
                ),
              );
            },
          ),
        );
        final api = MemberProfileApiService(
          ApiClient(storage: storage, sessionManager: session, customDio: dio),
        );
        for (final invalidId in [
          '',
          'not-a-guid',
          '$skillId\n',
          '00000000-0000-0000-0000-000000000000',
        ]) {
          await expectLater(
            api.declareSkill(skillId: invalidId),
            throwsA(
              isA<ValidationException>().having(
                (error) => error.code,
                'code',
                'MEMBER_SKILL_ID_INVALID',
              ),
            ),
          );
        }
        expect(requests, isEmpty);

        expect((await api.declareSkill(skillId: skillId)).status, 'Pending');
        final request = requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/api/member-skills');
        expect(request.data, {'skillId': skillId});
      },
    );

    test('NotificationRepositoryImpl marks all as read via API', () async {
      final fakeApi = FakeNotificationApiService();
      final fakeSignalR = FakeSignalRService();
      final repo = NotificationRepositoryImpl(
        apiService: fakeApi,
        signalRService: fakeSignalR,
      );

      await repo.markAllAsRead();
      expect(fakeApi.markAllCalled, true);
    });
  });
}

class FakeSignalRService extends SignalRService {
  FakeSignalRService() : super(SecureStorageService());

  @override
  Stream<Map<String, dynamic>> get notificationStream => const Stream.empty();
}
