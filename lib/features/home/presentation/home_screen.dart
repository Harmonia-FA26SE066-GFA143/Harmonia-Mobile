import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/errors/error_messages.dart';
import '../../../app/widgets/harmonia_svg_art.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../../app/widgets/harmonia_logo.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../calendar/data/liturgical_models.dart';
import '../../calendar/presentation/participation_prompt.dart';
import 'home_api_sections.dart';
import '../../notifications/presentation/notification_notifier.dart';
import '../../practice/data/practice_repository.dart';
import '../../profile/data/profile_repository.dart';

// Stitch tokens from "Harmonia Mobile 01 - Trang chủ Ca viên (Nhận diện Ca đoàn)"
// (screen 64f80823db954ee08d18403c2d7fc1d0) scoped locally to HomeScreen.
const _stitchMutedIcon = Color(0xFF76767E);
const _stitchBorder = Color(0xFFE6E1D8);
const _stitchSoftSurface = Color(0xFFF5F2EB);
const _stitchDisabledText = Color(0xFF45464D);
const _stitchBadgeGold = Color(0xFFC59B27);
const _stitchBadgeText = Color(0xFF05102B);
const _stitchLibraryIconBg = Color(0x33FECE57);
const _stitchLibraryIconBorder = Color(0x66FECE57);
const _stitchLibraryIconFg = Color(0xFF735700);

Color _resolveAccentButtonForeground(
  Set<WidgetState> states, {
  Color disabled = _stitchMutedIcon,
}) {
  if (states.contains(WidgetState.disabled)) return disabled;
  if (states.contains(WidgetState.hovered) ||
      states.contains(WidgetState.pressed) ||
      states.contains(WidgetState.focused)) {
    return MemberChoirStyle.wine;
  }
  return MemberChoirStyle.accent;
}

ThemeData _homeTheme(BuildContext context) {
  final base = MemberChoirStyle.theme(context);
  final primaryButtonStyle =
      (base.elevatedButtonTheme.style ?? const ButtonStyle()).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _stitchSoftSurface;
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.focused)) {
            return MemberChoirStyle.wine;
          }
          return MemberChoirStyle.accent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _stitchDisabledText;
          }
          return Colors.white;
        }),
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _stitchDisabledText;
          }
          return Colors.white;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const BorderSide(color: _stitchBorder);
          }
          return BorderSide.none;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered)) {
            return Colors.white.withValues(alpha: 0.08);
          }
          return Colors.transparent;
        }),
      );

  final accentForeground = WidgetStateProperty.resolveWith<Color>(
    (states) => _resolveAccentButtonForeground(states),
  );
  final outlinedForeground = WidgetStateProperty.resolveWith<Color>(
    (states) =>
        _resolveAccentButtonForeground(states, disabled: _stitchDisabledText),
  );

  return base.copyWith(
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: MemberChoirStyle.accent)
          .copyWith(
            foregroundColor: accentForeground,
            iconColor: accentForeground,
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.pressed)) {
                return MemberChoirStyle.accent.withValues(alpha: 0.10);
              }
              return Colors.transparent;
            }),
            overlayColor: WidgetStatePropertyAll(
              MemberChoirStyle.accent.withValues(alpha: 0.08),
            ),
          ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: (base.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _stitchSoftSurface;
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed)) {
            return MemberChoirStyle.accent.withValues(alpha: 0.08);
          }
          return Colors.white;
        }),
        foregroundColor: outlinedForeground,
        iconColor: outlinedForeground,
        side: const WidgetStatePropertyAll(BorderSide(color: _stitchBorder)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: MemberChoirStyle.accent,
        hoverColor: MemberChoirStyle.accent.withValues(alpha: 0.10),
        highlightColor: MemberChoirStyle.accent.withValues(alpha: 0.12),
      ),
    ),
    listTileTheme: base.listTileTheme.copyWith(iconColor: _stitchMutedIcon),
  );
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showParticipationDialog(
    BuildContext screenContext,
    WidgetRef ref,
    LiturgicalEvent event,
  ) {
    showModalBottomSheet<void>(
      context: screenContext,
      builder: (sheetContext) => Theme(
        data: _homeTheme(screenContext),
        child: SafeArea(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarState = ref.watch(calendarNotifierProvider);
    final notificationState = ref.watch(notificationNotifierProvider);
    final practiceState = ref.watch(practiceListNotifierProvider);
    final profile = ref.watch(currentMemberProfileProvider).asData?.value;

    final memberName = profile?.fullName.trim();
    final displayName = (memberName != null && memberName.isNotEmpty)
        ? memberName
        : 'Ca viên';
    final saintName = profile?.saintName?.trim();
    final greetingName = saintName != null && saintName.isNotEmpty
        ? '$saintName ${memberName ?? ''}'.trimRight()
        : displayName;
    final avatarInitial = displayName
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();

    return Theme(
      data: _homeTheme(context),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: MemberChoirStyle.wine,
          body: SafeArea(
            bottom: false,
            child: AntiphonaryBackground(
              backgroundColor: AppColors.background,
              child: RefreshIndicator(
                color: MemberChoirStyle.accent,
                onRefresh: () async {
                  ref.invalidate(rehearsalsProvider);
                  ref.invalidate(currentMemberProfileProvider);
                  await ref
                      .read(calendarNotifierProvider.notifier)
                      .loadEvents();
                  await ref
                      .read(practiceListNotifierProvider.notifier)
                      .loadAssignments();
                  await ref
                      .read(notificationNotifierProvider.notifier)
                      .refresh();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StitchEntrance(
                        distance: 0,
                        child: _HomeGreeting(
                          name: greetingName,
                          initial: avatarInitial,
                          choirNames: profile?.choirNames,
                          avatarUrl: profile?.avatarUrl,
                          unreadCount: notificationState.unreadCount,
                          onNotifications: () => context.go('/notifications'),
                          onProfile: () => context.go('/profile'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const HomePublicNotice(),

                            // Upcoming service
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: MemberChoirStyle.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Chương trình phục vụ sắp tới',
                                          style: AppTypography.titleMedium
                                              .copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF201C21),
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (calendarState.maybeWhen(
                                  data: (events) => events.isNotEmpty,
                                  orElse: () => false,
                                )) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: MemberChoirStyle.accent.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'ƯU TIÊN',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: MemberChoirStyle.accent,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),

                            // 1. Large Upcoming Event Card (Sacred Burgundy Stitch theme)
                            calendarState.when(
                              loading: () => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: CircularProgressIndicator(
                                    color: MemberChoirStyle.accent,
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
                                child: Text(
                                  ErrorMessages.forException(
                                    e,
                                    defaultMessage:
                                        'Không thể tải lịch. Vui lòng thử lại.',
                                  ),
                                ),
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
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          color: MemberChoirStyle.accent,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Chưa có sự kiện sắp tới được công bố cho ca viên.',
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                                  color: AppColors.muted,
                                                ),
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
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
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
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        mainEvent
                                                                .seasonName
                                                                .isNotEmpty
                                                            ? mainEvent
                                                                  .seasonName
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
                                                                  FontWeight
                                                                      .bold,
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
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
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
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            const SizedBox(height: 2),
                                            Text(
                                              mainEvent.title,
                                              style: AppTypography
                                                  .headlineMedium
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
                                                color: AppColors
                                                    .surfaceContainerLow,
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
                                                        DateFormat('dd/MM/yyyy')
                                                            .format(
                                                              mainEvent.date,
                                                            ),
                                                        style: AppTypography
                                                            .bodyMedium
                                                            .copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                      const Text(' • '),
                                                      Flexible(
                                                        child: Text(
                                                          mainEvent.timeRange,
                                                          style: AppTypography
                                                              .bodySmall,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .location_on_rounded,
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
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 10),

                                            // Khung phân công cá nhân riêng biệt theo Stitch
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFBF8F5),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: _stitchBorder,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(
                                                    Icons.music_note_rounded,
                                                    size: 20,
                                                    color: _stitchBadgeGold,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Phân công cá nhân:',
                                                          style: AppTypography
                                                              .labelMedium
                                                              .copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    const Color(
                                                                      0xFF111C2D,
                                                                    ),
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          mainEvent
                                                                  .assignedVocalPart
                                                                  .isNotEmpty
                                                              ? mainEvent
                                                                    .assignedVocalPart
                                                              : 'Chưa có phân công',
                                                          style: AppTypography
                                                              .bodySmall
                                                              .copyWith(
                                                                color:
                                                                    _stitchDisabledText,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 14),

                                            // Button: Xem chi tiết phục vụ
                                            ElevatedButton(
                                              onPressed: () {
                                                context.push(
                                                  '/event-detail/${mainEvent.id}',
                                                );
                                              },
                                              child: const Text(
                                                'Xem chi tiết phục vụ',
                                                textAlign: TextAlign.center,
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
                            const SizedBox(height: 16),
                            Card(
                              color: const Color(0xFFFFFCF4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: _stitchBorder),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 2,
                                ),
                                hoverColor: MemberChoirStyle.accent.withValues(
                                  alpha: 0.04,
                                ),
                                splashColor: MemberChoirStyle.accent.withValues(
                                  alpha: 0.08,
                                ),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _stitchLibraryIconBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _stitchLibraryIconBorder,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.menu_book_outlined,
                                    size: 22,
                                    color: _stitchLibraryIconFg,
                                  ),
                                ),
                                title: Text(
                                  'Thư viện thánh ca',
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF111C2D),
                                  ),
                                ),
                                subtitle: Text(
                                  'Tìm bài hát, phổ nhạc và tài liệu học của bạn',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: _stitchDisabledText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => context.go('/music-library'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const MemberAssignmentsCard(),
                            const SizedBox(height: 8),

                            // To-do and assignments
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.assignment_turned_in_rounded,
                                      color: MemberChoirStyle.accent,
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
                                                color: MemberChoirStyle.accent
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.event_available_rounded,
                                                color: MemberChoirStyle.accent,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors
                                                    .surfaceContainerLow,
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
                                                  style:
                                                      AppTypography.labelSmall,
                                                ),
                                              ],
                                            ),
                                            Flexible(
                                              child: ElevatedButton.icon(
                                                onPressed: !nextEvent.canRespond
                                                    ? null
                                                    : () =>
                                                          _showParticipationDialog(
                                                            context,
                                                            ref,
                                                            nextEvent,
                                                          ),
                                                style: ElevatedButton.styleFrom(
                                                  minimumSize: const Size(
                                                    0,
                                                    44,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                      ),
                                                ),
                                                icon: const Icon(
                                                  Icons.reply_rounded,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  'Phản hồi',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
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
                                                color: AppColors.gold
                                                    .withValues(alpha: 0.15),
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                      color: AppColors
                                                          .statusWarning,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                  style:
                                                      AppTypography.labelSmall,
                                                ),
                                              ],
                                            ),
                                            Flexible(
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  context.push(
                                                    '/practice-detail/${pendingAssignment.id}',
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  minimumSize: const Size(
                                                    0,
                                                    44,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                      ),
                                                ),
                                                icon: const Icon(
                                                  Icons
                                                      .fiber_manual_record_rounded,
                                                  size: 14,
                                                ),
                                                label: const Text(
                                                  'Thu âm ngay',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
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
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.event_note_rounded,
                                        color: MemberChoirStyle.accent,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Buổi tập hát',
                                          style: AppTypography.titleLarge
                                              .copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
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
      ),
    );
  }
}

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting({
    required this.name,
    required this.initial,
    required this.choirNames,
    required this.avatarUrl,
    required this.unreadCount,
    required this.onNotifications,
    required this.onProfile,
  });

  final String name;
  final String initial;
  final List<String>? choirNames;
  final String? avatarUrl;
  final int unreadCount;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final headerIconButtonStyle = IconButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.transparent,
      hoverColor: Colors.white.withValues(alpha: 0.10),
      highlightColor: Colors.white.withValues(alpha: 0.14),
      focusColor: Colors.white.withValues(alpha: 0.10),
    );
    final fallback = Center(
      child: Text(
        initial,
        style: AppTypography.titleMedium.copyWith(color: Colors.white),
      ),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MemberChoirStyle.wine,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const HarmoniaLogo(size: 42),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Harmonia',
                        style: AppTypography.headlineSmall.copyWith(
                          fontFamily: MemberChoirStyle.displayFont,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'CA ĐOÀN PHỤNG VỤ',
                        style: AppTypography.labelSmall.copyWith(
                          color: MemberChoirStyle.gold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Thông báo',
                  onPressed: onNotifications,
                  style: headerIconButtonStyle,
                  icon: Badge(
                    isLabelVisible: unreadCount > 0,
                    backgroundColor: _stitchBadgeGold,
                    textColor: _stitchBadgeText,
                    offset: const Offset(4, -4),
                    label: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 24,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cá nhân',
                  onPressed: onProfile,
                  style: headerIconButtonStyle,
                  icon: Container(
                    width: 36,
                    height: 36,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: MemberChoirStyle.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.30),
                        width: 2,
                      ),
                    ),
                    child: avatarUrl?.isNotEmpty == true
                        ? Image.network(
                            avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => fallback,
                          )
                        : fallback,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chào $name',
                        style: AppTypography.titleLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Chúc một ngày phụng vụ bình an',
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFECE57),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Ca viên',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w600,
                            ),
                            softWrap: true,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (choirNames case final names?) ...[
              const SizedBox(height: 10),
              Text(
                'Ca đoàn',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                names.isEmpty ? 'Chưa tham gia ca đoàn' : names.join(' · '),
                style: AppTypography.bodyMedium.copyWith(color: Colors.white),
              ),
            ],
            const SizedBox(height: 14),
            const MemberChoirArt(
              artwork: MemberChoirArtwork.home,
              height: 176,
              radius: BorderRadius.all(Radius.circular(16)),
            ),
          ],
        ),
      ),
    );
  }
}
