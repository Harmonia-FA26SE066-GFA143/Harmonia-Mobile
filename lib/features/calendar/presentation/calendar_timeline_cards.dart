import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/errors/error_messages.dart';
import '../../music/data/music_repository.dart';
import '../data/calendar_member_dto.dart';
import '../data/calendar_repository.dart';
import '../data/liturgical_models.dart';

const _softSurface = Color(0xFFF1F1F3);

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
        child: _CardError(
          message: 'Thông tin chi tiết không khớp với sự kiện này.',
          retryLabel: 'Thử lại chi tiết lễ',
          onRetry: retry,
        ),
      );
    }
    final current = detail?.event ?? event;
    return _CalendarSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!attendanceOnly) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!loading && current.seasonName.isNotEmpty)
                  _StatusBadge(
                    label: current.seasonName,
                    color: _seasonColor(current.seasonName),
                    icon: Icons.circle,
                    iconSize: 6,
                  )
                else
                  Text(
                    current.categoryName.isNotEmpty
                        ? current.categoryName.toUpperCase()
                        : 'PHỤNG VỤ',
                    style: AppTypography.labelSmall,
                  ),
                if (!loading &&
                    current.participationStatus != ParticipationStatus.unknown)
                  _ParticipationBadge(status: current.participationStatus),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(current.title, style: _eventTitle),
          if (current.location.isNotEmpty) ...[
            const SizedBox(height: 6),
            _Metadata(icon: Icons.church_outlined, text: current.location),
          ],
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              minHeight: 2,
              semanticsLabel: 'Đang tải chi tiết lễ',
            ),
          ] else ...[
            if (!attendanceOnly && current.assignedVocalPart.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoPanel(
                icon: Icons.record_voice_over_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phân công giọng hát:',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      current.assignedVocalPart,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _CardFooter(
              attendance: 'Chưa có thông tin điểm danh',
              onOpen: () => context.push(
                '/event-detail/${Uri.encodeComponent(event.id)}',
              ),
            ),
          ],
        ],
      ),
    );
  }
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
        child: _CardError(
          message: 'Thông tin chi tiết không khớp với buổi tập này.',
          retryLabel: 'Thử lại buổi tập',
          onRetry: retry,
        ),
      );
    }
    final current = detail?.rehearsal ?? rehearsal;
    return _CalendarSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!attendanceOnly) ...[
            Text('LUYỆN TẬP THÁNH NHẠC', style: AppTypography.labelSmall),
            const SizedBox(height: 8),
          ],
          Text(current.title, style: _eventTitle),
          if (current.location.isNotEmpty) ...[
            const SizedBox(height: 6),
            _Metadata(icon: Icons.location_on_outlined, text: current.location),
          ],
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              minHeight: 2,
              semanticsLabel: 'Đang tải chi tiết buổi tập',
            ),
          ] else ...[
            if (!attendanceOnly && detail!.songs.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoPanel(
                icon: Icons.music_note_outlined,
                child: Text.rich(
                  TextSpan(
                    text: 'Chuẩn bị: ',
                    style: AppTypography.bodySmall,
                    children: [
                      TextSpan(
                        text: detail.songs.map((song) => song.title).join(', '),
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            _CardFooter(
              attendance: MemberRehearsalDetail.attendanceLabel(
                detail!.myAttendanceStatus,
              ),
              status: detail.myAttendanceStatus,
              onOpen: () => context.push(
                '/rehearsal/${Uri.encodeComponent(rehearsal.id)}',
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
                          color: _softSurface,
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

TextStyle get _eventTitle => AppTypography.headlineSmall.copyWith(fontSize: 17);

class _CalendarSurface extends StatelessWidget {
  final Widget child;
  final bool accent;

  const _CalendarSurface({required this.child, this.accent = true});

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    color: AppColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: accent
            ? const Border(left: BorderSide(color: AppColors.primary, width: 4))
            : null,
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

class _Metadata extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Metadata({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: AppColors.muted),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: AppTypography.bodyMedium)),
    ],
  );
}

class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final Widget child;

  const _InfoPanel({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _softSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    ),
  );
}

class _CardFooter extends StatelessWidget {
  final String attendance;
  final String? status;
  final VoidCallback onOpen;

  const _CardFooter({
    required this.attendance,
    required this.onOpen,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Present' => AppColors.statusSuccess,
      'Absent' => AppColors.statusDanger,
      'Late' || 'Excused' => AppColors.statusWarning,
      _ => AppColors.muted,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Icon(Icons.circle, size: 7, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'Điểm danh: ',
                    style: AppTypography.bodySmall,
                    children: [
                      TextSpan(
                        text: attendance,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.body,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Xem chi tiết',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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
      const Icon(Icons.error_outline_rounded, color: AppColors.statusDanger),
      const SizedBox(height: 8),
      Text(
        message ?? ErrorMessages.forException(error),
        style: AppTypography.bodyMedium,
      ),
      const SizedBox(height: 4),
      TextButton(
        onPressed: onRetry,
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
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
      ParticipationStatus.confirmed => AppColors.statusSuccess,
      ParticipationStatus.declined => AppColors.statusDanger,
      _ => AppColors.statusWarning,
    },
    icon: status == ParticipationStatus.confirmed
        ? Icons.check_circle_outline_rounded
        : Icons.info_outline_rounded,
  );
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final double iconSize;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
    this.iconSize = 13,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text.rich(
      TextSpan(
        style: AppTypography.labelSmall.copyWith(color: color),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(icon, size: iconSize, color: color),
            ),
          ),
          TextSpan(text: label),
        ],
      ),
    ),
  );
}

Color _seasonColor(String name) {
  final season = name.toLowerCase();
  if (season.contains('vọng') || season.contains('chay')) {
    return AppColors.seasonAdventLent;
  }
  if (season.contains('phục sinh') || season.contains('giáng sinh')) {
    return AppColors.seasonEasterChristmas;
  }
  if (season.contains('tử đạo') || season.contains('hiện xuống')) {
    return AppColors.seasonPentecostMartyrs;
  }
  return season.contains('thường niên')
      ? AppColors.seasonOrdinary
      : AppColors.muted;
}
