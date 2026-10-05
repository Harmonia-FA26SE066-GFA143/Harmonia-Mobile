import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_env.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_messages.dart';
import '../data/notification_api_service.dart';
import '../data/notification_dto.dart';
import '../data/notification_repository.dart';

final notificationApiServiceProvider = Provider<NotificationApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return NotificationApiService(client);
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (AppEnv.useMock) {
    final repo = MockNotificationRepositoryImpl();
    ref.onDispose(() => repo.dispose());
    return repo;
  }
  final apiService = ref.watch(notificationApiServiceProvider);
  final signalR = ref.watch(signalRServiceProvider);
  final repo = NotificationRepositoryImpl(
    apiService: apiService,
    signalRService: signalR,
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});

class NotificationState {
  final List<NotificationDto> items;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final int pageNumber;
  final bool hasNextPage;
  final int unreadCount;
  final String? errorMessage;

  const NotificationState({
    this.items = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.pageNumber = 1,
    this.hasNextPage = false,
    this.unreadCount = 0,
    this.errorMessage,
  });

  NotificationState copyWith({
    List<NotificationDto>? items,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    int? pageNumber,
    bool? hasNextPage,
    int? unreadCount,
    String? errorMessage,
  }) {
    return NotificationState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      pageNumber: pageNumber ?? this.pageNumber,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      unreadCount: unreadCount ?? this.unreadCount,
      errorMessage: errorMessage,
    );
  }
}

class NotificationNotifier extends Notifier<NotificationState> {
  StreamSubscription? _realtimeSub;

  NotificationRepository get _repository =>
      ref.read(notificationRepositoryProvider);

  @override
  NotificationState build() {
    ref.onDispose(() {
      _realtimeSub?.cancel();
    });

    _listenRealtime();
    Future.microtask(() => loadInitial());
    return const NotificationState();
  }

  void _listenRealtime() {
    _realtimeSub = _repository.realtimeNotifications.listen((notification) {
      // Deduplicate by ID per Rule 06
      final existingIndex = state.items.indexWhere(
        (n) => n.id == notification.id,
      );
      if (existingIndex >= 0) {
        final updatedList = List<NotificationDto>.from(state.items);
        updatedList[existingIndex] = notification;
        state = state.copyWith(items: updatedList);
      } else {
        final updatedList = [notification, ...state.items];
        final newCount = notification.isRead
            ? state.unreadCount
            : state.unreadCount + 1;
        state = state.copyWith(items: updatedList, unreadCount: newCount);
      }
    });
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final pagedList = await _repository.getNotifications(pageNumber: 1);
      int unread = 0;
      try {
        unread = await _repository.getUnreadCount();
      } catch (_) {
        unread = pagedList.items.where((n) => !n.isRead).length;
      }

      state = state.copyWith(
        items: pagedList.items,
        isLoading: false,
        pageNumber: 1,
        hasNextPage: pagedList.hasNextPage,
        unreadCount: unread,
      );
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.getMessage(e.code, fallback: e.message),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải thông báo. Vui lòng thử lại.',
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, errorMessage: null);
    try {
      final pagedList = await _repository.getNotifications(pageNumber: 1);
      final unread = await _repository.getUnreadCount();
      state = state.copyWith(
        items: pagedList.items,
        isRefreshing: false,
        pageNumber: 1,
        hasNextPage: pagedList.hasNextPage,
        unreadCount: unread,
      );
    } catch (_) {
      state = state.copyWith(isRefreshing: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasNextPage) return;

    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.pageNumber + 1;

    try {
      final pagedList = await _repository.getNotifications(
        pageNumber: nextPage,
      );

      // Merge and deduplicate by id
      final existingIds = state.items.map((e) => e.id).toSet();
      final newItems = pagedList.items
          .where((e) => !existingIds.contains(e.id))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...newItems],
        isLoadingMore: false,
        pageNumber: nextPage,
        hasNextPage: pagedList.hasNextPage,
      );
    } catch (_) {
      // Keep previous data when load more fails per Rule 03
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> markAsRead(String id) async {
    final targetIndex = state.items.indexWhere((n) => n.id == id);
    if (targetIndex < 0) return;

    final target = state.items[targetIndex];
    if (target.isRead) return;

    // Optimistic update
    final updatedList = List<NotificationDto>.from(state.items);
    updatedList[targetIndex] = target.copyWith(
      isRead: true,
      readAt: DateTime.now(),
    );
    final newCount = (state.unreadCount > 0) ? state.unreadCount - 1 : 0;
    state = state.copyWith(items: updatedList, unreadCount: newCount);

    try {
      await _repository.markAsRead(id);
    } catch (_) {
      // Revert if failed
      final revertedList = List<NotificationDto>.from(state.items);
      revertedList[targetIndex] = target;
      state = state.copyWith(
        items: revertedList,
        unreadCount: state.unreadCount + 1,
      );
    }
  }

  void reset() {
    _realtimeSub?.cancel();
    _realtimeSub = null;
    state = const NotificationState();
  }

  void reconnectRealtime() {
    _realtimeSub?.cancel();
    _listenRealtime();
  }
}

final notificationNotifierProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(
      NotificationNotifier.new,
    );
