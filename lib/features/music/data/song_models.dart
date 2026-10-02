enum LearningStatus {
  notStarted('Chưa học'),
  needsPractice('Cần tập thêm'),
  learned('Đã thuộc');

  final String label;
  const LearningStatus(this.label);
}

class SongListItem {
  final String id;
  final String slotName; // Nhập lễ, Đáp ca, Dâng lễ, Hiệp lễ, Tạ lễ
  final String title;
  final String composer;
  final String tone; // C, F, G, Dm, etc.
  final String tempo;
  final String sheetMusicUrl;
  final String? audioSampleUrl;
  final String lyrics;
  final LearningStatus learningStatus;

  const SongListItem({
    required this.id,
    required this.slotName,
    required this.title,
    required this.composer,
    required this.tone,
    required this.tempo,
    required this.sheetMusicUrl,
    this.audioSampleUrl,
    required this.lyrics,
    required this.learningStatus,
  });

  SongListItem copyWith({LearningStatus? learningStatus}) {
    return SongListItem(
      id: id,
      slotName: slotName,
      title: title,
      composer: composer,
      tone: tone,
      tempo: tempo,
      sheetMusicUrl: sheetMusicUrl,
      audioSampleUrl: audioSampleUrl,
      lyrics: lyrics,
      learningStatus: learningStatus ?? this.learningStatus,
    );
  }
}
