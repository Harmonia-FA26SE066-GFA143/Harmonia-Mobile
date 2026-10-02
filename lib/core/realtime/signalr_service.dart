import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../../app/app_env.dart';
import '../storage/secure_storage_service.dart';

class SignalRService {
  final SecureStorageService _storage;
  HubConnection? _hubConnection;
  final _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStreamController.stream;

  SignalRService(this._storage);

  Future<void> connect() async {
    final token = await _storage.getAccessToken();
    if (token == null || token.isEmpty) return;

    if (_hubConnection != null &&
        _hubConnection!.state == HubConnectionState.Connected) {
      return;
    }

    _hubConnection = HubConnectionBuilder()
        .withUrl(
          AppEnv.notificationHubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async =>
                await _storage.getAccessToken() ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    // Event name must match exact server contract name (including Async suffix per Rule 06)
    _hubConnection!.on('ReceiveNotificationAsync', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final data = arguments.first;
        if (data is Map<String, dynamic>) {
          _notificationStreamController.add(data);
        }
      }
    });

    try {
      await _hubConnection!.start();
    } catch (_) {
      // Reconnect will be handled automatically or on demand
    }
  }

  Future<void> stop() async {
    if (_hubConnection != null) {
      await _hubConnection!.stop();
      _hubConnection = null;
    }
  }

  void dispose() {
    stop();
    _notificationStreamController.close();
  }
}
