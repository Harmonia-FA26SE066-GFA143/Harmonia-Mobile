import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../music/data/music_dto.dart';
import '../../music/data/music_repository.dart';
import '../data/staff_operations_api.dart';
import '../data/staff_workspace_repository.dart';
import 'staff_material_editor.dart';
import 'staff_ops_widgets.dart';
import 'staff_song_editor.dart';

final staffLibrarySongsProvider = FutureProvider.autoDispose.family(
  (Ref ref, (String, int) query) => ref
      .watch(musicRepositoryProvider)
      .getSongsPage(
        SearchSongsRequest(keyword: query.$1, pageNumber: query.$2),
      ),
);
final _song = FutureProvider.autoDispose.family(
  (Ref ref, String id) => ref.watch(staffWorkspaceRepositoryProvider).song(id),
);
final _materials = FutureProvider.autoDispose.family(
  (Ref ref, (String, int) query) =>
      ref.watch(staffOperationsApiProvider).songMaterials(query.$1, query.$2),
);
final _progress = FutureProvider.autoDispose.family(
  (Ref ref, (String, int, String?) query) => ref
      .watch(staffOperationsApiProvider)
      .materialProgress(query.$1, query.$2, query.$3),
);

class StaffLibraryScreen extends ConsumerStatefulWidget {
  const StaffLibraryScreen({super.key});

  @override
  ConsumerState<StaffLibraryScreen> createState() => _StaffLibraryScreenState();
}

class _StaffLibraryScreenState extends ConsumerState<StaffLibraryScreen> {
  final _search = TextEditingController();
  int _page = 1;
  String _keyword = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _find() => setState(() {
    _page = 1;
    _keyword = _search.text.trim();
  });

  Future<void> _add() async {
    final song = await showStaffSongEditor(context);
    if (song == null || !mounted) return;
    ref.invalidate(staffLibrarySongsProvider);
    context.push(opsPath('song-detail', song.id));
  }

  @override
  Widget build(BuildContext context) {
    final provider = staffLibrarySongsProvider((_keyword, _page));
    return OpsPage(
      title: 'Kho bài hát',
      actions: [
        IconButton(
          tooltip: 'Thêm bài hát',
          onPressed: _add,
          icon: const Icon(Icons.add),
        ),
        IconButton(
          tooltip: 'Tải lại',
          onPressed: () => ref.invalidate(provider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              maxLength: 100,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _find(),
              decoration: InputDecoration(
                labelText: 'Tìm theo tên bài hoặc tác giả',
                counterText: '',
                suffixIcon: IconButton(
                  tooltip: 'Tìm bài hát',
                  onPressed: _find,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
          ),
          Expanded(
            child: OpsAsync(
              value: ref.watch(provider),
              onRetry: () => ref.invalidate(provider),
              data: (page) => page.items.isEmpty
                  ? const Center(child: Text('Không tìm thấy bài hát.'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        for (final song in page.items)
                          OpsTile(
                            icon: Icons.music_note_outlined,
                            title: song.title,
                            subtitle: [
                              if (song.composer?.isNotEmpty == true)
                                song.composer!,
                              if (song.interactiveScoreCount case final count?)
                                '$count bản nhạc tương tác',
                            ].join(' · '),
                            onTap: () =>
                                context.push(opsPath('song-detail', song.id)),
                          ),
                        OpsPaging(
                          page: _page,
                          previous: page.hasPreviousPage
                              ? () => setState(() => _page--)
                              : null,
                          next: page.hasNextPage
                              ? () => setState(() => _page++)
                              : null,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class StaffLibrarySongScreen extends ConsumerStatefulWidget {
  const StaffLibrarySongScreen({super.key, required this.songId});
  final String songId;

  @override
  ConsumerState<StaffLibrarySongScreen> createState() =>
      _StaffLibrarySongScreenState();
}

class _StaffLibrarySongScreenState
    extends ConsumerState<StaffLibrarySongScreen> {
  int _page = 1;

  Future<void> _edit(SongDto song) async {
    if (await showStaffSongEditor(context, song: song) == null || !mounted) {
      return;
    }
    ref.invalidate(_song(widget.songId));
    ref.invalidate(staffLibrarySongsProvider);
  }

  Future<void> _material({MusicMaterialDto? current}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            StaffMaterialEditor(songId: widget.songId, current: current),
      ),
    );
    if (saved != true || !mounted) return;
    if (current == null) setState(() => _page = 1);
    ref.invalidate(_materials);
    ref.invalidate(_progress);
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = _song(widget.songId);
    final filesProvider = _materials((widget.songId, _page));
    final song = ref.watch(songProvider);
    final files = ref.watch(filesProvider);
    return OpsPage(
      title: 'Chi tiết bài hát',
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: () {
            ref.invalidate(songProvider);
            ref.invalidate(filesProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: OpsAsync(
        value: song,
        onRetry: () => ref.invalidate(songProvider),
        data: (song) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            OpsTile(
              icon: Icons.music_note_outlined,
              title: song.title,
              subtitle: [
                ?song.composer,
                if (song.lyricist case final name? when name.isNotEmpty)
                  'Lời · $name',
                ?song.musicalKey,
                ?song.tempo,
                ?song.notes,
              ].where((value) => value.isNotEmpty).join('\n'),
            ),
            OutlinedButton.icon(
              onPressed: () => _edit(song),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Sửa thông tin bài hát'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      StaffSongClassificationScreen(songId: song.id),
                ),
              ),
              icon: const Icon(Icons.category_outlined),
              label: const Text('Chỉnh phân loại'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push(opsPath('staff-scores', song.id)),
              icon: const Icon(Icons.piano_outlined),
              label: const Text('Bản nhạc tương tác'),
            ),
            const SizedBox(height: 16),
            Text(
              'Tài liệu của bài hát',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            FilledButton.icon(
              onPressed: () => _material(),
              icon: const Icon(Icons.upload_file),
              label: const Text('Tải tài liệu lên'),
            ),
            OpsAsync(
              value: files,
              onRetry: () => ref.invalidate(filesProvider),
              data: (page) => Column(
                children: [
                  if (page.items.isEmpty)
                    const Text('Bài hát chưa có tài liệu.'),
                  for (final file in page.items)
                    OpsTile(
                      icon: Icons.description_outlined,
                      title: file.title,
                      subtitle:
                          '${file.materialType.label} · ${file.targetSkillName ?? 'Cả ca đoàn'}',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              _MaterialProgressScreen(material: file),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Thao tác tài liệu',
                        onSelected: (value) {
                          switch (value) {
                            case 'progress':
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      _MaterialProgressScreen(material: file),
                                ),
                              );
                            case 'replace':
                              _material(current: file);
                            case 'score':
                              context.push(
                                opsPath('interactive-score', file.id),
                              );
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'progress',
                            child: Text('Xem tiến độ học'),
                          ),
                          if (file.lyricsText == null &&
                              file.materialType != MaterialType.unknown)
                            const PopupMenuItem(
                              value: 'replace',
                              child: Text('Thay tệp'),
                            ),
                          if (file.materialType ==
                              MaterialType.interactiveScore)
                            const PopupMenuItem(
                              value: 'score',
                              child: Text('Mở bản nhạc tương tác'),
                            ),
                        ],
                      ),
                    ),
                  OpsPaging(
                    page: _page,
                    previous: page.hasPreviousPage
                        ? () => setState(() => _page--)
                        : null,
                    next: page.hasNextPage
                        ? () => setState(() => _page++)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialProgressScreen extends ConsumerStatefulWidget {
  const _MaterialProgressScreen({required this.material});
  final MusicMaterialDto material;

  @override
  ConsumerState<_MaterialProgressScreen> createState() =>
      _MaterialProgressScreenState();
}

class _MaterialProgressScreenState
    extends ConsumerState<_MaterialProgressScreen> {
  int _page = 1;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final provider = _progress((widget.material.id, _page, _status));
    return OpsPage(
      title: 'Tiến độ học tài liệu',
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: () => ref.invalidate(provider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.material.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                OpsChoiceField(
                  label: 'Trạng thái',
                  value: _status,
                  optional: true,
                  emptyLabel: 'Tất cả',
                  options: [
                    for (final status in LearningStatus.values)
                      (id: status.wireName, name: status.label),
                  ],
                  onChanged: (status) => setState(() {
                    _status = status;
                    _page = 1;
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: OpsAsync(
              value: ref.watch(provider),
              onRetry: () => ref.invalidate(provider),
              data: (page) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (page.items.isEmpty)
                    const Center(child: Text('Không có ca viên phù hợp.')),
                  for (final row in page.items)
                    OpsTile(
                      icon: Icons.person_outline,
                      title: row.name,
                      subtitle: [
                        LearningStatus.values
                                .where((item) => item.wireName == row.status)
                                .firstOrNull
                                ?.label ??
                            'Chưa rõ trạng thái',
                        if (row.updatedAt case final time?) opsTime(time),
                      ].join(' · '),
                    ),
                  OpsPaging(
                    page: _page,
                    previous: page.hasPreviousPage
                        ? () => setState(() => _page--)
                        : null,
                    next: page.hasNextPage
                        ? () => setState(() => _page++)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
