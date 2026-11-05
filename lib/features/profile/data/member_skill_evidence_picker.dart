import 'package:flutter/services.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_messages.dart';

class MemberSkillEvidencePicker {
  static const MethodChannel _channel = MethodChannel('harmonia/avatar_picker');

  Future<String?> pickFile() async {
    try {
      return await _channel.invokeMethod<String>('pickEvidence');
    } on PlatformException catch (error) {
      throw AppException(
        code: error.code,
        message: ErrorMessages.getMessage(error.code),
      );
    }
  }
}
