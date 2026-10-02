import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../calendar/data/liturgical_models.dart';
import '../../notifications/presentation/notification_notifier.dart';
import '../../practice/data/practice_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showParticipationDialog(
    BuildContext context,
    WidgetRef ref,
    LiturgicalEvent event,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Xác nhận tham dự Thánh Lễ',
                  style: AppTypography.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(event.title, style: AppTypography.bodySmall),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.statusSuccess,
                  ),
                  title: const Text('Có mặt phục vụ'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onTap: () {
                    ref
                        .read(calendarNotifierProvider.notifier)
                        .setParticipation(
                          event.id,
                          ParticipationStatus.confirmed,
                        );
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã xác nhận tham gia phục vụ!'),
                        backgroundColor: AppColors.statusSuccess,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(
                    Icons.cancel_rounded,
                    color: AppColors.statusDanger,
                  ),
                  title: const Text('Báo vắng mặt'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onTap: () {
                    ref
                        .read(calendarNotifierProvider.notifier)
                        .setParticipation(
                          event.id,
                          ParticipationStatus.declined,
                        );
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã cập nhật trạng thái vắng mặt.'),
                        backgroundColor: AppColors.statusDanger,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(
                    Icons.help_outline_rounded,
                    color: AppColors.statusWarning,
                  ),
                  title: const Text('Chưa chắc chắn'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onTap: () {
                    ref
                        .read(calendarNotifierProvider.notifier)
                        .setParticipation(event.id, ParticipationStatus.unsure);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarState = ref.watch(calendarNotifierProvider);
    final notificationState = ref.watch(notificationNotifierProvider);
    final practiceState = ref.watch(practiceListNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(calendarNotifierProvider.notifier).loadEvents();
            await ref
                .read(practiceListNotifierProvider.notifier)
                .loadAssignments();
            await ref.read(notificationNotifierProvider.notifier).refresh();
          },
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Row
                Row(
                  children: [
                    // Member Avatar & Greeting
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'M',
                          style: AppTypography.titleLarge.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chào Maria Mai',
                            style: AppTypography.headlineSmall.copyWith(
                              fontSize: 18,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Bè Soprano',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• Ca viên',
                                style: AppTypography.labelSmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Notification Bell Icon with Badge
                    Stack(
                      children: [
                        IconButton(
                          onPressed: () => context.go('/notifications'),
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            size: 26,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                        if (notificationState.unreadCount > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '${notificationState.unreadCount}',
                                style: const TextStyle(
                                  color: AppColors.onPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Subtitle Context Banner
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sẵn sàng cho buổi phục vụ tiếp theo?',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Tuần XXVI Thường Niên • Phụng vụ Thánh ca',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Tuần 26',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. Large Upcoming Event Card (Sacred Burgundy Stitch theme)
                calendarState.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  error: (e, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('Không thể tải lịch: $e'),
                  ),
                  data: (events) {
                    if (events.isEmpty) return const SizedBox.shrink();
                    final mainEvent = events.first;

                    return Card(
                      child: Stack(
                        children: [
                          // Background Church Watermark
                          Positioned(
                            right: -10,
                            bottom: -10,
                            child: Icon(
                              Icons.church_rounded,
                              size: 110,
                              color: AppColors.primary.withValues(alpha: 0.05),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top badges: Season & Participation Status
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.statusSuccessSoft,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: AppColors.statusSuccess,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            mainEvent.seasonName,
                                            style: AppTypography.labelSmall
                                                .copyWith(
                                                  color:
                                                      AppColors.statusSuccess,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Confirmation Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            mainEvent.participationStatus ==
                                                ParticipationStatus.confirmed
                                            ? AppColors.statusSuccessSoft
                                            : AppColors.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            mainEvent.participationStatus ==
                                                    ParticipationStatus
                                                        .confirmed
                                                ? Icons.check_circle_rounded
                                                : Icons.help_outline_rounded,
                                            size: 14,
                                            color:
                                                mainEvent.participationStatus ==
                                                    ParticipationStatus
                                                        .confirmed
                                                ? AppColors.statusSuccess
                                                : AppColors.muted,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            mainEvent.participationStatus.label,
                                            style: AppTypography.labelSmall
                                                .copyWith(
                                                  color:
                                                      mainEvent
                                                              .participationStatus ==
                                                          ParticipationStatus
                                                              .confirmed
                                                      ? AppColors.statusSuccess
                                                      : AppColors.onSurface,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Event category & Title
                                Text(
                                  mainEvent.categoryName,
                                  style: AppTypography.labelSmall.copyWith(
                                    letterSpacing: 1.1,
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  mainEvent.title,
                                  style: AppTypography.headlineSmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Detail Box
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today_rounded,
                                            size: 16,
                                            color: AppColors.secondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '27/09/2026',
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const Text(' • '),
                                          Text(
                                            mainEvent.timeRange,
                                            style: AppTypography.bodySmall,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_rounded,
                                            size: 16,
                                            color: AppColors.secondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              mainEvent.location,
                                              style: AppTypography.bodyMedium,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.groups_rounded,
                                            size: 16,
                                            color: AppColors.secondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Phân công giọng hát: ',
                                            style: AppTypography.bodySmall,
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              mainEvent.assignedVocalPart,
                                              style: AppTypography.labelSmall
                                                  .copyWith(
                                                    color: AppColors.onPrimary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Button: Xem chi tiết phụng vụ & bài hát
                                ElevatedButton(
                                  onPressed: () {
                                    context.push(
                                      '/event-detail/${mainEvent.id}',
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Xem chi tiết phụng vụ & bài hát',
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 2. Section "Việc cần làm" (To-do / Actions)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.assignment_turned_in_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Việc cần làm',
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusDangerSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '2 việc',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.statusDanger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Card 1: Xác nhận tham dự lễ Chúa Nhật tới
                calendarState.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (events) {
                    final nextEvent = events.length > 1
                        ? events[1]
                        : events.first;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.event_available_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Xác nhận tham dự',
                                        style: AppTypography.titleMedium
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${nextEvent.title} (04/10 • 18:00)',
                                        style: AppTypography.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    nextEvent.participationStatus.label,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.body,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.timer_outlined,
                                      size: 14,
                                      color: AppColors.muted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Hạn chót: T7 tuần này',
                                      style: AppTypography.labelSmall,
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _showParticipationDialog(
                                    context,
                                    ref,
                                    nextEvent,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(104, 44),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.reply_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Phản hồi'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Card 2: Nộp bản thu âm luyện tập
                practiceState.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (assignments) {
                    if (assignments.isEmpty) return const SizedBox.shrink();
                    final pendingAssignment = assignments.first;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.mic_rounded,
                                    color: AppColors.gold,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bài luyện tập cần nộp',
                                        style: AppTypography.titleMedium
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        pendingAssignment.songTitle,
                                        style: AppTypography.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.statusWarningSoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    pendingAssignment.status.label,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.statusWarning,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.timer_outlined,
                                      size: 14,
                                      color: AppColors.muted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Còn 2 ngày',
                                      style: AppTypography.labelSmall,
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    context.push(
                                      '/practice-detail/${pendingAssignment.id}',
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(124, 44),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.fiber_manual_record_rounded,
                                    size: 14,
                                  ),
                                  label: const Text('Thu âm ngay'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 3. Section: Lịch tập hát sắp tới
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.event_note_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Buổi tập hát',
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => context.go('/calendar'),
                      child: const Text('Xem tất cả'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Thứ Sáu, 02/10/2026',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.statusInfoSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '19:30 – 21:00',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.statusInfo,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Phòng tập Ca đoàn Harmonia',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Nội dung: Ráp đàn và luyện kỹ thuật bè bài Đáp ca Chúa Nhật XXVII.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
