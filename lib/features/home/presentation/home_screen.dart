import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../calendar/data/liturgical_models.dart';
import '../../calendar/presentation/participation_prompt.dart';
import 'home_api_sections.dart';
import '../../notifications/presentation/notification_notifier.dart';
import '../../practice/data/practice_repository.dart';
import '../../profile/data/profile_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showParticipationDialog(
    BuildContext screenContext,
    WidgetRef ref,
    LiturgicalEvent event,
  ) {
    showModalBottomSheet<void>(
      context: screenContext,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(event.title, style: AppTypography.titleLarge),
            ),
            for (final status in [
              ParticipationStatus.confirmed,
              ParticipationStatus.declined,
              ParticipationStatus.unsure,
            ])
              ListTile(
                title: Text(status.label),
                enabled: event.canRespond,
                onTap: () {
                  Navigator.pop(sheetContext);
                  showParticipationPrompt(screenContext, ref, event, status);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarState = ref.watch(calendarNotifierProvider);
    final settings = ref.watch(publicAppSettingsProvider).value;
    final choirLabel = settings?.choirName.isNotEmpty == true
        ? settings!.choirName
        : 'Ca viên';
    final notificationState = ref.watch(notificationNotifierProvider);
    final practiceState = ref.watch(practiceListNotifierProvider);
    final profileState = ref.watch(currentMemberProfileProvider);

    final memberName = profileState.asData?.value.fullName.trim();
    final displayName = (memberName != null && memberName.isNotEmpty)
        ? memberName
        : 'Ca viên';
    final avatarInitial = displayName
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    final avatarUrl = profileState.asData?.value.avatarUrl;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          bottom: false,
          child: ColoredBox(
            color: AppColors.background,
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(rehearsalsProvider);
                ref.invalidate(publicAppSettingsProvider);
                ref.invalidate(currentMemberProfileProvider);
                await ref.read(calendarNotifierProvider.notifier).loadEvents();
                await ref
                    .read(practiceListNotifierProvider.notifier)
                    .loadAssignments();
                await ref.read(notificationNotifierProvider.notifier).refresh();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StitchEntrance(
                      distance: 0,
                      child: _HomeGreeting(
                        name: displayName,
                        initial: avatarInitial,
                        choirLabel: choirLabel,
                        avatarUrl: avatarUrl,
                        unreadCount: notificationState.unreadCount,
                        onNotifications: () => context.go('/notifications'),
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppColors.brandGradient,
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(32),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => context.go('/music-library'),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF0F3),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Icon(
                                        Icons.library_music_outlined,
                                        size: 24,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Thư viện thánh ca',
                                            style: AppTypography.titleMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.25,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Tìm bài hát và tài liệu học của bạn',
                                            style: AppTypography.bodySmall
                                                .copyWith(height: 1.3),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: AppColors.outline,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const HomePublicNotice(),
                          const MemberAssignmentsCard(),

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
                                      'Chỉ hiển thị sự kiện sắp tới được cha xứ công bố.',
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
                                  color: AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  DateFormat('dd/MM').format(DateTime.now()),
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.body,
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
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text('Không thể tải lịch: $e'),
                            ),
                            data: (events) {
                              if (events.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 24,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        color: AppColors.primary,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Chưa có sự kiện sắp tới được công bố cho ca viên.',
                                          style: AppTypography.bodySmall
                                              .copyWith(color: AppColors.muted),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              final mainEvent = events.first;

                              return Card(
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Top badges: Season & Participation Status
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors
                                                      .statusSuccessSoft,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration:
                                                          const BoxDecoration(
                                                            color: AppColors
                                                                .statusSuccess,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      mainEvent
                                                              .seasonName
                                                              .isNotEmpty
                                                          ? mainEvent.seasonName
                                                          : mainEvent
                                                                .categoryName
                                                                .isNotEmpty
                                                          ? mainEvent
                                                                .categoryName
                                                          : 'PHỤNG VỤ',
                                                      style: AppTypography
                                                          .labelSmall
                                                          .copyWith(
                                                            color: AppColors
                                                                .statusSuccess,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Confirmation Badge
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      mainEvent
                                                              .participationStatus ==
                                                          ParticipationStatus
                                                              .confirmed
                                                      ? AppColors
                                                            .statusSuccessSoft
                                                      : AppColors
                                                            .surfaceContainerHigh,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      mainEvent.participationStatus ==
                                                              ParticipationStatus
                                                                  .confirmed
                                                          ? Icons
                                                                .check_circle_rounded
                                                          : Icons
                                                                .help_outline_rounded,
                                                      size: 14,
                                                      color:
                                                          mainEvent
                                                                  .participationStatus ==
                                                              ParticipationStatus
                                                                  .confirmed
                                                          ? AppColors
                                                                .statusSuccess
                                                          : AppColors.muted,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      mainEvent
                                                          .participationStatus
                                                          .label,
                                                      style: AppTypography.labelSmall.copyWith(
                                                        color:
                                                            mainEvent
                                                                    .participationStatus ==
                                                                ParticipationStatus
                                                                    .confirmed
                                                            ? AppColors
                                                                  .statusSuccess
                                                            : AppColors
                                                                  .onSurface,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          // Event category & Title
                                          if (mainEvent.seasonName.isNotEmpty)
                                            Text(
                                              mainEvent.categoryName,
                                              style: AppTypography.labelSmall
                                                  .copyWith(
                                                    letterSpacing: 1.1,
                                                    color: AppColors.muted,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          const SizedBox(height: 2),
                                          Text(
                                            mainEvent.title,
                                            style: AppTypography.headlineMedium
                                                .copyWith(
                                                  color: AppColors.onSurface,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 14),

                                          // Detail Box
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color:
                                                  AppColors.surfaceContainerLow,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: AppColors.border,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .calendar_today_rounded,
                                                      size: 16,
                                                      color:
                                                          AppColors.secondary,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      DateFormat(
                                                        'dd/MM/yyyy',
                                                      ).format(mainEvent.date),
                                                      style: AppTypography
                                                          .bodyMedium
                                                          .copyWith(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                    const Text(' • '),
                                                    Text(
                                                      mainEvent.timeRange,
                                                      style: AppTypography
                                                          .bodySmall,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.location_on_rounded,
                                                      size: 16,
                                                      color:
                                                          AppColors.secondary,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        mainEvent.location,
                                                        style: AppTypography
                                                            .bodyMedium,
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
                                                      color:
                                                          AppColors.secondary,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Phân công giọng hát: ',
                                                      style: AppTypography
                                                          .bodySmall,
                                                    ),
                                                    Flexible(
                                                      child: Text(
                                                        mainEvent
                                                                .assignedVocalPart
                                                                .isNotEmpty
                                                            ? mainEvent
                                                                  .assignedVocalPart
                                                            : 'Chưa có phân công',
                                                        style: AppTypography
                                                            .labelMedium
                                                            .copyWith(
                                                              color: AppColors
                                                                  .primary,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
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
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Flexible(
                                                  child: Text(
                                                    'Xem chi tiết phụng vụ & bài hát',
                                                    textAlign: TextAlign.center,
                                                  ),
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
                                  'Của bạn',
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
                              if (events.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              final nextEvent = events.length > 1
                                  ? events[1]
                                  : events.first;

                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(10),
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
                                                  style: AppTypography
                                                      .titleMedium
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${nextEvent.title} (${DateFormat('dd/MM').format(nextEvent.date)} • ${nextEvent.timeRange})',
                                                  style:
                                                      AppTypography.bodySmall,
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
                                              color:
                                                  AppColors.surfaceContainerLow,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: AppColors.border,
                                              ),
                                            ),
                                            child: Text(
                                              nextEvent
                                                  .participationStatus
                                                  .label,
                                              style: AppTypography.labelSmall
                                                  .copyWith(
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
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
                                                'Phản hồi một lần',
                                                style: AppTypography.labelSmall,
                                              ),
                                            ],
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: !nextEvent.canRespond
                                                ? null
                                                : () =>
                                                      _showParticipationDialog(
                                                        context,
                                                        ref,
                                                        nextEvent,
                                                      ),
                                            style: ElevatedButton.styleFrom(
                                              minimumSize: const Size(104, 44),
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                            data: (practiceList) {
                              final assignments = practiceList.items;
                              if (assignments.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              final pendingAssignment = assignments.first;
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.gold.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
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
                                                  style: AppTypography
                                                      .titleMedium
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  pendingAssignment.songTitle,
                                                  style:
                                                      AppTypography.bodySmall,
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
                                              color:
                                                  AppColors.statusWarningSoft,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              pendingAssignment.status.label,
                                              style: AppTypography.labelSmall
                                                  .copyWith(
                                                    color:
                                                        AppColors.statusWarning,
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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

                          const UpcomingRehearsalCard(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting({
    required this.name,
    required this.initial,
    required this.choirLabel,
    required this.avatarUrl,
    required this.unreadCount,
    required this.onNotifications,
  });

  final String name;
  final String initial;
  final String choirLabel;
  final String? avatarUrl;
  final int unreadCount;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        initial,
        style: AppTypography.headlineMedium.copyWith(color: AppColors.primary),
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl?.isNotEmpty == true
                ? Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fallback,
                  )
                : fallback,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chào $name',
                  style: AppTypography.headlineSmall.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        choirLabel,
                        style: AppTypography.labelMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '• Ca viên',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: unreadCount > 0,
            backgroundColor: Colors.white,
            textColor: AppColors.primary,
            label: Text('$unreadCount'),
            child: IconButton(
              tooltip: 'Thông báo',
              onPressed: onNotifications,
              icon: const Icon(Icons.notifications_none_rounded, size: 26),
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                minimumSize: const Size(48, 48),
                shape: const CircleBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
