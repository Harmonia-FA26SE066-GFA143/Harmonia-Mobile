import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lookups/data/lookups_api_service.dart';
import '../../music/data/music_dto.dart';
import '../data/staff_operations_api.dart';
import '../data/staff_practice_providers.dart';
import '../data/staff_workspace_repository.dart';
import 'staff_ops_widgets.dart';
import 'staff_song_proposal.dart';

final _choirMembers = FutureProvider.autoDispose.family(
  (Ref ref, String choirId) =>
      ref.watch(staffOperationsApiProvider).choirMembers(choirId),
);
final _skills = FutureProvider.autoDispose(
  (ref) => ref.watch(lookupsApiServiceProvider).getSkills(),
);
final _songMaterials = FutureProvider.autoDispose.family((
  Ref ref,
  String songId,
) async {
  final api = ref.watch(staffOperationsApiProvider);
  final choices = <Choice>[];
  var page = 1;
  while (true) {
    final result = await api.songMaterials(songId, page);
    choices.addAll(
      result.items.map(
        (item) =>
            (id: item.id, name: '${item.title} · ${item.materialType.label}'),
      ),
    );
    if (!result.hasNextPage) return choices;
    page++;
  }
});

class StaffAssignmentForm extends ConsumerStatefulWidget {
  const StaffAssignmentForm({super.key, this.initialEventId});
  final String? initialEventId;

  @override
  ConsumerState<StaffAssignmentForm> createState() =>
      _StaffAssignmentFormState();
}

class _StaffAssignmentFormState extends ConsumerState<StaffAssignmentForm>
    with OpsActions<StaffAssignmentForm>, AutomaticKeepAliveClientMixin {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _instruction = TextEditingController();
  final _skillIds = <String>{};
  final _memberIds = <String>{};
  final _materialIds = <String>{};
  String? _choirId;
  late String? _eventId = widget.initialEventId;
  SongDto? _song;
  DateTime? _dueDate;
  StaffPracticeScope _scope = StaffPracticeScope.all;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _title.dispose();
    _instruction.dispose();
    super.dispose();
  }

  Future<void> _pickSong() async {
    final song = await showDialog<SongDto>(
      context: context,
      builder: (_) => const StaffSongPicker(),
    );
    if (mounted && song != null && song.id != _song?.id) {
      setState(() {
        _song = song;
        _materialIds.clear();
      });
    }
  }

  Future<void> _pickChoices(
    String title,
    List<Choice> options,
    Set<String> selected,
  ) async {
    final value = await showDialog<Set<String>>(
      context: context,
      builder: (_) =>
          OpsChoicePicker(title: title, choices: options, selected: selected),
    );
    if (mounted && value != null) {
      setState(() {
        selected
          ..clear()
          ..addAll(value);
      });
    }
  }

  Widget _choiceButton(
    String title,
    List<Choice> choices,
    Set<String> selected, {
    required String empty,
  }) => choices.isEmpty
      ? Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(empty))
      : OutlinedButton(
          onPressed: busy ? null : () => _pickChoices(title, choices, selected),
          child: Text('$title (${selected.length})'),
        );

  String? _lengthError(String? value, int max, {bool requiredText = false}) {
    final text = value?.trim() ?? '';
    if (requiredText && text.isEmpty) return 'Vui lòng nhập tiêu đề.';
    return text.length > max ? 'Tối đa $max ký tự.' : null;
  }

  Future<void> _submit(String? choirId, String? eventId) async {
    if (busy || !_form.currentState!.validate()) return;
    final dueDate = _dueDate;
    final problem = switch ((choirId, dueDate, _scope)) {
      (null, _, _) => 'Vui lòng chọn ca đoàn.',
      (_, null, _) => 'Vui lòng chọn hạn nộp.',
      (_, final due?, _) when !due.isAfter(DateTime.now()) =>
        'Hạn nộp phải sau thời điểm hiện tại.',
      (_, _, StaffPracticeScope.skillGroup) when _skillIds.isEmpty =>
        'Vui lòng chọn ít nhất một kỹ năng.',
      (_, _, StaffPracticeScope.individual) when _memberIds.isEmpty =>
        'Vui lòng chọn ít nhất một ca viên.',
      _ => null,
    };
    if (problem != null) {
      setState(() => actionError = problem);
      return;
    }
    final instruction = _instruction.text.trim();
    final api = ref.read(staffOperationsApiProvider);
    final created = await runAction(
      () => api.createPracticeAssignment(
        choirId: choirId!,
        eventId: eventId,
        songId: _song?.id,
        materialIds: _materialIds.toList(),
        title: _title.text.trim(),
        instruction: instruction.isEmpty ? null : instruction,
        scope: _scope,
        dueDate: dueDate!,
        skillIds: _skillIds.toList(),
        memberIds: _memberIds.toList(),
      ),
    );
    if (!created || !mounted) return;
    ref.invalidate(staffPracticeAssignmentsProvider);
    ref.invalidate(staffPreparationProgressProvider);
    setState(() {
      _title.clear();
      _instruction.clear();
      _song = null;
      _dueDate = null;
      _scope = StaffPracticeScope.all;
      _skillIds.clear();
      _memberIds.clear();
      _materialIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã giao bài tập. Xem lại ở thẻ Bài đã giao.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final choirs = ref.watch(staffChoirsProvider);
    final active =
        choirs.asData?.value.where((choir) => choir.isActive).toList() ??
        const <StaffChoir>[];
    final choirId = active.any((choir) => choir.id == _choirId)
        ? _choirId
        : _choirId == null && active.length == 1
        ? active.single.id
        : null;

    final events = ref.watch(staffUpcomingPracticeEventsProvider);
    final upcoming = events.asData?.value ?? const <StaffEvent>[];
    final eventId = upcoming.any((event) => event.id == _eventId)
        ? _eventId
        : null;
    final missingEvent = _eventId != null && eventId == null;
    final song = _song;

    return PopScope(
      canPop: !busy,
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            OpsAsync(
              value: choirs,
              onRetry: () => ref.invalidate(staffChoirsProvider),
              data: (_) => active.isEmpty
                  ? const Text('Bạn chưa phụ trách ca đoàn nào đang hoạt động.')
                  : OpsChoiceField(
                      label: 'Ca đoàn',
                      value: choirId,
                      options: [
                        for (final choir in active)
                          (id: choir.id, name: choir.name),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              _choirId = value;
                              _memberIds.clear();
                            }),
                    ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _title,
              enabled: !busy,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Tiêu đề bài tập'),
              validator: (value) =>
                  _lengthError(value, 200, requiredText: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _instruction,
              enabled: !busy,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Hướng dẫn (không bắt buộc)',
              ),
              validator: (value) => _lengthError(value, 1000),
            ),
            const SizedBox(height: 8),
            OpsChoiceField(
              label: 'Chương trình phụng vụ (không bắt buộc)',
              value: eventId,
              optional: true,
              emptyLabel: 'Không gắn chương trình',
              options: [
                for (final event in upcoming)
                  (
                    id: event.id,
                    name: '${opsDay(event.date)} · ${event.title}',
                  ),
              ],
              onChanged: busy || events.isLoading
                  ? null
                  : (value) => setState(() => _eventId = value),
            ),
            if (events.hasError)
              TextButton(
                onPressed: () =>
                    ref.invalidate(staffUpcomingPracticeEventsProvider),
                child: const Text('Tải lại chương trình'),
              ),
            if (missingEvent && !events.isLoading)
              TextButton(
                onPressed: busy ? null : () => setState(() => _eventId = null),
                child: const Text(
                  'Chương trình không có trong lịch sắp tới. Bỏ liên kết',
                ),
              ),
            if (eventId != null)
              const Text('Ca đoàn phải phục vụ chương trình được chọn.'),
            OutlinedButton.icon(
              onPressed: busy ? null : _pickSong,
              icon: const Icon(Icons.library_music_outlined),
              label: Text(song?.title ?? 'Chọn bài hát (không bắt buộc)'),
            ),
            if (song != null) ...[
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        _song = null;
                        _materialIds.clear();
                      }),
                child: const Text('Bỏ bài hát'),
              ),
              OpsAsync(
                value: ref.watch(_songMaterials(song.id)),
                onRetry: () => ref.invalidate(_songMaterials(song.id)),
                data: (choices) => _choiceButton(
                  'Chọn tài liệu gửi kèm',
                  choices,
                  _materialIds,
                  empty: 'Bài hát chưa có tài liệu gửi kèm.',
                ),
              ),
            ],
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final date = await pickOpsTime(
                        context,
                        _dueDate ?? DateTime.now().add(const Duration(days: 1)),
                      );
                      if (mounted && date != null) {
                        setState(() => _dueDate = date);
                      }
                    },
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _dueDate == null
                    ? 'Chọn hạn nộp'
                    : 'Hạn nộp ${opsTime(_dueDate!)}',
              ),
            ),
            const SizedBox(height: 10),
            OpsChoiceField(
              label: 'Giao cho',
              value: _scope.wireName,
              options: [
                for (final scope in StaffPracticeScope.values)
                  (id: scope.wireName, name: scope.label),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _scope = StaffPracticeScope.values.firstWhere(
                          (scope) => scope.wireName == value,
                        );
                      });
                    },
            ),
            if (_scope == StaffPracticeScope.skillGroup)
              OpsAsync(
                value: ref.watch(_skills),
                onRetry: () => ref.invalidate(_skills),
                data: (skills) => _choiceButton(
                  'Chọn kỹ năng',
                  [
                    for (final skill in skills)
                      (id: skill.id, name: skill.name),
                  ],
                  _skillIds,
                  empty: 'Chưa có kỹ năng để chọn.',
                ),
              ),
            if (_scope == StaffPracticeScope.individual)
              if (choirId == null)
                const Text('Chọn ca đoàn trước khi chọn ca viên.')
              else
                OpsAsync(
                  value: ref.watch(_choirMembers(choirId)),
                  onRetry: () => ref.invalidate(_choirMembers(choirId)),
                  data: (members) => _choiceButton(
                    'Chọn ca viên',
                    [
                      for (final member in members)
                        (id: member.id, name: member.name),
                    ],
                    _memberIds,
                    empty: 'Ca đoàn chưa có ca viên để giao bài.',
                  ),
                ),
            const SizedBox(height: 16),
            actionState,
            FilledButton.icon(
              onPressed: busy || active.isEmpty || missingEvent
                  ? null
                  : () => _submit(choirId, eventId),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Giao bài tập'),
            ),
          ],
        ),
      ),
    );
  }
}
