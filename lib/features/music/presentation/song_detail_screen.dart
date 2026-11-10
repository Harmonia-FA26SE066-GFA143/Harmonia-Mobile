import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../../core/errors/error_messages.dart';
import '../../practice/data/practice_repository.dart';
import '../data/music_dto.dart';
import 'music_library_notifier.dart';
import 'music_tile_icon.dart';
import 'reference_audio_panel.dart';

class SongDetailScreen extends ConsumerWidget {
  const SongDetailScreen({super.key, required this.songId});
  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = songDetailProvider(songId);
    final detail = ref.watch(provider);
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Plus Jakarta Sans'),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF7F9),
        appBar: AppPageHeader(
          centerTitle: true,
          roundedBottom: true,
          gradient: const LinearGradient(
            colors: [Color(0xFFE5003E), Color(0xFFF44269)],
          ),
          titleFontFamily: 'Plus Jakarta Sans',
          title: const Text('Chi tiết bài hát'),
        ),
        body: SafeArea(
          child: detail.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ErrorMessages.forException(error),
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(provider),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),
            data: (song) {
              if (song == null) {
                return const Center(child: Text('Không tìm thấy bài hát'));
              }
              final classification = song.classification;
              final assignment = ref
                  .watch(practiceListNotifierProvider)
                  .value
                  ?.items
                  .where((row) => row.songId == songId)
                  .firstOrNull;
              final tags = [
                ...?classification?.liturgicalSeasons.map(
                  (season) => season.name,
                ),
                ...?classification?.massTypes.map((mass) => mass.name),
                ...?classification?.vocalRequirements.map(
                  (voice) => voice.skillName,
                ),
              ];
              return RefreshIndicator(
                onRefresh: () async => await ref.refresh(provider.future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    StitchEntrance(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(17),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                style: AppTypography.headlineMedium.copyWith(
                                  fontFamily: 'Playfair Display',
                                  color: const Color(0xFF111C2D),
                                ),
                              ),
                              if (song.composer.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text('Tác giả: ${song.composer}'),
                              ],
                              if (song.tone.isNotEmpty ||
                                  song.tempo.isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (song.tone.isNotEmpty)
                                      _SongFact(
                                        icon: Icons.music_note,
                                        name: 'Cung giọng',
                                        value: song.tone,
                                      ),
                                    if (song.tempo.isNotEmpty)
                                      _SongFact(
                                        icon: Icons.speed_rounded,
                                        name: 'Điệu thức & Nhịp',
                                        value: song.tempo,
                                      ),
                                  ],
                                ),
                              ],
                              if (tags.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final tag in tags.toSet())
                                      Chip(label: Text(tag)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tài liệu học cho kỹ năng của bạn',
                            style: AppTypography.titleMedium,
                          ),
                        ),
                        if (song.materials.isNotEmpty)
                          Chip(
                            backgroundColor: AppColors.primarySoft,
                            label: Text('${song.materials.length} mục'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (song.materials.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          'Chưa có tài liệu phù hợp với kỹ năng của bạn cho bài hát này.',
                        ),
                      ),
                    for (final material in song.materials)
                      _SongMaterialCard(material: material, songId: songId),
                    if (song.lyrics.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Card(
                        color: const Color(0xFFFFEFF3),
                        child: ListTile(
                          leading: const Icon(
                            Icons.tips_and_updates_outlined,
                            color: AppColors.primary,
                          ),
                          title: const Text('Ghi chú bài hát'),
                          subtitle: Text(song.lyrics),
                        ),
                      ),
                    ],
                    if (assignment != null) ...[
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        icon: const Icon(Icons.mic_none_rounded),
                        label: const Text('Vào phòng thu luyện giọng'),
                        onPressed: () => context.push(
                          Uri(
                            pathSegments: [
                              '',
                              'practice-detail',
                              assignment.id,
                            ],
                          ).toString(),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SongFact extends StatelessWidget {
  const _SongFact({
    required this.icon,
    required this.name,
    required this.value,
  });
  final IconData icon;
  final String name, value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFAF3F6),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 19),
        const SizedBox(width: 7),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.muted,
                ),
              ),
              Text(value, style: AppTypography.labelLarge),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SongMaterialCard extends StatelessWidget {
  const _SongMaterialCard({required this.material, required this.songId});
  final MusicMaterialDto material;
  final String songId;

  @override
  Widget build(BuildContext context) {
    final type = material.materialType;
    final progress = material is MusicMaterialDetailDto
        ? (material as MusicMaterialDetailDto).learningStatus
        : null;
    final audio = type == MaterialType.sampleAudio;
    void open() => context.push(
      Uri(
        pathSegments: ['', 'music-material', material.id],
        queryParameters: {'songId': songId},
      ).toString(),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: MusicTileIcon(materialType: type),
              title: Text(
                material.title,
                style: AppTypography.titleMedium.copyWith(
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
              subtitle: Text(
                [
                  type.label,
                  ?material.targetSkillName,
                  ?progress?.label,
                ].join(' • '),
              ),
            ),
            const Divider(),
            if (material.lyricsText?.trim().isNotEmpty == true)
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F6F3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  material.lyricsText!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (audio)
                  TextButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Nghe mẫu'),
                    onPressed: () => showReferenceAudio(
                      context,
                      songId: songId,
                      materialId: material.id,
                      title: material.title,
                    ),
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: Text(
                    type == MaterialType.lyrics
                        ? 'Xem toàn bộ lời hát'
                        : 'Mở tài liệu',
                  ),
                  onPressed: open,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
