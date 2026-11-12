import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../core/errors/error_messages.dart';
import '../../lookups/data/lookups_api_service.dart';
import '../data/staff_workspace_repository.dart';
import 'staff_workflow_title.dart';

final _programOptions = FutureProvider.autoDispose((ref) {
  final lookup = ref.watch(lookupsApiServiceProvider);
  final repo = ref.watch(staffWorkspaceRepositoryProvider);
  return (
    lookup.getWorshipLocations(),
    lookup.getMassTypes(),
    lookup.getCeremonyTypes(),
    lookup.getLiturgicalSeasons(),
    lookup.getEventCategories(),
    repo.choirs(),
  ).wait;
});

typedef ChoirSelection = ({Set<String> ids, String? lead});
typedef FieldChoice = ({String id, String name});

class StaffProgramForm extends ConsumerStatefulWidget {
  const StaffProgramForm({super.key});

  @override
  ConsumerState<StaffProgramForm> createState() => _StaffProgramFormState();
}

class _StaffProgramFormState extends ConsumerState<StaffProgramForm> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _requirements = TextEditingController();
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  TimeOfDay? _time;
  String? _location, _mass, _ceremony, _season, _category, _error;
  ChoirSelection _choirs = (ids: {}, lead: null);
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _requirements.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final time = _time;
    final lead = _choirs.lead;
    final location = _location;
    final error = time == null
        ? 'Chọn giờ cử hành.'
        : location == null
        ? 'Chọn nơi cử hành.'
        : _mass == null && _ceremony == null
        ? 'Chọn loại Thánh lễ hoặc loại nghi thức.'
        : lead == null || !_choirs.ids.contains(lead)
        ? 'Chọn ca đoàn phục vụ và ca đoàn phụ trách.'
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref.read(staffWorkspaceRepositoryProvider).createEvent((
        date: DateFormat('yyyy-MM-dd').format(_date),
        time:
            '${time!.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00',
        locationId: location!,
        massTypeId: _mass,
        ceremonyTypeId: _ceremony,
        seasonId: _season,
        categoryId: _category,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        requirements: _requirements.text.trim().isEmpty
            ? null
            : _requirements.text.trim(),
        choirIds: _choirs.ids.toList(),
        leadChoirId: lead!,
      ));
      if (!mounted) return;
      if (context.canPop()) {
        context.pop(id);
      } else {
        context.go('/event-detail/${Uri.encodeComponent(id)}');
      }
    } catch (error) {
      if (mounted) setState(() => _error = ErrorMessages.forException(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(_programOptions);
    return Scaffold(
      appBar: const AppPageHeader(
        large: true,
        title: StaffWorkflowTitle(
          title: 'Tạo chương trình',
          role: 'Dành cho Cha xứ',
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(64),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ListTile(
              dense: true,
              tileColor: Color(0x306D2636),
              leading: Icon(Icons.info_outline, color: Color(0xFFFFD369)),
              title: Text(
                'Thiết lập phụng vụ và chọn ca đoàn phụ trách.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: options.hasValue
          ? StaffWorkflowBar(
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_busy ? 'Đang lưu…' : 'Lưu bản nháp'),
              ),
            )
          : null,
      body: SafeArea(
        child: options.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: OutlinedButton(
              onPressed: () => ref.invalidate(_programOptions),
              child: const Text('Tải lại danh mục'),
            ),
          ),
          data: (data) => Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProgramSectionTitle(
                          icon: Icons.church_outlined,
                          title: 'Thời gian & Nơi cử hành',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _title,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Tiêu đề phụng vụ (tùy chọn)',
                          ),
                          maxLength: 200,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_outlined),
                          title: const Text('Ngày cử hành'),
                          subtitle: Text(
                            DateFormat('dd/MM/yyyy').format(_date),
                          ),
                          onTap: _busy
                              ? null
                              : () async {
                                  final day = await showDatePicker(
                                    context: context,
                                    initialDate: _date,
                                    firstDate: DateUtils.dateOnly(
                                      DateTime.now(),
                                    ),
                                    lastDate: DateTime(2100),
                                  );
                                  if (mounted && day != null) {
                                    setState(() => _date = day);
                                  }
                                },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule),
                          title: const Text('Giờ cử hành'),
                          subtitle: Text(_time?.format(context) ?? 'Chọn giờ'),
                          onTap: _busy
                              ? null
                              : () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime:
                                        _time ??
                                        const TimeOfDay(hour: 6, minute: 0),
                                  );
                                  if (mounted && time != null) {
                                    setState(() => _time = time);
                                  }
                                },
                        ),
                        _field(
                          'Nơi cử hành',
                          [
                            for (final row in data.$1)
                              (id: row.id, name: row.name),
                          ],
                          _location,
                          (value) => _location = value,
                          optional: false,
                        ),
                        _field(
                          'Loại Thánh lễ',
                          [
                            for (final row in data.$2)
                              (id: row.id, name: row.name),
                          ],
                          _mass,
                          (value) => _mass = value,
                        ),
                        _field(
                          'Loại nghi thức',
                          [
                            for (final row in data.$3)
                              (id: row.id, name: row.name),
                          ],
                          _ceremony,
                          (value) => _ceremony = value,
                        ),
                        _field(
                          'Mùa phụng vụ',
                          [
                            for (final row in data.$4)
                              (id: row.id, name: row.name),
                          ],
                          _season,
                          (value) => _season = value,
                        ),
                        _field(
                          'Loại sự kiện',
                          [
                            for (final row in data.$5)
                              (id: row.id, name: row.name),
                          ],
                          _category,
                          (value) => _category = value,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ServingChoirFields(
                      options: [
                        for (final choir in data.$6)
                          if (choir.isActive && choir.id.isNotEmpty)
                            (id: choir.id, name: choir.name),
                      ],
                      value: _choirs,
                      onChanged: _busy
                          ? null
                          : (selection) => setState(() => _choirs = selection),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProgramSectionTitle(
                          icon: Icons.notes_rounded,
                          title: 'Ghi chú mục vụ',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _requirements,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Dặn dò phòng áo & ca đoàn',
                          ),
                          maxLength: 1000,
                          maxLines: 3,
                        ),
                        const ListTile(
                          tileColor: AppColors.surfaceContainerLow,
                          leading: Icon(
                            Icons.circle,
                            size: 9,
                            color: AppColors.statusWarning,
                          ),
                          title: Text('Trạng thái sau khi lưu'),
                          subtitle: Text('Bản nháp'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    List<FieldChoice> choices,
    String? value,
    ValueChanged<String?> onChanged, {
    bool optional = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items: [
        if (optional) const DropdownMenuItem(child: Text('Không chọn')),
        for (final choice in choices)
          DropdownMenuItem(
            value: choice.id,
            child: Text(choice.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _busy ? null : onChanged,
      validator: optional
          ? null
          : (value) => value == null ? 'Chọn nơi cử hành.' : null,
    ),
  );
}

class _ProgramSectionTitle extends StatelessWidget {
  const _ProgramSectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 21, color: AppColors.primary),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: AppTypography.titleMedium)),
    ],
  );
}

class ServingChoirFields extends StatelessWidget {
  const ServingChoirFields({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final List<FieldChoice> options;
  final ChoirSelection value;
  final ValueChanged<ChoirSelection>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _ProgramSectionTitle(
        icon: Icons.groups_outlined,
        title: 'Ca đoàn phục vụ',
      ),
      const SizedBox(height: 8),
      if (options.isEmpty)
        const Text('Chưa có ca đoàn đang hoạt động.')
      else
        const Text(
          'Chọn các ca đoàn phục vụ và đánh dấu một ca đoàn phụ trách chính.',
        ),
      const SizedBox(height: 12),
      for (final option in options)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: option.id == value.lead
                ? AppColors.primarySoft
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: option.id == value.lead
                  ? AppColors.primary
                  : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CheckboxListTile(
                title: Text(option.name, style: AppTypography.titleMedium),
                controlAffinity: ListTileControlAffinity.leading,
                value: value.ids.contains(option.id),
                onChanged: onChanged == null
                    ? null
                    : (checked) {
                        final ids = {...value.ids};
                        if (checked == true) {
                          ids.add(option.id);
                        } else {
                          ids.remove(option.id);
                        }
                        onChanged!((
                          ids: ids,
                          lead: ids.length == 1
                              ? ids.first
                              : ids.contains(value.lead)
                              ? value.lead
                              : null,
                        ));
                      },
              ),
              if (value.ids.contains(option.id)) ...[
                const Divider(indent: 12, endIndent: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onChanged == null
                        ? null
                        : () => onChanged!((ids: value.ids, lead: option.id)),
                    icon: Icon(
                      option.id == value.lead
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    label: Text(
                      option.id == value.lead
                          ? 'Phụ trách chính'
                          : 'Đặt làm chính',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
    ],
  );
}
