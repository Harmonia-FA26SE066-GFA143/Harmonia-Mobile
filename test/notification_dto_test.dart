import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_dto.dart';

void main() {
  group('Notification DTOs Contract Test', () {
    test('NotificationType maps wire enum values correctly', () {
      expect(NotificationType.fromValue(0), NotificationType.weekPublished);
      expect(NotificationType.fromValue(1), NotificationType.songListDecision);
      expect(
        NotificationType.fromValue(2),
        NotificationType.participationRequest,
      );
      expect(NotificationType.fromValue(3), NotificationType.assignmentNotice);
      expect(NotificationType.fromValue(4), NotificationType.practiceFeedback);
      expect(NotificationType.fromValue(5), NotificationType.directorNote);
      // Fallback for unknown enum
      expect(NotificationType.fromValue(99), NotificationType.directorNote);
    });

    test('NotificationDto decodes properly from JSON', () {
      final json = {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'type': 0,
        'title': 'Tuần XXVI Thường Niên đã công bố',
        'content':
            'Ca viên vui lòng xem danh sách bài hát và xác nhận tham dự.',
        'referenceType': 'LiturgicalWeek',
        'referenceId': 'e5f67890-abcd-ef12-3456-7890abcdef12',
        'createdAt': '2026-09-27T10:00:00Z',
        'isRead': false,
        'readAt': null,
      };

      final dto = NotificationDto.fromJson(json);
      expect(dto.id, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890');
      expect(dto.type, NotificationType.weekPublished);
      expect(dto.title, 'Tuần XXVI Thường Niên đã công bố');
      expect(dto.isRead, false);
      expect(dto.readAt, isNull);
    });

    test('PagedList decodes items and metadata directly', () {
      final json = {
        'items': [
          {
            'id': 'notif-1',
            'type': 1,
            'title': 'Duyệt bài hát',
            'content': 'Đã duyệt danh sách bài hát',
            'createdAt': '2026-09-28T08:00:00Z',
            'isRead': true,
          },
        ],
        'pageNumber': 1,
        'pageSize': 20,
        'totalCount': 1,
        'totalPages': 1,
        'hasPreviousPage': false,
        'hasNextPage': false,
      };

      final paged = PagedList<NotificationDto>.fromJson(
        json,
        NotificationDto.fromJson,
      );
      expect(paged.items.length, 1);
      expect(paged.items.first.id, 'notif-1');
      expect(paged.pageNumber, 1);
      expect(paged.hasNextPage, false);
    });
  });
}
