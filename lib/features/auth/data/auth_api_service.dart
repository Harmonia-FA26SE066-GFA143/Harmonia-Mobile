import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import 'auth_dto.dart';

class AuthApiService {
  final ApiClient _client;

  AuthApiService(this._client);

  Future<LoginResponse> login(LoginRequest request) async {
    try {
      final response = await _client.dio.post(
        ApiEndpoints.login,
        data: request.toJson(),
      );
      return LoginResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<LoginResponse> refresh(String refreshToken) async {
    try {
      final response = await _client.dio.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );
      return LoginResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<void> logout(String refreshToken) async {
    try {
      // 204 No Content per Rule 03
      await _client.dio.post(
        ApiEndpoints.logout,
        data: {'refreshToken': refreshToken},
      );
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<void> logoutAll() async {
    try {
      // 204 No Content per Rule 03
      await _client.dio.post(ApiEndpoints.logoutAll);
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }
}
