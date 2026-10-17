import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/errors/error_messages.dart';
import '../data/calendar_repository.dart';
import '../data/liturgical_models.dart';

String participationStatusMessage(LiturgicalEvent event) {
  if (!event.canRespond && event.cannotRespondReason != null) {
    return ErrorMessages.getMessage(event.cannotRespondReason!);
  }
  return event.participationStatus.label;
}

Future<void> showParticipationPrompt(
  BuildContext context,
  WidgetRef ref,
  LiturgicalEvent event,
  ParticipationStatus status,
) async {
  if (!event.canRespond) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(participationStatusMessage(event))));
    return;
  }
  final epoch = ref.read(sessionManagerProvider).sessionEpoch;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Gửi phản hồi: ${status.label}?'),
      content: Text(
        '${event.title}\n\nPhản hồi chỉ gửi một lần và không thể thay đổi trên hệ thống.'
        '${event.participationStatus == ParticipationStatus.unknown ? "\nBạn chỉ có thể phản hồi nếu đã nhận lời mời tham gia." : ""}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Gửi phản hồi'),
        ),
      ],
    ),
  );
  if (confirmed != true ||
      !context.mounted ||
      ref.read(sessionManagerProvider).sessionEpoch != epoch) {
    return;
  }
  final result = await showDialog<({bool ok, Object? error})>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _ParticipationRequestDialog(eventId: event.id, status: status),
  );
  if (!context.mounted ||
      ref.read(sessionManagerProvider).sessionEpoch != epoch ||
      result == null) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        result.ok
            ? 'Đã gửi phản hồi: ${status.label}'
            : ErrorMessages.forException(result.error),
      ),
    ),
  );
}

class _ParticipationRequestDialog extends ConsumerStatefulWidget {
  final String eventId;
  final ParticipationStatus status;
  const _ParticipationRequestDialog({
    required this.eventId,
    required this.status,
  });
  @override
  ConsumerState<_ParticipationRequestDialog> createState() =>
      _ParticipationRequestDialogState();
}

class _ParticipationRequestDialogState
    extends ConsumerState<_ParticipationRequestDialog> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_submit);
  }

  Future<void> _submit() async {
    final session = ref.read(sessionManagerProvider);
    final epoch = session.sessionEpoch;
    Object? error;
    try {
      await ref
          .read(calendarNotifierProvider.notifier)
          .setParticipation(widget.eventId, widget.status);
    } catch (failure) {
      error = failure;
    }
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.of(
      context,
    ).pop((ok: error == null && session.sessionEpoch == epoch, error: error));
  }

  @override
  Widget build(BuildContext context) => const PopScope(
    canPop: false,
    child: AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Expanded(child: Text('Đang gửi phản hồi…')),
        ],
      ),
    ),
  );
}
