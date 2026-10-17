import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../lookups/data/lookup_dto.dart';
import '../../lookups/data/lookups_api_service.dart';
import '../data/profile_repository.dart';

class ParticipationHistoryScreen extends ConsumerStatefulWidget {
  const ParticipationHistoryScreen({super.key});

  @override
  ConsumerState<ParticipationHistoryScreen> createState() =>
      _ParticipationHistoryScreenState();
}

class _ParticipationHistoryScreenState
    extends ConsumerState<ParticipationHistoryScreen> {
  String? _selectedSeasonId;
  DateTime? _fromDate;
  DateTime? _toDate;
  int _currentPage = 1;
  final int _pageSize = 20;

  bool _isLoading = false;
  String? _errorMessage;
  List<ParticipationHistoryDto> _items = [];
  bool _hasNextPage = false;

  List<LiturgicalSeasonDto> _seasons = [];

  int _requestGen = 0;

  @override
  void initState() {
    super.initState();
    _loadSeasons();
    _loadHistory(reset: true);
  }

  Future<void> _loadSeasons() async {
    try {
      final lookupService = ref.read(lookupsApiServiceProvider);
      final seasons = await lookupService.getLiturgicalSeasons();
      if (mounted) {
        setState(() {
          _seasons = seasons;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadHistory({bool reset = false}) async {
    final gen = ++_requestGen;
    final targetPage = reset ? 1 : _currentPage + 1;
    final seasonSnapshot = _selectedSeasonId;
    final fromDateSnapshot = _fromDate;
    final toDateSnapshot = _toDate;

    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final repo = ref.read(profileRepositoryProvider);
      final fromDateStr = fromDateSnapshot != null
          ? DateFormat('yyyy-MM-dd').format(fromDateSnapshot)
          : null;
      final toDateStr = toDateSnapshot != null
          ? DateFormat('yyyy-MM-dd').format(toDateSnapshot)
          : null;

      final result = await repo.getParticipationHistory(
        liturgicalSeasonId: seasonSnapshot,
        fromDate: fromDateStr,
        toDate: toDateStr,
        pageNumber: targetPage,
        pageSize: _pageSize,
      );

      if (!mounted || gen != _requestGen) return;

      setState(() {
        _currentPage = targetPage;
        if (reset) {
          _items = result.items;
        } else {
          final existingIds = _items.map((e) => e.eventId).toSet();
          final newItems = result.items
              .where((e) => !existingIds.contains(e.eventId))
              .toList();
          _items = [..._items, ...newItems];
        }
        _hasNextPage = result.hasNextPage;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || gen != _requestGen) return;
      setState(() {
        _errorMessage = 'Không thể tải lịch sử tham gia: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _loadHistory(reset: true);
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedSeasonId = null;
      _fromDate = null;
      _toDate = null;
    });
    _loadHistory(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Lịch sử tham gia & luyện tập',
          style: AppTypography.headlineSmall,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // Season dropdown
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedSeasonId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            labelText: 'Mùa phụng vụ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Tất cả các mùa'),
                            ),
                            ..._seasons.map(
                              (s) => DropdownMenuItem<String?>(
                                value: s.id,
                                child: Text(
                                  s.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedSeasonId = val);
                            _loadHistory(reset: true);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Date range button
                      IconButton.outlined(
                        tooltip: 'Chọn khoảng ngày',
                        icon: Icon(
                          Icons.calendar_month_rounded,
                          color: (_fromDate != null || _toDate != null)
                              ? AppColors.primary
                              : AppColors.muted,
                        ),
                        onPressed: _selectDateRange,
                      ),
                      if (_selectedSeasonId != null ||
                          _fromDate != null ||
                          _toDate != null)
                        IconButton(
                          tooltip: 'Xóa bộ lọc',
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: _clearFilters,
                        ),
                    ],
                  ),
                  if (_fromDate != null && _toDate != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Từ ${DateFormat('dd/MM/yyyy').format(_fromDate!)} đến ${DateFormat('dd/MM/yyyy').format(_toDate!)}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),

            // Content List
            Expanded(
              child: Builder(
                builder: (context) {
                  if (_isLoading && _items.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (_errorMessage != null && _items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: AppColors.statusDanger,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: AppTypography.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _loadHistory(reset: true),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (_items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 56,
                              color: AppColors.muted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chưa có dữ liệu lịch sử tham gia',
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.muted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lịch sử chỉ ghi nhận các sự kiện đã diễn ra mà bạn đã xác nhận tham gia hoặc có trong danh sách phục vụ.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.muted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => _loadHistory(reset: true),
                    color: AppColors.primary,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length + (_hasNextPage ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: ElevatedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : () => _loadHistory(reset: false),
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.expand_more_rounded),
                                label: const Text('Tải thêm sự kiện'),
                              ),
                            ),
                          );
                        }

                        final item = _items[index];
                        final rehearsalsPercent = item.rehearsalsHeld > 0
                            ? (item.rehearsalsAttended /
                                      item.rehearsalsHeld *
                                      100)
                                  .round()
                            : null;
                        final assignmentsPercent = item.assignmentsTotal > 0
                            ? (item.assignmentsPassed /
                                      item.assignmentsTotal *
                                      100)
                                  .round()
                            : null;

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (item.liturgicalSeasonName != null &&
                                        item
                                            .liturgicalSeasonName!
                                            .isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          item.liturgicalSeasonName!,
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    ],
                                    Text(
                                      item.eventDate,
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.title,
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (item.servedSkills.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.mic_rounded,
                                        size: 16,
                                        color: AppColors.secondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Bè / Kỹ năng phục vụ: ${item.servedSkills.join(', ')}',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.secondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricTile(
                                        icon: Icons.groups_rounded,
                                        label: 'Điểm danh buổi tập',
                                        value:
                                            '${item.rehearsalsAttended}/${item.rehearsalsHeld}',
                                        percent: rehearsalsPercent,
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 36,
                                      color: AppColors.border,
                                    ),
                                    Expanded(
                                      child: _buildMetricTile(
                                        icon:
                                            Icons.check_circle_outline_rounded,
                                        label: 'Bài tập đạt',
                                        value:
                                            '${item.assignmentsPassed}/${item.assignmentsTotal}',
                                        percent: assignmentsPercent,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    int? percent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      value,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (percent != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '($percent%)',
                        style: AppTypography.labelSmall.copyWith(
                          color: percent >= 80
                              ? AppColors.statusSuccess
                              : AppColors.statusWarning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
