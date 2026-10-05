import 'music_dto.dart';

export 'music_dto.dart';

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
  final SongClassificationDto? classification;
  final List<MusicMaterialDto> materials;

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
    this.classification,
    this.materials = const [],
  });

  SongListItem copyWith({
    LearningStatus? learningStatus,
    SongClassificationDto? classification,
    List<MusicMaterialDto>? materials,
  }) {
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
      classification: classification ?? this.classification,
      materials: materials ?? this.materials,
    );
  }
}
