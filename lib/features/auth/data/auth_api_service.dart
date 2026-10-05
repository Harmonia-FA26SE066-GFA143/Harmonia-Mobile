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

  Future<LoginResponse> loginWithGoogle(GoogleLoginRequest request) async {
    try {
      final response = await _client.dio.post(
        ApiEndpoints.google,
        data: request.toJson(),
      );
      return LoginResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<void> changePassword(ChangePasswordRequest request) async {
    try {
      // 204 No Content per Rule 03
      await _client.dio.post(
        ApiEndpoints.changePassword,
        data: request.toJson(),
      );
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<void> forgotPassword(ForgotPasswordRequest request) async {
    try {
      // 204 No Content per Rule 03
      await _client.dio.post(
        ApiEndpoints.forgotPassword,
        data: request.toJson(),
      );
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<void> resetPassword(ResetPasswordRequest request) async {
    try {
      // 204 No Content per Rule 03
      await _client.dio.post(
        ApiEndpoints.resetPassword,
        data: request.toJson(),
      );
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }
}
