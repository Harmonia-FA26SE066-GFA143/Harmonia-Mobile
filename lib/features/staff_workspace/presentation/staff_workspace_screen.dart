import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/role_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/session/session_manager.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../music/data/music_dto.dart' show SongDto, SongListDto;
import '../../music/data/music_repository.dart';
import '../../notifications/data/notification_dto.dart' show PagedList;
import '../data/staff_workspace_repository.dart';
import 'staff_chat_screen.dart' show staffThreadPath;
import 'staff_program_form.dart';
import 'staff_workflow_title.dart';
import 'staff_song_proposal.dart';

final _programs = FutureProvider.autoDispose.family<PagedList<StaffEvent>, int>(
  (ref, page) => ref.watch(staffWorkspaceRepositoryProvider).programs(page),
);
final _choirs = FutureProvider.autoDispose(
  (ref) => ref.watch(staffWorkspaceRepositoryProvider).choirs(),
);
final _approvals = FutureProvider.autoDispose(
  (ref) => ref.watch(staffWorkspaceRepositoryProvider).approvals(),
);
final _event = FutureProvider.autoDispose
    .family<StaffEvent, (MobileRole, String)>(
      (ref, key) =>
          ref.watch(staffWorkspaceRepositoryProvider).event(key.$1, key.$2),
    );
final _servingChoirs = FutureProvider.autoDispose.family(
  (ref, String id) =>
      ref.watch(staffWorkspaceRepositoryProvider).servingChoirs(id),
);
final _latestList = FutureProvider.autoDispose.family(
  (ref, String id) =>
      ref.watch(staffWorkspaceRepositoryProvider).latestList(id),
);
final _songList = FutureProvider.autoDispose.family<SongListDto, String>(
  (ref, id) => ref.watch(staffWorkspaceRepositoryProvider).songList(id),
);
final _song = FutureProvider.autoDispose.family<SongDto, String>(
  (ref, id) => ref.watch(staffWorkspaceRepositoryProvider).song(id),
);
final _note = FutureProvider.autoDispose.family<StaffNote, String>(
  (ref, id) => ref.watch(staffWorkspaceRepositoryProvider).note(id),
);

String _date(DateTime date) => DateFormat('dd/MM/yyyy').format(date);
String _timestamp(DateTime date) =>
    DateFormat('dd/MM/yyyy • HH:mm').format(date.toLocal());
String _eventStatus(String? status) => switch (status) {
  'Draft' => 'Bản nháp',
  'Published' => 'Đã công bố',
  'Cancelled' => 'Đã hủy',
  _ => '',
};
String _songListStatus(String status) => switch (status) {
  'Draft' => 'Bản nháp',
  'Submitted' => 'Chờ phê duyệt',
  'Approved' => 'Đã duyệt',
  'Rejected' => 'Đã từ chối',
  'NeedsRevision' => 'Yêu cầu chỉnh sửa',
  _ => 'Danh sách bài hát',
};

class StaffHomeScreen extends ConsumerWidget {
  const StaffHomeScreen({super.key, required this.role});
  final MobileRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(
      authNotifierProvider.select((s) => s.user?.fullName),
    );
    final isDirector = role == MobileRole.choirDirector;
    return _StaffPage(
      title: 'Trang chủ',
      children: [
        _Tile(
          icon: Icons.person_outline,
          title: name == null || name.trim().isEmpty
              ? role.label
              : 'Chào $name',
          subtitle: name == null || name.trim().isEmpty ? null : role.label,
        ),
        _Tile(
          icon: Icons.calendar_month_outlined,
          title: 'Lịch phụng vụ',
          subtitle: 'Xem chương trình và thông tin cử hành',
          onTap: () => context.go('/calendar'),
        ),
        _Tile(
          icon: isDirector ? Icons.groups_outlined : Icons.fact_check_outlined,
          title: isDirector ? 'Ca đoàn của tôi' : 'Danh sách chờ phê duyệt',
          onTap: () => context.go(workspacePath(role)),
        ),
        _Tile(
          icon: Icons.chat_bubble_outline,
          title: 'Tin nhắn',
          subtitle: 'Trao đổi giữa cha xứ và ca trưởng',
          onTap: () => context.push('/staff-chat'),
        ),
        _Tile(
          icon: Icons.piano_outlined,
          title: 'Bản nhạc tương tác',
          subtitle: 'Chọn bài hát để mở bản nhạc',
          onTap: () async {
            final song = await showDialog<SongDto>(
              context: context,
              builder: (_) => const StaffSongPicker(),
            );
            if (song != null && context.mounted) {
              context.push(_detailPath('staff-scores', song.id));
            }
          },
        ),
        _Tile(
          icon: Icons.bar_chart_outlined,
          title: 'Báo cáo',
          onTap: () => context.push('/staff-reports'),
        ),
      ],
    );
  }
}

class StaffAccountScreen extends ConsumerWidget {
  const StaffAccountScreen({super.key, required this.role});
  final MobileRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider.select((s) => s.user));
    return _StaffPage(
      title: 'Cá nhân',
      children: [
        _Tile(
          icon: Icons.account_circle_outlined,
          title: user?.fullName.trim().isNotEmpty == true
              ? user!.fullName
              : role.label,
          subtitle: [role.label, ?user?.email].join('\n'),
        ),
        _Tile(
          icon: Icons.lock_outline,
          title: 'Đổi mật khẩu',
          onTap: () => context.push('/change-password'),
        ),
        OutlinedButton.icon(
          onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
        ),
      ],
    );
  }
}

class StaffProgramsScreen extends ConsumerStatefulWidget {
  const StaffProgramsScreen({super.key});

  @override
  ConsumerState<StaffProgramsScreen> createState() =>
      _StaffProgramsScreenState();
}

class _StaffProgramsScreenState extends ConsumerState<StaffProgramsScreen> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final provider = _programs(_page);
    final isPriest = ref.watch(
      sessionManagerProvider.select(
        (session) => session.role == MobileRole.parishPriest,
      ),
    );
    return _DataPage(
      title: 'Lịch phụng vụ',
      data: ref.watch(provider),
      onRefresh: () => ref.refresh(provider.future),
      rows: (page) => [
        if (isPriest)
          FilledButton.icon(
            onPressed: () async {
              final id = await context.push<String>('/program-new');
              if (id == null || !context.mounted) return;
              ref.invalidate(_programs);
              await context.push(_detailPath('event-detail', id));
            },
            icon: const Icon(Icons.add),
            label: const Text('Tạo chương trình'),
          ),
        if (page.items.isEmpty) const Text('Chưa có chương trình phụng vụ.'),
        for (final event in page.items)
          _Tile(
            icon: Icons.event_outlined,
            title: event.title,
            subtitle: [
              _date(event.date),
              event.time,
              event.location,
              _eventStatus(event.status),
            ].where((value) => value.isNotEmpty).join(' • '),
            onTap: () => context.push(_detailPath('event-detail', event.id)),
          ),
        if (page.hasPreviousPage || page.hasNextPage)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: page.hasPreviousPage
                    ? () => setState(() => _page--)
                    : null,
                child: const Text('Trang trước'),
              ),
              Text('Trang $_page'),
              TextButton(
                onPressed: page.hasNextPage
                    ? () => setState(() => _page++)
                    : null,
                child: const Text('Trang sau'),
              ),
            ],
          ),
      ],
    );
  }
}

class StaffChoirsScreen extends ConsumerWidget {
  const StaffChoirsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _DataPage(
      title: 'Ca đoàn của tôi',
      data: ref.watch(_choirs),
      onRefresh: () => ref.refresh(_choirs.future),
      rows: (choirs) => [
        _Tile(
          icon: Icons.event_outlined,
          title: 'Lịch tập và điểm danh',
          onTap: () => context.push('/staff-rehearsals'),
        ),
        _Tile(
          icon: Icons.mic_none,
          title: 'Chấm bản thu',
          onTap: () => context.push('/staff-submissions'),
        ),
        if (choirs.isEmpty) const Text('Bạn chưa được giao phụ trách ca đoàn.'),
        for (final choir in choirs)
          _Tile(
            icon: Icons.groups_outlined,
            title: choir.name,
            subtitle: [
              if (!choir.isActive) 'Ngừng hoạt động',
              if (choir.description?.trim().isNotEmpty == true)
                choir.description!,
            ].join('\n'),
          ),
      ],
    );
  }
}

class StaffApprovalsScreen extends ConsumerWidget {
  const StaffApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _DataPage(
      title: 'Phê duyệt',
      data: ref.watch(_approvals),
      onRefresh: () => ref.refresh(_approvals.future),
      rows: (lists) => [
        if (lists.isEmpty)
          const Text('Chưa có danh sách bài hát chờ phê duyệt.'),
        for (final list in lists)
          _Tile(
            icon: Icons.library_music_outlined,
            title: 'Danh sách bài hát • Bản ${list.version}',
            subtitle: list.submittedAt == null
                ? 'Chờ phê duyệt'
                : 'Đã gửi ${_timestamp(list.submittedAt!)}',
            onTap: () => context.push(_detailPath('song-list', list.id)),
          ),
      ],
    );
  }
}

class StaffEventScreen extends ConsumerWidget {
  const StaffEventScreen({
    super.key,
    required this.eventId,
    required this.role,
  });
  final String eventId;
  final MobileRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = _event((role, eventId));
    final data = ref.watch(provider);
    final priest = role == MobileRole.parishPriest;
    Widget page(Widget? content, Widget? footer) => _DataPage(
      title: priest ? 'Chi tiết & Công bố' : 'Chi tiết phụng vụ',
      workflowRole: priest ? 'Dành cho Cha xứ' : 'Dành cho Ca trưởng',
      workflowSubtitle: data.asData?.value.title,
      backPath: '/calendar',
      data: data,
      footer: footer,
      onRefresh: () => ref.refresh(provider.future),
      rows: (event) => [
        StaffEventSummary(
          event: event,
          stateLabel: event.status == 'Draft'
              ? 'Chưa công bố'
              : _eventStatus(event.status),
        ),
        ?content,
      ],
    );
    final event = data.value;
    return event == null
        ? page(null, null)
        : _EventWorkflow(
            key: ValueKey(event.id),
            event: event,
            role: role,
            builder: page,
          );
  }
}

class StaffSongListScreen extends ConsumerWidget {
  const StaffSongListScreen({super.key, required this.listId});
  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = _songList(listId);
    final listData = ref.watch(provider);
    final role = ref.watch(
      sessionManagerProvider.select((session) => session.role),
    );
    final list = listData.value;
    final eventId = list?.eventId;
    final event = role == null || eventId == null || eventId.isEmpty
        ? null
        : ref.watch(_event((role, eventId))).asData?.value;
    Widget page(Widget? notes, Widget? footer) => _DataPage(
      title: role == MobileRole.parishPriest
          ? 'Phê duyệt danh sách'
          : 'Danh sách bài hát',
      workflowRole: role == MobileRole.parishPriest
          ? 'Dành cho Cha xứ'
          : 'Dành cho Ca trưởng',
      workflowSubtitle: event?.title,
      backPath: '/notifications',
      data: listData,
      footer: footer,
      onRefresh: () => ref.refresh(provider.future),
      rows: (list) {
        final items = list.items.toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        return [
          if (event != null)
            StaffEventSummary(
              event: event,
              stateLabel: _songListStatus(list.status),
              version: list.version,
            )
          else
            _Tile(
              icon: Icons.fact_check_outlined,
              title: _songListStatus(list.status),
              subtitle: 'Phiên bản ${list.version}',
              onTap: () =>
                  context.push(_detailPath('event-detail', list.eventId)),
            ),
          if (list.reviewNotes case final String note when note.isNotEmpty)
            _Tile(
              icon: Icons.notes,
              title: 'Nhận xét của cha xứ',
              subtitle: note,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Danh mục bài hát',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text('${items.length} bài'),
                  backgroundColor: AppColors.surfaceContainerHigh,
                ),
              ],
            ),
          ),
          if (items.isEmpty) const Text('Danh sách chưa có bài hát.'),
          for (final (index, item) in items.indexed)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primarySoft,
                      foregroundColor: AppColors.primary,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(
                      item.songTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: item.slotName.trim().isEmpty
                        ? null
                        : Text(
                            item.slotName.toUpperCase(),
                            style: const TextStyle(color: AppColors.primary),
                          ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push(_detailPath('song-detail', item.songId)),
                  ),
                  if (item.note?.trim().isNotEmpty == true)
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Ghi chú phụng vụ: ${item.note}'),
                    ),
                ],
              ),
            ),
          ?notes,
        ];
      },
    );
    return list?.status == 'Submitted' && role == MobileRole.parishPriest
        ? _SongListReview(key: ValueKey(list!.id), list: list, builder: page)
        : page(null, null);
  }
}

class StaffSongScreen extends ConsumerWidget {
  const StaffSongScreen({super.key, required this.songId});
  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = _song(songId);
    return _DataPage(
      title: 'Chi tiết bài hát',
      backPath: '/notifications',
      data: ref.watch(provider),
      onRefresh: () => ref.refresh(provider.future),
      rows: (song) => [
        _Tile(
          icon: Icons.music_note_outlined,
          title: song.title,
          subtitle: [
            ?song.composer,
            ?song.musicalKey,
            ?song.tempo,
            ?song.notes,
          ].where((value) => value.trim().isNotEmpty).join('\n'),
        ),
        _Tile(
          icon: Icons.piano_outlined,
          title: 'Bản nhạc tương tác',
          onTap: () => context.push(_detailPath('staff-scores', song.id)),
        ),
      ],
    );
  }
}

class StaffNoteScreen extends ConsumerWidget {
  const StaffNoteScreen({super.key, required this.noteId});
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = _note(noteId);
    final me = ref.watch(
      authNotifierProvider.select((state) => state.user?.id),
    );
    return _DataPage(
      title: 'Ghi chú',
      backPath: '/notifications',
      data: ref.watch(provider),
      onRefresh: () => ref.refresh(provider.future),
      rows: (note) => [
        _Tile(
          icon: Icons.notes,
          title: note.sender,
          subtitle: _timestamp(note.sentAt),
        ),
        SelectableText(note.content),
        if (me == note.senderId && note.recipientId != null)
          _Tile(
            icon: Icons.chat_bubble_outline,
            title: 'Mở cuộc trò chuyện',
            onTap: () => context.push(
              staffThreadPath(note.recipientId!, note.recipient ?? ''),
            ),
          ),
        if (me == note.recipientId && note.senderId != null)
          _Tile(
            icon: Icons.chat_bubble_outline,
            title: 'Trả lời',
            onTap: () =>
                context.push(staffThreadPath(note.senderId!, note.sender)),
          ),
        if (note.eventId != null)
          _Tile(
            icon: Icons.event_outlined,
            title: note.eventTitle ?? 'Chi tiết phụng vụ',
            onTap: () =>
                context.push(_detailPath('event-detail', note.eventId!)),
          ),
      ],
    );
  }
}

class _EventWorkflow extends ConsumerStatefulWidget {
  const _EventWorkflow({
    super.key,
    required this.event,
    required this.role,
    required this.builder,
  });
  final StaffEvent event;
  final MobileRole role;
  final Widget Function(Widget content, Widget? footer) builder;

  @override
  ConsumerState<_EventWorkflow> createState() => _EventWorkflowState();
}

class _EventWorkflowState extends ConsumerState<_EventWorkflow> {
  bool _busy = false;
  String? _error;

  String get _id => widget.event.id;

  Future<void> _run(
    Future<void> Function(StaffWorkspaceRepository) action,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(ref.read(staffWorkspaceRepositoryProvider));
    } catch (error) {
      if (mounted) setState(() => _error = ErrorMessages.forException(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Công bố chương trình?'),
        content: const Text(
          'Ca trưởng và ca viên sẽ nhận thông báo về chương trình.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Công bố'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run((repo) async {
      await repo.publish(_id);
      if (!mounted) return;
      ref.invalidate(_event((widget.role, _id)));
      ref.invalidate(_programs);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã công bố chương trình.')));
    });
  }

  Future<void> _editChoirs(List<ServingChoir> current) => _run((repo) async {
    final parish = await repo.choirs();
    if (!mounted) return;
    final updated =
        await showDialog<({ChoirSelection selection, String? reason})>(
          context: context,
          builder: (_) => _ServingChoirDialog(
            current: current,
            available: parish,
            published: widget.event.status == 'Published',
          ),
        );
    if (!mounted || updated == null) return;
    await repo.updateChoirs(
      _id,
      updated.selection.ids.toList(),
      updated.selection.lead!,
      updated.reason,
    );
    if (mounted) ref.invalidate(_servingChoirs(_id));
  });

  Future<void> _replaceDirector(ServingChoir choir) => _run((repo) async {
    final directors = (await repo.directors())
        .where((director) => director.id != choir.directorId)
        .toList();
    if (!mounted) return;
    final choice = await showDialog<({String? directorId, String? reason})>(
      context: context,
      builder: (_) => _SubstituteDialog(choir: choir, directors: directors),
    );
    if (!mounted || choice == null) return;
    await repo.setSubstitute(_id, choir.id, choice.directorId, choice.reason);
    if (mounted) ref.invalidate(_servingChoirs(_id));
  });

  Future<void> _propose(SongListDto? latest) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StaffSongProposal(event: widget.event, latest: latest),
    );
    if (!mounted) return;
    ref.invalidate(_latestList(_id));
    if (latest != null) ref.invalidate(_songList(latest.id));
  }

  @override
  Widget build(BuildContext context) {
    final serving = ref.watch(_servingChoirs(_id));
    final loadedChoirs = serving.asData?.value ?? const <ServingChoir>[];
    final lead =
        loadedChoirs.where((choir) => choir.isLead).firstOrNull ??
        (loadedChoirs.length == 1 ? loadedChoirs.first : null);
    final priest = widget.role == MobileRole.parishPriest;
    final published = widget.event.status == 'Published';
    final editable =
        widget.event.status != 'Cancelled' &&
        !widget.event.date.isBefore(DateUtils.dateOnly(DateTime.now()));
    final userId = ref.watch(
      authNotifierProvider.select((state) => state.user?.id),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            foregroundColor: AppColors.primary,
            child: Icon(Icons.groups_outlined),
          ),
          title: Text(
            'Ca đoàn phục vụ',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        serving.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => TextButton(
            onPressed: () => ref.invalidate(_servingChoirs(_id)),
            child: const Text('Tải lại ca đoàn phục vụ'),
          ),
          data: (choirs) {
            final canPropose =
                !priest &&
                userId != null &&
                (lead?.directorId == userId || lead?.substituteId == userId);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (choirs.isEmpty) const Text('Chưa có ca đoàn phục vụ.'),
                for (final choir in choirs)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: choir.id == lead?.id
                        ? AppColors.primarySoft
                        : AppColors.surface,
                    child: ListTile(
                      leading: const Icon(Icons.groups_outlined),
                      title: Text(choir.name),
                      subtitle: Text(
                        [
                          if (choir.id == lead?.id)
                            'Phụ trách chính'
                          else
                            'Hỗ trợ',
                          if (choir.directorName != null)
                            'Ca trưởng: ${choir.directorName}',
                          if (choir.substituteName != null)
                            'Người thay: ${choir.substituteName}',
                        ].join('\n'),
                      ),
                      trailing: priest && editable
                          ? IconButton(
                              tooltip: 'Chỉ định ca trưởng thay thế',
                              onPressed: _busy
                                  ? null
                                  : () => _replaceDirector(choir),
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                            )
                          : null,
                    ),
                  ),
                if (priest && editable)
                  OutlinedButton(
                    onPressed: _busy ? null : () => _editChoirs(choirs),
                    child: const Text('Chọn ca đoàn phục vụ'),
                  ),

                if (published) _songSection(canPropose),
                if (published && widget.role == MobileRole.choirDirector) ...[
                  _Tile(
                    icon: Icons.event_outlined,
                    title: 'Lịch tập của chương trình',
                    onTap: () => context.push(
                      Uri(
                        path: '/staff-rehearsals',
                        queryParameters: {'eventId': _id},
                      ).toString(),
                    ),
                  ),
                  _Tile(
                    icon: Icons.assignment_ind_outlined,
                    title: 'Phân công phục vụ',
                    onTap: () => context.push(_detailPath('staff-roster', _id)),
                  ),
                ],
              ],
            );
          },
        ),
        if (widget.event.requirements?.trim().isNotEmpty == true)
          _Tile(
            icon: Icons.edit_note_rounded,
            title: 'Ghi chú mục vụ & Dặn dò phòng áo',
            subtitle: widget.event.requirements,
          ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
    final footer = priest && widget.event.status == 'Draft' && editable
        ? StaffWorkflowBar(
            child: FilledButton.icon(
              onPressed: _busy || lead?.isActive != true ? null : _publish,
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Công bố phụng vụ'),
            ),
          )
        : null;
    return widget.builder(content, footer);
  }

  Widget _songSection(bool canPropose) {
    final provider = _latestList(_id);
    return ref
        .watch(provider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => TextButton(
            onPressed: () => ref.invalidate(provider),
            child: const Text('Tải lại danh sách bài hát'),
          ),
          data: (list) {
            final canEdit =
                canPropose &&
                (list == null ||
                    const [
                      'Draft',
                      'Rejected',
                      'NeedsRevision',
                    ].contains(list.status));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Danh sách bài hát',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (list == null)
                  const Text('Chưa có danh sách được gửi.')
                else
                  _Tile(
                    icon: Icons.library_music_outlined,
                    title: _songListStatus(list.status),
                    subtitle: 'Phiên bản ${list.version}',
                    onTap: () =>
                        context.push(_detailPath('song-list', list.id)),
                  ),
                if (canEdit)
                  FilledButton(
                    onPressed: _busy ? null : () => _propose(list),
                    child: Text(
                      list?.status == 'Draft'
                          ? 'Sửa bản nháp'
                          : 'Đề xuất bài hát',
                    ),
                  ),
                if (!canPropose && widget.role == MobileRole.choirDirector)
                  const Text(
                    'Ca trưởng của ca đoàn phụ trách hoặc người thay có thể đề xuất bài hát.',
                  ),
              ],
            );
          },
        );
  }
}

class _SongListReview extends ConsumerStatefulWidget {
  const _SongListReview({super.key, required this.list, required this.builder});
  final SongListDto list;
  final Widget Function(Widget notes, Widget footer) builder;

  @override
  ConsumerState<_SongListReview> createState() => _SongListReviewState();
}

class _SongListReviewState extends ConsumerState<_SongListReview> {
  final _notes = TextEditingController();
  final _notesFocus = FocusNode();
  bool _busy = false;
  bool _decided = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  Future<void> _review(String decision, String label) async {
    if (_busy || _decided) return;
    final note = _notes.text.trim();
    if (decision != 'Approve' && note.isEmpty) {
      setState(
        () =>
            _error = 'Nhập nhận xét trước khi yêu cầu chỉnh sửa hoặc từ chối.',
      );
      _notesFocus.requestFocus();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: const Text('Xác nhận quyết định cho danh sách bài hát này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(staffWorkspaceRepositoryProvider)
          .reviewProposal(widget.list.id, decision, note.isEmpty ? null : note);
      if (!mounted) return;
      setState(() => _decided = true);
      ref.invalidate(_songList(widget.list.id));
      ref.invalidate(_approvals);
      ref.invalidate(_latestList(widget.list.eventId));
      ref.invalidate(eventApprovedSongListProvider(widget.list.eventId));
    } catch (error) {
      if (mounted) setState(() => _error = ErrorMessages.forException(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _busy || _decided;
    final notes = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nhận xét của Cha xứ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('Bắt buộc khi yêu cầu chỉnh sửa hoặc từ chối đề xuất.'),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              focusNode: _notesFocus,
              enabled: !disabled,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Nhập ý kiến chỉ đạo hoặc lý do cần chỉnh sửa…',
                fillColor: AppColors.surfaceContainerLow,
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
        ),
      ),
    );
    final footer = StaffWorkflowBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: disabled
                ? null
                : () => _review('Approve', 'Phê duyệt danh sách'),
            icon: const Icon(Icons.check),
            label: const Text('Phê duyệt danh sách'),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.statusWarning,
                ),
                onPressed: disabled
                    ? null
                    : () => _review('RequestRevision', 'Yêu cầu chỉnh sửa'),
                child: const Text('Yêu cầu chỉnh sửa'),
              ),
              OutlinedButton(
                onPressed: disabled
                    ? null
                    : () => _review('Reject', 'Từ chối đề xuất'),
                child: const Text('Từ chối đề xuất'),
              ),
            ],
          ),
        ],
      ),
    );
    return widget.builder(notes, footer);
  }
}

class _ServingChoirDialog extends StatefulWidget {
  const _ServingChoirDialog({
    required this.current,
    required this.available,
    required this.published,
  });
  final List<ServingChoir> current;
  final List<StaffChoir> available;
  final bool published;

  @override
  State<_ServingChoirDialog> createState() => _ServingChoirDialogState();
}

class _ServingChoirDialogState extends State<_ServingChoirDialog> {
  late ChoirSelection _selection;
  String _reason = '';

  @override
  void initState() {
    super.initState();
    _selection = (
      ids: widget.current.map((choir) => choir.id).toSet(),
      lead:
          widget.current.where((choir) => choir.isLead).firstOrNull?.id ??
          (widget.current.length == 1 ? widget.current.first.id : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIds = widget.current.map((choir) => choir.id).toSet();
    final removing =
        widget.published && currentIds.difference(_selection.ids).isNotEmpty;
    final choices = [
      for (final choir in widget.current) (id: choir.id, name: choir.name),
      for (final choir in widget.available)
        if (choir.isActive &&
            choir.id.isNotEmpty &&
            !currentIds.contains(choir.id))
          (id: choir.id, name: choir.name),
    ];
    return AlertDialog(
      title: const Text('Chọn ca đoàn'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ServingChoirFields(
            options: choices,
            value: _selection,
            onChanged: (value) => setState(() => _selection = value),
          ),
          if (removing) ...[
            const SizedBox(height: 12),
            const Text(
              'Lời mời và phân công của ca viên không còn ca đoàn phục vụ sẽ bị gỡ.',
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Lý do gỡ ca đoàn'),
              maxLength: 500,
              maxLines: 3,
              onChanged: (value) => setState(() => _reason = value.trim()),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _selection.lead == null || (removing && _reason.isEmpty)
              ? null
              : () => Navigator.pop(context, (
                  selection: _selection,
                  reason: removing ? _reason : null,
                )),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

class _SubstituteDialog extends StatefulWidget {
  const _SubstituteDialog({required this.choir, required this.directors});
  final ServingChoir choir;
  final List<StaffDirector> directors;

  @override
  State<_SubstituteDialog> createState() => _SubstituteDialogState();
}

class _SubstituteDialogState extends State<_SubstituteDialog> {
  late String? _directorId;
  String _reason = '';

  @override
  void initState() {
    super.initState();
    _directorId =
        widget.directors.any(
          (director) => director.id == widget.choir.substituteId,
        )
        ? widget.choir.substituteId
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final changed = _directorId != widget.choir.substituteId;
    return AlertDialog(
      title: const Text('Ca trưởng thay thế'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.choir.name),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _directorId,
            hint: const Text('Không chỉ định'),
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Người thay'),
            items: [
              const DropdownMenuItem(child: Text('Không chỉ định')),
              for (final director in widget.directors)
                DropdownMenuItem(
                  value: director.id,
                  child: Text(director.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _directorId = value),
          ),
          if (_directorId != null)
            TextField(
              decoration: const InputDecoration(labelText: 'Lý do chỉ định'),
              maxLength: 500,
              maxLines: 2,
              onChanged: (value) => setState(() => _reason = value.trim()),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: !changed || (_directorId != null && _reason.isEmpty)
              ? null
              : () => Navigator.pop(context, (
                  directorId: _directorId,
                  reason: _directorId == null ? null : _reason,
                )),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

String _detailPath(String segment, String id) =>
    Uri(pathSegments: ['', segment, id]).toString();

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: subtitle == null || subtitle!.isEmpty ? null : Text(subtitle!),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _DataPage<T> extends StatelessWidget {
  const _DataPage({
    required this.title,
    required this.data,
    required this.onRefresh,
    required this.rows,
    this.backPath,
    this.workflowRole,
    this.workflowSubtitle,
    this.footer,
  });

  final String title;
  final String? workflowRole, workflowSubtitle;
  final Widget? footer;
  final AsyncValue<T> data;
  final Future<T> Function() onRefresh;
  final List<Widget> Function(T) rows;
  final String? backPath;

  @override
  Widget build(BuildContext context) {
    return _StaffPage(
      title: title,
      backPath: backPath,
      workflowRole: workflowRole,
      workflowSubtitle: workflowSubtitle,
      footer: footer,
      onRefresh: () async {
        try {
          await onRefresh();
        } catch (_) {
          // The provider renders its error state.
        }
      },
      children: data.when(
        data: rows,
        loading: () => const [Center(child: CircularProgressIndicator())],
        error: (error, _) => [
          Text(ErrorMessages.forException(error)),
          OutlinedButton(
            onPressed: () async {
              try {
                await onRefresh();
              } catch (_) {
                // The provider renders its error state.
              }
            },
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

class _StaffPage extends StatelessWidget {
  const _StaffPage({
    required this.title,
    required this.children,
    this.backPath,
    this.onRefresh,
    this.workflowRole,
    this.workflowSubtitle,
    this.footer,
  });
  final String title;
  final String? workflowRole, workflowSubtitle;
  final Widget? footer;
  final List<Widget> children;
  final String? backPath;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: children,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppPageHeader(
        title: workflowRole == null
            ? Text(title)
            : StaffWorkflowTitle(
                title: title,
                role: workflowRole!,
                subtitle: workflowSubtitle,
              ),
        large: backPath == null || workflowRole != null,
        actions: [
          if (workflowRole != null && onRefresh != null)
            IconButton(
              tooltip: 'Tải lại',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: onRefresh,
            ),
        ],
        leading: backPath != null && !context.canPop()
            ? BackButton(onPressed: () => context.go(backPath!))
            : null,
      ),
      bottomNavigationBar: footer,
      body: SafeArea(
        bottom: footer == null,
        child: onRefresh == null
            ? list
            : RefreshIndicator(onRefresh: onRefresh!, child: list),
      ),
    );
  }
}
