import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/features/music/data/music_dto.dart';
import 'package:harmonia_mobile/features/music/data/music_repository.dart';
import 'package:harmonia_mobile/features/music/presentation/music_library_notifier.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_dto.dart';

PagedList<T> page<T>(List<T> items, int number, {bool more = false}) =>
    PagedList(
      items: items,
      pageNumber: number,
      pageSize: 20,
      totalCount: 40,
      totalPages: 2,
      hasPreviousPage: number > 1,
      hasNextPage: more,
    );

class LibraryRepository extends MockMusicRepositoryImpl {
  final requests = <SearchSongsRequest>[];
  final materialRequests = <SearchMusicMaterialsRequest>[];
  final responses = <Completer<PagedList<SongDto>>>[];
  @override
  Future<PagedList<SongDto>> getSongsPage(SearchSongsRequest request) {
    requests.add(request);
    final pending = Completer<PagedList<SongDto>>();
    responses.add(pending);
    return pending.future;
  }

  @override
  Future<PagedList<MusicMaterialDetailDto>> getMyMaterialsPage(
    SearchMusicMaterialsRequest request,
  ) async {
    materialRequests.add(request);
    return page([], request.pageNumber);
  }
}

void main() {
  late LibraryRepository repository;
  late MusicLibraryNotifier notifier;
  setUp(() {
    repository = LibraryRepository();
    notifier = MusicLibraryNotifier(repository, canLoad: () => true);
  });
  tearDown(() => notifier.dispose());

  test('paging deduplicates IDs, blocks duplicate loads and retries the failed page', () async {
    final first = notifier.refresh();
    repository.responses[0].complete(
      page([const SongDto(id: 'a', title: 'A')], 1, more: true),
    );
    await first;
    final second = notifier.loadMore();
    await notifier.loadMore();
    expect(repository.requests.length, 2);
    repository.responses[1].completeError(const NetworkException());
    await second;
    expect(notifier.state.songs.single.id, 'a');
    expect(notifier.state.page, 1);
    expect(notifier.state.error, isNotNull);
    final retry = notifier.loadMore();
    expect(repository.requests.last.pageNumber, 2);
    repository.responses[2].complete(
      page([
        const SongDto(id: 'a', title: 'A updated'),
        const SongDto(id: 'b', title: 'B'),
      ], 2),
    );
    await retry;
    expect(notifier.state.songs.map((s) => s.id), ['a', 'b']);
    expect(notifier.state.songs.first.title, 'A updated');
    await notifier.loadMore();
    expect(repository.requests.length, 3);
  });

  test('old search cannot replace a newer result', () async {
    final old = notifier.refresh(keyword: 'old');
    final latest = notifier.refresh(keyword: 'new');
    repository.responses[1].complete(
      page([const SongDto(id: 'new', title: 'New')], 1),
    );
    await latest;
    repository.responses[0].complete(
      page([const SongDto(id: 'old', title: 'Old')], 1),
    );
    await old;
    expect(notifier.state.keyword, 'new');
    expect(notifier.state.songs.single.id, 'new');
  });

  test('refresh invalidates an in-flight next page', () async {
    final first = notifier.refresh();
    repository.responses[0].complete(
      page([const SongDto(id: 'a', title: 'A')], 1, more: true),
    );
    await first;
    final next = notifier.loadMore();
    final refresh = notifier.refresh();
    repository.responses[2].complete(
      page([const SongDto(id: 'fresh', title: 'Fresh')], 1),
    );
    await refresh;
    repository.responses[1].complete(
      page([const SongDto(id: 'old', title: 'Old')], 2),
    );
    await next;
    expect(notifier.state.songs.single.id, 'fresh');
    expect(notifier.state.page, 1);
  });

  test(
    'switching to materials drops song response and sends server filters',
    () async {
      final old = notifier.refresh();
      await notifier.refresh(
        materialsTab: true,
        keyword: '  lễ  ',
        materialType: MaterialType.sampleAudio,
        learningStatus: LearningStatus.needsPractice,
        replaceFilters: true,
      );
      repository.responses[0].complete(
        page([const SongDto(id: 'old', title: 'Old')], 1),
      );
      await old;
      expect(notifier.state.materialsTab, isTrue);
      expect(notifier.state.songs, isEmpty);
      expect(repository.materialRequests.single.toQueryParameters(), {
        'pageNumber': 1,
        'pageSize': 20,
        'keyword': 'lễ',
        'materialType': 'SampleAudio',
        'learningStatus': 'NeedsPractice',
      });
    },
  );

  test('session reset discards an old pending response', () async {
    final pending = notifier.refresh();
    notifier.reset();
    repository.responses[0].complete(
      page([const SongDto(id: 'old', title: 'Old')], 1),
    );
    await pending;
    expect(notifier.state.songs, isEmpty);
    expect(notifier.state.loading, isFalse);
  });
}
