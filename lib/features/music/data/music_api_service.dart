import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/network/api_client.dart';
import '../../notifications/data/notification_dto.dart';
import 'music_dto.dart';

final musicApiServiceProvider = Provider<MusicApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return MusicApiService(client);
});

class MusicApiService {
  final ApiClient _client;

  MusicApiService(this._client);

  Future<PagedList<SongDto>> getSongs(SearchSongsRequest request) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.songs,
        queryParameters: request.toQueryParameters(),
      );
      final data = response.data as Map<String, dynamic>;
      final rawItems = data['items'] as List<dynamic>? ?? [];
      final items = rawItems
          .map((e) => SongDto.fromJson(e as Map<String, dynamic>))
          .toList();

      return PagedList<SongDto>(
        items: items,
        pageNumber: (data['pageNumber'] as num?)?.toInt() ?? 1,
        pageSize: (data['pageSize'] as num?)?.toInt() ?? 20,
        totalCount: (data['totalCount'] as num?)?.toInt() ?? items.length,
        totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
        hasPreviousPage: data['hasPreviousPage'] == true,
        hasNextPage: data['hasNextPage'] == true,
      );
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<SongDto> getSongById(String id) async {
    try {
      final response = await _client.dio.get(ApiEndpoints.songById(id));
      return SongDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<SongClassificationDto> getSongClassification(String id) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.songClassification(id),
      );
      return SongClassificationDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<PagedList<MusicMaterialDto>> getMaterialsBySong(
    String songId, {
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.musicMaterials,
        queryParameters: {
          'songId': songId,
          'pageNumber': pageNumber,
          'pageSize': pageSize,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final rawItems = data['items'] as List<dynamic>? ?? [];
      final items = rawItems
          .map((e) => MusicMaterialDto.fromJson(e as Map<String, dynamic>))
          .toList();

      return PagedList<MusicMaterialDto>(
        items: items,
        pageNumber: (data['pageNumber'] as num?)?.toInt() ?? 1,
        pageSize: (data['pageSize'] as num?)?.toInt() ?? 50,
        totalCount: (data['totalCount'] as num?)?.toInt() ?? items.length,
        totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
        hasPreviousPage: data['hasPreviousPage'] == true,
        hasNextPage: data['hasNextPage'] == true,
      );
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<PagedList<MusicMaterialDetailDto>> getMyMaterials(
    SearchMusicMaterialsRequest request,
  ) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.musicMaterialsMine,
        queryParameters: request.toQueryParameters(),
      );
      final data = response.data as Map<String, dynamic>;
      final rawItems = data['items'] as List<dynamic>? ?? [];
      final items = rawItems
          .map(
            (e) => MusicMaterialDetailDto.fromJson(e as Map<String, dynamic>),
          )
          .toList();

      return PagedList<MusicMaterialDetailDto>(
        items: items,
        pageNumber: (data['pageNumber'] as num?)?.toInt() ?? 1,
        pageSize: (data['pageSize'] as num?)?.toInt() ?? 20,
        totalCount: (data['totalCount'] as num?)?.toInt() ?? items.length,
        totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
        hasPreviousPage: data['hasPreviousPage'] == true,
        hasNextPage: data['hasNextPage'] == true,
      );
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<MaterialLearningProgressDto> updateLearningProgress(
    String materialId,
    LearningStatus status,
  ) async {
    try {
      final response = await _client.dio.put(
        ApiEndpoints.materialLearningProgress(materialId),
        data: UpdateMaterialLearningProgressRequest(status: status).toJson(),
      );
      return MaterialLearningProgressDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }
}
