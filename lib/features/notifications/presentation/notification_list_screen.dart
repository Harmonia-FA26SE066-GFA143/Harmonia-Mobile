import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/role_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/di/core_providers.dart';
import '../data/notification_dto.dart';
import 'notification_notifier.dart';

class NotificationListScreen extends ConsumerStatefulWidget {
  const NotificationListScreen({super.key});

  @override
  ConsumerState<NotificationListScreen> createState() =>
      _NotificationListScreenState();
}

class _NotificationListScreenState
    extends ConsumerState<NotificationListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationNotifierProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.weekPublished:
        return Icons.event_available_outlined;
      case NotificationType.eventCancelled:
        return Icons.event_busy_outlined;
      case NotificationType.rehearsalChanged:
        return Icons.edit_calendar_outlined;
      case NotificationType.songListDecision:
      case NotificationType.songListSubmitted:
        return Icons.library_music_rounded;
      case NotificationType.participationRequest:
        return Icons.event_available_rounded;
      case NotificationType.assignmentNotice:
        return Icons.assignment_ind_rounded;
      case NotificationType.practiceFeedback:
        return Icons.rate_review_rounded;
      case NotificationType.skillReview:
        return Icons.verified_rounded;
      case NotificationType.directorNote:
        return Icons.notes_rounded;
      case NotificationType.eventChoirChanged:
        return Icons.groups_rounded;
      case NotificationType.unknown:
        return Icons.notifications_none_rounded;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Vừa xong';
    if (difference.inMinutes < 60) return '${difference.inMinutes} phút trước';
    if (difference.inHours < 24) return '${difference.inHours} giờ trước';
    if (difference.inDays < 7) return '${difference.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime.toLocal());
  }

  void _handleNotificationTap(NotificationDto item) {
    if (!item.isRead) {
      ref.read(notificationNotifierProvider.notifier).markAsRead(item.id);
    }

    final target = notificationRoute(
      role: ref.read(sessionManagerProvider).role,
      referenceType: item.referenceType,
      referenceId: item.referenceId,
    );
    if (target != null) {
      context.push(target);
      return;
    }

    // Default: Show bottom sheet with full notification details
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt.toLocal()),
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                item.content,
                style: AppTypography.bodyMedium.copyWith(height: 1.5),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationNotifierProvider);
    final notifier = ref.read(notificationNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppPageHeader(
        large: true,
        title: Row(
          children: [
            Flexible(
              child: Text(
                'Thông báo',
                style: AppTypography.headlineMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
            if (state.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.unreadCount}',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (state.unreadCount > 0)
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0x22FFFFFF),
              ),
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Đánh dấu tất cả đã đọc',
              onPressed: () => notifier.markAllAsRead(),
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.isLoading && state.items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state.errorMessage != null && state.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 56,
                      color: AppColors.muted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage!,
                      style: AppTypography.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => notifier.loadInitial(),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => notifier.refresh(),
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              size: 36,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Bạn chưa có thông báo',
                            style: AppTypography.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Các cập nhật phụng vụ và lịch tập sẽ xuất hiện tại đây.',
                            style: AppTypography.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => notifier.refresh(),
            color: AppColors.primary,
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == state.items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }

                final item = state.items[index];
                final tone = switch (item.type) {
                  NotificationType.eventCancelled => AppColors.statusWarning,
                  NotificationType.skillReview
                      when item.title == 'Kỹ năng đã được duyệt' =>
                    AppColors.statusSuccess,
                  _ => item.isRead ? AppColors.body : AppColors.primary,
                };
                return StitchEntrance(
                  key: ValueKey(item.id),
                  child: InkWell(
                    onTap: () => _handleNotificationTap(item),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: item.isRead
                            ? AppColors.surface
                            : Color.alphaBlend(
                                tone.withValues(alpha: .026),
                                AppColors.surface,
                              ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: item.isRead && tone == AppColors.body
                              ? AppColors.border
                              : tone.withValues(alpha: .16),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Type Icon
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: tone.withValues(alpha: .065),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: tone.withValues(alpha: .15),
                              ),
                            ),
                            child: Icon(
                              _getIconForType(item.type),
                              color: tone,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Title, Content, Timestamp
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: AppTypography.titleMedium
                                            .copyWith(
                                              color: AppColors.onSurface,
                                              fontWeight: item.isRead
                                                  ? FontWeight.w600
                                                  : FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    if (!item.isRead) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.content,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.body,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _formatTime(item.createdAt),
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
