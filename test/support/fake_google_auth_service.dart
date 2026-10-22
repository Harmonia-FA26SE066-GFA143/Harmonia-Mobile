import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/features/auth/data/google_auth_service.dart';

class MockGoogleAuthService implements GoogleAuthService {
  final String? mockToken;
  final bool shouldCancel;
  final AppException? errorToThrow;

  MockGoogleAuthService({
    this.mockToken = 'mock-google-id-token',
    this.shouldCancel = false,
    this.errorToThrow,
  });

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> getIdToken() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (shouldCancel) {
      return null;
    }
    return mockToken;
  }

  @override
  Future<void> signOut() async {}
}
