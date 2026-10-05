enum MaterialType {
  sheetMusic('SheetMusic', 'Bản nhạc phổ'),
  lyrics('Lyrics', 'Lời bài hát'),
  sampleAudio('SampleAudio', 'Audio mẫu'),
  rehearsalMaterial('RehearsalMaterial', 'Tài liệu tập hát');

  final String wireName;
  final String label;
  const MaterialType(this.wireName, this.label);

  static MaterialType fromWire(dynamic value) {
    if (value == null) return MaterialType.sheetMusic;
    final str = value.toString().toLowerCase();
    for (final t in MaterialType.values) {
      if (t.wireName.toLowerCase() == str || t.name == str) {
        return t;
      }
    }
    return MaterialType.sheetMusic;
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

class SongDto {
  final String id;
  final String title;
  final String? composer;
  final String? lyricist;
  final String? musicalKey;
  final String? tempo;
  final String? notes;

  const SongDto({
    required this.id,
    required this.title,
    this.composer,
    this.lyricist,
    this.musicalKey,
    this.tempo,
    this.notes,
  });

  factory SongDto.fromJson(Map<String, dynamic> json) {
    return SongDto(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      composer: json['composer']?.toString(),
      lyricist: json['lyricist']?.toString(),
      musicalKey: json['musicalKey']?.toString(),
      tempo: json['tempo']?.toString(),
      notes: json['notes']?.toString(),
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

  const SongVocalRequirementDto({
    required this.skillId,
    required this.skillName,
    required this.isMandatory,
  });

  factory SongVocalRequirementDto.fromJson(Map<String, dynamic> json) {
    return SongVocalRequirementDto(
      skillId: json['skillId']?.toString() ?? '',
      skillName: json['skillName']?.toString() ?? '',
      isMandatory: json['isMandatory'] == true,
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

  const SongInstrumentRequirementDto({
    required this.skillId,
    required this.skillName,
    required this.isMandatory,
  });

  factory SongInstrumentRequirementDto.fromJson(Map<String, dynamic> json) {
    return SongInstrumentRequirementDto(
      skillId: json['skillId']?.toString() ?? '',
      skillName: json['skillName']?.toString() ?? '',
      isMandatory: json['isMandatory'] == true,
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
  final List<SongVocalRequirementDto> vocalRequirements;
  final List<SongInstrumentRequirementDto> instrumentRequirements;

  const SongClassificationDto({
    required this.songId,
    this.liturgicalSeasons = const [],
    this.massTypes = const [],
    this.ceremonyTypes = const [],
    this.songThemes = const [],
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
  final String? skillId;
  final int pageNumber;
  final int pageSize;

  const SearchSongsRequest({
    this.keyword,
    this.liturgicalSeasonId,
    this.massTypeId,
    this.ceremonyTypeId,
    this.songThemeId,
    this.skillId,
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
    if (skillId != null) {
      params['skillId'] = skillId;
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
