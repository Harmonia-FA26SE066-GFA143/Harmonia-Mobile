import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
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
