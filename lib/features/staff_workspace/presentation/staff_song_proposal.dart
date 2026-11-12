import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/app_page_header.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/error_messages.dart';
import '../../lookups/data/lookup_dto.dart';
import '../../lookups/data/lookups_api_service.dart';
import '../../music/data/music_dto.dart'
    show SearchSongsRequest, SongDto, SongListDto;
import '../../music/data/music_repository.dart';
import '../data/staff_workspace_repository.dart';
import '../data/staff_dashboard_providers.dart';
import 'staff_workflow_title.dart';

final _slots = FutureProvider.autoDispose((ref) {
  ref.watch(sessionManagerProvider.select((session) => session.sessionEpoch));
  return ref.watch(lookupsApiServiceProvider).getLiturgicalSlots();
});

final _songSearch = FutureProvider.autoDispose.family((
  ref,
  (String, int) query,
) {
  ref.watch(sessionManagerProvider.select((session) => session.sessionEpoch));
  return ref
      .watch(musicRepositoryProvider)
      .getSongsPage(
        SearchSongsRequest(
          keyword: query.$1.isEmpty ? null : query.$1,
          pageNumber: query.$2,
        ),
      );
});

class StaffSongProposal extends ConsumerStatefulWidget {
  const StaffSongProposal({super.key, required this.event, this.latest});
  final StaffEvent event;
  final SongListDto? latest;

  @override
  ConsumerState<StaffSongProposal> createState() => _StaffSongProposalState();
}

class _DraftSong {
  _DraftSong(this.id, this.title, {this.slot, this.note = ''});
  final String id;
  final String title;
  String? slot;
  String note;
}

class _StaffSongProposalState extends ConsumerState<StaffSongProposal> {
  late final List<_DraftSong> _songs;
  String? _draftId;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final latest = widget.latest;
    final items = latest?.items.toList() ?? [];
    items.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    _songs = [
      for (final item in items)
        _DraftSong(
          item.songId,
          item.songTitle,
          slot: item.slotId,
          note: item.note ?? '',
        ),
    ];
    _draftId = latest?.status == 'Draft' ? latest?.id : null;
  }

  Future<void> _add() async {
    final song = await showDialog<SongDto>(
      context: context,
      builder: (_) => const StaffSongPicker(),
    );
    if (mounted && song != null) {
      setState(() => _songs.add(_DraftSong(song.id, song.title)));
    }
  }

  void _move(int from, int to) {
    setState(() {
      final row = _songs.removeAt(from);
      _songs.insert(to, row);
    });
  }

  Future<void> _save(bool submit, List<LiturgicalSlotDto> slots) async {
    if (_busy) return;
    final validSlots = slots.map((slot) => slot.id).toSet();
    if (_songs.isEmpty ||
        _songs.any((song) => !validSlots.contains(song.slot))) {
      setState(
        () => _error = 'Thêm ít nhất một bài hát và chọn vị trí cho từng bài.',
      );
      return;
    }
    if (_songs.map((song) => (song.id, song.slot)).toSet().length !=
        _songs.length) {
      setState(
        () => _error = 'Một bài chỉ được chọn một lần trong cùng vị trí.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(staffWorkspaceRepositoryProvider);
    try {
      final saved = await repo.saveProposal(widget.event.id, _draftId, [
        for (final song in _songs)
          (
            songId: song.id,
            slotId: song.slot!,
            note: song.note.trim().isEmpty ? null : song.note.trim(),
          ),
      ]);
      _draftId = saved.id;
      if (!mounted) return;
      if (mounted) ref.invalidate(staffDirectorProgramsProvider);
      if (submit) {
        await repo.submitProposal(saved.id);
        if (mounted) ref.invalidate(staffDirectorProgramsProvider);
      }
      if (mounted) Navigator.of(context).pop(submit);
    } catch (error) {
      if (mounted) setState(() => _error = ErrorMessages.forException(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(_slots);
    final choices = slots.asData?.value;
    final version =
        (widget.latest?.version ?? 0) +
        (widget.latest?.status == 'Draft' ? 0 : 1);
    return PopScope(
      canPop: !_busy,
      child: Dialog.fullscreen(
        child: Scaffold(
          appBar: AppPageHeader(
            large: true,
            title: const StaffWorkflowTitle(
              title: 'Đề xuất bài hát',
              role: 'Dành cho Ca trưởng',
            ),
            leading: IconButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              tooltip: 'Đóng',
            ),
          ),
          bottomNavigationBar: choices == null
              ? null
              : StaffWorkflowBar(
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _save(false, choices),
                          child: const Text('Lưu bản nháp'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy ? null : () => _save(true, choices),
                          child: Text(_busy ? 'Đang xử lý…' : 'Gửi phê duyệt'),
                        ),
                      ),
                    ],
                  ),
                ),
          body: SafeArea(
            child: slots.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(_slots),
                  child: const Text('Tải lại vị trí phụng vụ'),
                ),
              ),
              data: (choices) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  StaffEventSummary(
                    event: widget.event,
                    stateLabel: 'Bản nháp',
                    version: version,
                  ),
                  if (widget.latest?.reviewNotes case final String note
                      when note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Nhận xét của cha xứ: $note'),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Danh mục bài hát',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Chip(
                        label: Text('${_songs.length} bài'),
                        backgroundColor: AppColors.surfaceContainerHigh,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_songs.isEmpty)
                    const Text('Chưa có bài hát trong bản nháp.'),
                  for (final (index, song) in _songs.indexed)
                    Card(
                      key: ObjectKey(song),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.primarySoft,
                                  foregroundColor: AppColors.primary,
                                  child: Text('${index + 1}'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    song.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue:
                                  choices.any((slot) => slot.id == song.slot)
                                  ? song.slot
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Vị trí phụng vụ',
                              ),
                              isExpanded: true,
                              items: [
                                for (final slot in choices)
                                  DropdownMenuItem(
                                    value: slot.id,
                                    child: Text(
                                      slot.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: _busy
                                  ? null
                                  : (value) =>
                                        setState(() => song.slot = value),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: song.note,
                              enabled: !_busy,
                              decoration: const InputDecoration(
                                labelText: 'Ghi chú phụng vụ (tùy chọn)',
                              ),
                              onChanged: (value) => song.note = value,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  tooltip: 'Đưa bài lên',
                                  onPressed: _busy || index == 0
                                      ? null
                                      : () => _move(index, index - 1),
                                  icon: const Icon(Icons.arrow_upward),
                                ),
                                IconButton(
                                  tooltip: 'Đưa bài xuống',
                                  onPressed: _busy || index == _songs.length - 1
                                      ? null
                                      : () => _move(index, index + 1),
                                  icon: const Icon(Icons.arrow_downward),
                                ),
                                IconButton(
                                  tooltip: 'Bỏ bài hát',
                                  onPressed: _busy
                                      ? null
                                      : () => setState(
                                          () => _songs.removeAt(index),
                                        ),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _add,
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm bài hát từ thư viện'),
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 12),
                  const ListTile(
                    tileColor: AppColors.statusWarningSoft,
                    leading: Icon(
                      Icons.info_outline,
                      color: AppColors.statusWarning,
                    ),
                    title: Text(
                      'Sau khi gửi, danh sách sẽ chờ Cha xứ phê duyệt.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StaffSongPicker extends ConsumerStatefulWidget {
  const StaffSongPicker({super.key});

  @override
  ConsumerState<StaffSongPicker> createState() => _SongPickerState();
}

class _SongPickerState extends ConsumerState<StaffSongPicker> {
  final _search = TextEditingController();
  String _query = '';
  int _page = 1;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applySearch() {
    setState(() {
      _query = _search.text.trim();
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = _songSearch((_query, _page));
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppPageHeader(
          title: const Text('Chọn bài hát'),
          leading: const CloseButton(),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _applySearch(),
                  decoration: InputDecoration(
                    labelText: 'Tìm bài hát',
                    suffixIcon: IconButton(
                      onPressed: _applySearch,
                      tooltip: 'Tìm',
                      icon: const Icon(Icons.search),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ref
                    .watch(provider)
                    .when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(
                        child: OutlinedButton(
                          onPressed: () => ref.invalidate(provider),
                          child: const Text('Tải lại bài hát'),
                        ),
                      ),
                      data: (page) => ListView(
                        children: [
                          if (page.items.isEmpty)
                            const ListTile(
                              title: Text('Không tìm thấy bài hát.'),
                            ),
                          for (final song in page.items)
                            ListTile(
                              title: Text(song.title),
                              subtitle: song.composer == null
                                  ? null
                                  : Text(song.composer!),
                              onTap: () => Navigator.of(context).pop(song),
                            ),
                          if (page.hasPreviousPage || page.hasNextPage)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                TextButton(
                                  onPressed: page.hasPreviousPage
                                      ? () => setState(() => _page--)
                                      : null,
                                  child: const Text('Trang trước'),
                                ),
                                TextButton(
                                  onPressed: page.hasNextPage
                                      ? () => setState(() => _page++)
                                      : null,
                                  child: const Text('Trang sau'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
