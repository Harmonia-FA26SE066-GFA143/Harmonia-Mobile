import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../data/calendar_repository.dart';
import '../data/liturgical_models.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  int _selectedFilter = 0; // 0: Tất cả, 1: Thánh lễ, 2: Buổi tập

  @override
  Widget build(BuildContext context) {
    final calendarState = ref.watch(calendarNotifierProvider);
    final repo = ref.watch(calendarRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Lịch phụng vụ & Tập hát',
          style: AppTypography.headlineSmall,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Chips
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _buildFilterChip('Tất cả', 0),
                  const SizedBox(width: 8),
                  _buildFilterChip('Thánh lễ', 1),
                  const SizedBox(width: 8),
                  _buildFilterChip('Buổi tập', 2),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content List
            Expanded(
              child: calendarState.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
                data: (events) {
                  return FutureBuilder<List<RehearsalSession>>(
                    future: repo.getRehearsals(),
                    builder: (context, snapshot) {
                      final rehearsals = snapshot.data ?? [];

                      final showEvents =
                          _selectedFilter == 0 || _selectedFilter == 1;
                      final showRehearsals =
                          _selectedFilter == 0 || _selectedFilter == 2;

                      return RefreshIndicator(
                        onRefresh: () => ref
                            .read(calendarNotifierProvider.notifier)
                            .loadEvents(),
                        color: AppColors.primary,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (showEvents) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Thánh lễ & Sự kiện',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ...events.map(
                                (event) => _buildEventCard(context, event),
                              ),
                            ],
                            if (showRehearsals && rehearsals.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 16,
                                  bottom: 12,
                                ),
                                child: Text(
                                  'Lịch tập hát ca đoàn',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ...rehearsals.map(
                                (rehearsal) => _buildRehearsalCard(rehearsal),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: isSelected ? AppColors.onPrimary : AppColors.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, LiturgicalEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/event-detail/${event.id}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusSuccessSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      event.seasonName,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.statusSuccess,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          event.participationStatus ==
                              ParticipationStatus.confirmed
                          ? AppColors.statusSuccessSoft
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      event.participationStatus.label,
                      style: AppTypography.labelSmall.copyWith(
                        color:
                            event.participationStatus ==
                                ParticipationStatus.confirmed
                            ? AppColors.statusSuccess
                            : AppColors.muted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                event.title,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormat('dd/MM/yyyy').format(event.date)} • ${event.timeRange}',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(event.location, style: AppTypography.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRehearsalCard(RehearsalSession rehearsal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rehearsal.title,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.statusInfoSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rehearsal.attendanceStatus,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.statusInfo,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  '${DateFormat('dd/MM/yyyy').format(rehearsal.date)} • ${rehearsal.timeRange}',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.room_outlined,
                  size: 16,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 6),
                Text(rehearsal.location, style: AppTypography.bodySmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              rehearsal.contentSummary,
              style: AppTypography.bodySmall.copyWith(color: AppColors.body),
            ),
          ],
        ),
      ),
    );
  }
}
