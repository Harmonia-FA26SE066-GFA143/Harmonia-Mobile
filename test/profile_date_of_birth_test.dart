import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/app/theme/app_theme.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_repository.dart';
import 'package:harmonia_mobile/features/profile/data/profile_repository.dart';
import 'package:harmonia_mobile/features/profile/presentation/profile_screen.dart';

import 'support/fake_profile_repository.dart';

class _FakeProfileRepo extends MockProfileRepositoryImpl {
  _FakeProfileRepo({required this.initialProfile, this.failUpdate = false});

  MemberProfileDto initialProfile;
  final bool failUpdate;
  UpdateMyMemberProfileRequest? lastUpdateRequest;
  int updateCallCount = 0;
  int getProfileCallCount = 0;

  @override
  Future<MemberProfileDto> getProfile() async {
    getProfileCallCount++;
    return initialProfile;
  }

  @override
  Future<MemberProfileDto> updateProfile(
    UpdateMyMemberProfileRequest request,
  ) async {
    updateCallCount++;
    lastUpdateRequest = request;
    if (failUpdate) {
      throw const AppException(
        code: 'VALIDATION_FAILED',
        message: 'Dữ liệu không hợp lệ từ máy chủ.',
      );
    }
    initialProfile = MemberProfileDto(
      id: initialProfile.id,
      fullName: request.fullName,
      email: initialProfile.email,
      phone: request.phone ?? initialProfile.phone,
      dateOfBirth: request.dateOfBirth,
      gender: request.gender ?? initialProfile.gender,
      saintName: request.saintName,
      joinedDate: initialProfile.joinedDate,
      status: initialProfile.status,
      avatarUrl: initialProfile.avatarUrl,
    );
    return initialProfile;
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Profile date of birth unit helpers', () {
    test('formatProfileDateOfBirthDisplay converts ISO to dd/MM/yyyy', () {
      expect(formatProfileDateOfBirthDisplay('2004-05-16'), '16/05/2004');
      expect(formatProfileDateOfBirthDisplay('1995-12-05'), '05/12/1995');
      expect(
        formatProfileDateOfBirthDisplay('2004-05-16T00:00:00Z'),
        '16/05/2004',
      );
      expect(formatProfileDateOfBirthDisplay('16/05/2004'), '16/05/2004');
      expect(formatProfileDateOfBirthDisplay(null), isNull);
      expect(formatProfileDateOfBirthDisplay(''), isNull);
      expect(formatProfileDateOfBirthDisplay('   '), isNull);
    });

    test('validateProfileDateOfBirthInput validates calendar validity & future date', () {
      expect(validateProfileDateOfBirthInput('16/05/2004'), isNull);
      expect(
        validateProfileDateOfBirthInput('29/02/2004'),
        isNull,
      ); // leap year
      expect(validateProfileDateOfBirthInput(''), isNull); // optional
      expect(validateProfileDateOfBirthInput(null), isNull); // optional

      // Invalid calendar days
      expect(
        validateProfileDateOfBirthInput('31/02/2004'),
        'Ngày sinh không hợp lệ (ngày không tồn tại).',
      );
      expect(
        validateProfileDateOfBirthInput('29/02/2003'),
        'Ngày sinh không hợp lệ (ngày không tồn tại).',
      );
      expect(
        validateProfileDateOfBirthInput('31/04/2004'),
        'Ngày sinh không hợp lệ (ngày không tồn tại).',
      );

      // Future date
      final nextYear = DateTime.now().year + 1;
      expect(
        validateProfileDateOfBirthInput('01/01/$nextYear'),
        'Ngày sinh không được ở trong tương lai.',
      );

      // Invalid format
      expect(
        validateProfileDateOfBirthInput('2004-05-16'),
        'Ngày sinh không đúng định dạng dd/mm/yyyy.',
      );
      expect(
        validateProfileDateOfBirthInput('16-05-2004'),
        'Ngày sinh không đúng định dạng dd/mm/yyyy.',
      );
      expect(
        validateProfileDateOfBirthInput('abc'),
        'Ngày sinh không đúng định dạng dd/mm/yyyy.',
      );
    });

    test('convertProfileDisplayDateToIso converts dd/MM/yyyy to yyyy-MM-dd without timezone shifting', () {
      expect(convertProfileDisplayDateToIso('16/05/2004'), '2004-05-16');
      expect(convertProfileDisplayDateToIso('01/01/2000'), '2000-01-01');
      expect(convertProfileDisplayDateToIso('29/02/2004'), '2004-02-29');
      expect(convertProfileDisplayDateToIso(''), isNull);
      expect(convertProfileDisplayDateToIso(null), isNull);
    });
  });

  group('ProfileScreen widget date of birth flow', () {
    testWidgets(
      'displays dd/MM/yyyy on profile page and in edit form with dd/mm/yyyy placeholder',
      (tester) async {
        final session = SessionManager(SecureStorageService());
        await session.markAuthenticated(role: 'ChoirMember');
        addTearDown(session.dispose);

        final repo = _FakeProfileRepo(
          initialProfile: const MemberProfileDto(
            id: 'm1',
            fullName: 'Nguyen Van A',
            email: 'a@example.com',
            phone: '0901234567',
            dateOfBirth: '2004-05-16',
            joinedDate: '2023-01-01',
            status: MemberStatus.active,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionManagerProvider.overrideWithValue(session),
              profileRepositoryProvider.overrideWithValue(repo),
              publicAppSettingsProvider.overrideWith(
                (ref) async =>
                    const PublicAppSettings(choirName: 'Ca đoàn Cecilia'),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const ProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Profile screen displays formatted dd/MM/yyyy
        expect(find.text('16/05/2004'), findsOneWidget);
        expect(find.text('2004-05-16'), findsNothing);

        // 2. Open edit dialog
        await tester.tap(find.text('Chỉnh sửa thông tin cá nhân'));
        await tester.pumpAndSettle();

        // 3. Edit form shows dd/MM/yyyy and placeholder dd/mm/yyyy
        expect(find.text('Cập nhật hồ sơ ca viên'), findsOneWidget);
        final dobField = find.widgetWithText(TextField, '16/05/2004');
        expect(dobField, findsOneWidget);
        final textFieldWidget = tester.widget<TextField>(dobField);
        expect(textFieldWidget.decoration?.hintText, 'dd/mm/yyyy');
      },
    );

    testWidgets(
      'empty date of birth displays Chưa cập nhật and opens form with empty text field',
      (tester) async {
        final session = SessionManager(SecureStorageService());
        await session.markAuthenticated(role: 'ChoirMember');
        addTearDown(session.dispose);

        final repo = _FakeProfileRepo(
          initialProfile: const MemberProfileDto(
            id: 'm2',
            fullName: 'Nguyen Van B',
            email: 'b@example.com',
            phone: '0901234568',
            dateOfBirth: null,
            joinedDate: '2023-01-01',
            status: MemberStatus.active,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionManagerProvider.overrideWithValue(session),
              profileRepositoryProvider.overrideWithValue(repo),
              publicAppSettingsProvider.overrideWith(
                (ref) async =>
                    const PublicAppSettings(choirName: 'Ca đoàn Cecilia'),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const ProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final label in ['Ngày sinh', 'Giới tính', 'Tên thánh']) {
          final row = find
              .ancestor(of: find.text(label), matching: find.byType(Row))
              .first;
          expect(
            find.descendant(of: row, matching: find.text('Chưa cập nhật')),
            findsOneWidget,
          );
        }

        await tester.tap(find.text('Chỉnh sửa thông tin cá nhân'));
        await tester.pumpAndSettle();

        // dob field is empty with placeholder dd/mm/yyyy
        final dobFieldFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'dd/mm/yyyy',
        );
        expect(dobFieldFinder, findsOneWidget);
        final dobField = tester.widget<TextField>(dobFieldFinder);
        expect(dobField.controller?.text, isEmpty);
      },
    );

    testWidgets(
      'entering invalid date 31/02/2004 shows error under field and stops before calling API',
      (tester) async {
        final session = SessionManager(SecureStorageService());
        await session.markAuthenticated(role: 'ChoirMember');
        addTearDown(session.dispose);

        final repo = _FakeProfileRepo(
          initialProfile: const MemberProfileDto(
            id: 'm3',
            fullName: 'Nguyen Van C',
            email: 'c@example.com',
            phone: '0901234569',
            dateOfBirth: null,
            joinedDate: '2023-01-01',
            status: MemberStatus.active,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionManagerProvider.overrideWithValue(session),
              profileRepositoryProvider.overrideWithValue(repo),
              publicAppSettingsProvider.overrideWith(
                (ref) async =>
                    const PublicAppSettings(choirName: 'Ca đoàn Cecilia'),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const ProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Chỉnh sửa thông tin cá nhân'));
        await tester.pumpAndSettle();

        final dobFieldFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'dd/mm/yyyy',
        );
        await tester.enterText(dobFieldFinder, '31022004');
        await tester.pumpAndSettle();

        expect(find.text('31/02/2004'), findsOneWidget);
        expect(
          find.text('Ngày sinh không hợp lệ (ngày không tồn tại).'),
          findsOneWidget,
        );

        final saveButton = find.text('Lưu thay đổi');
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();
        // API update was NOT called
        expect(repo.updateCallCount, 0);
        expect(repo.lastUpdateRequest, isNull);
      },
    );

    testWidgets(
      'entering future date shows error and stops before calling API',
      (tester) async {
        final session = SessionManager(SecureStorageService());
        await session.markAuthenticated(role: 'ChoirMember');
        addTearDown(session.dispose);

        final repo = _FakeProfileRepo(
          initialProfile: const MemberProfileDto(
            id: 'm4',
            fullName: 'Nguyen Van D',
            email: 'd@example.com',
            phone: '0901234570',
            dateOfBirth: null,
            joinedDate: '2023-01-01',
            status: MemberStatus.active,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionManagerProvider.overrideWithValue(session),
              profileRepositoryProvider.overrideWithValue(repo),
              publicAppSettingsProvider.overrideWith(
                (ref) async =>
                    const PublicAppSettings(choirName: 'Ca đoàn Cecilia'),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const ProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Chỉnh sửa thông tin cá nhân'));
        await tester.pumpAndSettle();

        final dobFieldFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'dd/mm/yyyy',
        );
        final nextYear = DateTime.now().year + 1;
        await tester.enterText(dobFieldFinder, '16/05/$nextYear');
        await tester.pumpAndSettle();

        final saveButton = find.text('Lưu thay đổi');
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(
          find.text('Ngày sinh không được ở trong tương lai.'),
          findsOneWidget,
        );
        expect(repo.updateCallCount, 0);
      },
    );

    testWidgets(
      'saving date of birth, gender and saint name refreshes the profile',
      (tester) async {
        final session = SessionManager(SecureStorageService());
        await session.markAuthenticated(role: 'ChoirMember');
        addTearDown(session.dispose);

        final repo = _FakeProfileRepo(
          initialProfile: const MemberProfileDto(
            id: 'm5',
            fullName: 'Nguyen Van E',
            email: 'e@example.com',
            saintName: 'Giuse',
            phone: '0901234571',
            dateOfBirth: null,
            joinedDate: '2023-01-01',
            status: MemberStatus.active,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionManagerProvider.overrideWithValue(session),
              profileRepositoryProvider.overrideWithValue(repo),
              publicAppSettingsProvider.overrideWith(
                (ref) async =>
                    const PublicAppSettings(choirName: 'Ca đoàn Cecilia'),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const ProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Chỉnh sửa thông tin cá nhân'));
        await tester.pumpAndSettle();

        final dobFieldFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'dd/mm/yyyy',
        );
        final saintNameField = find.widgetWithText(
          TextField,
          'Tên thánh (không bắt buộc)',
        );
        expect(
          tester.widget<TextField>(saintNameField).controller?.text,
          'Giuse',
        );
        await tester.enterText(saintNameField, '  Têrêsa  ');

        await tester.enterText(dobFieldFinder, '160');
        await tester.pumpAndSettle();
        expect(find.text('16/0'), findsOneWidget);

        await tester.enterText(dobFieldFinder, '16052004');
        await tester.pumpAndSettle();
        expect(find.text('16/05/2004'), findsOneWidget);

        final genderField = find.byType(DropdownButtonFormField<MemberGender>);
        await tester.ensureVisible(genderField);
        await tester.tap(genderField);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nam').last);
        await tester.pumpAndSettle();

        final saveButton = find.text('Lưu thay đổi');
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // 1. API was called with yyyy-MM-dd
        expect(repo.updateCallCount, 1);
        expect(repo.lastUpdateRequest?.dateOfBirth, '2004-05-16');
        expect(repo.lastUpdateRequest?.toJson()['dateOfBirth'], '2004-05-16');

        // 2. Profile was reloaded and displays 16/05/2004
        expect(find.text('16/05/2004'), findsOneWidget);
        expect(repo.lastUpdateRequest?.toJson()['gender'], 'Male');
        expect(repo.lastUpdateRequest?.toJson()['saintName'], 'Têrêsa');
        expect(find.text('Têrêsa'), findsOneWidget);
        expect(find.text('Nam'), findsOneWidget);
        expect(find.text('Đã cập nhật hồ sơ thành công!'), findsOneWidget);

        await tester.tap(find.text('Chỉnh sửa thông tin cá nhân'));
        await tester.pumpAndSettle();

        await tester.enterText(saintNameField, 'a' * 51);
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();
        expect(
          find.text('Tên thánh không được vượt quá 50 ký tự.'),
          findsOneWidget,
        );
        expect(repo.updateCallCount, 1);

        await tester.enterText(saintNameField, '');
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();
        expect(repo.updateCallCount, 2);
        expect(repo.lastUpdateRequest?.toJson()['saintName'], '');
        expect(find.text('Têrêsa'), findsNothing);
      },
    );

    testWidgets(
      'API failure preserves user inputs and displays error message',
      (tester) async {
        final session = SessionManager(SecureStorageService());
        await session.markAuthenticated(role: 'ChoirMember');
        addTearDown(session.dispose);

        final repo = _FakeProfileRepo(
          initialProfile: const MemberProfileDto(
            id: 'm6',
            fullName: 'Nguyen Van F',
            email: 'f@example.com',
            phone: '0901234572',
            dateOfBirth: null,
            joinedDate: '2023-01-01',
            status: MemberStatus.active,
          ),
          failUpdate: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionManagerProvider.overrideWithValue(session),
              profileRepositoryProvider.overrideWithValue(repo),
              publicAppSettingsProvider.overrideWith(
                (ref) async =>
                    const PublicAppSettings(choirName: 'Ca đoàn Cecilia'),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const ProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Chỉnh sửa thông tin cá nhân'));
        await tester.pumpAndSettle();

        final dobFieldFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'dd/mm/yyyy',
        );
        await tester.enterText(dobFieldFinder, '16/05/2004');
        await tester.pumpAndSettle();

        final saveButton = find.text('Lưu thay đổi');
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Error message displayed from ErrorMessages.forException
        expect(
          find.text('Vui lòng kiểm tra lại thông tin đã nhập.'),
          findsOneWidget,
        );

        // Input is preserved
        final dobField = tester.widget<TextField>(dobFieldFinder);
        expect(dobField.controller?.text, '16/05/2004');
      },
    );
  });
}
