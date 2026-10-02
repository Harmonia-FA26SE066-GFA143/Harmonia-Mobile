import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  return MockMusicRepositoryImpl();
});
