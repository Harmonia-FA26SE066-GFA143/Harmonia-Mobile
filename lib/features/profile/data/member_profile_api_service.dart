import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../notifications/data/notification_dto.dart';
import 'member_profile_dto.dart';

class MemberProfileApiService {
  final ApiClient _client;

  MemberProfileApiService(this._client);

  Future<MemberProfileDto> getMyProfile() async {
    try {
      final response = await _client.dio.get(ApiEndpoints.memberProfileMe);
      return MemberProfileDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<MemberProfileDto> updateMyProfile(
    UpdateMyMemberProfileRequest request,
  ) async {
    try {
      final response = await _client.dio.put(
        ApiEndpoints.memberProfileMe,
        data: request.toJson(),
      );
      return MemberProfileDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<void> updateMyAvatar(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const AppException(
        code: 'AVATAR_FILE_REQUIRED',
        message: 'Không tìm thấy ảnh đã chọn.',
      );
    }

    final extension = file.uri.pathSegments.last.split('.').last.toLowerCase();
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      throw const AppException(
        code: 'AVATAR_FILE_TYPE_NOT_ALLOWED',
        message: 'Ảnh phải có định dạng JPG, PNG hoặc WEBP.',
      );
    }

    final size = await file.length();
    if (size == 0) {
      throw const AppException(
        code: 'AVATAR_FILE_REQUIRED',
        message: 'Tệp ảnh đang rỗng.',
      );
    }
    if (size > 2 * 1024 * 1024) {
      throw const AppException(
        code: 'AVATAR_FILE_TOO_LARGE',
        message: 'Ảnh đại diện không được vượt quá 2 MB.',
      );
    }

    final epoch = _client.sessionManager.sessionEpoch;
    try {
      await _client.dio.put(
        ApiEndpoints.authMeAvatar,
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(
            filePath,
            filename: file.uri.pathSegments.last,
          ),
        }),
        options: Options(extra: {'expectedSessionEpoch': epoch}),
      );
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<void> deleteMyAvatar() async {
    final epoch = _client.sessionManager.sessionEpoch;
    try {
      await _client.dio.delete(
        ApiEndpoints.authMeAvatar,
        options: Options(extra: {'expectedSessionEpoch': epoch}),
      );
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<PagedList<MemberSkillDto>> getMySkills({
    String? status,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    try {
      final query = <String, dynamic>{
        'pageNumber': pageNumber,
        'pageSize': pageSize,
      };
      if (status != null && status.isNotEmpty) query['status'] = status;

      final response = await _client.dio.get(
        ApiEndpoints.memberSkillsMine,
        queryParameters: query,
      );
      return PagedList<MemberSkillDto>.fromJson(
        response.data as Map<String, dynamic>,
        MemberSkillDto.fromJson,
      );
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<MemberSkillDto> getMemberSkillById(String id) async {
    try {
      final response = await _client.dio.get(ApiEndpoints.memberSkillById(id));
      return MemberSkillDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<MemberSkillDto> declareSkill({
    required String skillId,
    String? level,
  }) async {
    try {
      final data = <String, dynamic>{'skillId': skillId};
      if (level != null && level.isNotEmpty) data['level'] = level;
      final response = await _client.dio.post(
        ApiEndpoints.memberSkills,
        data: data,
      );
      return MemberSkillDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<MemberSkillDto> uploadSkillEvidence(
    String id,
    String filePath, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists() || await file.length() == 0) {
      throw const AppException(
        code: 'MEMBER_SKILL_EVIDENCE_REQUIRED',
        message: 'Vui lòng chọn tệp minh chứng.',
      );
    }

    final fileName = file.uri.pathSegments.last;
    final extension = fileName.split('.').last.toLowerCase();
    final length = await file.length();
    const voiceExtensions = {'mp3', 'm4a', 'wav'};
    const clipExtensions = {'mp4', 'mov'};
    final maxBytes = voiceExtensions.contains(extension)
        ? 20 * 1024 * 1024
        : clipExtensions.contains(extension)
        ? 100 * 1024 * 1024
        : 0;
    if (maxBytes == 0) {
      throw const AppException(
        code: 'MEMBER_SKILL_EVIDENCE_TYPE_NOT_ALLOWED',
        message: 'Chỉ hỗ trợ ghi âm MP3, M4A, WAV hoặc video MP4, MOV.',
      );
    }
    if (length > maxBytes) {
      throw const AppException(
        code: 'MEMBER_SKILL_EVIDENCE_TOO_LARGE',
        message: 'Tệp minh chứng vượt quá dung lượng cho phép.',
      );
    }

    final epoch = _client.sessionManager.sessionEpoch;
    try {
      final response = await _client.dio.put(
        ApiEndpoints.memberSkillEvidence(id),
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(filePath, filename: fileName),
        }),
        onSendProgress: onSendProgress,
        options: Options(
          extra: {
            'expectedSessionEpoch': epoch,
            // A multipart file may have been consumed; the user can retry explicitly.
            'skipAuthRetry': true,
          },
        ),
      );
      return MemberSkillDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<PagedList<ParticipationHistoryDto>> getParticipationHistory({
    String? liturgicalSeasonId,
    String? fromDate,
    String? toDate,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    try {
      final query = <String, dynamic>{
        'pageNumber': pageNumber,
        'pageSize': pageSize,
      };
      if (liturgicalSeasonId != null && liturgicalSeasonId.isNotEmpty) {
        query['liturgicalSeasonId'] = liturgicalSeasonId;
      }
      if (fromDate != null && fromDate.isNotEmpty) query['fromDate'] = fromDate;
      if (toDate != null && toDate.isNotEmpty) query['toDate'] = toDate;

      final response = await _client.dio.get(
        ApiEndpoints.memberProfileHistory,
        queryParameters: query,
      );
      return PagedList<ParticipationHistoryDto>.fromJson(
        response.data as Map<String, dynamic>,
        ParticipationHistoryDto.fromJson,
      );
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }
}
