enum MaterialType {
  sheetMusic(0, 'SheetMusic', 'Bản nhạc phổ'),
  lyrics(1, 'Lyrics', 'Lời bài hát'),
  sampleAudio(2, 'SampleAudio', 'Audio mẫu'),
  rehearsalMaterial(3, 'RehearsalMaterial', 'Tài liệu tập hát'),
  interactiveScore(4, 'InteractiveScore', 'Bản nhạc tương tác'),
  unknown(-1, 'Unknown', 'Loại tài liệu chưa hỗ trợ');

  final int value;
  final String wireName;
  final String label;
  const MaterialType(this.value, this.wireName, this.label);

  static Iterable<MaterialType> get filterOptions =>
      values.where((type) => type != unknown);

  static MaterialType fromWire(Object? value) {
    final name = value?.toString().toLowerCase();
    return filterOptions.firstWhere(
      (type) => type.value == value || type.wireName.toLowerCase() == name,
      orElse: () => unknown,
    );
  }
}

enum LearningStatus {
  notStarted('NotStarted', 'Chưa học'),
  needsPractice('NeedsPractice', 'Cần tập thêm'),
  learned('Learned', 'Đã thuộc');

  final String wireName;
  final String label;
  const LearningStatus(this.wireName, this.label);

  static LearningStatus fromWire(dynamic value) {
    if (value == null) return LearningStatus.notStarted;
    final str = value.toString().toLowerCase();
    for (final s in LearningStatus.values) {
      if (s.wireName.toLowerCase() == str || s.name == str) {
        return s;
      }
    }
    return LearningStatus.notStarted;
  }
}

enum PlaybackInstrument {
  piano('Piano'),
  organ('Organ'),
  guitar('Guitar'),
  stringEnsemble('StringEnsemble');

  final String wireName;
  const PlaybackInstrument(this.wireName);

  String get label => switch (this) {
    PlaybackInstrument.piano => 'Piano',
    PlaybackInstrument.organ => 'Đàn organ',
    PlaybackInstrument.guitar => 'Guitar',
    PlaybackInstrument.stringEnsemble => 'Bộ dây',
  };

  static PlaybackInstrument fromWire(dynamic value) {
    if (value is num) {
      final index = value.toInt();
      if (index >= 0 && index < values.length) return values[index];
    }
    final normalized = value?.toString().toLowerCase();
    return values.firstWhere(
      (instrument) => instrument.wireName.toLowerCase() == normalized,
      orElse: () => PlaybackInstrument.piano,
    );
  }
}

class MusicMaterialPlaybackDto {
  final String id;
  final String songId;
  final String title;
  final String status;
  final int schemaVersion;
  final double durationSeconds;
  final PlaybackInstrument instrument;
  final String audioUrl;
  final String notesUrl;

  const MusicMaterialPlaybackDto({
    required this.id,
    required this.songId,
    required this.title,
    required this.status,
    required this.schemaVersion,
    required this.durationSeconds,
    required this.instrument,
    required this.audioUrl,
    required this.notesUrl,
  });

  factory MusicMaterialPlaybackDto.fromJson(Map<String, dynamic> json) =>
      MusicMaterialPlaybackDto(
        id: json['id']?.toString() ?? '',
        songId: json['songId']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0,
        instrument: PlaybackInstrument.fromWire(json['instrument']),
        audioUrl: json['audioUrl']?.toString() ?? '',
        notesUrl: json['notesUrl']?.toString() ?? '',
      );
}

class SongDto {
  final String id;
  final String title;
  final String? composer;
  final String? lyricist;
  final String? musicalKey;
  final String? tempo;
  final String? notes;
  final Map<MaterialType, int> materialCounts;

  int? get interactiveScoreCount =>
      materialCounts[MaterialType.interactiveScore];

  const SongDto({
    required this.id,
    required this.title,
    this.composer,
    this.lyricist,
    this.musicalKey,
    this.tempo,
    this.notes,
    this.materialCounts = const {},
  });

  factory SongDto.fromJson(Map<String, dynamic> json) {
    final counts = json['materialCounts'];
    return SongDto(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      composer: json['composer']?.toString(),
      lyricist: json['lyricist']?.toString(),
      musicalKey: json['musicalKey']?.toString(),
      tempo: json['tempo']?.toString(),
      notes: json['notes']?.toString(),
      materialCounts: {
        if (counts is Map<String, dynamic>)
          for (final entry in counts.entries)
            if (entry.value is int &&
                MaterialType.fromWire(entry.key) != MaterialType.unknown)
              MaterialType.fromWire(entry.key): entry.value as int,
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'composer': composer,
    'lyricist': lyricist,
    'musicalKey': musicalKey,
    'tempo': tempo,
    'notes': notes,
    if (materialCounts.isNotEmpty)
      'materialCounts': {
        for (final entry in materialCounts.entries)
          entry.key.wireName: entry.value,
      },
  };
}

class SongClassificationSummaryDto {
  final String id;
  final String name;

  const SongClassificationSummaryDto({required this.id, required this.name});

  factory SongClassificationSummaryDto.fromJson(Map<String, dynamic> json) {
    return SongClassificationSummaryDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class SongVocalRequirementDto {
  final String skillId;
  final String skillName;
  final bool isMandatory;
  final int requiredCount;

  const SongVocalRequirementDto({
    required this.skillId,
    required this.skillName,
    required this.isMandatory,
    this.requiredCount = 1,
  });

  factory SongVocalRequirementDto.fromJson(Map<String, dynamic> json) {
    return SongVocalRequirementDto(
      skillId: json['skillId']?.toString() ?? '',
      skillName: json['skillName']?.toString() ?? '',
      isMandatory: json['isMandatory'] == true,
      requiredCount: (json['requiredCount'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'skillId': skillId,
    'skillName': skillName,
    'isMandatory': isMandatory,
  };
}

class SongInstrumentRequirementDto {
  final String skillId;
  final String skillName;
  final bool isMandatory;
  final int requiredCount;

  const SongInstrumentRequirementDto({
    required this.skillId,
    required this.skillName,
    required this.isMandatory,
    this.requiredCount = 1,
  });

  factory SongInstrumentRequirementDto.fromJson(Map<String, dynamic> json) {
    return SongInstrumentRequirementDto(
      skillId: json['skillId']?.toString() ?? '',
      skillName: json['skillName']?.toString() ?? '',
      isMandatory: json['isMandatory'] == true,
      requiredCount: (json['requiredCount'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'skillId': skillId,
    'skillName': skillName,
    'isMandatory': isMandatory,
  };
}

class SongClassificationDto {
  final String songId;
  final List<SongClassificationSummaryDto> liturgicalSeasons;
  final List<SongClassificationSummaryDto> massTypes;
  final List<SongClassificationSummaryDto> ceremonyTypes;
  final List<SongClassificationSummaryDto> songThemes;
  final List<SongClassificationSummaryDto> liturgicalSlots;
  final List<SongVocalRequirementDto> vocalRequirements;
  final List<SongInstrumentRequirementDto> instrumentRequirements;

  const SongClassificationDto({
    required this.songId,
    this.liturgicalSeasons = const [],
    this.massTypes = const [],
    this.ceremonyTypes = const [],
    this.songThemes = const [],
    this.liturgicalSlots = const [],
    this.vocalRequirements = const [],
    this.instrumentRequirements = const [],
  });

  factory SongClassificationDto.fromJson(Map<String, dynamic> json) {
    return SongClassificationDto(
      songId: json['songId']?.toString() ?? '',
      liturgicalSeasons: (json['liturgicalSeasons'] as List<dynamic>? ?? [])
          .map(
            (e) => SongClassificationSummaryDto.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      massTypes: (json['massTypes'] as List<dynamic>? ?? [])
          .map(
            (e) => SongClassificationSummaryDto.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      ceremonyTypes: (json['ceremonyTypes'] as List<dynamic>? ?? [])
          .map(
            (e) => SongClassificationSummaryDto.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      songThemes: (json['songThemes'] as List<dynamic>? ?? [])
          .map(
            (e) => SongClassificationSummaryDto.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      liturgicalSlots: (json['liturgicalSlots'] as List<dynamic>? ?? [])
          .map(
            (e) => SongClassificationSummaryDto.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      vocalRequirements: (json['vocalRequirements'] as List<dynamic>? ?? [])
          .map(
            (e) => SongVocalRequirementDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      instrumentRequirements:
          (json['instrumentRequirements'] as List<dynamic>? ?? [])
              .map(
                (e) => SongInstrumentRequirementDto.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }
}

class SearchSongsRequest {
  final String? keyword;
  final String? liturgicalSeasonId;
  final String? massTypeId;
  final String? ceremonyTypeId;
  final String? songThemeId;
  final String? liturgicalSlotId;
  final String? skillId;
  final bool? isClassified;
  final MaterialType? missingMaterialType;
  final int pageNumber;
  final int pageSize;

  const SearchSongsRequest({
    this.keyword,
    this.liturgicalSeasonId,
    this.massTypeId,
    this.ceremonyTypeId,
    this.songThemeId,
    this.liturgicalSlotId,
    this.skillId,
    this.isClassified,
    this.missingMaterialType,
    this.pageNumber = 1,
    this.pageSize = 20,
  });

  Map<String, dynamic> toQueryParameters() {
    final params = <String, dynamic>{
      'pageNumber': pageNumber,
      'pageSize': pageSize,
    };
    if (keyword != null && keyword!.isNotEmpty) {
      params['keyword'] = keyword;
    }
    if (liturgicalSeasonId != null) {
      params['liturgicalSeasonId'] = liturgicalSeasonId;
    }
    if (massTypeId != null) {
      params['massTypeId'] = massTypeId;
    }
    if (ceremonyTypeId != null) {
      params['ceremonyTypeId'] = ceremonyTypeId;
    }
    if (songThemeId != null) {
      params['songThemeId'] = songThemeId;
    }
    if (liturgicalSlotId != null) {
      params['liturgicalSlotId'] = liturgicalSlotId;
    }
    if (skillId != null) {
      params['skillId'] = skillId;
    }
    if (isClassified != null) {
      params['isClassified'] = isClassified;
    }
    if (missingMaterialType != null) {
      params['missingMaterialType'] = missingMaterialType!.wireName;
    }
    return params;
  }
}

class MusicMaterialDto {
  final String id;
  final String songId;
  final MaterialType materialType;
  final String title;
  final String fileName;
  final int? fileSizeBytes;
  final String? targetSkillId;
  final String? targetSkillName;
  final String fileUrl;
  final String? lyricsText;
  final String createdAt;

  const MusicMaterialDto({
    required this.id,
    required this.songId,
    required this.materialType,
    required this.title,
    required this.fileName,
    this.fileSizeBytes,
    this.targetSkillId,
    this.targetSkillName,
    required this.fileUrl,
    this.lyricsText,
    required this.createdAt,
  });

  factory MusicMaterialDto.fromJson(Map<String, dynamic> json) {
    return MusicMaterialDto(
      id: json['id']?.toString() ?? '',
      songId: json['songId']?.toString() ?? '',
      materialType: MaterialType.fromWire(json['materialType']),
      title: json['title']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      targetSkillId: json['targetSkillId']?.toString(),
      targetSkillName: json['targetSkillName']?.toString(),
      fileUrl: json['fileUrl']?.toString() ?? '',
      lyricsText: json['lyricsText'] as String?,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'songId': songId,
    'materialType': materialType.wireName,
    'title': title,
    'fileName': fileName,
    'fileSizeBytes': fileSizeBytes,
    'targetSkillId': targetSkillId,
    'targetSkillName': targetSkillName,
    'fileUrl': fileUrl,
    'lyricsText': ?lyricsText,
    'createdAt': createdAt,
  };
}

class MusicMaterialDetailDto extends MusicMaterialDto {
  final LearningStatus learningStatus;
  final String? learningUpdatedAt;

  const MusicMaterialDetailDto({
    required super.id,
    required super.songId,
    required super.materialType,
    required super.title,
    required super.fileName,
    super.fileSizeBytes,
    super.targetSkillId,
    super.targetSkillName,
    required super.fileUrl,
    super.lyricsText,
    required super.createdAt,
    required this.learningStatus,
    this.learningUpdatedAt,
  });

  factory MusicMaterialDetailDto.fromJson(Map<String, dynamic> json) {
    final base = MusicMaterialDto.fromJson(json);
    return MusicMaterialDetailDto(
      id: base.id,
      songId: base.songId,
      materialType: base.materialType,
      title: base.title,
      fileName: base.fileName,
      fileSizeBytes: base.fileSizeBytes,
      targetSkillId: base.targetSkillId,
      targetSkillName: base.targetSkillName,
      fileUrl: base.fileUrl,
      lyricsText: base.lyricsText,
      createdAt: base.createdAt,
      learningStatus: LearningStatus.fromWire(json['learningStatus']),
      learningUpdatedAt: json['learningUpdatedAt']?.toString(),
    );
  }
}

class SearchMusicMaterialsRequest {
  final String? keyword;
  final String? songId;
  final String? liturgicalSeasonId;
  final String? skillId;
  final MaterialType? materialType;
  final LearningStatus? learningStatus;
  final int pageNumber;
  final int pageSize;

  const SearchMusicMaterialsRequest({
    this.keyword,
    this.songId,
    this.liturgicalSeasonId,
    this.skillId,
    this.materialType,
    this.learningStatus,
    this.pageNumber = 1,
    this.pageSize = 20,
  });

  Map<String, dynamic> toQueryParameters() {
    final params = <String, dynamic>{
      'pageNumber': pageNumber,
      'pageSize': pageSize,
    };
    if (keyword != null && keyword!.isNotEmpty) {
      params['keyword'] = keyword;
    }
    if (songId != null) {
      params['songId'] = songId;
    }
    if (liturgicalSeasonId != null) {
      params['liturgicalSeasonId'] = liturgicalSeasonId;
    }
    if (skillId != null) {
      params['skillId'] = skillId;
    }
    if (materialType != null) {
      params['materialType'] = materialType!.wireName;
    }
    if (learningStatus != null) {
      params['learningStatus'] = learningStatus!.wireName;
    }
    return params;
  }
}

class UpdateMaterialLearningProgressRequest {
  final LearningStatus status;

  const UpdateMaterialLearningProgressRequest({required this.status});

  Map<String, dynamic> toJson() => {'status': status.wireName};
}

class MaterialLearningProgressDto {
  final String materialId;
  final LearningStatus status;
  final String updatedAt;

  const MaterialLearningProgressDto({
    required this.materialId,
    required this.status,
    required this.updatedAt,
  });

  factory MaterialLearningProgressDto.fromJson(Map<String, dynamic> json) {
    return MaterialLearningProgressDto(
      materialId: json['materialId']?.toString() ?? '',
      status: LearningStatus.fromWire(json['status']),
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }
}

class SongListItemDto {
  final String id;
  final String songId;
  final String songTitle;
  final String slotId;
  final String slotName;
  final int displayOrder;
  final String? note;

  const SongListItemDto({
    required this.id,
    required this.songId,
    required this.songTitle,
    required this.slotId,
    required this.slotName,
    required this.displayOrder,
    this.note,
  });

  factory SongListItemDto.fromJson(Map<String, dynamic> json) {
    return SongListItemDto(
      id: json['id']?.toString() ?? '',
      songId: json['songId']?.toString() ?? '',
      songTitle: json['songTitle']?.toString() ?? '',
      slotId: json['slotId']?.toString() ?? '',
      slotName: json['slotName']?.toString() ?? '',
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 1,
      note: json['note']?.toString(),
    );
  }
}

class SongListDto {
  final String id;
  final String eventId;
  final int version;
  final String status;
  final List<SongListItemDto> items;
  final DateTime? submittedAt;
  final String? reviewNotes;

  const SongListDto({
    required this.id,
    required this.eventId,
    required this.version,
    required this.status,
    required this.items,
    this.submittedAt,
    this.reviewNotes,
  });

  factory SongListDto.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final reviews = json['reviews'] as List<dynamic>? ?? [];
    return SongListDto(
      id: json['id']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      version: (json['version'] as num?)?.toInt() ?? 1,
      status: json['status']?.toString() ?? '',
      submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? ''),
      reviewNotes: reviews.isEmpty
          ? null
          : (reviews.last as Map)['notes'] as String?,
      items: rawItems
          .map((e) => SongListItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
