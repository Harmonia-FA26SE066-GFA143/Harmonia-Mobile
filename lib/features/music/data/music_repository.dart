import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../notifications/data/notification_dto.dart';
import 'music_api_service.dart';
import 'song_models.dart';

abstract class MusicRepository {
  Future<PagedList<SongDto>> getSongsPage(SearchSongsRequest request);
  Future<PagedList<MusicMaterialDetailDto>> getMyMaterialsPage(
    SearchMusicMaterialsRequest request,
  );
  Future<MusicMaterialDetailDto?> getMyMaterial(
    String materialId,
    String songId,
  );
  Future<List<SongListItem>> getSongListForEvent(String eventId);
  Future<SongListDto?> getApprovedSongList(String eventId);
  Future<SongListItem?> getSongDetail(String songId);
  Future<void> updateLearningStatus(String songId, LearningStatus status);
  Future<List<SongDto>> searchSongs({
    String? keyword,
    int pageNumber = 1,
    int pageSize = 20,
  });
  Future<List<MusicMaterialDetailDto>> getMyMaterials({String? keyword});
  Future<void> updateMaterialProgress(String materialId, LearningStatus status);
}

class MusicRepositoryImpl implements MusicRepository {
  final MusicApiService apiService;

  MusicRepositoryImpl({required this.apiService});

  @override
  Future<SongListDto?> getApprovedSongList(String eventId) async {
    return apiService.getApprovedSongListForEvent(eventId);
  }

  @override
  Future<List<SongListItem>> getSongListForEvent(String eventId) async {
    final approvedList = await apiService.getApprovedSongListForEvent(eventId);
    if (approvedList == null || approvedList.items.isEmpty) {
      return const [];
    }
    return approvedList.items.map((item) {
      return SongListItem(
        id: item.songId,
        slotName: item.slotName.isNotEmpty ? item.slotName : 'Bài hát phụng vụ',
        title: item.songTitle,
        composer: '',
        tone: '',
        tempo: '',
        sheetMusicUrl: '',
        audioSampleUrl: null,
        lyrics: '',
        displayOrder: item.displayOrder,
        note: item.note,
        learningStatus: LearningStatus.notStarted,
      );
    }).toList();
  }

  @override
  Future<PagedList<SongDto>> getSongsPage(SearchSongsRequest request) =>
      apiService.getSongs(request);

  @override
  Future<PagedList<MusicMaterialDetailDto>> getMyMaterialsPage(
    SearchMusicMaterialsRequest request,
  ) => apiService.getMyMaterials(request);

  @override
  Future<MusicMaterialDetailDto?> getMyMaterial(
    String materialId,
    String songId,
  ) async {
    if (materialId.isEmpty || songId.isEmpty) return null;
    var page = 1;
    while (true) {
      final result = await getMyMaterialsPage(
        SearchMusicMaterialsRequest(songId: songId, pageNumber: page),
      );
      for (final material in result.items) {
        if (material.id == materialId && material.songId == songId) {
          return material;
        }
      }
      if (!result.hasNextPage || result.pageNumber < page) return null;
      page = result.pageNumber + 1;
    }
  }

  @override
  Future<SongListItem?> getSongDetail(String songId) async {
    late SongDto song;
    try {
      song = await apiService.getSongById(songId);
    } on NotFoundException {
      return null;
    }
    final classification = await apiService.getSongClassification(songId);
    // The member endpoint includes progress and enforces material eligibility.
    final materials = <MusicMaterialDetailDto>[];
    var page = 1;
    while (true) {
      final result = await getMyMaterialsPage(
        SearchMusicMaterialsRequest(songId: songId, pageNumber: page),
      );
      materials.addAll(result.items);
      if (!result.hasNextPage || result.pageNumber < page) break;
      page = result.pageNumber + 1;
    }
    return SongListItem(
      id: song.id,
      slotName: 'Thánh ca',
      title: song.title,
      composer: song.composer ?? '',
      tone: song.musicalKey ?? '',
      tempo: song.tempo ?? '',
      lyrics: song.notes ?? '',
      learningStatus: LearningStatus.notStarted,
      classification: classification,
      materials: {for (final material in materials) material.id: material}
          .values
          .toList(),
    );
  }

  @override
  Future<void> updateLearningStatus(
    String songId,
    LearningStatus status,
  ) async {
    // Progress belongs to a material, never to an arbitrary first material of a song.
    throw UnsupportedError(
      'Select a material before updating learning progress.',
    );
  }

  @override
  Future<List<SongDto>> searchSongs({
    String? keyword,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    final paged = await apiService.getSongs(
      SearchSongsRequest(
        keyword: keyword,
        pageNumber: pageNumber,
        pageSize: pageSize,
      ),
    );
    return paged.items;
  }

  @override
  Future<List<MusicMaterialDetailDto>> getMyMaterials({String? keyword}) async {
    final paged = await apiService.getMyMaterials(
      SearchMusicMaterialsRequest(keyword: keyword),
    );
    return paged.items;
  }

  @override
  Future<void> updateMaterialProgress(
    String materialId,
    LearningStatus status,
  ) async {
    if (status == LearningStatus.notStarted) {
      throw const ValidationException(
        code: 'MATERIAL_LEARNING_STATUS_INVALID',
        message: 'Chỉ có thể chọn Đã thuộc hoặc Cần tập thêm.',
      );
    }
    await apiService.updateLearningProgress(materialId, status);
  }
}

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  final apiService = ref.watch(musicApiServiceProvider);
  return MusicRepositoryImpl(apiService: apiService);
});

final eventApprovedSongListProvider = FutureProvider.autoDispose
    .family<SongListDto?, String>((ref, eventId) async {
      ref.watch(sessionManagerProvider.select((s) => s.sessionEpoch));
      final repo = ref.watch(musicRepositoryProvider);
      return repo.getApprovedSongList(eventId);
    });
