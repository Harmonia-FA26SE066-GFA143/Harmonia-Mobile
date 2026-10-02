enum NotificationType {
  weekPublished(0, 'Tuần phụng vụ mới'),
  songListDecision(1, 'Duyệt danh sách bài hát'),
  participationRequest(2, 'Yêu cầu điểm diện / tham gia'),
  assignmentNotice(3, 'Phân công phục vụ'),
  practiceFeedback(4, 'Nhận xét bài thu âm'),
  directorNote(5, 'Ghi chú từ Ca trưởng');

  final int value;
  final String label;
  const NotificationType(this.value, this.label);

  static NotificationType fromValue(int value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.directorNote,
    );
  }
}

class NotificationDto {
  final String id;
  final NotificationType type;
  final String title;
  final String content;
  final String? referenceType;
  final String? referenceId;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;

  const NotificationDto({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.referenceType,
    this.referenceId,
    required this.createdAt,
    required this.isRead,
    this.readAt,
  });

  NotificationDto copyWith({bool? isRead, DateTime? readAt}) {
    return NotificationDto(
      id: id,
      type: type,
      title: title,
      content: content,
      referenceType: referenceType,
      referenceId: referenceId,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    return NotificationDto(
      id: json['id']?.toString() ?? '',
      type: NotificationType.fromValue(
        json['type'] is int ? json['type'] as int : 5,
      ),
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      referenceType: json['referenceType']?.toString(),
      referenceId: json['referenceId']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] == true,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
    );
  }
}

class PagedList<T> {
  final List<T> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool hasPreviousPage;
  final bool hasNextPage;

  const PagedList({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  factory PagedList.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final rawList = json['items'] as List<dynamic>? ?? [];
    return PagedList<T>(
      items: rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => fromJsonT(item))
          .toList(),
      pageNumber: json['pageNumber'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      totalCount: json['totalCount'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      hasPreviousPage: json['hasPreviousPage'] as bool? ?? false,
      hasNextPage: json['hasNextPage'] as bool? ?? false,
    );
  }
}
