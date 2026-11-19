import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_notifier.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../lookups/data/lookups_api_service.dart';
import '../../music/data/music_dto.dart' show SongDto;
import '../data/staff_operations_api.dart';
import '../data/staff_workspace_repository.dart';
import '../../../app/widgets/harmonia_blocking_progress.dart';
import 'staff_ops_widgets.dart';
import 'staff_song_proposal.dart';

final _rehearsals = FutureProvider.autoDispose.family(
  (ref, (int, String?) key) =>
      ref.watch(staffOperationsApiProvider).rehearsals(key.$1, key.$2),
);
final _attendance = FutureProvider.autoDispose.family(
  (ref, String id) => ref.watch(staffOperationsApiProvider).attendances(id),
);
final _rehearsalOptions = FutureProvider.autoDispose.family(
  (ref, String? eventId) => (
    ref.watch(staffWorkspaceRepositoryProvider).choirs(),
    ref.watch(lookupsApiServiceProvider).getWorshipLocations(),
    eventId == null
        ? Future.value(<ServingChoir>[])
        : ref.watch(staffWorkspaceRepositoryProvider).servingChoirs(eventId),
  ).wait,
);

class StaffRehearsalsScreen extends ConsumerStatefulWidget {
  const StaffRehearsalsScreen({super.key, this.eventId});
  final String? eventId;

  @override
  ConsumerState<StaffRehearsalsScreen> createState() =>
      _StaffRehearsalsScreenState();
}

class _StaffRehearsalsScreenState extends ConsumerState<StaffRehearsalsScreen>
    with OpsActions {
  int _page = 1;

  Future<void> _edit([
    StaffRehearsal? rehearsal,
    bool songsOnly = false,
  ]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RehearsalForm(
        eventId: widget.eventId,
        rehearsal: rehearsal,
        songsOnly: songsOnly,
      ),
    );
    if (mounted && changed == true) ref.invalidate(_rehearsals);
  }

  Future<void> _delete(StaffRehearsal rehearsal) async {
    final yes = await opsConfirm(
      context,
      'Xóa buổi tập?',
      'Buổi tập sẽ được xóa nếu chưa có dữ liệu điểm danh.',
      'Xóa',
    );
    if (!mounted || !yes) return;
    if (await runAction(
      () => ref.read(staffOperationsApiProvider).deleteRehearsal(rehearsal.id),
    )) {
      ref.invalidate(_rehearsals);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = _rehearsals((_page, widget.eventId));
    return OpsPage(
      title: 'Lịch tập',
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(provider),
          tooltip: 'Tải lại',
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: OpsAsync(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (page) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: busy ? null : () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Tạo buổi tập'),
            ),
            actionState,
            if (page.items.isEmpty) const Text('Chưa có buổi tập.'),
            for (final row in page.items)
              OpsTile(
                icon: Icons.event_outlined,
                title: row.isJoint ? 'Buổi tập chung' : 'Buổi tập hát',
                subtitle: [
                  opsTime(row.start),
                  ?row.location,
                  ?row.note,
                  if (row.isPassed) 'Đã kết thúc',
                ].join('\n'),
                onTap: () => context.push(
                  opsPath('rehearsal', row.id),
                  extra: row.canManage,
                ),
                trailing: !row.canManage
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: 'Thao tác buổi tập',
                        enabled: !busy,
                        onSelected: (value) {
                          switch (value) {
                            case 'attendance':
                              context.push(
                                opsPath('staff-attendance', row.id),
                                extra: row.start,
                              );
                            case 'edit':
                              _edit(row);
                            case 'songs':
                              _edit(row, true);
                            case 'delete':
                              _delete(row);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'attendance',
                            child: Text('Điểm danh'),
                          ),
                          if (!row.isPassed)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Sửa lịch tập'),
                            ),
                          const PopupMenuItem(
                            value: 'songs',
                            child: Text('Sửa bài tập hát'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Xóa buổi tập'),
                          ),
                        ],
                      ),
              ),
            OpsPaging(
              page: _page,
              previous: page.hasPreviousPage
                  ? () => setState(() => _page--)
                  : null,
              next: page.hasNextPage ? () => setState(() => _page++) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _RehearsalForm extends ConsumerStatefulWidget {
  const _RehearsalForm({this.eventId, this.rehearsal, required this.songsOnly});
  final String? eventId;
  final StaffRehearsal? rehearsal;
  final bool songsOnly;
  @override
  ConsumerState<_RehearsalForm> createState() => _RehearsalFormState();
}

class _RehearsalFormState extends ConsumerState<_RehearsalForm>
    with OpsActions {
  late DateTime _start, _end;
  String? _choir, _location, _note;
  bool _joint = false;
  late List<RehearsalSong> _songs;
  bool get _creating => widget.rehearsal == null;
  String? get _event => widget.rehearsal?.eventId ?? widget.eventId;

  @override
  void initState() {
    super.initState();
    _start =
        widget.rehearsal?.start ??
        DateTime.now().toUtc().add(const Duration(hours: 1));
    _end = widget.rehearsal?.end ?? _start.add(const Duration(hours: 1));
    _location = widget.rehearsal?.locationId;
    _note = widget.rehearsal?.note;
    _songs = [...?widget.rehearsal?.songs];
  }

  Future<void> _pick(bool start) async {
    final time = await pickOpsTime(context, start ? _start : _end);
    if (time == null || !mounted) return;
    setState(() {
      if (start) {
        _start = time;
        if (!_end.isAfter(time)) _end = time.add(const Duration(hours: 1));
      } else {
        _end = time;
      }
    });
  }

  Future<void> _addSong() async {
    final song = await showDialog<SongDto>(
      context: context,
      builder: (_) => const StaffSongPicker(),
    );
    if (!mounted || song == null || _songs.any((item) => item.id == song.id)) {
      return;
    }
    setState(() => _songs.add((id: song.id, title: song.title, note: null)));
  }

  Future<void> _suggest() async {
    final event = _event;
    if (event == null) return;
    await runAction(() async {
      final suggested = await ref
          .read(staffOperationsApiProvider)
          .suggestedSongs(event);
      if (mounted) {
        setState(() {
          final ids = _songs.map((song) => song.id).toSet();
          _songs.addAll(suggested.where((song) => ids.add(song.id)));
        });
      }
    });
  }

  Future<void> _save() async {
    final repo = ref.read(staffOperationsApiProvider);
    var conflicts = <RehearsalConflict>[];
    final ok = await runAction(() async {
      if (widget.songsOnly) {
        await repo.saveRehearsalSongs(widget.rehearsal!.id, _songs);
      } else {
        conflicts = await repo.saveRehearsal(
          id: widget.rehearsal?.id,
          eventId: _event,
          choirId: _joint ? null : _choir,
          isJoint: _joint,
          locationId: _location,
          start: _start,
          end: _end,
          note: _note?.trim().isEmpty == true ? null : _note?.trim(),
          songs: _songs,
        );
      }
    });
    if (!mounted || !ok) return;
    if (conflicts.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đã lưu buổi tập có trùng lịch'),
          scrollable: true,
          content: Text(
            [
              'Các ca viên sau đang được phân công ở lễ trùng giờ.',
              for (final row in conflicts)
                '${row.member} · ${row.eventDate} ${row.time}',
            ].join('\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
    if (mounted) Navigator.pop(context, true);
  }

  Widget _songFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Bài hát của buổi tập'),
      if (_songs.isEmpty) const Text('Chưa thêm bài hát.'),
      for (final (index, row) in _songs.indexed)
        OpsTile(
          title: row.title,
          subtitle: row.note,
          icon: Icons.music_note_outlined,
          onTap: busy
              ? null
              : () async {
                  final note = await opsText(
                    context,
                    'Ghi chú bài tập hát',
                    'Ghi chú',
                    initial: row.note ?? '',
                  );
                  if (mounted && note != null) {
                    setState(
                      () => _songs[index] = (
                        id: row.id,
                        title: row.title,
                        note: note.isEmpty ? null : note,
                      ),
                    );
                  }
                },
          trailing: IconButton(
            tooltip: 'Bỏ bài hát',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: busy
                ? null
                : () => setState(() => _songs.removeAt(index)),
          ),
        ),
      OutlinedButton(
        onPressed: busy ? null : _addSong,
        child: const Text('Thêm bài hát'),
      ),
      if (_event != null)
        TextButton(
          onPressed: busy ? null : _suggest,
          child: const Text('Thêm bài đã duyệt của chương trình'),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final provider = _rehearsalOptions(_creating ? _event : null);
    final options = widget.songsOnly ? null : ref.watch(provider);
    final userId = ref.watch(
      authNotifierProvider.select((auth) => auth.user?.id),
    );
    final title = widget.songsOnly
        ? 'Bài hát buổi tập'
        : _creating
        ? 'Tạo buổi tập'
        : 'Sửa lịch tập';
    return HarmoniaBlockingOverlay(
      label: busy ? 'Đang lưu buổi tập…' : null,
      child: Dialog.fullscreen(
        child: OpsPage(
          title: title,
          actions: [
            IconButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              tooltip: 'Đóng',
            ),
          ],
          child: options == null
              ? _fields()
              : OpsAsync(
                  value: options,
                  onRetry: () => ref.invalidate(provider),
                  data: (data) => _fields(
                    canCreateJoint:
                        userId != null &&
                        data.$3.any(
                          (row) =>
                              (row.isLead || data.$3.length == 1) &&
                              (row.directorId == userId ||
                                  row.substituteId == userId),
                        ),
                    choirs: [
                      for (final choir in data.$1)
                        if (choir.isActive &&
                            choir.id.isNotEmpty &&
                            (!_creating ||
                                _event == null ||
                                data.$3.any((row) => row.id == choir.id)))
                          (id: choir.id, name: choir.name),
                    ],
                    places: [
                      for (final place in data.$2)
                        (id: place.id, name: place.name),
                      if (_location != null &&
                          !data.$2.any((place) => place.id == _location))
                        (
                          id: _location!,
                          name:
                              widget.rehearsal?.location ?? 'Nơi tập hiện tại',
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _fields({
    List<Choice> choirs = const [],
    List<Choice> places = const [],
    bool canCreateJoint = false,
  }) {
    final startInPast = _creating && !_start.isAfter(DateTime.now());
    final valid =
        widget.songsOnly ||
        (!startInPast &&
            _end.isAfter(_start) &&
            (!_creating ||
                (_joint
                    ? canCreateJoint
                    : choirs.any((row) => row.id == _choir))));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!widget.songsOnly) ...[
          if (_creating && canCreateJoint)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Buổi tập chung'),
              subtitle: const Text('Dành cho các ca đoàn phục vụ chương trình'),
              value: _joint,
              onChanged: busy
                  ? null
                  : (value) => setState(() => _joint = value),
            ),
          if (_creating && !_joint)
            OpsChoiceField(
              label: 'Ca đoàn',
              options: choirs,
              value: _choir,
              onChanged: busy
                  ? null
                  : (value) => setState(() => _choir = value),
            ),
          OpsChoiceField(
            label: 'Nơi tập',
            options: places,
            value: _location,
            optional: true,
            onChanged: busy
                ? null
                : (value) => setState(() => _location = value),
          ),
          OpsTile(
            title: 'Bắt đầu (giờ Việt Nam)',
            subtitle: opsTime(_start),
            onTap: busy ? null : () => _pick(true),
          ),
          OpsTile(
            title: 'Kết thúc (giờ Việt Nam)',
            subtitle: opsTime(_end),
            onTap: busy ? null : () => _pick(false),
          ),
          if (!_end.isAfter(_start))
            const Text('Giờ kết thúc phải sau giờ bắt đầu.'),
          if (startInPast) const Text('Giờ bắt đầu phải ở tương lai.'),
          TextFormField(
            initialValue: _note,
            enabled: !busy,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Ghi chú buổi tập'),
            onChanged: (text) => _note = text,
          ),
        ],
        if (_creating || widget.songsOnly) _songFields(),
        actionState,
        FilledButton(
          onPressed: busy || !valid ? null : _save,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

class StaffAttendanceScreen extends ConsumerStatefulWidget {
  const StaffAttendanceScreen({
    super.key,
    required this.rehearsalId,
    this.rehearsalStart,
  });
  final String rehearsalId;
  final DateTime? rehearsalStart;

  @override
  ConsumerState<StaffAttendanceScreen> createState() =>
      _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends ConsumerState<StaffAttendanceScreen>
    with OpsActions {
  static const _statuses = {
    'Present': 'Có mặt',
    'Absent': 'Vắng mặt',
    'Late': 'Đi muộn',
    'Excused': 'Vắng có phép',
  };
  final _changes = <String, String>{};
  String _search = '';

  Future<void> _save(List<AttendanceRow> rows, DateTime? opensAt) async {
    if (opensAt != null && DateTime.now().isBefore(opensAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Điểm danh mở lúc ${opsTime(opensAt)}.')),
      );
      return;
    }
    final id = widget.rehearsalId;
    final changes = {
      for (final row in rows)
        if (_changes[row.id] case final status? when row.isActive)
          row.id: status,
    };
    if (changes.isEmpty) return;
    if (await runAction(
          () =>
              ref.read(staffOperationsApiProvider).saveAttendance(id, changes),
        ) &&
        mounted) {
      setState(_changes.clear);
      ref.invalidate(_attendance(id));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu điểm danh.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = _attendance(widget.rehearsalId);
    final start = widget.rehearsalStart;
    final settings = start == null
        ? null
        : ref.watch(publicAppSettingsProvider).asData?.value;
    final opensAt =
        start != null &&
            settings != null &&
            settings.attendanceStartCheckEnabled
        ? start.subtract(
            Duration(minutes: settings.attendanceOpensMinutesBefore),
          )
        : null;
    return OpsPage(
      title: 'Điểm danh',
      actions: [
        IconButton(
          onPressed: busy ? null : () => ref.invalidate(provider),
          tooltip: 'Tải lại',
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: OpsAsync(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (rows) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Tìm ca viên',
                ),
                onChanged: (text) =>
                    setState(() => _search = text.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (rows.isEmpty) const Text('Chưa có ca viên để điểm danh.'),
                  for (final row in rows)
                    if (row.name.toLowerCase().contains(_search))
                      Card(
                        child: ListTile(
                          title: Text(row.name),
                          subtitle: !row.isActive
                              ? Text(
                                  '${_statuses[row.status] ?? 'Chưa điểm danh'} · Không còn hoạt động',
                                )
                              : DropdownButton<String>(
                                  icon: const SizedBox.shrink(),
                                  key: ValueKey(row.id),
                                  isExpanded: true,
                                  value:
                                      _statuses.containsKey(
                                        _changes[row.id] ?? row.status,
                                      )
                                      ? _changes[row.id] ?? row.status
                                      : null,
                                  hint: const Text('Chưa điểm danh'),
                                  items: [
                                    for (final status in _statuses.entries)
                                      DropdownMenuItem(
                                        value: status.key,
                                        child: Text(status.value),
                                      ),
                                  ],
                                  onChanged: busy
                                      ? null
                                      : (value) {
                                          if (value == null) return;
                                          setState(() {
                                            if (value == row.status) {
                                              _changes.remove(row.id);
                                            } else {
                                              _changes[row.id] = value;
                                            }
                                          });
                                        },
                                ),
                        ),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  actionState,
                  if (opensAt != null && DateTime.now().isBefore(opensAt))
                    Text('Điểm danh mở lúc ${opsTime(opensAt)}.'),
                  FilledButton(
                    onPressed:
                        busy ||
                            !rows.any(
                              (row) =>
                                  row.isActive && _changes.containsKey(row.id),
                            )
                        ? null
                        : () => _save(rows, opensAt),
                    child: Text('Lưu điểm danh (${_changes.length})'),
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
