import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/role_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/session/session_manager.dart';
import '../../calendar/data/calendar_repository.dart'
    show publicAppSettingsProvider;
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
  _MemberNotificationFilter _memberFilter = _MemberNotificationFilter.all;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final member =
        ref.read(sessionManagerProvider).role == MobileRole.choirMember;
    if (!_scrollController.hasClients ||
        (member &&
            (_memberFilter != _MemberNotificationFilter.all || _unreadOnly))) {
      return;
    }
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
      case NotificationType.choirChanged:
        return Icons.groups_rounded;
      case NotificationType.directorNomination:
        return Icons.workspace_premium_outlined;
      case NotificationType.memberRegistrationSubmitted:
        return Icons.person_add_alt_1_outlined;
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

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item.title, style: AppTypography.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt.toLocal()),
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const Divider(height: 1),
              Text(
                item.content,
                style: AppTypography.bodyMedium.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberNotifications(
    NotificationState state,
    NotificationNotifier notifier,
  ) {
    final settings = ref.watch(publicAppSettingsProvider).asData?.value;
    final choir = settings?.choirName.trim();
    final showChoir =
        choir != null &&
        choir.isNotEmpty &&
        MediaQuery.textScalerOf(context).scale(16) <= 25;
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final groups = <String, List<NotificationDto>>{};
    final visible = state.items.where(
      (item) =>
          _memberFilter.matches(item.type) && (!_unreadOnly || !item.isRead),
    );
    for (final item in visible) {
      final date = item.createdAt.toLocal();
      final group = DateUtils.isSameDay(date, now)
          ? 'Hôm nay'
          : DateUtils.isSameDay(date, yesterday)
          ? 'Hôm qua'
          : 'Trước đó';
      (groups[group] ??= []).add(item);
    }

    return Theme(
      data: MemberChoirStyle.theme(context),
      child: Scaffold(
        backgroundColor: MemberChoirStyle.serviceCanvas,
        appBar: AppPageHeader(
          large: true,
          gradient: const LinearGradient(
            colors: [MemberChoirStyle.wine, MemberChoirStyle.accent],
          ),
          titleFontFamily: MemberChoirStyle.displayFont,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              if (showChoir)
                Text(
                  choir,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(
                    color: MemberChoirStyle.softGold,
                  ),
                ),
              Text(
                'Thông báo phụng vụ',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headlineSmall.copyWith(
                  color: Colors.white,
                  fontFamily: MemberChoirStyle.displayFont,
                  height: 1.05,
                ),
              ),
            ],
          ),
          actions: [
            if (state.unreadCount > 0)
              IconButton(
                tooltip: 'Đánh dấu tất cả đã đọc',
                onPressed: notifier.markAllAsRead,
                icon: const Icon(Icons.done_all_rounded),
              ),
            IconButton(
              tooltip: _unreadOnly
                  ? 'Hiện cả thông báo đã đọc'
                  : 'Chỉ hiện chưa đọc',
              onPressed: () => setState(() => _unreadOnly = !_unreadOnly),
              icon: Icon(
                _unreadOnly ? Icons.filter_alt_rounded : Icons.tune_rounded,
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                spacing: 8,
                children: [
                  const Icon(
                    Icons.circle,
                    color: MemberChoirStyle.gold,
                    size: 8,
                  ),
                  Expanded(
                    child: Text(
                      '${state.unreadCount} thông báo chưa đọc',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMedium.copyWith(
                        color: MemberChoirStyle.softGold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 8,
                    children: [
                      for (final filter in _MemberNotificationFilter.values)
                        ChoiceChip(
                          label: Text(filter.label),
                          selected: filter == _memberFilter,
                          onSelected: (_) =>
                              setState(() => _memberFilter = filter),
                        ),
                    ],
                  ),
                ),
                if (_unreadOnly)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: InputChip(
                      label: const Text('Chỉ hiện chưa đọc'),
                      onDeleted: () => setState(() => _unreadOnly = false),
                    ),
                  ),
                if (state.isLoading && state.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.errorMessage != null && state.items.isEmpty)
                  _MemberNotificationMessage(
                    message: state.errorMessage!,
                    onRetry: notifier.loadInitial,
                  )
                else if (groups.isEmpty)
                  _MemberNotificationMessage(
                    message: state.items.isEmpty
                        ? 'Bạn chưa có thông báo'
                        : 'Chưa có thông báo đã tải phù hợp với bộ lọc.',
                  ),
                for (final group in ['Hôm nay', 'Hôm qua', 'Trước đó'])
                  if (groups[group] case final items?) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
                      child: Row(
                        spacing: 8,
                        children: [
                          Expanded(
                            child: Text(
                              group.toUpperCase(),
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          Text(
                            '${items.length} tin',
                            style: AppTypography.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    for (final item in items)
                      Padding(
                        key: ValueKey(item.id),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: StitchEntrance(
                          child: _MemberNotificationCard(
                            item: item,
                            icon: _getIconForType(item.type),
                            time: _formatTime(item.createdAt),
                            onOpen: () => _handleNotificationTap(item),
                          ),
                        ),
                      ),
                  ],
                if (state.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (state.hasNextPage)
                  OutlinedButton(
                    onPressed: notifier.loadMore,
                    child: const Text('Tải thêm thông báo'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationNotifierProvider);
    final notifier = ref.read(notificationNotifierProvider.notifier);
    final role = ref.watch(
      sessionManagerProvider.select((session) => session.role),
    );
    if (role == MobileRole.choirMember) {
      return _buildMemberNotifications(state, notifier);
    }

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

enum _MemberNotificationFilter {
  all('Tất cả'),
  service('Phân công & Lịch'),
  practice('Bài tập & Nhận xét'),
  other('Khác');

  const _MemberNotificationFilter(this.label);

  final String label;

  bool matches(NotificationType type) => this == all || this == _category(type);

  static _MemberNotificationFilter _category(NotificationType type) =>
      switch (type) {
        NotificationType.weekPublished ||
        NotificationType.eventCancelled ||
        NotificationType.rehearsalChanged ||
        NotificationType.songListDecision ||
        NotificationType.songListSubmitted ||
        NotificationType.participationRequest ||
        NotificationType.assignmentNotice ||
        NotificationType.eventChoirChanged => service,
        NotificationType.practiceFeedback => practice,
        _ => other,
      };
}

class _MemberNotificationCard extends StatelessWidget {
  const _MemberNotificationCard({
    required this.item,
    required this.icon,
    required this.time,
    required this.onOpen,
  });

  final NotificationDto item;
  final IconData icon;
  final String time;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tone = switch (item.type) {
      NotificationType.assignmentNotice ||
      NotificationType.participationRequest => AppColors.statusSuccess,
      NotificationType.rehearsalChanged ||
      NotificationType.eventCancelled => AppColors.tertiary,
      NotificationType.skillReview => const Color(0xFF754393),
      NotificationType.practiceFeedback => MemberChoirStyle.wine,
      _ => MemberChoirStyle.ink,
    };
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!item.isRead)
              ColoredBox(
                color: MemberChoirStyle.gold,
                child: const SizedBox(height: 3),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 9,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: tone.withValues(alpha: .09),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 5,
                            children: [
                              Icon(icon, size: 15, color: tone),
                              Flexible(
                                child: Text(
                                  item.type.label,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: tone,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        time,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    item.title,
                    style: AppTypography.titleMedium.copyWith(
                      color: MemberChoirStyle.ink,
                      fontWeight: item.isRead
                          ? FontWeight.w600
                          : FontWeight.w700,
                    ),
                  ),
                  if (item.content.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: MemberChoirStyle.serviceCanvas,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.content,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                  const Divider(height: 1),
                  Row(
                    spacing: 6,
                    children: [
                      if (!item.isRead)
                        Expanded(
                          child: Text(
                            'Chưa đọc',
                            style: AppTypography.labelSmall.copyWith(
                              color: MemberChoirStyle.wine,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      Flexible(
                        flex: 2,
                        child: TextButton.icon(
                          onPressed: onOpen,
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                          ),
                          iconAlignment: IconAlignment.end,
                          label: const Text('Xem chi tiết'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberNotificationMessage extends StatelessWidget {
  const _MemberNotificationMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
    child: Column(
      spacing: 8,
      children: [
        Icon(
          onRetry == null
              ? Icons.notifications_none_rounded
              : Icons.cloud_off_rounded,
          color: AppColors.muted,
          size: 34,
        ),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium,
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}
