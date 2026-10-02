import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../music/data/music_repository.dart';
import '../../music/data/song_models.dart';
import '../data/calendar_repository.dart';
import '../data/liturgical_models.dart';

class LiturgicalEventDetailScreen extends ConsumerWidget {
  final String eventId;

  const LiturgicalEventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarState = ref.watch(calendarNotifierProvider);
    final musicRepo = ref.watch(musicRepositoryProvider);

    final event = calendarState.value?.firstWhere(
      (e) => e.id == eventId,
      orElse: () => calendarState.value!.first,
    );

    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết sự kiện')),
        body: const Center(child: Text('Không tìm thấy sự kiện')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chi tiết phụng vụ')),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
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
                              'Phân công: ${event.assignedVocalPart}',
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
                        'Vui lòng xác nhận để Ca trưởng sắp xếp phân công bè và bài tập.',
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
                              onPressed: () {
                                ref
                                    .read(calendarNotifierProvider.notifier)
                                    .setParticipation(
                                      event.id,
                                      ParticipationStatus.confirmed,
                                    );
                              },
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
                              onPressed: () {
                                ref
                                    .read(calendarNotifierProvider.notifier)
                                    .setParticipation(
                                      event.id,
                                      ParticipationStatus.declined,
                                    );
                              },
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusSuccessSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Đã phê duyệt',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.statusSuccess,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              FutureBuilder<List<SongListItem>>(
                future: musicRepo.getSongListForEvent(eventId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  final songs = snapshot.data ?? [];
                  if (songs.isEmpty) {
                    return const Center(child: Text('Chưa có bài hát'));
                  }

                  return Column(
                    children: songs.map((song) {
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
                            song.title,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${song.slotName} • ${song.composer}',
                                style: AppTypography.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tone: ${song.tone}',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.muted,
                          ),
                          onTap: () {
                            context.push('/song-detail/${song.id}');
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
