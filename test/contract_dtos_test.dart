import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/features/auth/data/auth_dto.dart';
import 'package:harmonia_mobile/features/lookups/data/lookup_dto.dart';
import 'package:harmonia_mobile/features/music/data/music_dto.dart';
import 'package:harmonia_mobile/features/profile/data/member_profile_dto.dart';

void main() {
  group('Backend Contract DTO Tests', () {
    test('MemberProfileDto correctly parses API response', () {
      final json = {
        'id': 'mem-101',
        'fullName': 'Têrêsa Trần Thị Hương',
        'email': 'teresa.huong@harmonia.org',
        'phone': '0901234567',
        'dateOfBirth': '1998-12-25',
        'joinedDate': '2023-01-15T00:00:00Z',
        'status': 'Active',
        'avatarUrl': 'https://storage.harmonia.org/avatars/teresa.png',
      };

      final profile = MemberProfileDto.fromJson(json);
      expect(profile.id, 'mem-101');
      expect(profile.fullName, 'Têrêsa Trần Thị Hương');
      expect(profile.email, 'teresa.huong@harmonia.org');
      expect(profile.phone, '0901234567');
      expect(profile.dateOfBirth, '1998-12-25');
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
      );
      final updateJson = updateReq.toJson();
      expect(updateJson['fullName'], 'Têrêsa Trần Thị Hương (Cập nhật)');
      expect(updateJson['phone'], '0909999888');
      expect(updateJson['dateOfBirth'], '1998-12-25');
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

    test('Auth extended requests serialize properly', () {
      const googleReq = GoogleLoginRequest(
        idToken: 'google-id-token-abc',
        deviceId: 'dev-456',
        platform: 0,
      );
      expect(googleReq.toJson()['idToken'], 'google-id-token-abc');

      const changePwReq = ChangePasswordRequest(
        currentPassword: 'OldPassword123!',
        newPassword: 'NewPassword456!',
      );
      expect(changePwReq.toJson()['currentPassword'], 'OldPassword123!');
      expect(changePwReq.toJson()['newPassword'], 'NewPassword456!');

      const forgotPwReq = ForgotPasswordRequest(email: 'test@harmonia.org');
      expect(forgotPwReq.toJson()['email'], 'test@harmonia.org');

      const resetPwReq = ResetPasswordRequest(
        token: 'token-xyz',
        newPassword: 'NewPassword789!',
      );
      expect(resetPwReq.toJson()['token'], 'token-xyz');
      expect(resetPwReq.toJson()['newPassword'], 'NewPassword789!');
    });
  });
}
