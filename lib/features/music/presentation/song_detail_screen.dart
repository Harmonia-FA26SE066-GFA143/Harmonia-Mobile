import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/errors/error_messages.dart';
import '../data/music_dto.dart';
import 'music_library_notifier.dart';

class SongDetailScreen extends ConsumerWidget {
  final String songId;
  const SongDetailScreen({super.key, required this.songId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(songDetailProvider(songId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chi tiết bài hát')),
      body: SafeArea(
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(ErrorMessages.forException(error)),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(songDetailProvider(songId)),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
          data: (song) {
            if (song == null) {
              return const Center(child: Text('Không tìm thấy bài hát'));
            }
            final classification = song.classification;
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(songDetailProvider(songId));
                await ref.read(songDetailProvider(songId).future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: AppColors.primary),
                          ),
                          if (song.composer.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Tác giả: ${song.composer}'),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (song.tone.isNotEmpty)
                                Chip(label: Text('Giọng: ${song.tone}')),
                              if (song.tempo.isNotEmpty)
                                Chip(label: Text('Tempo: ${song.tempo}')),
                              if (classification != null) ...[
                                for (final season
                                    in classification.liturgicalSeasons)
                                  Chip(label: Text(season.name)),
                                for (final mass in classification.massTypes)
                                  Chip(label: Text(mass.name)),
                                for (final voice
                                    in classification.vocalRequirements)
                                  Chip(label: Text(voice.skillName)),
                              ],
                            ],
                          ),
                          if (song.lyrics.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Ghi chú',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(song.lyrics),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tài liệu học của tôi',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (song.materials.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Chưa có tài liệu phù hợp với kỹ năng của bạn cho bài hát này.',
                      ),
                    ),
                  for (final material in song.materials)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          material.materialType == MaterialType.sampleAudio
                              ? Icons.audiotrack
                              : Icons.description,
                          color: AppColors.primary,
                        ),
                        title: Text(material.title),
                        subtitle: Text(
                          [
                            material.materialType.label,
                            if (material.targetSkillName != null)
                              material.targetSkillName!,
                            if (material is MusicMaterialDetailDto)
                              material.learningStatus.label,
                          ].join(' • '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          Uri(
                            path: '/music-material/${material.id}',
                            queryParameters: {'songId': songId},
                          ).toString(),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
