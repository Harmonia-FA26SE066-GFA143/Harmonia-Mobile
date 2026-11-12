import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lookups/data/lookups_api_service.dart';
import '../../music/data/music_dto.dart';
import '../data/staff_operations_api.dart';
import 'staff_ops_widgets.dart';

Future<SongDto?> showStaffSongEditor(BuildContext context, {SongDto? song}) =>
    showDialog<SongDto>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SongEditor(song: song),
    );

const _songFields = [
  (key: 'title', label: 'Tên bài hát', max: 200),
  (key: 'composer', label: 'Nhạc sĩ', max: 150),
  (key: 'lyricist', label: 'Tác giả lời', max: 150),
  (key: 'musicalKey', label: 'Giọng', max: 10),
  (key: 'tempo', label: 'Nhịp độ', max: 50),
  (key: 'notes', label: 'Ghi chú', max: 1000),
];

class _SongEditor extends ConsumerStatefulWidget {
  const _SongEditor({this.song});
  final SongDto? song;

  @override
  ConsumerState<_SongEditor> createState() => _SongEditorState();
}

class _SongEditorState extends ConsumerState<_SongEditor>
    with OpsActions<_SongEditor> {
  final _form = GlobalKey<FormState>();
  late final _values = widget.song?.toJson() ?? <String, dynamic>{};

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    final api = ref.read(staffOperationsApiProvider);
    SongDto? song;
    final saved = await runAction(() async {
      song = await api.saveSong(SongDto.fromJson(_values), id: widget.song?.id);
    });
    if (saved && mounted) Navigator.of(context).pop(song);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      scrollable: true,
      title: Text(
        widget.song == null ? 'Thêm bài hát' : 'Sửa thông tin bài hát',
      ),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in _songFields)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextFormField(
                  initialValue: _values[field.key] as String?,
                  enabled: !busy,
                  maxLength: field.max,
                  maxLines: field.key == 'notes' ? 3 : 1,
                  decoration: InputDecoration(
                    labelText: field.label,
                    counterText: '',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (field.key == 'title' && text.isEmpty) {
                      return 'Vui lòng nhập tên bài hát.';
                    }
                    return text.length > field.max
                        ? 'Tối đa ${field.max} ký tự.'
                        : null;
                  },
                  onSaved: (value) {
                    final text = value?.trim() ?? '';
                    _values[field.key] = text.isEmpty ? null : text;
                  },
                ),
              ),
            actionState,
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: busy ? null : _save,
          child: const Text('Lưu bài hát'),
        ),
      ],
    ),
  );
}

const _dimensions = {
  'liturgicalSeasonIds': 'Mùa phụng vụ',
  'massTypeIds': 'Loại Thánh lễ',
  'ceremonyTypeIds': 'Loại nghi thức',
  'liturgicalSlotIds': 'Phần phụng vụ',
  'songThemeIds': 'Chủ đề',
};

typedef _Requirement = ({String id, String name, int count, bool mandatory});
typedef _ClassificationFormData = ({
  Map<String, List<Choice>> catalog,
  Map<String, List<Choice>> current,
  List<_Requirement> vocals,
  List<_Requirement> instruments,
  List<Choice> vocalChoices,
  List<Choice> instrumentChoices,
});

List<Choice> _summaryChoices(List<SongClassificationSummaryDto> items) => [
  for (final row in items) (id: row.id, name: row.name),
];

final _classification = FutureProvider.autoDispose.family((
  Ref ref,
  String songId,
) async {
  final api = ref.watch(staffOperationsApiProvider);
  final lookups = ref.watch(lookupsApiServiceProvider);
  final (
    song,
    seasons,
    masses,
    ceremonies,
    slots,
    themes,
    skills,
    categories,
  ) = await (
    api.songClassification(songId),
    lookups.getLiturgicalSeasons(),
    lookups.getMassTypes(),
    lookups.getCeremonyTypes(),
    lookups.getLiturgicalSlots(),
    lookups.getSongThemes(),
    lookups.getSkills(),
    lookups.getSkillCategories(),
  ).wait;
  final instrumentCategory = categories
      .where(
        (row) => const {
          'nhạc cụ',
          'instrument',
        }.contains(row.name.trim().toLowerCase()),
      )
      .firstOrNull
      ?.id;
  return (
    catalog: <String, List<Choice>>{
      'liturgicalSeasonIds': [
        for (final row in seasons) (id: row.id, name: row.name),
      ],
      'massTypeIds': [for (final row in masses) (id: row.id, name: row.name)],
      'ceremonyTypeIds': [
        for (final row in ceremonies) (id: row.id, name: row.name),
      ],
      'liturgicalSlotIds': [
        for (final row in slots) (id: row.id, name: row.name),
      ],
      'songThemeIds': [for (final row in themes) (id: row.id, name: row.name)],
    },
    current: <String, List<Choice>>{
      'liturgicalSeasonIds': _summaryChoices(song.liturgicalSeasons),
      'massTypeIds': _summaryChoices(song.massTypes),
      'ceremonyTypeIds': _summaryChoices(song.ceremonyTypes),
      'liturgicalSlotIds': _summaryChoices(song.liturgicalSlots),
      'songThemeIds': _summaryChoices(song.songThemes),
    },
    vocals: <_Requirement>[
      for (final row in song.vocalRequirements)
        (
          id: row.skillId,
          name: row.skillName,
          count: row.requiredCount,
          mandatory: row.isMandatory,
        ),
    ],
    instruments: <_Requirement>[
      for (final row in song.instrumentRequirements)
        (
          id: row.skillId,
          name: row.skillName,
          count: row.requiredCount,
          mandatory: row.isMandatory,
        ),
    ],
    vocalChoices: <Choice>[
      for (final row in skills)
        if (row.categoryId != instrumentCategory) (id: row.id, name: row.name),
    ],
    instrumentChoices: <Choice>[
      for (final row in skills)
        if (instrumentCategory == null || row.categoryId == instrumentCategory)
          (id: row.id, name: row.name),
    ],
  );
});

class StaffSongClassificationScreen extends ConsumerWidget {
  const StaffSongClassificationScreen({super.key, required this.songId});
  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = _classification(songId);
    return OpsPage(
      title: 'Phân loại bài hát',
      child: OpsAsync(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (data) => _ClassificationForm(songId: songId, data: data),
      ),
    );
  }
}

class _ClassificationForm extends ConsumerStatefulWidget {
  const _ClassificationForm({required this.songId, required this.data});
  final String songId;
  final _ClassificationFormData data;

  @override
  ConsumerState<_ClassificationForm> createState() =>
      _ClassificationFormState();
}

class _ClassificationFormState extends ConsumerState<_ClassificationForm>
    with OpsActions<_ClassificationForm> {
  final _form = GlobalKey<FormState>();
  late final _selected = {
    for (final entry in widget.data.current.entries)
      entry.key: {for (final choice in entry.value) choice.id},
  };
  late final _vocal = {for (final row in widget.data.vocals) row.id: row};
  late final _instrument = {
    for (final row in widget.data.instruments) row.id: row,
  };

  Future<Set<String>?> _pick(
    String label,
    List<Choice> options,
    Set<String> current,
  ) => showDialog<Set<String>>(
    context: context,
    builder: (_) =>
        OpsChoicePicker(title: label, choices: options, selected: current),
  );

  Future<void> _editDimension(String key, String label) async {
    final options = {
      for (final item in [
        ...widget.data.catalog[key]!,
        ...widget.data.current[key]!,
      ])
        item.id: item,
    };
    final selected = await _pick(
      label,
      options.values.toList(),
      _selected[key]!,
    );
    if (mounted && selected != null) setState(() => _selected[key] = selected);
  }

  Future<void> _editRequirements(
    String label,
    List<Choice> choices,
    List<_Requirement> initial,
    Map<String, _Requirement> current,
  ) async {
    final options = {
      for (final item in choices) item.id: item,
      for (final item in initial) item.id: (id: item.id, name: item.name),
    };
    final selected = await _pick(
      label,
      options.values.toList(),
      current.keys.toSet(),
    );
    if (!mounted || selected == null) return;
    setState(() {
      current.removeWhere((id, _) => !selected.contains(id));
      for (final id in selected) {
        current.putIfAbsent(
          id,
          () => (id: id, name: options[id]!.name, count: 1, mandatory: false),
        );
      }
    });
  }

  List<Map<String, Object>> _body(Map<String, _Requirement> values) => [
    for (final row in values.values)
      {
        'skillId': row.id,
        'isMandatory': row.mandatory,
        'requiredCount': row.count,
      },
  ];

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final api = ref.read(staffOperationsApiProvider);
    final saved = await runAction(
      () => api.saveSongClassification(widget.songId, {
        for (final entry in _selected.entries) entry.key: entry.value.toList(),
        'vocalRequirements': _body(_vocal),
        'instrumentRequirements': _body(_instrument),
      }),
    );
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu phân loại bài hát.')),
      );
      Navigator.of(context).pop();
    }
  }

  Widget _requirements(
    String title,
    Map<String, _Requirement> values,
    VoidCallback edit,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton(
        onPressed: busy ? null : edit,
        child: Text('$title (${values.length})'),
      ),
      for (final row in values.values)
        Card(
          key: ValueKey((title, row.id)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(row.name),
                TextFormField(
                  initialValue: row.count.toString(),
                  enabled: !busy,
                  decoration: const InputDecoration(labelText: 'Số người'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final count = int.tryParse(value?.trim() ?? '');
                    return count == null || count < 1 || count > 50
                        ? 'Nhập số nguyên từ 1 đến 50.'
                        : null;
                  },
                  onChanged: (value) {
                    final current = values[row.id]!;
                    values[row.id] = (
                      id: current.id,
                      name: current.name,
                      count: int.tryParse(value.trim()) ?? 0,
                      mandatory: current.mandatory,
                    );
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bắt buộc'),
                  value: row.mandatory,
                  onChanged: busy
                      ? null
                      : (checked) => setState(() {
                          final current = values[row.id]!;
                          values[row.id] = (
                            id: current.id,
                            name: current.name,
                            count: current.count,
                            mandatory: checked == true,
                          );
                        }),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final field in _dimensions.entries)
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => _editDimension(field.key, field.value),
              child: Text('${field.value} (${_selected[field.key]!.length})'),
            ),
          const SizedBox(height: 8),
          _requirements(
            'Yêu cầu bè giọng',
            _vocal,
            () => _editRequirements(
              'Yêu cầu bè giọng',
              widget.data.vocalChoices,
              widget.data.vocals,
              _vocal,
            ),
          ),
          _requirements(
            'Yêu cầu nhạc cụ',
            _instrument,
            () => _editRequirements(
              'Yêu cầu nhạc cụ',
              widget.data.instrumentChoices,
              widget.data.instruments,
              _instrument,
            ),
          ),
          actionState,
          FilledButton(
            onPressed: busy ? null : _save,
            child: const Text('Lưu phân loại'),
          ),
        ],
      ),
    ),
  );
}
