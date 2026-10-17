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
              if (detail.rehearsals.isNotEmpty)
                Card(
                  child: Column(
                    children: [
                      for (final item in detail.rehearsals)
                        ListTile(
                          title: Text(item.rehearsal.title),
                          subtitle: Text(
                            '${DateFormat('dd/MM/yyyy').format(item.rehearsal.date)} • ${item.rehearsal.timeRange}\n${item.rehearsal.attendanceStatus}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                            '/rehearsal/${Uri.encodeComponent(item.rehearsal.id)}',
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // Participation Confirmation Box
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.how_to_reg_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Xác nhận tham gia',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        participationStatusMessage(event),
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    event.participationStatus ==
                                        ParticipationStatus.confirmed
                                    ? AppColors.statusSuccessSoft
                                    : null,
                                side: BorderSide(
                                  color:
                                      event.participationStatus ==
                                          ParticipationStatus.confirmed
                                      ? AppColors.statusSuccess
                                      : AppColors.border,
                                ),
                              ),
                              onPressed: !event.canRespond
                                  ? null
                                  : () => showParticipationPrompt(
                                      context,
                                      ref,
                                      event,
                                      ParticipationStatus.confirmed,
                                    ),
                              child: Text(
                                'Có mặt',
                                style: TextStyle(
                                  color:
                                      event.participationStatus ==
                                          ParticipationStatus.confirmed
                                      ? AppColors.statusSuccess
                                      : AppColors.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    event.participationStatus ==
                                        ParticipationStatus.declined
                                    ? AppColors.statusDangerSoft
                                    : null,
                                side: BorderSide(
                                  color:
                                      event.participationStatus ==
                                          ParticipationStatus.declined
                                      ? AppColors.statusDanger
                                      : AppColors.border,
                                ),
                              ),
                              onPressed: !event.canRespond
                                  ? null
                                  : () => showParticipationPrompt(
                                      context,
                                      ref,
                                      event,
                                      ParticipationStatus.declined,
                                    ),
                              child: Text(
                                'Vắng mặt',
                                style: TextStyle(
                                  color:
                                      event.participationStatus ==
                                          ParticipationStatus.declined
                                      ? AppColors.statusDanger
                                      : AppColors.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Trạng thái: ${event.participationStatus.label}',
                        style: AppTypography.bodySmall,
                      ),
                      TextButton(
                        onPressed: event.canRespond
                            ? () => showParticipationPrompt(
                                context,
                                ref,
                                event,
                                ParticipationStatus.unsure,
                              )
                            : null,
                        child: const Text('Chưa chắc chắn'),
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
                    children: items.map((item) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(
                            item.songTitle,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                item.slotName.isNotEmpty
                                    ? item.slotName
                                    : 'Bài hát phụng vụ',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (item.note != null &&
                                  item.note!.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Ghi chú: ${item.note}',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
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
