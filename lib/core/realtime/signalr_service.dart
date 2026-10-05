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

  bool _isConnecting = false;

  bool get isConnected => _hubConnection?.state == HubConnectionState.Connected;

  Future<void> connect() async {
    if (_isConnecting) return;

    if (_hubConnection != null &&
        (_hubConnection!.state == HubConnectionState.Connected ||
            _hubConnection!.state == HubConnectionState.Connecting ||
            _hubConnection!.state == HubConnectionState.Reconnecting)) {
      return;
    }

    final token = await _storage.getAccessToken();
    if (token == null || token.isEmpty) return;

    _isConnecting = true;

    try {
      // Disconnect previous connection if in a weird state
      if (_hubConnection != null) {
        try {
          await _hubConnection!.stop();
        } catch (_) {}
        _hubConnection = null;
      }

      _hubConnection = HubConnectionBuilder()
          .withUrl(
            AppEnv.notificationHubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async =>
                  await _storage.getAccessToken() ?? '',
            ),
          )
          .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 30000])
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

      await _hubConnection!.start();
    } catch (_) {
      // Handled gracefully: Automatic reconnect or reconnect on next session action
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> stop() async {
    _isConnecting = false;
    if (_hubConnection != null) {
      try {
        await _hubConnection!.stop();
      } catch (_) {}
      _hubConnection = null;
    }
  }

  void dispose() {
    stop();
    _notificationStreamController.close();
  }
}
