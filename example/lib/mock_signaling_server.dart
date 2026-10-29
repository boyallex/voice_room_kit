import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Minimal in-memory WebSocket signaling server for the example app.
class MockSignalingServer {
  MockSignalingServer({this.port = 8765});

  final int port;
  HttpServer? _server;
  final Map<WebSocket, _ConnectedUser> _clients = {};

  Future<void> start() async {
    if (_server != null) {
      return;
    }

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    unawaited(_server!.forEach(_handleRequest));
  }

  Future<void> stop() async {
    for (final client in _clients.keys.toList()) {
      await client.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path != '/signaling' ||
        !WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found')
        ..close();
      return;
    }

    final socket = await WebSocketTransformer.upgrade(request);
    _clients[socket] = _ConnectedUser();

    socket.listen(
      (dynamic message) => _handleMessage(socket, message),
      onDone: () => _removeClient(socket),
      onError: (_) => _removeClient(socket),
    );
  }

  void _handleMessage(WebSocket socket, dynamic rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage as String);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      switch (decoded['type'] as String?) {
        case 'join':
          _clients[socket] = _ConnectedUser(
            channel: decoded['channel'] as String?,
            userId: decoded['userId'] as String?,
            userName: decoded['userName'] as String?,
            role: decoded['role'] as String? ?? 'participant',
          );
          _broadcastParticipants(decoded['channel'] as String?);
        case 'mute':
          _updateUser(
            decoded['userId'] as String?,
            isMuted: decoded['isMuted'] as bool?,
          );
        case 'speaking':
          _updateUser(
            decoded['userId'] as String?,
            isSpeaking: decoded['isSpeaking'] as bool?,
          );
      }
    } on Object {
      socket.add(jsonEncode({'type': 'error', 'message': 'Invalid message'}));
    }
  }

  void _updateUser(
    String? userId, {
    bool? isMuted,
    bool? isSpeaking,
  }) {
    if (userId == null) {
      return;
    }

    String? channel;
    for (final entry in _clients.entries) {
      if (entry.value.userId == userId) {
        entry.value
          ..isMuted = isMuted ?? entry.value.isMuted
          ..isSpeaking = isSpeaking ?? entry.value.isSpeaking;
        channel = entry.value.channel;
      }
    }

    if (channel != null) {
      _broadcastParticipants(channel);
    }
  }

  void _removeClient(WebSocket socket) {
    final channel = _clients.remove(socket)?.channel;
    if (channel != null) {
      _broadcastParticipants(channel);
    }
  }

  void _broadcastParticipants(String? channel) {
    if (channel == null) {
      return;
    }

    final users = _clients.values
        .where((user) => user.channel == channel && user.userId != null)
        .map(
          (user) => {
            'userId': user.userId,
            'userName': user.userName,
            'role': user.role,
            'isMuted': user.isMuted,
            'isSpeaking': user.isSpeaking,
          },
        )
        .toList();

    final payload = jsonEncode({'type': 'participants', 'users': users});

    for (final entry in _clients.entries) {
      if (entry.value.channel == channel) {
        entry.key.add(payload);
      }
    }
  }
}

class _ConnectedUser {
  _ConnectedUser({
    this.channel,
    this.userId,
    this.userName,
    this.role = 'participant',
  });

  final String? channel;
  final String? userId;
  final String? userName;
  final String role;
  bool isMuted = false;
  bool isSpeaking = false;
}
