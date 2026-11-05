import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/features/profile/data/avatar_image_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('harmonia/avatar_picker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final picker = AvatarImagePicker();

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'returns null when the member cancels the system image picker',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);

      expect(await picker.pickImage(), isNull);
    },
  );

  test('returns the selected image path from the platform picker', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => r'C:\cache\avatar.jpg',
    );

    expect(await picker.pickImage(), r'C:\cache\avatar.jpg');
  });
}
