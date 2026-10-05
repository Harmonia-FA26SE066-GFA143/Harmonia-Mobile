class LookupItemDto {
  final String id;
  final String name;
  final String? description;

  const LookupItemDto({required this.id, required this.name, this.description});

  factory LookupItemDto.fromJson(Map<String, dynamic> json) {
    return LookupItemDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
  };
}

class LiturgicalSeasonDto {
  final String id;
  final String name;
  final String startDate;
  final String endDate;
  final String? colorHex;

  const LiturgicalSeasonDto({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.colorHex,
  });

  factory LiturgicalSeasonDto.fromJson(Map<String, dynamic> json) {
    return LiturgicalSeasonDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      colorHex: json['colorHex']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startDate': startDate,
    'endDate': endDate,
    'colorHex': colorHex,
  };
}

class LiturgicalSlotDto {
  final String id;
  final String name;
  final int defaultOrder;

  const LiturgicalSlotDto({
    required this.id,
    required this.name,
    required this.defaultOrder,
  });

  factory LiturgicalSlotDto.fromJson(Map<String, dynamic> json) {
    return LiturgicalSlotDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      defaultOrder: (json['defaultOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'defaultOrder': defaultOrder,
  };
}

class WorshipLocationDto {
  final String id;
  final String name;
  final String? address;

  const WorshipLocationDto({
    required this.id,
    required this.name,
    this.address,
  });

  factory WorshipLocationDto.fromJson(Map<String, dynamic> json) {
    return WorshipLocationDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'address': address};
}

class SkillDto {
  final String id;
  final String categoryId;
  final String name;
  final String? description;

  const SkillDto({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
  });

  factory SkillDto.fromJson(Map<String, dynamic> json) {
    return SkillDto(
      id: json['id']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'name': name,
    'description': description,
  };
}
