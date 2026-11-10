import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../../app/app_env.dart';
import '../storage/secure_storage_service.dart';

class SignalRService {
  final SecureStorageService _storage;
  HubConnection? _hubConnection;
  final _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _connectedStreamController = StreamController<void>.broadcast();

  final _directorNoteController = StreamController<int>.broadcast();
  int _directorNoteVersion = 0;

  Stream<int> get directorNoteStream => _directorNoteController.stream;

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStreamController.stream;
  Stream<void> get connectedStream => _connectedStreamController.stream;

  SignalRService(this._storage);

  bool _isConnecting = false;
  int _connectionEpoch = 0;

  bool get isConnected => _hubConnection?.state == HubConnectionState.Connected;

  Future<void> connect() async {
    if (_isConnecting || _notificationStreamController.isClosed) return;
    if (_hubConnection != null &&
        (_hubConnection!.state == HubConnectionState.Connected ||
            _hubConnection!.state == HubConnectionState.Connecting ||
            _hubConnection!.state == HubConnectionState.Reconnecting)) {
      return;
    }

    _isConnecting = true;
    final epoch = _connectionEpoch;
    try {
      final token = await _storage.getAccessToken();
      if (epoch != _connectionEpoch || token == null || token.isEmpty) return;
      final previous = _hubConnection;
      _hubConnection = null;
      if (previous != null) {
        try {
          await previous.stop();
        } catch (_) {}
        if (epoch != _connectionEpoch) return;
      }

      final connection = HubConnectionBuilder()
          .withUrl(
            AppEnv.notificationHubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async =>
                  await _storage.getAccessToken() ?? '',
            ),
          )
          .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 30000])
          .build();
      _hubConnection = connection;

      // Ignore callbacks from connections that belonged to an earlier session.
      bool isCurrent() =>
          epoch == _connectionEpoch &&
          identical(_hubConnection, connection) &&
          !_notificationStreamController.isClosed;

      connection.on('ReceiveNotificationAsync', (arguments) {
        if (!isCurrent() || arguments == null || arguments.isEmpty) return;
        final data = arguments.first;
        if (data is Map<String, dynamic>) {
          _notificationStreamController.add(data);
        }
      });
      for (final method in [
        'ReceiveDirectorNoteAsync',
        'ReceiveDirectorNotesReadAsync',
      ]) {
        connection.on(method, (_) {
          if (isCurrent()) _directorNoteController.add(++_directorNoteVersion);
        });
      }
      void notifyConnected() {
        if (!isCurrent()) return;
        _connectedStreamController.add(null);
        _directorNoteController.add(++_directorNoteVersion);
      }

      connection.onreconnected(({connectionId}) => notifyConnected());
      await connection.start();
      if (isConnected) notifyConnected();
    } catch (_) {
      // Reconnect automatically, or retry when the app returns to the foreground.
    } finally {
      if (epoch == _connectionEpoch) _isConnecting = false;
    }
  }

  Future<void> stop() async {
    _connectionEpoch++;
    _isConnecting = false;
    final connection = _hubConnection;
    _hubConnection = null;
    try {
      await connection?.stop();
    } catch (_) {}
  }

  void dispose() {
    unawaited(stop());
    _notificationStreamController.close();
    _connectedStreamController.close();
    _directorNoteController.close();
  }
}
