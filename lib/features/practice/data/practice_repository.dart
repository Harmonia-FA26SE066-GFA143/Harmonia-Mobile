import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_env.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/session/session_manager.dart';
import '../../notifications/data/notification_dto.dart';
import 'practice_api_service.dart';
import 'practice_models.dart';

export '../../notifications/data/notification_dto.dart' show PagedList;

class MockPracticeData {
  static final List<PracticeAssignment> assignments = [
    PracticeAssignment(
      id: 'practice-01',
      title: 'Thu âm bè Soprano: Thánh Vịnh 24',
      songTitle: 'Thánh Vịnh 24: Lạy Chúa Xin Chỉ Cho Con',
      instruction: 'Ca viên bè Soprano chú ý lấy hơi sâu ở đầu câu, ngân đủ 3 phách ở từ "Chúa" tại ô nhịp 14. Nộp trước 21h Thứ Sáu để Ca trưởng nhận xét.',
      dueDate: DateTime.now().add(const Duration(days: 2)),
      vocalPart: 'Soprano',
      status: PracticeStatus.pending,
      canSubmit: true,
    ),
    PracticeAssignment(
      id: 'practice-02',
      title: 'Luyện câu đáp: Ca Hiệp Lễ',
      songTitle: 'Lắng Nghe Lời Chúa',
      instruction: 'Hát đúng trường độ các nốt móc kép đoạn điệp khúc. Chú ý sắc thái nhẹ nhàng, sâu lắng.',
      dueDate: DateTime.now().add(const Duration(days: 4)),
      vocalPart: 'Soprano',
      status: PracticeStatus.pending,
      canSubmit: true,
    ),
    PracticeAssignment(
      id: 'practice-03',
      title: 'Bản thu kiểm tra: Ca Nhập Lễ Tuần 25',
      songTitle: 'Từ Muôn Phương',
      instruction: 'Yêu cầu kiểm tra phát âm rõ phụ âm cuối và chuẩn cao độ.',
      dueDate: DateTime.now().subtract(const Duration(days: 5)),
      vocalPart: 'Soprano',
      status: PracticeStatus.passed,
      canSubmit: false,
      cannotSubmitReason: 'PRACTICE_SUBMISSION_ALREADY_PASSED',
      audioDurationSeconds: 124,
      feedbackComment: 'Hát rất chuẩn cao độ và nhịp phách! Chú ý thêm một chút âm lượng ở câu kết bài.',
      feedbackDate: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];
}

abstract class PracticeRepository {
  Future<List<PracticeAssignment>> getAssignments({
    bool? isOpen,
    String? status,
    bool? hasSubmission,
    int pageNumber = 1,
    int pageSize = 50,
  });
  Future<PagedList<PracticeAssignment>> getAssignmentsPaged({
    bool? isOpen,
    String? status,
    bool? hasSubmission,
    int pageNumber = 1,
    int pageSize = 50,
  });
  Future<PracticeAssignment?> getAssignmentDetail(String id);
  Future<void> submitRecording({
    required String assignmentId,
    required String audioPath,
    required int durationSeconds,
  });
  Future<PracticeCounts> getMyAssignmentCounts();
  Future<List<PracticeSubmissionDetail>> getMySubmissions({
    String? assignmentId,
    int pageNumber = 1,
    int pageSize = 20,
  });
  Future<PagedList<PracticeSubmissionDetail>> getMySubmissionsPaged({
    String? assignmentId,
    int pageNumber = 1,
    int pageSize = 20,
  });
  Future<PracticeSubmissionDetail?> getMySubmissionDetail(String id);
}

class PracticeRepositoryImpl implements PracticeRepository {
  final PracticeApiService apiService;

  PracticeRepositoryImpl({required this.apiService});

  @override
  Future<List<PracticeAssignment>> getAssignments({
    bool? isOpen,
    String? status,
    bool? hasSubmission,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    final paged = await getAssignmentsPaged(
      isOpen: isOpen,
      status: status,
      hasSubmission: hasSubmission,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
    return paged.items;
  }

  @override
  Future<PagedList<PracticeAssignment>> getAssignmentsPaged({
    bool? isOpen,
    String? status,
    bool? hasSubmission,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    final response = await apiService.getMyAssignments(
      isOpen: isOpen,
      status: status,
      hasSubmission: hasSubmission,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
    final itemsJson = response['items'] as List? ?? [];
    final items = itemsJson
        .map((item) => _mapToAssignment(item as Map<String, dynamic>))
        .toList();
    return PagedList<PracticeAssignment>(
      items: items,
      pageNumber: response['pageNumber'] as int? ?? pageNumber,
      pageSize: response['pageSize'] as int? ?? pageSize,
      totalCount: response['totalCount'] as int? ?? items.length,
      totalPages: response['totalPages'] as int? ?? 1,
      hasPreviousPage: response['hasPreviousPage'] as bool? ?? false,
      hasNextPage: response['hasNextPage'] as bool? ?? false,
    );
  }

  @override
  Future<PracticeAssignment?> getAssignmentDetail(String id) async {
    try {
      final map = await apiService.getAssignmentDetail(id);
      return _mapToAssignment(map);
    } on NotFoundException {
      return null;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> submitRecording({
    required String assignmentId,
    required String audioPath,
    required int durationSeconds,
  }) async {
    await apiService.submitRecording(
      assignmentId: assignmentId,
      filePath: audioPath,
      durationSeconds: durationSeconds,
    );
  }

  @override
  Future<PracticeCounts> getMyAssignmentCounts() async {
    final map = await apiService.getMyAssignmentCounts();
    return PracticeCounts.fromJson(map);
  }

  @override
  Future<List<PracticeSubmissionDetail>> getMySubmissions({
    String? assignmentId,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    final paged = await getMySubmissionsPaged(
      assignmentId: assignmentId,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
    return paged.items;
  }

  @override
  Future<PagedList<PracticeSubmissionDetail>> getMySubmissionsPaged({
    String? assignmentId,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    final response = await apiService.getMySubmissions(
      assignmentId: assignmentId,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
    final itemsJson = response['items'] as List? ?? [];
    final items = itemsJson
        .map(
          (item) =>
              PracticeSubmissionDetail.fromJson(item as Map<String, dynamic>),
        )
        .toList();
    return PagedList<PracticeSubmissionDetail>(
      items: items,
      pageNumber: response['pageNumber'] as int? ?? pageNumber,
      pageSize: response['pageSize'] as int? ?? pageSize,
      totalCount: response['totalCount'] as int? ?? items.length,
      totalPages: response['totalPages'] as int? ?? 1,
      hasPreviousPage: response['hasPreviousPage'] as bool? ?? false,
      hasNextPage: response['hasNextPage'] as bool? ?? false,
    );
  }

  @override
  Future<PracticeSubmissionDetail?> getMySubmissionDetail(String id) async {
    try {
      final map = await apiService.getMySubmissionDetail(id);
      return PracticeSubmissionDetail.fromJson(map);
    } on NotFoundException {
      return null;
    } catch (e) {
      rethrow;
    }
  }

  PracticeAssignment _mapToAssignment(Map<String, dynamic> map) {
    final id = map['id']?.toString() ?? '';
    final title = map['title']?.toString() ?? 'Bài tập luyện tập';
    final songTitle =
        map['songTitle']?.toString() ?? (map['title']?.toString() ?? '');
    final instruction =
        map['instruction']?.toString() ??
        (map['description']?.toString() ?? '');
    final dueDateStr = map['dueDate']?.toString();
    final dueDate = dueDateStr != null
        ? DateTime.tryParse(dueDateStr)?.toLocal()
        : null;
    final latestStatus = map['latestSubmissionStatus']?.toString();

    PracticeStatus status;
    if (latestStatus == 'Passed') {
      status = PracticeStatus.passed;
    } else if (latestStatus == 'NeedsRevision') {
      status = PracticeStatus.needsRevision;
    } else if (latestStatus == 'Submitted') {
      status = PracticeStatus.submitted;
    } else {
      status = PracticeStatus.pending;
    }

    final isOverdue =
        (map['isOverdue'] as bool?) ??
        (dueDate != null && DateTime.now().isAfter(dueDate));

    return PracticeAssignment(
      id: id,
      title: title,
      songTitle: songTitle,
      instruction: instruction,
      dueDate: dueDate ?? DateTime.now(),
      vocalPart: 'Ca viên',
      status: status,
      isOverdue: isOverdue,
      canSubmit: map['canSubmit'] is bool ? map['canSubmit'] as bool : null,
      cannotSubmitReason: map['cannotSubmitReason'] is String
          ? map['cannotSubmitReason'] as String
          : null,
    );
  }
}

class PracticeListState {
  final List<PracticeAssignment> items;
  final int pageNumber;
  final int totalCount;
  final bool hasNextPage;
  final bool isLoadingMore;
  final String? loadMoreError;

  const PracticeListState({
    this.items = const [],
    this.pageNumber = 1,
    this.totalCount = 0,
    this.hasNextPage = false,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  PracticeListState copyWith({
    List<PracticeAssignment>? items,
    int? pageNumber,
    int? totalCount,
    bool? hasNextPage,
    bool? isLoadingMore,
    String? loadMoreError,
  }) {
    return PracticeListState(
      items: items ?? this.items,
      pageNumber: pageNumber ?? this.pageNumber,
      totalCount: totalCount ?? this.totalCount,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: loadMoreError,
    );
  }
}

class MockPracticeRepositoryImpl implements PracticeRepository {
  List<PracticeAssignment> _assignments = List.from(
    MockPracticeData.assignments,
  );

  @override
  Future<List<PracticeAssignment>> getAssignments({
    bool? isOpen,
    String? status,
    bool? hasSubmission,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    final paged = await getAssignmentsPaged(
      isOpen: isOpen,
      status: status,
      hasSubmission: hasSubmission,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
    return paged.items;
  }

  @override
  Future<PagedList<PracticeAssignment>> getAssignmentsPaged({
    bool? isOpen,
    String? status,
    bool? hasSubmission,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    var list = _assignments;
    if (hasSubmission != null) {
      if (hasSubmission) {
        list = list.where((a) => a.status != PracticeStatus.pending).toList();
      } else {
        list = list.where((a) => a.status == PracticeStatus.pending).toList();
      }
    }
    if (status != null && status.isNotEmpty) {
      if (status == 'Overdue') {
        list = list.where((a) => a.isOverdue).toList();
      } else {
        list = list
            .where((a) => a.status.name.toLowerCase() == status.toLowerCase())
            .toList();
      }
    }
    final totalCount = list.length;
    final startIndex = (pageNumber - 1) * pageSize;
    final items = startIndex < totalCount
        ? list.skip(startIndex).take(pageSize).toList()
        : <PracticeAssignment>[];
    final totalPages = (totalCount / pageSize).ceil();
    return PagedList<PracticeAssignment>(
      items: items,
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: totalCount,
      totalPages: totalPages > 0 ? totalPages : 1,
      hasPreviousPage: pageNumber > 1,
      hasNextPage: pageNumber < totalPages,
    );
  }

  @override
  Future<PracticeAssignment?> getAssignmentDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _assignments.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> submitRecording({
    required String assignmentId,
    required String audioPath,
    required int durationSeconds,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _assignments = _assignments.map((a) {
      if (a.id == assignmentId) {
        return a.copyWith(
          status: PracticeStatus.submitted,
          audioPath: audioPath,
          audioDurationSeconds: durationSeconds,
        );
      }
      return a;
    }).toList();
  }

  @override
  Future<PracticeCounts> getMyAssignmentCounts() async {
    await Future.delayed(const Duration(milliseconds: 100));
    final notSubmitted = _assignments
        .where((a) => a.status == PracticeStatus.pending)
        .length;
    final submitted = _assignments
        .where((a) => a.status == PracticeStatus.submitted)
        .length;
    final needsRevision = _assignments
        .where((a) => a.status == PracticeStatus.needsRevision)
        .length;
    final passed = _assignments
        .where((a) => a.status == PracticeStatus.passed)
        .length;
    final overdue = _assignments.where((a) => a.isOverdue).length;

    return PracticeCounts(
      total: _assignments.length,
      notSubmitted: notSubmitted,
      submitted: submitted,
      needsRevision: needsRevision,
      passed: passed,
      overdue: overdue,
    );
  }

  @override
  Future<List<PracticeSubmissionDetail>> getMySubmissions({
    String? assignmentId,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    final paged = await getMySubmissionsPaged(
      assignmentId: assignmentId,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
    return paged.items;
  }

  @override
  Future<PagedList<PracticeSubmissionDetail>> getMySubmissionsPaged({
    String? assignmentId,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final allList = [
      PracticeSubmissionDetail(
        id: 'submission-01',
        practiceAssignmentId: assignmentId ?? 'practice-03',
        attemptNo: 1,
        submittedAt: DateTime.now().subtract(const Duration(days: 3)),
        status: 'Passed',
        durationSeconds: 124,
        audioUrl: 'https://example.com/audio/sample.mp3',
        assignmentTitle: 'Bản thu kiểm tra: Ca Nhập Lễ Tuần 25',
        feedbacks: [
          PracticeFeedbackItem(
            id: 'fb-01',
            result: 'Passed',
            comment: 'Hát rất chuẩn cao độ và nhịp phách! Chú ý thêm một chút âm lượng ở câu kết bài.',
            reviewerName: 'Ca trưởng Giuse',
            reviewedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ],
      ),
    ];
    final startIndex = (pageNumber - 1) * pageSize;
    final items = startIndex < allList.length
        ? allList.skip(startIndex).take(pageSize).toList()
        : <PracticeSubmissionDetail>[];
    final totalPages = (allList.length / pageSize).ceil();
    final hasNext = pageNumber < totalPages;
    return PagedList<PracticeSubmissionDetail>(
      items: items,
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: allList.length,
      totalPages: totalPages > 0 ? totalPages : 1,
      hasPreviousPage: pageNumber > 1,
      hasNextPage: hasNext,
    );
  }

  @override
  Future<PracticeSubmissionDetail?> getMySubmissionDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return PracticeSubmissionDetail(
      id: id,
      practiceAssignmentId: 'practice-01',
      attemptNo: 1,
      submittedAt: DateTime.now().subtract(const Duration(days: 1)),
      status: 'Submitted',
      durationSeconds: 85,
      audioUrl: 'https://example.com/audio/sample.mp3',
      assignmentTitle: 'Thu âm bè Soprano: Thánh Vịnh 24',
      feedbacks: const [],
    );
  }
}

final practiceApiServiceProvider = Provider<PracticeApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return PracticeApiService(client);
});

final practiceRepositoryProvider = Provider<PracticeRepository>((ref) {
  if (AppEnv.useMock) {
    return MockPracticeRepositoryImpl();
  }
  final apiService = ref.watch(practiceApiServiceProvider);
  return PracticeRepositoryImpl(apiService: apiService);
});

class PracticeListNotifier extends Notifier<AsyncValue<PracticeListState>> {
  int _requestGen = 0;
  String? _currentStatusFilter;
  bool? _currentHasSubmissionFilter;
  int _currentPage = 1;
  static const int _pageSize = 20;

  @override
  AsyncValue<PracticeListState> build() {
    loadAssignments();
    return const AsyncValue.loading();
  }

  PracticeRepository get _repository => ref.read(practiceRepositoryProvider);

  Future<void> loadAssignments({
    String? statusFilter,
    bool? hasSubmissionFilter,
  }) async {
    final gen = ++_requestGen;
    _currentStatusFilter = statusFilter;
    _currentHasSubmissionFilter = hasSubmissionFilter;
    _currentPage = 1;
    state = const AsyncValue.loading();

    try {
      final paged = await _repository.getAssignmentsPaged(
        status: _currentStatusFilter,
        hasSubmission: _currentHasSubmissionFilter,
        pageNumber: 1,
        pageSize: _pageSize,
      );

      if (gen != _requestGen) return;

      state = AsyncValue.data(
        PracticeListState(
          items: paged.items,
          pageNumber: paged.pageNumber,
          totalCount: paged.totalCount,
          hasNextPage: paged.hasNextPage,
        ),
      );
    } catch (e, st) {
      if (gen != _requestGen) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final currentState = state.asData?.value;
    if (currentState == null ||
        currentState.isLoadingMore ||
        !currentState.hasNextPage) {
      return;
    }

    final gen = _requestGen;
    final targetPage = _currentPage + 1;

    state = AsyncValue.data(
      currentState.copyWith(isLoadingMore: true, loadMoreError: null),
    );

    try {
      final paged = await _repository.getAssignmentsPaged(
        status: _currentStatusFilter,
        hasSubmission: _currentHasSubmissionFilter,
        pageNumber: targetPage,
        pageSize: _pageSize,
      );

      if (gen != _requestGen) return;

      // Deduplicate by ID
      final existingIds = currentState.items.map((i) => i.id).toSet();
      final newItems = paged.items
          .where((i) => !existingIds.contains(i.id))
          .toList();

      _currentPage = targetPage;
      state = AsyncValue.data(
        currentState.copyWith(
          items: [...currentState.items, ...newItems],
          pageNumber: targetPage,
          totalCount: paged.totalCount,
          hasNextPage: paged.hasNextPage,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      if (gen != _requestGen) return;
      state = AsyncValue.data(
        currentState.copyWith(
          isLoadingMore: false,
          loadMoreError: 'Không thể tải thêm bài tập: $e',
        ),
      );
    }
  }

  Future<void> submitAssignment({
    required String assignmentId,
    required String audioPath,
    required int durationSeconds,
  }) async {
    await _repository.submitRecording(
      assignmentId: assignmentId,
      audioPath: audioPath,
      durationSeconds: durationSeconds,
    );
    await loadAssignments(
      statusFilter: _currentStatusFilter,
      hasSubmissionFilter: _currentHasSubmissionFilter,
    );
  }
}

final practiceListNotifierProvider =
    NotifierProvider<PracticeListNotifier, AsyncValue<PracticeListState>>(
      PracticeListNotifier.new,
    );

final practiceDetailProvider = FutureProvider.autoDispose
    .family<PracticeAssignment?, String>((ref, id) async {
      final repo = ref.watch(practiceRepositoryProvider);
      return repo.getAssignmentDetail(id);
    });

final practiceCountsProvider = FutureProvider<PracticeCounts>((ref) async {
  final repo = ref.watch(practiceRepositoryProvider);
  return repo.getMyAssignmentCounts();
});

class PracticeSubmissionsState {
  final List<PracticeSubmissionDetail> items;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final int pageNumber;
  final bool hasNextPage;
  final int totalCount;
  final String? errorMessage;
  final String? loadMoreErrorMessage;

  const PracticeSubmissionsState({
    this.items = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.pageNumber = 1,
    this.hasNextPage = false,
    this.totalCount = 0,
    this.errorMessage,
    this.loadMoreErrorMessage,
  });

  PracticeSubmissionsState copyWith({
    List<PracticeSubmissionDetail>? items,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    int? pageNumber,
    bool? hasNextPage,
    int? totalCount,
    String? errorMessage,
    String? loadMoreErrorMessage,
    bool clearLoadMoreError = false,
  }) {
    return PracticeSubmissionsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      pageNumber: pageNumber ?? this.pageNumber,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      totalCount: totalCount ?? this.totalCount,
      errorMessage: errorMessage,
      loadMoreErrorMessage: clearLoadMoreError
          ? null
          : (loadMoreErrorMessage ?? this.loadMoreErrorMessage),
    );
  }
}

class PracticeSubmissionsNotifier extends Notifier<PracticeSubmissionsState> {
  PracticeSubmissionsNotifier(this.arg);
  final String? arg;

  PracticeRepository get _repository => ref.read(practiceRepositoryProvider);
  int _requestId = 0;
  static const int defaultPageSize = 10;
  bool _buildLoadScheduled = false;
  Future<void>? _inFlightInitialLoad;

  @override
  PracticeSubmissionsState build() {
    ref.listen<SessionManager>(sessionManagerProvider, (prev, next) {
      if (prev != null &&
          (prev.sessionEpoch != next.sessionEpoch || !next.isAuthenticated)) {
        reset();
      }
    });

    _buildLoadScheduled = true;
    Future.microtask(() {
      if (_buildLoadScheduled) {
        _buildLoadScheduled = false;
        loadInitial();
      }
    });
    return const PracticeSubmissionsState();
  }

  void reset() {
    _requestId++;
    _buildLoadScheduled = false;
    _inFlightInitialLoad = null;
    state = const PracticeSubmissionsState();
  }

  Future<void> loadInitial() {
    _buildLoadScheduled = false;
    if (_inFlightInitialLoad != null) {
      return _inFlightInitialLoad!;
    }
    return _inFlightInitialLoad = _doLoadInitial();
  }

  Future<void> _doLoadInitial() async {
    final reqId = ++_requestId;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearLoadMoreError: true,
    );

    try {
      final pagedList = await _repository.getMySubmissionsPaged(
        assignmentId: arg,
        pageNumber: 1,
        pageSize: defaultPageSize,
      );
      if (_requestId != reqId) return;

      state = state.copyWith(
        items: pagedList.items,
        isLoading: false,
        pageNumber: 1,
        hasNextPage: pagedList.hasNextPage,
        totalCount: pagedList.totalCount,
        clearLoadMoreError: true,
      );
    } on AppException catch (e) {
      if (_requestId != reqId) return;
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      if (_requestId != reqId) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải lịch sử nộp bài. Vui lòng thử lại.',
      );
    } finally {
      _inFlightInitialLoad = null;
    }
  }

  Future<void> refresh() async {
    final reqId = ++_requestId;
    state = state.copyWith(isRefreshing: true, clearLoadMoreError: true);

    try {
      final pagedList = await _repository.getMySubmissionsPaged(
        assignmentId: arg,
        pageNumber: 1,
        pageSize: defaultPageSize,
      );
      if (_requestId != reqId) return;

      state = state.copyWith(
        items: pagedList.items,
        isRefreshing: false,
        pageNumber: 1,
        hasNextPage: pagedList.hasNextPage,
        totalCount: pagedList.totalCount,
        clearLoadMoreError: true,
      );
    } catch (_) {
      if (_requestId != reqId) return;
      state = state.copyWith(isRefreshing: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasNextPage || state.isLoading) return;

    final reqId = _requestId;
    final nextPage = state.pageNumber + 1;
    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);

    try {
      final pagedList = await _repository.getMySubmissionsPaged(
        assignmentId: arg,
        pageNumber: nextPage,
        pageSize: defaultPageSize,
      );
      if (_requestId != reqId) return;

      final existingIds = state.items.map((e) => e.id).toSet();
      final newItems = pagedList.items
          .where((e) => !existingIds.contains(e.id))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...newItems],
        isLoadingMore: false,
        pageNumber: nextPage,
        hasNextPage: pagedList.hasNextPage,
        totalCount: pagedList.totalCount,
        clearLoadMoreError: true,
      );
    } catch (_) {
      if (_requestId != reqId) return;
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreErrorMessage: 'Không thể tải thêm bản thu. Vui lòng thử lại.',
      );
    }
  }
}

final practiceSubmissionsNotifierProvider = NotifierProvider.autoDispose
    .family<PracticeSubmissionsNotifier, PracticeSubmissionsState, String?>(
      PracticeSubmissionsNotifier.new,
    );

final mySubmissionsProvider = FutureProvider.autoDispose
    .family<List<PracticeSubmissionDetail>, String?>((ref, assignmentId) async {
      final state = ref.watch(
        practiceSubmissionsNotifierProvider(assignmentId),
      );
      if (state.isLoading && state.items.isEmpty) {
        final repo = ref.watch(practiceRepositoryProvider);
        return repo.getMySubmissions(assignmentId: assignmentId);
      }
      return state.items;
    });

final mySubmissionDetailProvider = FutureProvider.autoDispose
    .family<PracticeSubmissionDetail?, String>((ref, submissionId) async {
      final repo = ref.watch(practiceRepositoryProvider);
      return repo.getMySubmissionDetail(submissionId);
    });
