import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    ref.listen<NotificationRepository>(notificationRepositoryProvider, (
      previous,
      next,
    ) {
      _realtimeSub?.cancel();
      _realtimeSub = next.realtimeNotifications.listen(
        _handleRealtimeNotification,
      );
    });

    _listenRealtime();
    Future.microtask(() => loadInitial());
    return const NotificationState();
  }

  void _listenRealtime() {
    _realtimeSub = _repository.realtimeNotifications.listen(
      _handleRealtimeNotification,
    );
  }

  void _handleRealtimeNotification(NotificationDto notification) {
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
  }

  int _notifierEpoch = 0;
  int _syncEpoch = 0;
  bool _isMarkingAllAsRead = false;
  Future<void>? _inFlightInitialLoad;

  Future<void> loadInitial() {
    if (_inFlightInitialLoad != null) {
      return _inFlightInitialLoad!;
    }
    return _inFlightInitialLoad = _executeLoadInitial();
  }

  Future<void> _executeLoadInitial() async {
    final currentEpoch = _notifierEpoch;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final pagedList = await _repository.getNotifications(pageNumber: 1);
      if (_notifierEpoch != currentEpoch) return;
      int unread = 0;
      try {
        unread = await _repository.getUnreadCount();
      } catch (_) {
        unread = pagedList.items.where((n) => !n.isRead).length;
      }
      if (_notifierEpoch != currentEpoch) return;

      _syncEpoch++;
      state = state.copyWith(
        items: pagedList.items,
        isLoading: false,
        pageNumber: 1,
        hasNextPage: pagedList.hasNextPage,
        unreadCount: unread,
      );
    } on AppException catch (e) {
      if (_notifierEpoch != currentEpoch) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.getMessage(e.code, fallback: e.message),
      );
    } catch (_) {
      if (_notifierEpoch != currentEpoch) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải thông báo. Vui lòng thử lại.',
      );
    } finally {
      _inFlightInitialLoad = null;
    }
  }

  Future<void> refresh() async {
    final currentEpoch = _notifierEpoch;
    state = state.copyWith(isRefreshing: true, errorMessage: null);
    try {
      final pagedList = await _repository.getNotifications(pageNumber: 1);
      if (_notifierEpoch != currentEpoch) return;
      final unread = await _repository.getUnreadCount();
      if (_notifierEpoch != currentEpoch) return;
      _syncEpoch++;
      state = state.copyWith(
        items: pagedList.items,
        isRefreshing: false,
        pageNumber: 1,
        hasNextPage: pagedList.hasNextPage,
        unreadCount: unread,
      );
    } catch (_) {
      if (_notifierEpoch != currentEpoch) return;
      state = state.copyWith(isRefreshing: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasNextPage) return;

    final currentEpoch = _notifierEpoch;
    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.pageNumber + 1;

    try {
      final pagedList = await _repository.getNotifications(
        pageNumber: nextPage,
      );
      if (_notifierEpoch != currentEpoch) return;

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
      if (_notifierEpoch != currentEpoch) return;
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
    final currentEpoch = _notifierEpoch;
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
      if (_notifierEpoch != currentEpoch) return;
      final curIndex = state.items.indexWhere((n) => n.id == id);
      if (curIndex != -1) {
        final currentItem = state.items[curIndex];
        // Only revert and increment unreadCount if item in state is currently marked read
        if (currentItem.isRead) {
          final revertedList = List<NotificationDto>.from(state.items);
          revertedList[curIndex] = target;
          state = state.copyWith(
            items: revertedList,
            unreadCount: state.unreadCount + 1,
          );
        }
      }
    }
  }

  Future<void> markAllAsRead() async {
    if (_isMarkingAllAsRead) return;
    _isMarkingAllAsRead = true;

    final currentEpoch = _notifierEpoch;
    final startSyncEpoch = _syncEpoch;
    final baselineUnread = state.unreadCount;

    final markedIds = state.items
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .toSet();

    final updatedList = state.items.map((n) {
      if (!n.isRead) {
        return n.copyWith(isRead: true, readAt: DateTime.now());
      }
      return n;
    }).toList();
    state = state.copyWith(items: updatedList, unreadCount: 0);

    try {
      await _repository.markAllAsRead();
      if (_notifierEpoch != currentEpoch) return;
    } catch (_) {
      // Revert if failed, but NEVER revert if session was reset or changed while request was in-flight
      if (_notifierEpoch != currentEpoch) return;

      final revertedList = state.items.map((n) {
        if (markedIds.contains(n.id) && n.isRead) {
          return n.copyWith(isRead: false, readAt: null);
        }
        return n;
      }).toList();

      // Determine accurate unread count:
      // If pull-to-refresh succeeded during this flight (_syncEpoch != startSyncEpoch),
      // state.unreadCount is already the accurate server count from refresh.
      // Otherwise, state.unreadCount reflects any new notifications received via realtime
      // since the baseline zeroing, so we restore baselineUnread + state.unreadCount.
      final int fallbackUnread = (_syncEpoch != startSyncEpoch)
          ? state.unreadCount
          : (baselineUnread + state.unreadCount);

      state = state.copyWith(items: revertedList, unreadCount: fallbackUnread);

      // Attempt immediate resynchronization with server for exact consistency
      try {
        final serverUnread = await _repository.getUnreadCount();
        if (_notifierEpoch == currentEpoch) {
          state = state.copyWith(unreadCount: serverUnread);
        }
      } catch (_) {
        // Fallback unread count remains in effect if network is offline
      }
    } finally {
      _isMarkingAllAsRead = false;
    }
  }

  void reset() {
    _notifierEpoch++;
    _syncEpoch++;
    _isMarkingAllAsRead = false;
    _inFlightInitialLoad = null;
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
