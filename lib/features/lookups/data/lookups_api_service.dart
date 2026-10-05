import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/network/api_client.dart';
import 'lookup_dto.dart';

final lookupsApiServiceProvider = Provider<LookupsApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return LookupsApiService(client);
});

class LookupsApiService {
  final ApiClient _client;

  LookupsApiService(this._client);

  Future<List<LookupItemDto>> getMassTypes() async {
    try {
      final response = await _client.dio.get(ApiEndpoints.lookupMassTypes);
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((e) => LookupItemDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<List<LookupItemDto>> getCeremonyTypes() async {
    try {
      final response = await _client.dio.get(ApiEndpoints.lookupCeremonyTypes);
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((e) => LookupItemDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<List<LookupItemDto>> getEventCategories() async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.lookupEventCategories,
      );
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((e) => LookupItemDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<List<LookupItemDto>> getSongThemes() async {
    try {
      final response = await _client.dio.get(ApiEndpoints.lookupSongThemes);
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((e) => LookupItemDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<List<LookupItemDto>> getSkillCategories() async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.lookupSkillCategories,
      );
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((e) => LookupItemDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<List<LiturgicalSeasonDto>> getLiturgicalSeasons() async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.lookupLiturgicalSeasons,
      );
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((e) => LiturgicalSeasonDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<List<LiturgicalSlotDto>> getLiturgicalSlots() async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.lookupLiturgicalSlots,
      );
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((e) => LiturgicalSlotDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<List<WorshipLocationDto>> getWorshipLocations() async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.lookupWorshipLocations,
      );
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((e) => WorshipLocationDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<List<SkillDto>> getSkills({String? categoryId}) async {
    try {
      final query = <String, dynamic>{};
      if (categoryId != null) query['categoryId'] = categoryId;
      final response = await _client.dio.get(
        ApiEndpoints.lookupSkills,
        queryParameters: query,
      );
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((e) => SkillDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }
}
