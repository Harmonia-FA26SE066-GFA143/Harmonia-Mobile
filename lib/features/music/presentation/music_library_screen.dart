import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../data/music_dto.dart';
import 'music_library_notifier.dart';

class MusicLibraryScreen extends ConsumerStatefulWidget {
  const MusicLibraryScreen({super.key});

  @override
  ConsumerState<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends ConsumerState<MusicLibraryScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(musicLibraryProvider).keyword;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicLibraryProvider);
    final notifier = ref.read(musicLibraryProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Thư viện thánh ca')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Tìm bài hát hoặc tài liệu',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Tìm kiếm',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => notifier.refresh(keyword: _search.text),
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (value) => notifier.refresh(keyword: value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Bài hát'),
                      icon: Icon(Icons.library_music),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Tài liệu của tôi'),
                      icon: Icon(Icons.menu_book),
                    ),
                  ],
                  selected: {state.materialsTab},
                  onSelectionChanged: (value) => notifier.refresh(
                    materialsTab: value.single,
                    keyword: _search.text,
                  ),
                ),
              ),
            ),
            if (state.materialsTab)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<MaterialType>(
                        key: ValueKey(('type', state.materialType)),
                        initialValue: state.materialType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Loại tài liệu',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tất cả'),
                          ),
                          for (final type in MaterialType.values)
                            DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                        ],
                        onChanged: (value) => notifier.refresh(
                          materialType: value,
                          learningStatus: state.learningStatus,
                          replaceFilters: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<LearningStatus>(
                        key: ValueKey(('status', state.learningStatus)),
                        initialValue: state.learningStatus,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Tiến độ'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tất cả'),
                          ),
                          for (final status in LearningStatus.values)
                            DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                        ],
                        onChanged: (value) => notifier.refresh(
                          materialType: state.materialType,
                          learningStatus: value,
                          replaceFilters: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => notifier.refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (state.loading) const LinearProgressIndicator(),
                    if (state.error != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(state.error!, textAlign: TextAlign.center),
                              TextButton(
                                onPressed: state.loading || state.loadingMore
                                    ? null
                                    : () => state.hasMore
                                          ? notifier.loadMore()
                                          : notifier.refresh(),
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!state.loading && state.error == null && state.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Text(
                          state.keyword.isNotEmpty ||
                                  state.materialType != null ||
                                  state.learningStatus != null
                              ? 'Không có kết quả phù hợp'
                              : state.materialsTab
                              ? 'Bạn chưa có tài liệu học'
                              : 'Thư viện chưa có bài hát',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (!state.materialsTab)
                      for (final song in state.songs)
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.music_note,
                              color: AppColors.primary,
                            ),
                            title: Text(song.title),
                            subtitle: song.composer?.isNotEmpty == true
                                ? Text(song.composer!)
                                : null,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(
                              '/song-detail/${Uri.encodeComponent(song.id)}',
                            ),
                          ),
                        ),
                    if (state.materialsTab)
                      for (final material in state.materials)
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
                              '${material.materialType.label} • ${material.learningStatus.label}'
                              '${material.targetSkillName == null ? "" : "\n${material.targetSkillName}"}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await context.push(
                                Uri(
                                  path: '/music-material/${material.id}',
                                  queryParameters: {'songId': material.songId},
                                ).toString(),
                              );
                              if (mounted) {
                                await ref
                                    .read(musicLibraryProvider.notifier)
                                    .refresh();
                              }
                            },
                          ),
                        ),
                    if (state.hasMore)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: OutlinedButton(
                          onPressed: state.loading || state.loadingMore
                              ? null
                              : notifier.loadMore,
                          child: state.loadingMore
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Tải thêm'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
