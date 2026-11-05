import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/errors/error_messages.dart';
import 'participation_prompt.dart';
import '../../music/data/music_repository.dart';
import '../data/calendar_repository.dart';
import '../data/liturgical_models.dart';

class LiturgicalEventDetailScreen extends ConsumerWidget {
  final String eventId;

  const LiturgicalEventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(eventDetailProvider(eventId));
    final songListAsync = ref.watch(eventApprovedSongListProvider(eventId));
    if (detailState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết sự kiện')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (detailState.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết sự kiện')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ErrorMessages.forException(detailState.error)),
              TextButton(
                onPressed: () => ref.invalidate(eventDetailProvider(eventId)),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    final detail = detailState.requireValue;
    final event = detail.event;
    final respondedAt = detail.participation?.respondedAt?.toLocal();
    final responseAction = switch (event.participationStatus) {
      ParticipationStatus.confirmed => 'Đã xác nhận tham gia',
      ParticipationStatus.declined => 'Đã báo vắng',
      ParticipationStatus.unsure => 'Đã chọn chưa chắc chắn',
      ParticipationStatus.unknown ||
      ParticipationStatus.invited => 'Đã phản hồi',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết phụng vụ'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(eventDetailProvider(eventId));
              ref.invalidate(eventApprovedSongListProvider(eventId));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Event Hero Banner Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (event.seasonName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.statusSuccessSoft,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                event.seasonName,
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.statusSuccess,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              event.assignedVocalPart.isEmpty
                                  ? 'Chưa có thông tin phân công'
                                  : 'Phân công: ${event.assignedVocalPart}',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        event.title,
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat(
                              'EEEE, dd/MM/yyyy',
                              'vi',
                            ).format(event.date),
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            event.timeRange,
                            style: AppTypography.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 8),
                          Text(event.location, style: AppTypography.bodyMedium),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (detail.specialRequirements?.isNotEmpty == true)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hướng dẫn phục vụ',
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(detail.specialRequirements!),
                      ],
                    ),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phân công của bạn',
                        style: AppTypography.titleMedium,
                      ),
                      if (detail.assignments.isEmpty)
                        const Text('Chưa có phân công được công bố.'),
                      for (final assignment in detail.assignments)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.assignment_ind),
                          title: Text(assignment.skillName),
                          subtitle: assignment.songTitle == null
                              ? null
                              : Text(assignment.songTitle!),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Participation response
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Xác nhận tham gia',
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: _participationColor(
                              event.participationStatus,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            event.participationStatus.label,
                            style: AppTypography.labelSmall.copyWith(
                              color: _participationColor(
                                event.participationStatus,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ParticipationOption(
                              label: 'Xác nhận',
                              status: ParticipationStatus.confirmed,
                              selected:
                                  event.participationStatus ==
                                  ParticipationStatus.confirmed,
                              enabled: event.canRespond,
                              onPressed: () => showParticipationPrompt(
                                context,
                                ref,
                                event,
                                ParticipationStatus.confirmed,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _ParticipationOption(
                              label: 'Báo vắng',
                              status: ParticipationStatus.declined,
                              selected:
                                  event.participationStatus ==
                                  ParticipationStatus.declined,
                              enabled: event.canRespond,
                              onPressed: () => showParticipationPrompt(
                                context,
                                ref,
                                event,
                                ParticipationStatus.declined,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _ParticipationOption(
                              label: 'Chưa chắc chắn',
                              status: ParticipationStatus.unsure,
                              selected:
                                  event.participationStatus ==
                                  ParticipationStatus.unsure,
                              enabled: event.canRespond,
                              onPressed: () => showParticipationPrompt(
                                context,
                                ref,
                                event,
                                ParticipationStatus.unsure,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (respondedAt != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              size: 15,
                              color: _participationColor(
                                event.participationStatus,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$responseAction lúc ${DateFormat('HH:mm').format(respondedAt)} ngày ${DateFormat('dd/MM/yyyy').format(respondedAt)}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (!event.canRespond &&
                          event.cannotRespondReason != null &&
                          event.cannotRespondReason !=
                              'EVENT_PARTICIPATION_ALREADY_RESPONDED') ...[
                        const SizedBox(height: 8),
                        Text(
                          participationStatusMessage(event),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Lịch trình tập hát',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${detail.rehearsals.length} BUỔI TẬP',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (detail.rehearsals.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('Chưa có lịch tập hát được công bố.'),
                        )
                      else
                        for (final item in detail.rehearsals)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Material(
                              color: AppColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => context.push(
                                  '/rehearsal/${Uri.encodeComponent(item.rehearsal.id)}',
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.timer_outlined,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.rehearsal.title,
                                              style: AppTypography.bodyMedium
                                                  .copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${DateFormat('dd/MM/yyyy').format(item.rehearsal.date)} • ${item.rehearsal.timeRange}',
                                              style: AppTypography.bodySmall
                                                  .copyWith(
                                                    color: AppColors.muted,
                                                  ),
                                            ),
                                            if (item
                                                .rehearsal
                                                .location
                                                .isNotEmpty)
                                              Text(
                                                item.rehearsal.location,
                                                style: AppTypography.bodySmall
                                                    .copyWith(
                                                      color: AppColors.muted,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            item.rehearsal.attendanceStatus,
                                            textAlign: TextAlign.center,
                                            style: AppTypography.labelSmall
                                                .copyWith(
                                                  color:
                                                      item
                                                              .rehearsal
                                                              .attendanceStatus ==
                                                          'Có mặt'
                                                      ? AppColors.statusSuccess
                                                      : AppColors.muted,
                                                ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Approved Song List Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Danh sách bài hát phụng vụ',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  songListAsync.when(
                    data: (songList) {
                      final hasApproved = songList != null;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: hasApproved
                              ? AppColors.statusSuccessSoft
                              : AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          hasApproved ? 'Đã phê duyệt' : 'Chưa có danh sách',
                          style: AppTypography.labelSmall.copyWith(
                            color: hasApproved
                                ? AppColors.statusSuccess
                                : AppColors.muted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                    loading: () => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Đang tải...',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    error: (_, _) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusDangerSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Lỗi tải',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.statusDanger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              songListAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                error: (err, _) => Card(
                  color: AppColors.statusDangerSoft,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.statusDanger,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Không thể tải danh sách bài hát',
                              style: TextStyle(
                                color: AppColors.statusDanger,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Thử lại'),
                          onPressed: () => ref.refresh(
                            eventApprovedSongListProvider(eventId),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (songList) {
                  if (songList == null) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'Chưa có danh sách bài hát được duyệt cho sự kiện này',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ),
                    );
                  }

                  if (songList.items.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'Danh sách bài hát đã được duyệt nhưng chưa có bài hát nào',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ),
                    );
                  }

                  final items = List.of(songList.items)
                    ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

                  return Column(
                    children: items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final isGoldPair = (index ~/ 2).isOdd;
                      final ordinalColor = isGoldPair
                          ? AppColors.tertiary
                          : AppColors.navyPrimary;
                      final ordinalBackground = isGoldPair
                          ? AppColors.goldSoft
                          : AppColors.navyPrimary.withValues(alpha: 0.08);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: ordinalBackground,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: AppTypography.labelMedium.copyWith(
                                  color: ordinalColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          title: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.slotName.isNotEmpty
                                    ? item.slotName.toUpperCase()
                                    : 'BÀI HÁT PHỤNG VỤ',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.tertiary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.songTitle,
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          subtitle:
                              item.note != null && item.note!.trim().isNotEmpty
                              ? Text(
                                  'Ghi chú: ${item.note}',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.muted,
                                  ),
                                )
                              : null,
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.muted,
                          ),
                          onTap: () {
                            context.push('/song-detail/${item.songId}');
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _participationColor(ParticipationStatus status) => switch (status) {
  ParticipationStatus.confirmed => AppColors.statusSuccess,
  ParticipationStatus.declined => AppColors.statusDanger,
  ParticipationStatus.unsure => AppColors.statusWarning,
  ParticipationStatus.unknown || ParticipationStatus.invited => AppColors.muted,
};

class _ParticipationOption extends StatelessWidget {
  const _ParticipationOption({
    required this.label,
    required this.status,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final ParticipationStatus status;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = _participationColor(status);
    final softColor = switch (status) {
      ParticipationStatus.confirmed => AppColors.statusSuccessSoft,
      ParticipationStatus.declined => AppColors.statusDangerSoft,
      ParticipationStatus.unsure => AppColors.statusWarningSoft,
      ParticipationStatus.unknown ||
      ParticipationStatus.invited => AppColors.surface,
    };

    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        backgroundColor: selected ? softColor : AppColors.surface,
        foregroundColor: selected ? color : AppColors.onSurface,
        disabledForegroundColor: selected ? color : AppColors.muted,
        side: BorderSide(
          color: selected ? color : AppColors.border,
          width: selected ? 1.4 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (selected) ...[
            Icon(Icons.check_rounded, size: 13, color: color),
            const SizedBox(width: 2),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              softWrap: true,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
