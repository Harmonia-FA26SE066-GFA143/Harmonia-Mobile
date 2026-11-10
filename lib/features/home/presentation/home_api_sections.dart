import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/error_messages.dart';
import '../../calendar/data/calendar_repository.dart';

class HomePublicNotice extends ConsumerWidget {
  const HomePublicNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(publicAppSettingsProvider)
      .when(
        loading: () => const SizedBox.shrink(),
        error: (error, _) => TextButton.icon(
          onPressed: () => ref.invalidate(publicAppSettingsProvider),
          icon: const Icon(Icons.refresh),
          label: const Text('Tải lại thông tin ca đoàn'),
        ),
        data: (settings) {
          if (settings.parishName.isEmpty && settings.announcement.isEmpty) {
            return const SizedBox.shrink();
          }
          return Card(
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (settings.parishName.isNotEmpty)
                    Text(
                      settings.parishName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  if (settings.announcement.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(settings.announcement),
                  ],
                ],
              ),
            ),
          );
        },
      );
}

class MemberAssignmentsCard extends ConsumerWidget {
  const MemberAssignmentsCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(calendarNotifierProvider)
        .when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (events) {
            final assigned = events
                .where((event) => event.assignedVocalPart.isNotEmpty)
                .toList();
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Phân công của bạn',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (assigned.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Chưa có phân công sắp tới được công bố.'),
                      ),
                    ),
                  for (final event in assigned)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.assignment_ind),
                        title: Text(
                          event.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy').format(event.date)} • ${event.assignedVocalPart}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '/event-detail/${Uri.encodeComponent(event.id)}',
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
  }
}

class UpcomingRehearsalCard extends ConsumerWidget {
  const UpcomingRehearsalCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(rehearsalsProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => Card(
          child: ListTile(
            title: Text(ErrorMessages.forException(error)),
            trailing: IconButton(
              tooltip: 'Thử lại',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(rehearsalsProvider),
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Chưa có buổi tập sắp tới.'),
              ),
            );
          }
          final rehearsal = items.first;
          return Card(
            child: ListTile(
              leading: const Icon(Icons.event_note),
              title: Text(
                rehearsal.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  '${DateFormat('dd/MM/yyyy').format(rehearsal.date)} • ${rehearsal.timeRange}',
                  if (rehearsal.location.isNotEmpty) rehearsal.location,
                  if (rehearsal.note?.trim().isNotEmpty ?? false)
                    'Ghi chú: ${rehearsal.note!.trim()}',
                  if (rehearsal.contentSummary.isNotEmpty)
                    rehearsal.contentSummary,
                ].join('\n'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                '/rehearsal/${Uri.encodeComponent(rehearsal.id)}',
              ),
            ),
          );
        },
      );
}
