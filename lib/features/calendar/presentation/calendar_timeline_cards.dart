import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../core/errors/error_messages.dart';
import '../../music/data/music_repository.dart';
import '../data/calendar_member_dto.dart';
import '../data/calendar_repository.dart';
import '../data/liturgical_models.dart';
import 'participation_prompt.dart';

const _stitchSurfaceBg = Color(0xFFFAF8F5);
const _stitchBorder = Color(0xFFE6E1D8);
const _stitchInsetBorder = Color(0x99E6E1D8);
const _stitchTextDark = Color(0xFF201C21);
const _stitchTextMuted = Color(0xFF76767E);
const _stitchTextBody = Color(0xFF45464D);
const _stitchGold = Color(0xFFFECE57);
const _stitchAmberText = Color(0xFF775A00);
const _stitchSuccessGreen = Color(0xFF2E7D32);
const _stitchDangerRed = Color(0xFFBA1A1A);

class CalendarEventCard extends ConsumerWidget {
  final LiturgicalEvent event;
  final bool attendanceOnly;

  const CalendarEventCard({
    super.key,
    required this.event,
    this.attendanceOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(eventDetailProvider(event.id));
    void retry() => ref.invalidate(eventDetailProvider(event.id));
    if (state.hasError) {
      return _CalendarSurface(
        accent: false,
        child: _CardError(
          error: state.error,
          retryLabel: 'Thử lại chi tiết lễ',
          onRetry: retry,
        ),
      );
    }
    final loading = state.isLoading;
    final detail = loading ? null : state.asData?.value;
    if (!loading && detail?.event.id != event.id) {
      return _CalendarSurface(
        accent: false,
        child: _CardError(
          message: 'Thông tin chi tiết không khớp với sự kiện này.',
          retryLabel: 'Thử lại chi tiết lễ',
          onRetry: retry,
        ),
      );
    }
    final current = detail?.event ?? event;
    final specialRequirements = detail?.specialRequirements?.trim() ?? '';
    final hasMetadata =
        current.location.isNotEmpty ||
        (!attendanceOnly && current.assignedVocalPart.isNotEmpty) ||
        (!attendanceOnly && specialRequirements.isNotEmpty);

    return _CalendarSurface(
      accent: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!attendanceOnly) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: MemberChoirStyle.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        size: 13,
                        color: MemberChoirStyle.accent,
                      ),
                      Flexible(
                        child: Text(
                          current.categoryName.isNotEmpty
                              ? current.categoryName.toUpperCase()
                              : 'PHỤNG VỤ',
                          style: AppTypography.labelSmall.copyWith(
                            color: MemberChoirStyle.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!loading &&
                    current.participationStatus != ParticipationStatus.unknown)
                  _ParticipationBadge(status: current.participationStatus),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(current.title, style: _eventTitle),
          if (hasMetadata) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _stitchSurfaceBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _stitchInsetBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [
                  if (current.location.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: MemberChoirStyle.accent,
                          ),
                        ),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: AppTypography.bodySmall.copyWith(
                                color: _stitchTextBody,
                                fontSize: 13,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Địa điểm: ',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(text: current.location),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!attendanceOnly && current.assignedVocalPart.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.record_voice_over_outlined,
                            size: 15,
                            color: _stitchAmberText,
                          ),
                        ),
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Nhiệm vụ:',
                                style: AppTypography.bodySmall.copyWith(
                                  color: _stitchTextBody,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                current.assignedVocalPart,
                                style: AppTypography.bodySmall.copyWith(
                                  color: _stitchTextDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (!attendanceOnly && specialRequirements.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.sticky_note_2_outlined,
                            size: 15,
                            color: _stitchTextMuted,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Ghi chú: $specialRequirements',
                            style: AppTypography.bodySmall.copyWith(
                              color: _stitchTextBody,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              minHeight: 2,
              color: MemberChoirStyle.wine,
              backgroundColor: Color(0xFFE7EEFF),
              semanticsLabel: 'Đang tải chi tiết lễ',
            ),
          ] else ...[
            if (current.canRespond) _EventParticipationActions(event: current),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0x33C6C6CE)),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => context.push(
                  '/event-detail/${Uri.encodeComponent(event.id)}',
                ),
                style:
                    TextButton.styleFrom(
                      foregroundColor: MemberChoirStyle.accent,
                      minimumSize: const Size(44, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ).copyWith(
                      overlayColor: WidgetStatePropertyAll(
                        MemberChoirStyle.accent.withValues(alpha: 0.08),
                      ),
                    ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    Flexible(
                      child: Text(
                        'Xem chi tiết phụng vụ & bài hát',
                        textAlign: TextAlign.right,
                        style: AppTypography.labelMedium.copyWith(
                          color: MemberChoirStyle.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: MemberChoirStyle.accent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventParticipationActions extends ConsumerWidget {
  final LiturgicalEvent event;

  const _EventParticipationActions({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (label, status) in [
          ('Có mặt', ParticipationStatus.confirmed),
          ('Vắng', ParticipationStatus.declined),
          ('Chưa chắc chắn', ParticipationStatus.unsure),
        ])
          TextButton(
            onPressed: () =>
                showParticipationPrompt(context, ref, event, status),
            style: TextButton.styleFrom(
              foregroundColor: switch (status) {
                ParticipationStatus.unsure => _stitchAmberText,
                ParticipationStatus.declined => _stitchDangerRed,
                _ => MemberChoirStyle.wine,
              },
              backgroundColor: switch (status) {
                ParticipationStatus.unsure => _stitchGold.withValues(
                  alpha: 0.16,
                ),
                ParticipationStatus.declined => _stitchDangerRed.withValues(
                  alpha: 0.08,
                ),
                _ => MemberChoirStyle.wine.withValues(alpha: 0.08),
              },
              minimumSize: const Size(44, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    ),
  );
}

class CalendarRehearsalCard extends ConsumerWidget {
  final RehearsalSession rehearsal;
  final bool attendanceOnly;

  const CalendarRehearsalCard({
    super.key,
    required this.rehearsal,
    this.attendanceOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rehearsalDetailProvider(rehearsal.id));
    void retry() => ref.invalidate(rehearsalDetailProvider(rehearsal.id));
    if (state.hasError) {
      return _CalendarSurface(
        accent: false,
        child: _CardError(
          error: state.error,
          retryLabel: 'Thử lại buổi tập',
          onRetry: retry,
        ),
      );
    }
    final loading = state.isLoading;
    final detail = loading ? null : state.asData?.value;
    if (!loading && detail?.rehearsal.id != rehearsal.id) {
      return _CalendarSurface(
        accent: false,
        child: _CardError(
          message: 'Thông tin chi tiết không khớp với buổi tập này.',
          retryLabel: 'Thử lại buổi tập',
          onRetry: retry,
        ),
      );
    }
    final current = detail?.rehearsal ?? rehearsal;
    final noteText = current.note?.trim() ?? '';
    final hasSongs =
        !attendanceOnly && detail != null && detail.songs.isNotEmpty;
    final hasMetadata =
        current.location.isNotEmpty || noteText.isNotEmpty || hasSongs;

    return _CalendarSurface(
      accent: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!attendanceOnly) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _stitchAmberText.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 5,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _stitchGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          'LỊCH TẬP DƯỢT',
                          style: AppTypography.labelSmall.copyWith(
                            color: _stitchAmberText,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!loading)
                  _AttendanceBadge(
                    label: MemberRehearsalDetail.attendanceLabel(
                      detail!.myAttendanceStatus,
                    ),
                    status: detail.myAttendanceStatus,
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(current.title, style: _eventTitle),
          if (hasMetadata) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _stitchSurfaceBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _stitchInsetBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [
                  if (current.location.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.meeting_room_outlined,
                            size: 15,
                            color: _stitchTextMuted,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            current.location,
                            style: AppTypography.bodySmall.copyWith(
                              color: _stitchTextBody,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (noteText.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.notes_rounded,
                            size: 15,
                            color: MemberChoirStyle.accent,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Ghi chú: $noteText',
                            style: AppTypography.bodySmall.copyWith(
                              color: _stitchTextBody,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (hasSongs)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.music_note_outlined,
                            size: 15,
                            color: _stitchAmberText,
                          ),
                        ),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'Chuẩn bị: ',
                              style: AppTypography.bodySmall.copyWith(
                                color: _stitchTextBody,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              children: [
                                TextSpan(
                                  text: detail.songs
                                      .map((song) => song.title)
                                      .join(', '),
                                  style: AppTypography.bodySmall.copyWith(
                                    color: _stitchTextDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              minHeight: 2,
              color: MemberChoirStyle.wine,
              backgroundColor: Color(0xFFE7EEFF),
              semanticsLabel: 'Đang tải chi tiết buổi tập',
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0x33C6C6CE)),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ElevatedButton(
                onPressed: () => context.push(
                  '/rehearsal/${Uri.encodeComponent(rehearsal.id)}',
                ),
                style:
                    ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: MemberChoirStyle.wine,
                      elevation: 0,
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ).copyWith(
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.pressed)) {
                          return MemberChoirStyle.accent;
                        }
                        return MemberChoirStyle.wine;
                      }),
                    ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: const [
                    Icon(Icons.queue_music_rounded, size: 15),
                    Flexible(
                      child: Text(
                        'Xem chi tiết',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, size: 15),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CalendarApprovedSongs extends ConsumerWidget {
  final LiturgicalEvent event;

  const CalendarApprovedSongs({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(eventDetailProvider(event.id));
    if (detail.hasError) {
      return const SizedBox.shrink();
    }
    if (detail.isLoading) {
      return const SizedBox.shrink();
    }
    if (detail.asData?.value.event.id != event.id) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(eventApprovedSongListProvider(event.id));
    Widget content;
    if (state.hasError) {
      content = _CardError(
        error: state.error,
        retryLabel: 'Thử lại bộ lễ',
        onRetry: () => ref.invalidate(eventApprovedSongListProvider(event.id)),
      );
    } else if (state.isLoading) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(
          minHeight: 2,
          semanticsLabel: 'Đang tải bộ lễ đã duyệt',
        ),
      );
    } else {
      final songList = state.asData?.value;
      if (songList == null) {
        content = Text(
          'Chưa có danh sách bài hát được duyệt cho sự kiện này.',
          style: AppTypography.bodyMedium,
        );
      } else if (songList.eventId != event.id) {
        content = _CardError(
          message: 'Danh sách bài hát không thuộc sự kiện này.',
          retryLabel: 'Thử lại bộ lễ',
          onRetry: () =>
              ref.invalidate(eventApprovedSongListProvider(event.id)),
        );
      } else if (songList.status != 'Approved') {
        content = Text(
          'Danh sách bài hát chưa được duyệt.',
          style: AppTypography.bodyMedium,
        );
      } else if (songList.items.isEmpty) {
        content = Text(
          'Bộ lễ đã được duyệt nhưng chưa có bài hát.',
          style: AppTypography.bodyMedium,
        );
      } else {
        final items = List.of(songList.items)
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        content = Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) const Divider(height: 1),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.push(
                  '/song-detail/${Uri.encodeComponent(items[index].songId)}',
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: MemberChoirStyle.paper,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.body,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                            if (items[index].slotName.isNotEmpty)
                              items[index].slotName,
                            items[index].songTitle,
                          ].join(': '),
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      }
    }
    return _CalendarSurface(
      accent: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.queue_music_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Bộ lễ đã duyệt', style: AppTypography.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Cho: ${detail.requireValue.event.title}',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }
}

TextStyle get _eventTitle => AppTypography.titleMedium.copyWith(
  color: _stitchTextDark,
  fontSize: 16,
  fontWeight: FontWeight.w700,
  height: 1.3,
);

class _CalendarSurface extends StatelessWidget {
  final Widget child;
  final bool accent;

  const _CalendarSurface({required this.child, this.accent = true});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _stitchBorder),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A1B2541),
          blurRadius: 20,
          spreadRadius: -2,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: accent
              ? const Border(
                  left: BorderSide(color: MemberChoirStyle.accent, width: 3),
                )
              : null,
        ),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

class _CardError extends StatelessWidget {
  final Object? error;
  final String? message;
  final String retryLabel;
  final VoidCallback onRetry;

  const _CardError({
    this.error,
    this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.error_outline_rounded, color: _stitchDangerRed),
      const SizedBox(height: 8),
      Text(
        message ?? ErrorMessages.forException(error),
        style: AppTypography.bodyMedium.copyWith(color: _stitchTextBody),
      ),
      const SizedBox(height: 4),
      TextButton(
        onPressed: onRetry,
        style: TextButton.styleFrom(
          foregroundColor: MemberChoirStyle.wine,
          minimumSize: const Size(48, 44),
        ),
        child: Text(retryLabel),
      ),
    ],
  );
}

class _ParticipationBadge extends StatelessWidget {
  final ParticipationStatus status;

  const _ParticipationBadge({required this.status});

  @override
  Widget build(BuildContext context) => _StatusBadge(
    label: status == ParticipationStatus.declined
        ? 'Không tham gia'
        : status.label,
    color: switch (status) {
      ParticipationStatus.confirmed => _stitchSuccessGreen,
      ParticipationStatus.declined => _stitchDangerRed,
      _ => _stitchAmberText,
    },
    icon: status == ParticipationStatus.confirmed
        ? Icons.check_circle_outline_rounded
        : Icons.info_outline_rounded,
  );
}

class _AttendanceBadge extends StatelessWidget {
  final String label;
  final String? status;

  const _AttendanceBadge({required this.label, this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      'Present' => (_stitchSuccessGreen, Icons.check_circle_outline_rounded),
      'Absent' => (_stitchDangerRed, Icons.cancel_outlined),
      'Late' || 'Excused' => (_stitchAmberText, Icons.schedule_rounded),
      _ => (_stitchTextMuted, Icons.schedule_rounded),
    };
    return _StatusBadge(label: label, color: color, icon: icon);
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Icon(icon, size: 13, color: color),
        Flexible(
          child: Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

Color calendarSeasonColor(String name) {
  final season = name.toLowerCase();
  if (season.contains('vọng') ||
      season.contains('chay') ||
      season.contains('advent') ||
      season.contains('lent')) {
    return AppColors.seasonAdventLent;
  }
  if (season.contains('phục sinh') ||
      season.contains('giáng sinh') ||
      season.contains('easter') ||
      season.contains('christmas')) {
    return AppColors.seasonEasterChristmas;
  }
  if (season.contains('tử đạo') ||
      season.contains('hiện xuống') ||
      season.contains('pentecost') ||
      season.contains('martyr')) {
    return AppColors.seasonPentecostMartyrs;
  }
  return (season.contains('thường niên') || season.contains('ordinary'))
      ? _stitchSuccessGreen
      : _stitchTextMuted;
}
