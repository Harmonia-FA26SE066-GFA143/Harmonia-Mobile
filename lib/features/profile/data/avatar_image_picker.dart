import 'package:flutter/services.dart';

class AvatarImagePicker {
  static const MethodChannel _channel = MethodChannel('harmonia/avatar_picker');

  Future<String?> pickImage() => _channel.invokeMethod<String>('pickImage');
}
