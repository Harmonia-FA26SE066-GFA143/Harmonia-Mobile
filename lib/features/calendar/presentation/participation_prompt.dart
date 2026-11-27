import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/harmonia_blocking_progress.dart';
import '../../../app/widgets/member_choir_visuals.dart';
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
  final isChange = event.participationStatus.isAnswer;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        '${isChange ? 'Đổi sang' : 'Gửi phản hồi'}: ${status.label}?',
      ),
      content: Text(event.title),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, MemberChoirStyle.dialogActionHeight),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(isChange ? 'Đổi phản hồi' : 'Gửi phản hồi'),
            ),
            OutlinedButton(
              style: MemberChoirStyle.cancelButtonStyle,
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Quay lại'),
            ),
          ],
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
    useSafeArea: false,
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
    child: HarmoniaBlockingProgress(label: 'Đang gửi phản hồi…'),
  );
}
