import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
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
}
