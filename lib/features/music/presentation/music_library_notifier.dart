import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../app/app_env.dart';
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
  final List<SongDto> songs;
  final List<MusicMaterialDetailDto> materials;
  final int page;
  final bool hasMore;
  final bool loading;
  final bool loadingMore;
  final String? error;

  const MusicLibraryState({
    this.materialsTab = false,
    this.keyword = '',
    this.materialType,
    this.learningStatus,
    this.songs = const [],
    this.materials = const [],
    this.page = 0,
    this.hasMore = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  bool get isEmpty => materialsTab ? materials.isEmpty : songs.isEmpty;
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
      songs: changed ? const [] : old.songs,
      materials: changed ? const [] : old.materials,
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
      songs: old.songs,
      materials: old.materials,
      page: old.page,
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
        hasMore = result.hasNextPage;
      } else {
        final result = await _repository.getSongsPage(
          SearchSongsRequest(keyword: query.keyword, pageNumber: page),
        );
        songs = {
          for (final item in (append ? query.songs : <SongDto>[]))
            item.id: item,
          for (final item in result.items) item.id: item,
        }.values.toList();
        currentPage = result.pageNumber;
        hasMore = result.hasNextPage;
      }
      if (!mounted || request != _generation || !canLoad()) return;
      state = MusicLibraryState(
        materialsTab: query.materialsTab,
        keyword: query.keyword,
        materialType: query.materialType,
        learningStatus: query.learningStatus,
        songs: songs,
        materials: materials,
        page: currentPage,
        hasMore: hasMore,
      );
    } catch (error) {
      if (!mounted || request != _generation || !canLoad()) return;
      state = MusicLibraryState(
        materialsTab: query.materialsTab,
        keyword: query.keyword,
        materialType: query.materialType,
        learningStatus: query.learningStatus,
        songs: query.songs,
        materials: query.materials,
        page: query.page,
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
        canLoad: () =>
            session.sessionEpoch == epoch &&
            (AppEnv.useMock || session.isAuthenticated),
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
