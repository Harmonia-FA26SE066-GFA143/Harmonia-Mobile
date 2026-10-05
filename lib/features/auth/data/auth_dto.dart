enum DevicePlatform {
  android(0, 'Android'),
  ios(1, 'iOS'),
  web(2, 'Web');

  final int value;
  final String wireName;
  const DevicePlatform(this.value, this.wireName);
}

class LoginRequest {
  final String email;
  final String password;
  final String? deviceId;
  final int? platform;

  const LoginRequest({
    required this.email,
    required this.password,
    this.deviceId,
    this.platform,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'email': email, 'password': password};
    if (deviceId != null) map['deviceId'] = deviceId;
    if (platform != null) map['platform'] = platform;
    return map;
  }
}

class GoogleLoginRequest {
  final String idToken;
  final String? deviceId;
  final int? platform;

  const GoogleLoginRequest({
    required this.idToken,
    this.deviceId,
    this.platform,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'idToken': idToken};
    if (deviceId != null) map['deviceId'] = deviceId;
    if (platform != null) map['platform'] = platform;
    return map;
  }
}

class RefreshTokenRequest {
  final String refreshToken;

  const RefreshTokenRequest({required this.refreshToken});

  Map<String, dynamic> toJson() => {'refreshToken': refreshToken};
}

class LogoutRequest {
  final String refreshToken;

  const LogoutRequest({required this.refreshToken});

  Map<String, dynamic> toJson() => {'refreshToken': refreshToken};
}

class ChangePasswordRequest {
  final String currentPassword;
  final String newPassword;

  const ChangePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
    'currentPassword': currentPassword,
    'newPassword': newPassword,
  };
}

class ForgotPasswordRequest {
  final String email;
  final int? platform;

  const ForgotPasswordRequest({required this.email, this.platform});

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'email': email};
    if (platform != null) map['platform'] = platform;
    return map;
  }
}

class ResetPasswordRequest {
  final String token;
  final String newPassword;

  const ResetPasswordRequest({required this.token, required this.newPassword});

  Map<String, dynamic> toJson() => {'token': token, 'newPassword': newPassword};
}

class UserDto {
  final String id;
  final String email;
  final String fullName;
  final String roleName;

  const UserDto({
    required this.id,
    required this.email,
    required this.fullName,
    required this.roleName,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      roleName: json['roleName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'roleName': roleName,
  };
}

class LoginResponse {
  final String accessToken;
  final String accessTokenExpiresAt;
  final String refreshToken;
  final UserDto user;

  const LoginResponse({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['accessToken']?.toString() ?? '',
      accessTokenExpiresAt: json['accessTokenExpiresAt']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      user: UserDto.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
    );
  }
}
