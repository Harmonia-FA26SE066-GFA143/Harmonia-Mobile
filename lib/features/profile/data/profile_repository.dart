import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_env.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/session/session_manager.dart';
import '../../notifications/data/notification_dto.dart';
import 'member_profile_api_service.dart';
import 'member_profile_dto.dart';
import 'profile_models.dart';

export '../../notifications/data/notification_dto.dart' show PagedList;
export 'member_profile_dto.dart';

final memberProfileApiServiceProvider = Provider<MemberProfileApiService>((
  ref,
) {
  final client = ref.watch(apiClientProvider);
  return MemberProfileApiService(client);
});

class MockProfileData {
  static final MemberProfileDto profile = MemberProfileDto(
    id: 'member-01',
    fullName: 'Maria Nguyễn Thị Mai',
    email: 'maria.mai@harmonia.org',
    phone: '0912 345 678',
    dateOfBirth: '1995-05-15',
    joinedDate: '2023-08-15',
    status: MemberStatus.active,
    avatarUrl: null,
  );

  static final List<MemberSkill> skills = [
    const MemberSkill(
      id: 'skill-01',
      name: 'Xướng âm & Hát đơn ca (Solo)',
      categoryName: 'Kỹ năng thanh nhạc',
      level: 'Nâng cao',
      status: SkillApprovalStatus.approved,
    ),
    const MemberSkill(
      id: 'skill-02',
      name: 'Thị tấu & Đọc nốt nhạc nhanh',
      categoryName: 'Kỹ năng thanh nhạc',
      level: 'Trung cấp',
      status: SkillApprovalStatus.approved,
    ),
    const MemberSkill(
      id: 'skill-03',
      name: 'Đệm đàn Organ phụng vụ',
      categoryName: 'Kỹ năng nhạc cụ',
      level: 'Trung cấp',
      status: SkillApprovalStatus.pending,
      note: 'Đã hoàn thành khóa đệm thánh ca phụng vụ cơ bản.',
    ),
  ];
}

abstract class ProfileRepository {
  Future<MemberProfileDto> getProfile();
  Future<MemberProfileDto> updateProfile(UpdateMyMemberProfileRequest request);
  Future<List<MemberSkill>> getSkills({
    String? status,
    int pageNumber = 1,
    int pageSize = 50,
  });
  Future<PagedList<MemberSkill>> getSkillsPaged({
    String? status,
    int pageNumber = 1,
    int pageSize = 50,
  });
  Future<MemberSkill?> getSkillById(String id);
  Future<void> declareNewSkill({
    required String skillId,
    String? level,
    String? name,
    String? categoryName,
    String? note,
  });
  Future<PagedList<ParticipationHistoryDto>> getParticipationHistory({
    String? liturgicalSeasonId,
    String? fromDate,
    String? toDate,
    int pageNumber = 1,
    int pageSize = 20,
  });
}

class ProfileRepositoryImpl implements ProfileRepository {
  final MemberProfileApiService apiService;

  ProfileRepositoryImpl({required this.apiService});

  @override
  Future<MemberProfileDto> getProfile() async {
    return await apiService.getMyProfile();
  }

  @override
  Future<MemberProfileDto> updateProfile(
    UpdateMyMemberProfileRequest request,
  ) async {
    return await apiService.updateMyProfile(request);
  }

  MemberSkill _mapSkillDto(MemberSkillDto dto) {
    SkillApprovalStatus status;
    if (dto.status == 'Approved') {
      status = SkillApprovalStatus.approved;
    } else if (dto.status == 'Rejected') {
      status = SkillApprovalStatus.rejected;
    } else {
      status = SkillApprovalStatus.pending;
    }

    return MemberSkill(
      id: dto.id,
      skillId: dto.skillId,
      name: dto.skillName,
      categoryId: dto.categoryId,
      categoryName: dto.categoryName,
      level: dto.level,
      status: status,
      note: dto.rejectReason,
      rejectReason: dto.rejectReason,
      declaredAt: dto.declaredAt,
      approvedAt: dto.approvedAt,
    );
  }

  @override
  Future<List<MemberSkill>> getSkills({
    String? status,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    final paged = await getSkillsPaged(
      status: status,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
    return paged.items;
  }

  @override
  Future<PagedList<MemberSkill>> getSkillsPaged({
    String? status,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    final pagedList = await apiService.getMySkills(
      status: status,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
    return PagedList<MemberSkill>(
      items: pagedList.items.map(_mapSkillDto).toList(),
      pageNumber: pagedList.pageNumber,
      pageSize: pagedList.pageSize,
      totalCount: pagedList.totalCount,
      totalPages: pagedList.totalPages,
      hasPreviousPage: pagedList.hasPreviousPage,
      hasNextPage: pagedList.hasNextPage,
    );
  }

  @override
  Future<MemberSkill?> getSkillById(String id) async {
    try {
      final dto = await apiService.getMemberSkillById(id);
      return _mapSkillDto(dto);
    } on NotFoundException {
      return null;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> declareNewSkill({
    required String skillId,
    String? level,
    String? name,
    String? categoryName,
    String? note,
  }) async {
    await apiService.declareSkill(skillId: skillId, level: level);
  }

  @override
  Future<PagedList<ParticipationHistoryDto>> getParticipationHistory({
    String? liturgicalSeasonId,
    String? fromDate,
    String? toDate,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    return await apiService.getParticipationHistory(
      liturgicalSeasonId: liturgicalSeasonId,
      fromDate: fromDate,
      toDate: toDate,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
  }
}

class MockProfileRepositoryImpl implements ProfileRepository {
  MemberProfileDto _profile = MockProfileData.profile;
  List<MemberSkill> _skills = List.from(MockProfileData.skills);

  @override
  Future<MemberProfileDto> getProfile() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _profile;
  }

  @override
  Future<MemberProfileDto> updateProfile(
    UpdateMyMemberProfileRequest request,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _profile = MemberProfileDto(
      id: _profile.id,
      fullName: request.fullName,
      email: _profile.email,
      phone: request.phone ?? _profile.phone,
      dateOfBirth: request.dateOfBirth ?? _profile.dateOfBirth,
      joinedDate: _profile.joinedDate,
      status: _profile.status,
      avatarUrl: _profile.avatarUrl,
    );
    return _profile;
  }

  @override
  Future<List<MemberSkill>> getSkills({
    String? status,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    final paged = await getSkillsPaged(
      status: status,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
    return paged.items;
  }

  @override
  Future<PagedList<MemberSkill>> getSkillsPaged({
    String? status,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    List<MemberSkill> filtered = _skills;
    if (status != null && status.isNotEmpty) {
      filtered = _skills
          .where(
            (s) =>
                s.status.name.toLowerCase() == status.toLowerCase() ||
                s.status.label.toLowerCase() == status.toLowerCase(),
          )
          .toList();
    }
    final startIndex = (pageNumber - 1) * pageSize;
    final items = startIndex < filtered.length
        ? filtered.skip(startIndex).take(pageSize).toList()
        : <MemberSkill>[];
    final totalPages = (filtered.length / pageSize).ceil();
    final hasNext = pageNumber < totalPages;
    return PagedList<MemberSkill>(
      items: items,
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: filtered.length,
      totalPages: totalPages > 0 ? totalPages : 1,
      hasPreviousPage: pageNumber > 1,
      hasNextPage: hasNext,
    );
  }

  @override
  Future<MemberSkill?> getSkillById(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _skills.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> declareNewSkill({
    required String skillId,
    String? level,
    String? name,
    String? categoryName,
    String? note,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newSkill = MemberSkill(
      id: 'skill-${DateTime.now().millisecondsSinceEpoch}',
      skillId: skillId,
      name: name ?? 'Kỹ năng mới',
      categoryName: categoryName ?? 'Kỹ năng thanh nhạc',
      level: level ?? 'Sơ cấp',
      status: SkillApprovalStatus.pending,
      note: note,
      declaredAt: DateTime.now(),
    );
    _skills = [..._skills, newSkill];
  }

  @override
  Future<PagedList<ParticipationHistoryDto>> getParticipationHistory({
    String? liturgicalSeasonId,
    String? fromDate,
    String? toDate,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final mockItems = [
      const ParticipationHistoryDto(
        eventId: 'event-01',
        eventDate: '2026-09-27',
        title: 'Chúa nhật XXVI Thường niên',
        liturgicalSeasonName: 'Mùa Thường niên',
        participationStatus: 'Confirmed',
        servedSkills: ['Soprano'],
        rehearsalsHeld: 2,
        rehearsalsAttended: 2,
        assignmentsTotal: 2,
        assignmentsPassed: 2,
      ),
      const ParticipationHistoryDto(
        eventId: 'event-02',
        eventDate: '2026-09-20',
        title: 'Chúa nhật XXV Thường niên',
        liturgicalSeasonName: 'Mùa Thường niên',
        participationStatus: 'Confirmed',
        servedSkills: ['Soprano'],
        rehearsalsHeld: 2,
        rehearsalsAttended: 1,
        assignmentsTotal: 3,
        assignmentsPassed: 2,
      ),
    ];
    return PagedList<ParticipationHistoryDto>(
      items: mockItems,
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: mockItems.length,
      totalPages: 1,
      hasPreviousPage: false,
      hasNextPage: false,
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (AppEnv.useMock) {
    return MockProfileRepositoryImpl();
  }
  final apiService = ref.watch(memberProfileApiServiceProvider);
  return ProfileRepositoryImpl(apiService: apiService);
});

final currentMemberProfileProvider = FutureProvider<MemberProfileDto>((
  ref,
) async {
  final repo = ref.watch(profileRepositoryProvider);
  return await repo.getProfile();
});

class MemberSkillsState {
  final List<MemberSkill> items;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final int pageNumber;
  final bool hasNextPage;
  final int totalCount;
  final String? errorMessage;
  final String? loadMoreErrorMessage;

  const MemberSkillsState({
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

  MemberSkillsState copyWith({
    List<MemberSkill>? items,
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
    return MemberSkillsState(
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

class MemberSkillsNotifier extends Notifier<MemberSkillsState> {
  ProfileRepository get _repository => ref.read(profileRepositoryProvider);
  int _requestId = 0;
  String? _currentStatus;

  static const int defaultPageSize = 10;
  bool _buildLoadScheduled = false;
  Future<void>? _inFlightInitialLoad;

  @override
  MemberSkillsState build() {
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
    return const MemberSkillsState();
  }

  void reset() {
    _requestId++;
    _buildLoadScheduled = false;
    _inFlightInitialLoad = null;
    state = const MemberSkillsState();
  }

  Future<void> loadInitial({String? status}) {
    _buildLoadScheduled = false;
    if (_inFlightInitialLoad != null && _currentStatus == status) {
      return _inFlightInitialLoad!;
    }
    return _inFlightInitialLoad = _doLoadInitial(status);
  }

  Future<void> _doLoadInitial(String? status) async {
    final reqId = ++_requestId;
    _currentStatus = status;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearLoadMoreError: true,
    );

    try {
      final pagedList = await _repository.getSkillsPaged(
        status: status,
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
        errorMessage: 'Không thể tải danh sách kỹ năng. Vui lòng thử lại.',
      );
    } finally {
      _inFlightInitialLoad = null;
    }
  }

  Future<void> refresh() async {
    final reqId = ++_requestId;
    state = state.copyWith(isRefreshing: true, clearLoadMoreError: true);

    try {
      final pagedList = await _repository.getSkillsPaged(
        status: _currentStatus,
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
      final pagedList = await _repository.getSkillsPaged(
        status: _currentStatus,
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
        loadMoreErrorMessage: 'Không thể tải thêm kỹ năng. Vui lòng thử lại.',
      );
    }
  }
}

final memberSkillsNotifierProvider =
    NotifierProvider<MemberSkillsNotifier, MemberSkillsState>(
      MemberSkillsNotifier.new,
    );

final currentMemberSkillsProvider = FutureProvider<List<MemberSkill>>((
  ref,
) async {
  final state = ref.watch(memberSkillsNotifierProvider);
  if (state.isLoading && state.items.isEmpty) {
    final repo = ref.watch(profileRepositoryProvider);
    return await repo.getSkills();
  }
  return state.items;
});
