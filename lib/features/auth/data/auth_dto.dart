enum DevicePlatform {
  android(0),
  ios(1),
  web(2);

  final int value;
  const DevicePlatform(this.value);
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

class UserDto {
  final String id;
  final String email;
  final String roleName;

  const UserDto({
    required this.id,
    required this.email,
    required this.roleName,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      roleName: json['roleName']?.toString() ?? '',
    );
  }
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
