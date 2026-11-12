import 'dart:async';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_messages.dart';
import '../../lookups/data/lookups_api_service.dart';
import '../../music/data/music_dto.dart';
import '../data/staff_documents.dart';
import '../data/staff_operations_api.dart';
import 'staff_ops_widgets.dart';

const _documents = ['pdf', 'png', 'jpg'];
const _audio = ['mp3', 'm4a', 'wav', 'mid', 'midi'];
const _extensions = {
  MaterialType.sheetMusic: _documents,
  MaterialType.lyrics: ['docx'],
  MaterialType.sampleAudio: _audio,
  MaterialType.rehearsalMaterial: [..._documents, ..._audio],
  MaterialType.interactiveScore: ['musicxml', 'mxl'],
};

final _targetSkills = FutureProvider.autoDispose(
  (ref) => ref.watch(lookupsApiServiceProvider).getSkills(),
);

class StaffDocumentField extends StatefulWidget {
  const StaffDocumentField({
    super.key,
    required this.extensions,
    required this.onChanged,
    required this.enabled,
  });

  final List<String> extensions;
  final ValueChanged<StaffDocument> onChanged;
  final bool enabled;

  @override
  State<StaffDocumentField> createState() => _StaffDocumentFieldState();
}

class _StaffDocumentFieldState extends State<StaffDocumentField> {
  StaffDocument? _file;
  bool _picking = false;
  String? _error;

  @override
  void dispose() {
    unawaited(_file?.dispose());
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final file = await StaffDocuments.pick(widget.extensions);
      if (file == null) return;
      if (!mounted) {
        await file.dispose();
        return;
      }
      unawaited(_file?.dispose());
      setState(() => _file = file);
      widget.onChanged(file);
    } catch (error) {
      if (mounted) setState(() => _error = ErrorMessages.forException(error));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: !widget.enabled || _picking ? null : _pick,
        icon: const Icon(Icons.attach_file),
        label: Text(_file?.name ?? 'Chọn tệp'),
      ),
      Text(
        '${widget.extensions.map((ext) => ext.toUpperCase()).join(', ')} · Tối đa 20 MB',
      ),
      if (_error case final error?)
        Text(
          error,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}

class StaffMaterialEditor extends ConsumerStatefulWidget {
  const StaffMaterialEditor({super.key, required this.songId, this.current});
  final String songId;
  final MusicMaterialDto? current;

  @override
  ConsumerState<StaffMaterialEditor> createState() =>
      _StaffMaterialEditorState();
}

class _StaffMaterialEditorState extends ConsumerState<StaffMaterialEditor>
    with OpsActions<StaffMaterialEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _lyrics = TextEditingController();
  late MaterialType _type =
      widget.current?.materialType ?? MaterialType.sheetMusic;
  StaffDocument? _file;
  String? _target;
  String _instrument = 'Piano';
  bool _lyricsMode = false;
  bool _resetProgress = false;

  bool get _replacing => widget.current != null;

  @override
  void dispose() {
    _title.dispose();
    _lyrics.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final file = _file;
    if (!_lyricsMode && file == null) {
      setState(() => actionError = 'Vui lòng chọn tệp.');
      return;
    }
    final instrument = file?.needsPlaybackInstrument == true
        ? _instrument
        : null;
    final api = ref.read(staffOperationsApiProvider);
    final saved = await runAction(
      () => _replacing
          ? api.replaceMaterialFile(
              widget.current!.id,
              file!,
              resetProgress: _resetProgress,
              instrument: instrument,
            )
          : api.uploadMaterial(
              songId: widget.songId,
              type: _type,
              title: _title.text.trim(),
              targetSkillId: _target,
              lyricsText: _lyricsMode ? _lyrics.text.trim() : null,
              file: file,
              instrument: instrument,
            ),
    );
    if (!saved || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _replacing ? 'Đã thay tệp tài liệu.' : 'Đã tải tài liệu lên.',
        ),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: OpsPage(
      title: _replacing ? 'Thay tệp tài liệu' : 'Tải tài liệu lên',
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_replacing) ...[
              OpsTile(
                icon: Icons.description_outlined,
                title: widget.current!.title,
                subtitle: widget.current!.materialType.label,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đặt lại tiến độ học'),
                subtitle: const Text(
                  'Dùng khi nội dung mới cần ca viên học lại.',
                ),
                value: _resetProgress,
                onChanged: busy
                    ? null
                    : (value) => setState(() => _resetProgress = value),
              ),
            ] else ...[
              TextFormField(
                controller: _title,
                enabled: !busy,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề tài liệu',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Vui lòng nhập tiêu đề.';
                  return text.length > 200 ? 'Tiêu đề tối đa 200 ký tự.' : null;
                },
              ),
              OpsChoiceField(
                label: 'Loại tài liệu',
                value: _type.wireName,
                options: [
                  for (final type in _extensions.keys)
                    (id: type.wireName, name: type.label),
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        if (value == null || value == _type.wireName) return;
                        setState(() {
                          _type = MaterialType.fromWire(value);
                          _lyricsMode = false;
                          _file = null;
                        });
                      },
              ),
              OpsAsync(
                value: ref.watch(_targetSkills),
                onRetry: () => ref.invalidate(_targetSkills),
                data: (skills) => OpsChoiceField(
                  label: 'Kỹ năng nhận tài liệu',
                  optional: true,
                  emptyLabel: 'Cả ca đoàn',
                  value: _target,
                  options: [
                    for (final skill in skills)
                      (id: skill.id, name: skill.name),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() => _target = value),
                ),
              ),
              if (_type == MaterialType.lyrics)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Nhập lời bài hát trực tiếp'),
                  value: _lyricsMode,
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          _lyricsMode = value;
                          _file = null;
                        }),
                ),
            ],
            if (_lyricsMode)
              TextFormField(
                controller: _lyrics,
                enabled: !busy,
                maxLength: 20000,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(labelText: 'Lời bài hát'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Vui lòng nhập lời bài hát.';
                  return text.length > 20000
                      ? 'Lời bài hát tối đa 20.000 ký tự.'
                      : null;
                },
              )
            else
              StaffDocumentField(
                key: ValueKey(_type),
                extensions: _extensions[_type]!,
                onChanged: (file) => setState(() => _file = file),
                enabled: !busy,
              ),
            if (_file?.needsPlaybackInstrument == true) ...[
              const SizedBox(height: 12),
              OpsChoiceField(
                label: 'Nhạc cụ phát bản nhạc',
                value: _instrument,
                options: const [
                  (id: 'Piano', name: 'Piano'),
                  (id: 'Organ', name: 'Organ'),
                  (id: 'Guitar', name: 'Guitar'),
                  (id: 'StringEnsemble', name: 'Dàn dây'),
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        if (value != null) setState(() => _instrument = value);
                      },
              ),
              const SizedBox(height: 8),
              const Text('Máy chủ có thể mất vài giây để dựng tệp WAV.'),
            ],
            const SizedBox(height: 12),
            actionState,
            FilledButton(
              onPressed: busy ? null : _save,
              child: Text(_replacing ? 'Lưu tệp thay thế' : 'Tải lên'),
            ),
          ],
        ),
      ),
    ),
  );
}
