import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/errors/error_messages.dart';
import '../data/music_dto.dart';
import '../data/music_repository.dart';
import '../data/song_models.dart' show SongListItem;

class MusicLibraryState {
  final bool materialsTab;
  final String keyword;
  final MaterialType? materialType;
  final LearningStatus? learningStatus;
  final String? liturgicalSeasonId;
  final String? massTypeId;
  final String? ceremonyTypeId;
  final String? songThemeId;
  final String? liturgicalSlotId;
  final String? skillId;
  final bool? isClassified;
  final MaterialType? missingMaterialType;
  final List<SongDto> songs;
  final List<MusicMaterialDetailDto> materials;
  final int page;
  final int totalCount;
  final bool hasMore;
  final bool loading;
  final bool loadingMore;
  final String? error;

  const MusicLibraryState({
    this.materialsTab = false,
    this.keyword = '',
    this.materialType,
    this.learningStatus,
    this.liturgicalSeasonId,
    this.massTypeId,
    this.ceremonyTypeId,
    this.songThemeId,
    this.liturgicalSlotId,
    this.skillId,
    this.isClassified,
    this.missingMaterialType,
    this.songs = const [],
    this.materials = const [],
    this.page = 0,
    this.totalCount = 0,
    this.hasMore = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  bool get isEmpty => materialsTab ? materials.isEmpty : songs.isEmpty;
  bool get hasSongFilters =>
      liturgicalSeasonId != null ||
      massTypeId != null ||
      ceremonyTypeId != null ||
      songThemeId != null ||
      liturgicalSlotId != null ||
      skillId != null ||
      isClassified != null ||
      missingMaterialType != null;
}

class MusicLibraryNotifier extends StateNotifier<MusicLibraryState> {
  final MusicRepository _repository;
  final bool Function() canLoad;
  int _generation = 0;

  MusicLibraryNotifier(this._repository, {required this.canLoad})
    : super(const MusicLibraryState());

  Future<void> refresh({
    String? keyword,
    bool? materialsTab,
    MaterialType? materialType,
    LearningStatus? learningStatus,
    String? liturgicalSeasonId,
    String? massTypeId,
    String? ceremonyTypeId,
    String? songThemeId,
    String? liturgicalSlotId,
    String? skillId,
    bool? isClassified,
    MaterialType? missingMaterialType,
    bool replaceFilters = false,
  }) async {
    final old = state;
    final tab = materialsTab ?? old.materialsTab;
    final changed =
        (keyword != null && keyword.trim() != old.keyword) ||
        tab != old.materialsTab ||
        replaceFilters;
    final request = ++_generation;
    state = MusicLibraryState(
      materialsTab: tab,
      keyword: keyword?.trim() ?? old.keyword,
      materialType: replaceFilters
          ? materialType
          : (tab == old.materialsTab ? old.materialType : null),
      learningStatus: replaceFilters
          ? learningStatus
          : (tab == old.materialsTab ? old.learningStatus : null),
      liturgicalSeasonId: replaceFilters
          ? liturgicalSeasonId
          : (tab == old.materialsTab ? old.liturgicalSeasonId : null),
      massTypeId: replaceFilters
          ? massTypeId
          : (tab == old.materialsTab ? old.massTypeId : null),
      ceremonyTypeId: replaceFilters
          ? ceremonyTypeId
          : (tab == old.materialsTab ? old.ceremonyTypeId : null),
      songThemeId: replaceFilters
          ? songThemeId
          : (tab == old.materialsTab ? old.songThemeId : null),
      liturgicalSlotId: replaceFilters
          ? liturgicalSlotId
          : (tab == old.materialsTab ? old.liturgicalSlotId : null),
      skillId: replaceFilters
          ? skillId
          : (tab == old.materialsTab ? old.skillId : null),
      isClassified: replaceFilters
          ? isClassified
          : (tab == old.materialsTab ? old.isClassified : null),
      missingMaterialType: replaceFilters
          ? missingMaterialType
          : (tab == old.materialsTab ? old.missingMaterialType : null),
      songs: changed ? const [] : old.songs,
      materials: changed ? const [] : old.materials,
      totalCount: changed ? 0 : old.totalCount,
      loading: true,
    );
    if (!canLoad()) {
      state = const MusicLibraryState();
      return;
    }
    await _fetch(1, request, append: false);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore || !canLoad()) {
      return;
    }
    final old = state;
    state = MusicLibraryState(
      materialsTab: old.materialsTab,
      keyword: old.keyword,
      materialType: old.materialType,
      learningStatus: old.learningStatus,
      liturgicalSeasonId: old.liturgicalSeasonId,
      massTypeId: old.massTypeId,
      ceremonyTypeId: old.ceremonyTypeId,
      songThemeId: old.songThemeId,
      liturgicalSlotId: old.liturgicalSlotId,
      skillId: old.skillId,
      isClassified: old.isClassified,
      missingMaterialType: old.missingMaterialType,
      songs: old.songs,
      materials: old.materials,
      page: old.page,
      totalCount: old.totalCount,
      hasMore: old.hasMore,
      loadingMore: true,
    );
    await _fetch(old.page + 1, _generation, append: true);
  }

  Future<void> _fetch(int page, int request, {required bool append}) async {
    final query = state;
    try {
      var songs = query.songs;
      var materials = query.materials;
      late int currentPage;
      late int totalCount;
      late bool hasMore;
      if (query.materialsTab) {
        final result = await _repository.getMyMaterialsPage(
          SearchMusicMaterialsRequest(
            keyword: query.keyword,
            materialType: query.materialType,
            learningStatus: query.learningStatus,
            pageNumber: page,
          ),
        );
        materials = {
          for (final item
              in (append ? query.materials : <MusicMaterialDetailDto>[]))
            item.id: item,
          for (final item in result.items) item.id: item,
        }.values.toList();
        currentPage = result.pageNumber;
        totalCount = result.totalCount;
        hasMore = result.hasNextPage;
      } else {
        final result = await _repository.getSongsPage(
          SearchSongsRequest(
            keyword: query.keyword,
            liturgicalSeasonId: query.liturgicalSeasonId,
            massTypeId: query.massTypeId,
            ceremonyTypeId: query.ceremonyTypeId,
            songThemeId: query.songThemeId,
            liturgicalSlotId: query.liturgicalSlotId,
            skillId: query.skillId,
            isClassified: query.isClassified,
            missingMaterialType: query.missingMaterialType,
            pageNumber: page,
          ),
        );
        songs = {
          for (final item in (append ? query.songs : <SongDto>[]))
            item.id: item,
          for (final item in result.items) item.id: item,
        }.values.toList();
        currentPage = result.pageNumber;
        totalCount = result.totalCount;
        hasMore = result.hasNextPage;
      }
      if (!mounted || request != _generation || !canLoad()) return;
      state = MusicLibraryState(
        materialsTab: query.materialsTab,
        keyword: query.keyword,
        materialType: query.materialType,
        learningStatus: query.learningStatus,
        liturgicalSeasonId: query.liturgicalSeasonId,
        massTypeId: query.massTypeId,
        ceremonyTypeId: query.ceremonyTypeId,
        songThemeId: query.songThemeId,
        liturgicalSlotId: query.liturgicalSlotId,
        skillId: query.skillId,
        isClassified: query.isClassified,
        missingMaterialType: query.missingMaterialType,
        songs: songs,
        materials: materials,
        page: currentPage,
        totalCount: totalCount,
        hasMore: hasMore,
      );
    } catch (error) {
      if (!mounted || request != _generation || !canLoad()) return;
      state = MusicLibraryState(
        materialsTab: query.materialsTab,
        keyword: query.keyword,
        materialType: query.materialType,
        learningStatus: query.learningStatus,
        liturgicalSeasonId: query.liturgicalSeasonId,
        massTypeId: query.massTypeId,
        ceremonyTypeId: query.ceremonyTypeId,
        songThemeId: query.songThemeId,
        liturgicalSlotId: query.liturgicalSlotId,
        skillId: query.skillId,
        isClassified: query.isClassified,
        missingMaterialType: query.missingMaterialType,
        songs: query.songs,
        materials: query.materials,
        page: query.page,
        totalCount: query.totalCount,
        hasMore: query.hasMore,
        error: ErrorMessages.forException(error),
      );
    }
  }

  void reset() {
    ++_generation;
    state = const MusicLibraryState();
  }
}

final musicLibraryProvider =
    StateNotifierProvider<MusicLibraryNotifier, MusicLibraryState>((ref) {
      final session = ref.read(sessionManagerProvider);
      final epoch = session.sessionEpoch;
      final notifier = MusicLibraryNotifier(
        ref.watch(musicRepositoryProvider),
        canLoad: () => session.sessionEpoch == epoch && session.isAuthenticated,
      );
      ref.listen<int>(sessionManagerProvider.select((s) => s.sessionEpoch), (
        _,
        next,
      ) {
        if (next != epoch) {
          notifier.reset();
          ref.invalidateSelf();
        }
      });
      notifier.refresh();
      return notifier;
    });

typedef MaterialIdentity = ({String materialId, String songId});

final memberMaterialProvider = FutureProvider.autoDispose
    .family<MusicMaterialDetailDto?, MaterialIdentity>((ref, identity) async {
      ref.watch(sessionManagerProvider.select((s) => s.sessionEpoch));
      return ref
          .watch(musicRepositoryProvider)
          .getMyMaterial(identity.materialId, identity.songId);
    });

final songDetailProvider = FutureProvider.autoDispose
    .family<SongListItem?, String>((ref, songId) async {
      ref.watch(sessionManagerProvider.select((s) => s.sessionEpoch));
      return ref.watch(musicRepositoryProvider).getSongDetail(songId);
    });
