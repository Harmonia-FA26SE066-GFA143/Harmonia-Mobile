import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../data/music_repository.dart';
import '../data/song_models.dart';

class SongDetailScreen extends ConsumerStatefulWidget {
  final String songId;

  const SongDetailScreen({super.key, required this.songId});

  @override
  ConsumerState<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends ConsumerState<SongDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isPlaying = false;
  double _currentAudioPosition = 24.0;
  final double _totalAudioDuration = 185.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDuration(double seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds.toInt() % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _showSheetMusicPreview(SongListItem song) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text(song.title),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {},
                ),
              ],
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 72,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Bản nhạc phổ: ${song.title}',
                          style: AppTypography.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tác giả: ${song.composer} • Tone ${song.tone}',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final musicRepo = ref.watch(musicRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chi tiết bài hát')),
      body: FutureBuilder<SongListItem?>(
        future: musicRepo.getSongDetail(widget.songId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final song = snapshot.data;
          if (song == null) {
            return const Center(child: Text('Không tìm thấy bài hát'));
          }

          return SafeArea(
            child: Column(
              children: [
                // Song Header
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              song.slotName,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Learning Status Dropdown/Menu
                          PopupMenuButton<LearningStatus>(
                            initialValue: song.learningStatus,
                            onSelected: (status) {
                              musicRepo.updateLearningStatus(song.id, status);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    song.learningStatus.label,
                                    style: AppTypography.labelSmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          song.learningStatus ==
                                              LearningStatus.learned
                                          ? AppColors.statusSuccess
                                          : AppColors.body,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_drop_down, size: 18),
                                ],
                              ),
                            ),
                            itemBuilder: (context) => [
                              for (final status in LearningStatus.values)
                                PopupMenuItem(
                                  value: status,
                                  child: Text(status.label),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        song.title,
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tác giả: ${song.composer}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.body,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Tone: ${song.tone}',
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Tempo: ${song.tempo}',
                              style: AppTypography.labelSmall,
                            ),
                          ),
                        ],
                      ),
                      if (song.classification != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final season
                                in song.classification!.liturgicalSeasons)
                              Chip(
                                label: Text(
                                  season.name,
                                  style: AppTypography.labelSmall,
                                ),
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                side: BorderSide.none,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            for (final mass in song.classification!.massTypes)
                              Chip(
                                label: Text(
                                  mass.name,
                                  style: AppTypography.labelSmall,
                                ),
                                backgroundColor: AppColors.surfaceContainerLow,
                                side: BorderSide.none,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            for (final vocal
                                in song.classification!.vocalRequirements)
                              Chip(
                                label: Text(
                                  vocal.skillName,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                side: BorderSide.none,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Audio Player Control Bar (From Stitch)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _isPlaying = !_isPlaying;
                              });
                            },
                            icon: Icon(
                              _isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              size: 44,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bản thu mẫu chuẩn',
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Bè Soprano xướng âm',
                                  style: AppTypography.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: AppColors.secondary,
                            ),
                            tooltip: 'Xem bản nhạc phổ',
                            onPressed: () => _showSheetMusicPreview(song),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: AppColors.surfaceContainerHigh,
                          thumbColor: AppColors.primary,
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                        ),
                        child: Slider(
                          value: _currentAudioPosition,
                          max: _totalAudioDuration,
                          onChanged: (val) {
                            setState(() {
                              _currentAudioPosition = val;
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_currentAudioPosition),
                              style: AppTypography.labelSmall,
                            ),
                            Text(
                              _formatDuration(_totalAudioDuration),
                              style: AppTypography.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab Bar: Lời bài hát & Thông tin
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.muted,
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(text: 'Lời bài hát'),
                    Tab(text: 'Tài liệu âm nhạc'),
                  ],
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Lyrics
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          song.lyrics,
                          style: AppTypography.bodyLarge.copyWith(
                            height: 1.8,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),

                      // Tab 2: Materials
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: AppColors.primary,
                              ),
                              title: const Text('Bản nhạc phổ (PDF)'),
                              subtitle: const Text(
                                'Đầy đủ 4 bè kèm hợp âm Organ',
                              ),
                              trailing: const Icon(Icons.open_in_new_rounded),
                              onTap: () => _showSheetMusicPreview(song),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.audiotrack_rounded,
                                color: AppColors.secondary,
                              ),
                              title: const Text('File âm thanh mẫu (.mp3)'),
                              subtitle: const Text('Chất lượng cao 320kbps'),
                              trailing: const Icon(Icons.download_rounded),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Đang tải file âm thanh mẫu...',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
