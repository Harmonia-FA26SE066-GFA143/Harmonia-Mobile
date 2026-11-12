import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../core/errors/error_messages.dart';
import '../data/staff_operations_api.dart';

class OpsPage extends StatelessWidget {
  const OpsPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppPageHeader(title: Text(title), actions: actions),
    body: SafeArea(child: child),
  );
}

class OpsTile extends StatelessWidget {
  const OpsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onTap,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(title),
      subtitle: subtitle == null || subtitle!.isEmpty ? null : Text(subtitle!),
      leading: icon == null ? null : Icon(icon, color: AppColors.primary),
      trailing:
          trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
      onTap: onTap,
    ),
  );
}

class OpsAsync<T> extends StatelessWidget {
  const OpsAsync({
    super.key,
    required this.value,
    required this.onRetry,
    required this.data,
  });
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T) data;
  @override
  Widget build(BuildContext context) => value.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ErrorMessages.forException(error),
              textAlign: TextAlign.center,
            ),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    ),
    data: data,
  );
}

class OpsPaging extends StatelessWidget {
  const OpsPaging({super.key, required this.page, this.previous, this.next});
  final int page;
  final VoidCallback? previous, next;

  @override
  Widget build(BuildContext context) => previous == null && next == null
      ? const SizedBox.shrink()
      : Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(onPressed: previous, child: const Text('Trang trước')),
            Text('Trang $page'),
            TextButton(onPressed: next, child: const Text('Trang sau')),
          ],
        );
}

mixin OpsActions<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool busy = false;
  String? actionError;

  Future<bool> runAction(Future<void> Function() action) async {
    if (busy) return false;
    setState(() {
      busy = true;
      actionError = null;
    });
    try {
      await action();
      return mounted;
    } catch (error) {
      if (mounted) {
        setState(() => actionError = ErrorMessages.forException(error));
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget get actionState => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (busy) const LinearProgressIndicator(),
      if (actionError != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            actionError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ],
  );
}

String opsPath(String route, String id) =>
    Uri(pathSegments: ['', route, id]).toString();

DateTime vietnamClock(DateTime utc) =>
    utc.toUtc().add(const Duration(hours: 7));
String opsTime(DateTime utc) =>
    DateFormat('dd/MM/yyyy • HH:mm').format(vietnamClock(utc));
String opsDay(DateTime day) => DateFormat('dd/MM/yyyy').format(day);

Future<DateTime?> pickOpsTime(BuildContext context, DateTime initial) async {
  final local = vietnamClock(initial);
  final day = await showDatePicker(
    context: context,
    initialDate: local,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(local),
  );
  return time == null
      ? null
      : DateTime.utc(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        ).subtract(const Duration(hours: 7));
}

Future<bool> opsConfirm(
  BuildContext context,
  String title,
  String body,
  String label,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(label),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> opsText(
  BuildContext context,
  String title,
  String label, {
  String initial = '',
  bool requiredText = false,
  int max = 500,
}) {
  var text = initial;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: TextFormField(
          initialValue: initial,
          maxLength: max,
          maxLines: 3,
          decoration: InputDecoration(labelText: label),
          onChanged: (value) => update(() => text = value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: requiredText && text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, text.trim()),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ),
  );
}

class OpsChoiceField extends StatelessWidget {
  const OpsChoiceField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.optional = false,
    this.emptyLabel = 'Không chọn',
  });
  final String label;
  final List<Choice> options;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool optional;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      key: ValueKey((label, value)),
      initialValue: options.any((choice) => choice.id == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items: [
        if (optional) DropdownMenuItem(child: Text(emptyLabel)),
        for (final option in options)
          DropdownMenuItem(
            value: option.id,
            child: Text(option.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    ),
  );
}

class OpsChoicePicker extends StatefulWidget {
  const OpsChoicePicker({
    super.key,
    required this.title,
    required this.choices,
    required this.selected,
  });

  final String title;
  final List<Choice> choices;
  final Set<String> selected;

  @override
  State<OpsChoicePicker> createState() => _OpsChoicePickerState();
}

class _OpsChoicePickerState extends State<OpsChoicePicker> {
  late final _selected = widget.selected.intersection(
    widget.choices.map((item) => item.id).toSet(),
  );
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    final matches = widget.choices
        .where((choice) => choice.name.toLowerCase().contains(_keyword))
        .toList();
    return Dialog.fullscreen(
      child: OpsPage(
        title: widget.title,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Tìm theo tên',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) =>
                    setState(() => _keyword = value.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final item = matches[index];
                  return CheckboxListTile(
                    value: _selected.contains(item.id),
                    title: Text(item.name),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selected.add(item.id);
                      } else {
                        _selected.remove(item.id);
                      }
                    }),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: Text('Xác nhận (${_selected.length})'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
