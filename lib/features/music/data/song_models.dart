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
  final int? displayOrder;
  final String? note;

  const SongListItem({
    required this.id,
    required this.slotName,
    required this.title,
    this.composer = '',
    this.tone = '',
    this.tempo = '',
    this.sheetMusicUrl = '',
    this.audioSampleUrl,
    this.lyrics = '',
    required this.learningStatus,
    this.classification,
    this.materials = const [],
    this.displayOrder,
    this.note,
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
