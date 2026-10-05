import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_env.dart';
import 'music_api_service.dart';
import 'song_models.dart';

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

abstract class MusicRepository {
  Future<List<SongListItem>> getSongListForEvent(String eventId);
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
  Future<List<SongListItem>> getSongListForEvent(String eventId) async {
    // Event-specific song list endpoint is not yet available on Harmonia-BE controllers.
    // Falls back to available songs catalog.
    try {
      final paged = await apiService.getSongs(
        const SearchSongsRequest(pageNumber: 1, pageSize: 10),
      );
      return paged.items.map((song) {
        return SongListItem(
          id: song.id,
          slotName: 'Bài hát phụng vụ',
          title: song.title,
          composer: song.composer ?? 'Khuyết danh',
          tone: song.musicalKey ?? 'Đô Trưởng (C)',
          tempo: song.tempo ?? 'Vừa phải',
          sheetMusicUrl: '',
          audioSampleUrl: null,
          lyrics: song.notes ?? '',
          learningStatus: LearningStatus.notStarted,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<SongListItem?> getSongDetail(String songId) async {
    try {
      final song = await apiService.getSongById(songId);

      SongClassificationDto? classification;
      try {
        classification = await apiService.getSongClassification(songId);
      } catch (_) {
        // Classification optional fallback
      }

      List<MusicMaterialDto> materials = [];
      try {
        final matPaged = await apiService.getMaterialsBySong(songId);
        materials = matPaged.items;
      } catch (_) {
        // Materials optional fallback
      }

      final sheetMat = materials
          .where((m) => m.materialType == MaterialType.sheetMusic)
          .firstOrNull;
      final audioMat = materials
          .where((m) => m.materialType == MaterialType.sampleAudio)
          .firstOrNull;

      final slot =
          classification?.liturgicalSeasons.firstOrNull?.name ??
          classification?.massTypes.firstOrNull?.name ??
          'Thánh ca Phụng vụ';

      return SongListItem(
        id: song.id,
        slotName: slot,
        title: song.title,
        composer: song.composer ?? 'Khuyết danh',
        tone: song.musicalKey ?? 'Đô Trưởng (C)',
        tempo: song.tempo ?? 'Vừa phải',
        sheetMusicUrl: sheetMat?.fileUrl ?? '',
        audioSampleUrl: audioMat?.fileUrl,
        lyrics: song.notes ?? '',
        learningStatus: LearningStatus.notStarted,
        classification: classification,
        materials: materials,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> updateLearningStatus(
    String songId,
    LearningStatus status,
  ) async {
    // When learning status is updated for a song, updates its primary material if available
    try {
      final materials = await apiService.getMaterialsBySong(songId);
      if (materials.items.isNotEmpty) {
        await apiService.updateLearningProgress(
          materials.items.first.id,
          status,
        );
      }
    } catch (_) {
      // Ignored if no materials exist for this song
    }
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
    await apiService.updateLearningProgress(materialId, status);
  }
}

class MockMusicRepositoryImpl implements MusicRepository {
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
}

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  if (AppEnv.useMock) {
    return MockMusicRepositoryImpl();
  }
  final apiService = ref.watch(musicApiServiceProvider);
  return MusicRepositoryImpl(apiService: apiService);
});
