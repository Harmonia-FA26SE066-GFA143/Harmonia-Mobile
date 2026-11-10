import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/core_providers.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../data/staff_operations_api.dart';
import 'staff_ops_widgets.dart';

final _chatUpdates = StreamProvider.autoDispose(
  (ref) => ref.watch(signalRServiceProvider).directorNoteStream,
);
final _conversations = FutureProvider.autoDispose((ref) {
  ref.watch(_chatUpdates);
  return ref.watch(staffOperationsApiProvider).conversations();
});
final _recipients = FutureProvider.autoDispose(
  (ref) => ref.watch(staffOperationsApiProvider).recipients(),
);
final _thread = FutureProvider.autoDispose.family((ref, (String, int) key) {
  ref.watch(_chatUpdates);
  return ref.watch(staffOperationsApiProvider).thread(key.$1, key.$2);
});

String staffThreadPath(String id, String name) => Uri(
  pathSegments: ['', 'staff-chat', id],
  queryParameters: {'name': name},
).toString();

class StaffChatScreen extends ConsumerWidget {
  const StaffChatScreen({super.key, this.chooseRecipient = false});
  final bool chooseRecipient;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OpsPage(
    title: chooseRecipient ? 'Người nhận' : 'Tin nhắn',
    actions: [
      IconButton(
        tooltip: 'Tải lại',
        icon: const Icon(Icons.refresh),
        onPressed: () => chooseRecipient
            ? ref.invalidate(_recipients)
            : ref.invalidate(_conversations),
      ),
      if (!chooseRecipient)
        IconButton(
          tooltip: 'Tin nhắn mới',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => context.push('/staff-chat-new'),
        ),
    ],
    child: chooseRecipient
        ? OpsAsync(
            value: ref.watch(_recipients),
            onRetry: () => ref.invalidate(_recipients),
            data: (choices) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (choices.isEmpty) const Text('Chưa có người nhận phù hợp.'),
                for (final choice in choices)
                  OpsTile(
                    title: choice.name,
                    icon: Icons.person_outline,
                    onTap: () async {
                      await context.push(
                        staffThreadPath(choice.id, choice.name),
                      );
                      if (context.mounted) ref.invalidate(_conversations);
                    },
                  ),
              ],
            ),
          )
        : OpsAsync(
            value: ref.watch(_conversations),
            onRetry: () => ref.invalidate(_conversations),
            data: (threads) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (threads.isEmpty) const Text('Chưa có cuộc trò chuyện.'),
                for (final thread in threads)
                  OpsTile(
                    title: thread.name,
                    icon: Icons.chat_bubble_outline,
                    subtitle:
                        '${thread.last.content}\n${opsTime(thread.last.sentAt)}',
                    trailing: thread.unread > 0
                        ? Badge(label: Text('${thread.unread}'))
                        : null,
                    onTap: () async {
                      await context.push(
                        staffThreadPath(thread.id, thread.name),
                      );
                      if (context.mounted) ref.invalidate(_conversations);
                    },
                  ),
              ],
            ),
          ),
  );
}

class StaffThreadScreen extends ConsumerStatefulWidget {
  const StaffThreadScreen({
    super.key,
    required this.userId,
    required this.name,
  });
  final String userId;
  final String name;
  @override
  ConsumerState<StaffThreadScreen> createState() => _StaffThreadScreenState();
}

class _StaffThreadScreenState extends ConsumerState<StaffThreadScreen>
    with OpsActions<StaffThreadScreen> {
  final _input = TextEditingController();
  int _page = 1;
  String? _lastReadAttempt;
  bool _reading = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _markRead(String? messageId) async {
    if (messageId == null || _reading || _lastReadAttempt == messageId) return;
    _reading = true;
    _lastReadAttempt = messageId;
    try {
      await ref.read(staffOperationsApiProvider).readThread(widget.userId);
      if (mounted) {
        ref.invalidate(_conversations);
        ref.invalidate(_thread((widget.userId, _page)));
      }
    } catch (_) {
      // Messages remain readable if the receipt fails. Refresh can retry.
    } finally {
      _reading = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _send() async {
    final message = _input.text.trim();
    if (message.isEmpty || message.length > 2000) return;
    final api = ref.read(staffOperationsApiProvider);
    if (!await runAction(() => api.sendMessage(widget.userId, message)) ||
        !mounted) {
      return;
    }
    if (_input.text.trim() == message) _input.clear();
    setState(() => _page = 1);
    ref.invalidate(_thread((widget.userId, 1)));
    ref.invalidate(_conversations);
  }

  @override
  Widget build(BuildContext context) {
    final provider = _thread((widget.userId, _page));
    final me = ref.watch(
      authNotifierProvider.select((state) => state.user?.id),
    );
    return OpsPage(
      title: widget.name.isEmpty ? 'Cuộc trò chuyện' : widget.name,
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            _lastReadAttempt = null;
            ref.invalidate(provider);
          },
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: OpsAsync(
              value: ref.watch(provider),
              onRetry: () => ref.invalidate(provider),
              data: (page) {
                final unread = page.items
                    .where((row) => row.toId == me && row.readAt == null)
                    .firstOrNull;
                if (unread != null &&
                    !_reading &&
                    _lastReadAttempt != unread.id) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
                      unawaited(_markRead(unread.id));
                    }
                  });
                }
                if (page.items.isEmpty && _page == 1) {
                  return const Center(
                    child: Text('Hãy bắt đầu cuộc trò chuyện.'),
                  );
                }
                return ListView(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final message in page.items)
                      Align(
                        alignment: message.fromId == me
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Card(
                            color: message.fromId == me
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (message.eventTitle?.isNotEmpty == true)
                                    Text(
                                      message.eventTitle!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge,
                                    ),
                                  SelectableText(message.content),
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      opsTime(message.sentAt),
                                      if (message.fromId == me)
                                        message.readAt == null
                                            ? 'Đã gửi'
                                            : 'Đã đọc',
                                    ].join(' • '),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    OpsPaging(
                      page: _page,
                      previous: _page > 1
                          ? () => setState(() => _page--)
                          : null,
                      next: page.hasNextPage
                          ? () => setState(() => _page++)
                          : null,
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                actionState,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        enabled: !busy,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Tin nhắn',
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Gửi tin nhắn',
                      icon: const Icon(Icons.send_outlined),
                      onPressed: busy || _input.text.trim().isEmpty
                          ? null
                          : _send,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
