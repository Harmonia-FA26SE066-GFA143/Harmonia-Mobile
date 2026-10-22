import 'package:harmonia_mobile/features/music/data/music_repository.dart';
import 'package:harmonia_mobile/features/music/data/song_models.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_dto.dart';

class MockMusicData {
  static final List<SongListItem> songs = [
    SongListItem(
      id: 'song-01',
      slotName: 'Ca Nhập Lễ',
      title: 'Từ Muôn Phương',
      composer: 'Lm. Kim Long',
      tone: 'Fa Trưởng (F)',
      tempo: 'Nhịp nhàng - Vừa phải (68)',
      sheetMusicUrl: 'https://example.com/sheet-music/tu-muon-phuong.pdf',
      audioSampleUrl: 'https://example.com/audio/tu-muon-phuong.mp3',
      lyrics: '''1. Từ muôn phương ta về đây sánh vai lên đường.
Đường đưa ta đi lên đền Chúa ta.
Lòng hân hoan ta hòa chung tiếng ca nhịp nhàng.
Đến phụng sự Chúa trong tình yêu mến thiết tha.

ĐK: Về nơi đây ta hãy dâng lên Ngài trọn niềm tin yêu.
Ngợi khen Thiên Chúa Đấng ban muôn ơn lành trời cao.
Dâng câu cảm tạ, câu ca chúc tụng Ngài đến muôn đời.''',
      learningStatus: LearningStatus.learned,
    ),
    SongListItem(
      id: 'song-02',
      slotName: 'Đáp Ca (Thánh Vịnh)',
      title: 'Thánh Vịnh 24: Lạy Chúa Xin Chỉ Cho Con',
      composer: 'Lm. Thành Tâm',
      tone: 'Đô Trưởng (C)',
      tempo: 'Sâu lắng - Thiết tha (60)',
      sheetMusicUrl: 'https://example.com/sheet-music/thanh-vinh-24.pdf',
      audioSampleUrl: 'https://example.com/audio/thanh-vinh-24.mp3',
      lyrics: '''ĐK: Lạy Chúa xin chỉ cho con đường lối của Chúa.
Xin dạy bảo con nước bước của Ngài.
Xin hướng dẫn con trong chân lý của Ngài và dạy dỗ con,
Vì Ngài là Thiên Chúa cứu độ con.

1. Lạy Chúa, xin nhớ lại lòng thương xót của Ngài,
và tình yêu muôn thuở Ngài đã dành cho chúng con.''',
      learningStatus: LearningStatus.needsPractice,
    ),
    SongListItem(
      id: 'song-03',
      slotName: 'Ca Dâng Lễ',
      title: 'Hiến Lễ Đầu Mùa',
      composer: 'Mi Trầm',
      tone: 'Sol Trưởng (G)',
      tempo: 'Trang trọng (64)',
      sheetMusicUrl: 'https://example.com/sheet-music/hien-le-dau-mua.pdf',
      audioSampleUrl: 'https://example.com/audio/hien-le-dau-mua.mp3',
      lyrics: '''ĐK: Xin dâng lên bàn thờ Chúa bánh thơm rượu nồng.
Cùng muôn hy sinh trong đời lao nhọc nắng mưa.
Xin Chúa thương nhận lời con nguyện xin chân thành,
biến thành Mình Máu Thánh nuôi dưỡng linh hồn chúng con.''',
      learningStatus: LearningStatus.learned,
    ),
    SongListItem(
      id: 'song-04',
      slotName: 'Ca Hiệp Lễ',
      title: 'Lắng Nghe Lời Chúa',
      composer: 'Lm. Nguyễn Duy',
      tone: 'Rê Thứ (Dm)',
      tempo: 'Lắng đọng (58)',
      sheetMusicUrl: 'https://example.com/sheet-music/lang-nghe-loi-chua.pdf',
      audioSampleUrl: 'https://example.com/audio/lang-nghe-loi-chua.mp3',
      lyrics: '''1. Xin cho con biết lắng nghe Lời Ngài dạy con trong đêm tối.
Xin cho con biết lắng nghe Lời Ngài dạy con lúc lẻ loi.
Lời Ngài là sức sống của con, Lời Ngài là ánh sáng đời con,
Lời Ngài là chứa chan hy vọng, là đường để con dõi bước.''',
      learningStatus: LearningStatus.needsPractice,
    ),
    SongListItem(
      id: 'song-05',
      slotName: 'Ca Kết Lễ',
      title: 'Tán Tụng Hồng Ân',
      composer: 'Hải Triều',
      tone: 'Fa Trưởng (F)',
      tempo: 'Hân hoan - Vui tươi (76)',
      sheetMusicUrl: 'https://example.com/sheet-music/tan-tung-hong-an.pdf',
      audioSampleUrl: 'https://example.com/audio/tan-tung-hong-an.mp3',
      lyrics: '''ĐK: Xin dâng lời cảm tạ hồng ân Thiên Chúa bao la.
Xin dâng lời ca ngợi Ngài mãi đến muôn đời.
Vì tình thương Chúa muôn đời bền vững thiên thu,
ngày đêm che chở giữ gìn đoàn con trung kiên.''',
      learningStatus: LearningStatus.learned,
    ),
  ];
}

class MockMusicRepositoryImpl implements MusicRepository {
  @override
  Future<PagedList<SongDto>> getSongsPage(SearchSongsRequest request) async {
    final keyword = request.keyword?.toLowerCase() ?? '';
    final songs = (await searchSongs())
        .where(
          (song) =>
              song.title.toLowerCase().contains(keyword) ||
              (song.composer?.toLowerCase().contains(keyword) ?? false),
        )
        .toList();
    final start = (request.pageNumber - 1) * request.pageSize;
    return PagedList(
      items: songs.skip(start).take(request.pageSize).toList(),
      pageNumber: request.pageNumber,
      pageSize: request.pageSize,
      totalCount: songs.length,
      totalPages: (songs.length / request.pageSize).ceil(),
      hasPreviousPage: request.pageNumber > 1,
      hasNextPage: start + request.pageSize < songs.length,
    );
  }

  @override
  Future<PagedList<MusicMaterialDetailDto>> getMyMaterialsPage(
    SearchMusicMaterialsRequest request,
  ) async => PagedList(
    items: const [],
    pageNumber: request.pageNumber,
    pageSize: request.pageSize,
    totalCount: 0,
    totalPages: 0,
    hasPreviousPage: false,
    hasNextPage: false,
  );

  @override
  Future<MusicMaterialDetailDto?> getMyMaterial(
    String materialId,
    String songId,
  ) async => null;

  List<SongListItem> _songs = List.from(MockMusicData.songs);

  @override
  Future<List<SongListItem>> getSongListForEvent(String eventId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _songs;
  }

  @override
  Future<SongListItem?> getSongDetail(String songId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _songs.firstWhere((s) => s.id == songId, orElse: () => _songs.first);
  }

  @override
  Future<void> updateLearningStatus(
    String songId,
    LearningStatus status,
  ) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _songs = _songs.map((s) {
      if (s.id == songId) return s.copyWith(learningStatus: status);
      return s;
    }).toList();
  }

  @override
  Future<List<SongDto>> searchSongs({
    String? keyword,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _songs
        .map(
          (s) => SongDto(
            id: s.id,
            title: s.title,
            composer: s.composer,
            musicalKey: s.tone,
            tempo: s.tempo,
            notes: s.lyrics,
          ),
        )
        .toList();
  }

  @override
  Future<List<MusicMaterialDetailDto>> getMyMaterials({String? keyword}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return [];
  }

  @override
  Future<void> updateMaterialProgress(
    String materialId,
    LearningStatus status,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<SongListDto?> getApprovedSongList(String eventId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return SongListDto(
      id: 'mock-song-list-$eventId',
      eventId: eventId,
      version: 1,
      status: 'Approved',
      items: _songs
          .asMap()
          .entries
          .map(
            (entry) => SongListItemDto(
              id: entry.value.id,
              songId: entry.value.id,
              songTitle: entry.value.title,
              slotId: 'slot-${entry.key + 1}',
              slotName: entry.value.slotName,
              displayOrder: entry.key + 1,
              note: null,
            ),
          )
          .toList(),
    );
  }
}
