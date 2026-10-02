import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_messages.dart';
import '../data/auth_api_service.dart';
import '../data/auth_dto.dart';
import '../data/auth_repository.dart';

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthApiService(client);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiService = ref.watch(authApiServiceProvider);
  final storage = ref.watch(secureStorageServiceProvider);
  final sessionManager = ref.watch(sessionManagerProvider);
  return AuthRepositoryImpl(
    apiService: apiService,
    storage: storage,
    sessionManager: sessionManager,
  );
});

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, List<String>>? fieldErrors;
  final UserDto? user;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.fieldErrors,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, List<String>>? fieldErrors,
    UserDto? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      fieldErrors: fieldErrors,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<bool> login({
    required String email,
    required String password,
    DevicePlatform? platform,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      fieldErrors: null,
    );
    try {
      final user = await _repository.login(
        email: email,
        password: password,
        platform: platform,
      );
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } on AppException catch (e) {
      final msg = ErrorMessages.getMessage(e.code, fallback: e.message);
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
        fieldErrors: e.fieldErrors,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Đã có lỗi xảy ra. Vui lòng thử lại.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _repository.logout();
    state = const AuthState();
  }

  Future<void> logoutAll() async {
    state = state.copyWith(isLoading: true);
    await _repository.logoutAll();
    state = const AuthState();
  }

  void clearErrors() {
    state = state.copyWith(errorMessage: null, fieldErrors: null);
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
