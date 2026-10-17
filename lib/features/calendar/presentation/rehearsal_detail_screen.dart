import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/errors/error_messages.dart';
import '../data/calendar_repository.dart';

class RehearsalDetailScreen extends ConsumerWidget {
  final String rehearsalId;
  const RehearsalDetailScreen({super.key, required this.rehearsalId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rehearsalDetailProvider(rehearsalId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chi tiết buổi tập')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(rehearsalDetailProvider(rehearsalId));
            try {
              await ref.read(rehearsalDetailProvider(rehearsalId).future);
            } catch (_) {
              /* The provider renders the error below. */
            }
          },
          child: state.when(
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
            error: (error, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Text(ErrorMessages.forException(error)),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(rehearsalDetailProvider(rehearsalId)),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
            data: (detail) {
              final rehearsal = detail.rehearsal;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rehearsal.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${DateFormat('dd/MM/yyyy').format(rehearsal.date)} • ${rehearsal.timeRange}',
                          ),
                          if (rehearsal.location.isNotEmpty)
                            Text(rehearsal.location),
                          const SizedBox(height: 8),
                          Text('Điểm danh: ${rehearsal.attendanceStatus}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bài hát trong buổi tập',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (detail.songs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Buổi tập chưa có danh sách bài hát.'),
                    ),
                  for (final song in detail.songs)
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.music_note,
                          color: AppColors.primary,
                        ),
                        title: Text(song.title),
                        subtitle: song.note?.isNotEmpty == true
                            ? Text(song.note!)
                            : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '/song-detail/${Uri.encodeComponent(song.songId)}',
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
