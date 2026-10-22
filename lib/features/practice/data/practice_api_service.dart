import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';

class PracticeApiService {
  final ApiClient _client;

  PracticeApiService(this._client);

  Future<Map<String, dynamic>> getMyAssignments({
    bool? isOpen,
    String? status,
    bool? hasSubmission,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'pageNumber': pageNumber,
        'pageSize': pageSize,
      };
      if (isOpen != null) queryParams['IsOpen'] = isOpen;
      if (status != null) queryParams['Status'] = status;
      if (hasSubmission != null) queryParams['HasSubmission'] = hasSubmission;

      final response = await _client.dio.get(
        ApiEndpoints.practiceAssignmentsMine,
        queryParameters: queryParams,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<Map<String, dynamic>> getAssignmentDetail(String id) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.practiceAssignmentMineById(id),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<void> submitRecording({
    required String assignmentId,
    required String filePath,
    required int durationSeconds,
  }) async {
    final epoch = _client.sessionManager.sessionEpoch;
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw AppException(
          code: 'PRACTICE_FILE_NOT_FOUND',
          message: 'Tệp âm thanh bản thu không tồn tại trên thiết bị.',
        );
      }
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw AppException(
          code: 'PRACTICE_FILE_INVALID',
          message: 'Tệp âm thanh bản thu rỗng.',
        );
      }
      final ext = filePath.split('.').last.toLowerCase();
      if (!['mp3', 'm4a', 'wav'].contains(ext)) {
        throw AppException(
          code: 'PRACTICE_FILE_INVALID',
          message: 'Định dạng tệp không được hỗ trợ. Chỉ chấp nhận .mp3, .m4a hoặc .wav.',
        );
      }
      if (fileSize > 20 * 1024 * 1024) {
        throw AppException(
          code: 'PRACTICE_FILE_TOO_LARGE',
          message: 'Dung lượng tệp bản thu vượt quá giới hạn 20 MB.',
        );
      }
      if (durationSeconds < 1 || durationSeconds > 3600) {
        throw AppException(
          code: 'PRACTICE_DURATION_INVALID',
          message: 'Thời lượng bản thu phải từ 1 giây đến 60 phút.',
        );
      }
      final fileName = file.uri.pathSegments.last;
      DioMediaType? mediaType;
      switch (ext) {
        case 'm4a':
          mediaType = DioMediaType('audio', 'm4a');
          break;
        case 'mp3':
          mediaType = DioMediaType('audio', 'mpeg');
          break;
        case 'wav':
          mediaType = DioMediaType('audio', 'wav');
          break;
      }

      final formData = FormData.fromMap({
        'durationSeconds': durationSeconds,
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: mediaType,
        ),
      });

      await _client.dio.post(
        ApiEndpoints.practiceAssignmentSubmissions(assignmentId),
        data: formData,
        options: Options(extra: {'expectedSessionEpoch': epoch}),
      );
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<Map<String, dynamic>> getMyAssignmentCounts() async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.practiceAssignmentsMineCounts,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<Map<String, dynamic>> getMySubmissions({
    String? assignmentId,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    try {
      final query = <String, dynamic>{
        'pageNumber': pageNumber,
        'pageSize': pageSize,
      };
      if (assignmentId != null && assignmentId.isNotEmpty) {
        query['assignmentId'] = assignmentId;
      }
      final response = await _client.dio.get(
        ApiEndpoints.practiceSubmissionsMine,
        queryParameters: query,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<Map<String, dynamic>> getMySubmissionDetail(String id) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.practiceSubmissionMineById(id),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }
}
