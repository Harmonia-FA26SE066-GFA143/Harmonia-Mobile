import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/data/calendar_repository.dart';
import '../data/staff_documents.dart';
import '../data/staff_operations_api.dart';
import 'staff_material_editor.dart' show StaffDocumentField;
import 'staff_ops_widgets.dart';

class StaffRehearsalRecordingEditor extends ConsumerStatefulWidget {
  const StaffRehearsalRecordingEditor({super.key, required this.rehearsalId});
  final String rehearsalId;

  @override
  ConsumerState<StaffRehearsalRecordingEditor> createState() =>
      _StaffRehearsalRecordingEditorState();
}

class _StaffRehearsalRecordingEditorState
    extends ConsumerState<StaffRehearsalRecordingEditor>
    with OpsActions<StaffRehearsalRecordingEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  StaffDocument? _file;
  String? _songId;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final file = _file;
    if (file == null) {
      setState(() => actionError = 'Vui lòng chọn tệp âm thanh.');
      return;
    }
    final title = _title.text.trim();
    final api = ref.read(staffOperationsApiProvider);
    final saved = await runAction(
      () => api.uploadRehearsalRecording(
        widget.rehearsalId,
        file,
        title: title.isEmpty ? null : title,
        songId: _songId,
      ),
    );
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final songs = rehearsalSongsProvider(widget.rehearsalId);
    return PopScope(
      canPop: !busy,
      child: OpsPage(
        title: 'Tải bản thu buổi tập',
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _title,
                enabled: !busy,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề (không bắt buộc)',
                ),
                validator: (value) => (value?.trim().length ?? 0) > 200
                    ? 'Tiêu đề tối đa 200 ký tự.'
                    : null,
              ),
              OpsAsync(
                value: ref.watch(songs),
                onRetry: () => ref.invalidate(songs),
                data: (items) => OpsChoiceField(
                  label: 'Bài hát',
                  value: _songId,
                  optional: true,
                  emptyLabel: 'Bản thu cả buổi tập',
                  options: [
                    for (final song in items)
                      (id: song.songId, name: song.title),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() => _songId = value),
                ),
              ),
              StaffDocumentField(
                extensions: const ['webm', 'ogg', 'm4a', 'mp3', 'wav'],
                enabled: !busy,
                onChanged: (file) => setState(() => _file = file),
              ),
              const SizedBox(height: 12),
              actionState,
              FilledButton(
                onPressed: busy ? null : _save,
                child: const Text('Tải lên'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
