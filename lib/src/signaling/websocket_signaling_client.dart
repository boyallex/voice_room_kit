import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/voice_room_participant.dart';
import 'signaling_client.dart';

/// WebSocket signaling client using a simple JSON message protocol.
class WebSocketSignalingClient implements SignalingClient {
  WebSocketSignalingClient();

  final _eventsController = StreamController<SignalingEvent>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  @override
  Stream<SignalingEvent> get events => _eventsController.stream;

  @override
  Future<void> connect({
    required String wsUrl,
    required String channelName,
    required String userId,
    required String userName,
    required String token,
    VoiceRoomRole role = VoiceRoomRole.participant,
  }) async {
    await disconnect();

    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _subscription = _channel!.stream.listen(
      _handleMessage,
      onError: (Object error) {
        _eventsController.add(SignalingError(error.toString()));
      },
      onDone: () {
        _eventsController.add(SignalingDisconnected());
      },
    );

    _send({
      'type': 'join',
      'channel': channelName,
      'userId': userId,
      'userName': userName,
      'token': token,
      'role': role.name,
    });
  }

  @override
  Future<void> sendMuteUpdate({
    required String userId,
    required bool isMuted,
  }) async {
    _send({
      'type': 'mute',
      'userId': userId,
      'isMuted': isMuted,
    });
  }

  @override
  Future<void> sendSpeakingUpdate({
    required String userId,
    required bool isSpeaking,
  }) async {
    _send({
      'type': 'speaking',
      'userId': userId,
      'isSpeaking': isSpeaking,
    });
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _eventsController.close();
  }

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    channel.sink.add(jsonEncode(message));
  }

  void _handleMessage(dynamic rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage as String);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      switch (decoded['type'] as String?) {
        case 'participants':
          _eventsController.add(
            SignalingParticipantsUpdated(_parseParticipants(decoded)),
          );
        case 'error':
          _eventsController.add(
            SignalingError(decoded['message'] as String? ?? 'Unknown error'),
          );
        case 'disconnected':
          _eventsController.add(SignalingDisconnected());
      }
    } on Object catch (error) {
      _eventsController.add(SignalingError(error.toString()));
    }
  }

  List<VoiceRoomParticipant> _parseParticipants(Map<String, dynamic> message) {
    final users = message['users'];
    if (users is! List) {
      return const [];
    }

    return users
        .whereType<Map<String, dynamic>>()
        .map(
          (user) => VoiceRoomParticipant(
            id: user['userId'] as String? ?? '',
            name: user['userName'] as String? ?? '',
            role: _parseRole(user['role'] as String?),
            isMuted: user['isMuted'] as bool? ?? false,
            isSpeaking: user['isSpeaking'] as bool? ?? false,
          ),
        )
        .toList();
  }

  VoiceRoomRole _parseRole(String? role) {
    return switch (role) {
      'organizer' => VoiceRoomRole.organizer,
      _ => VoiceRoomRole.participant,
    };
  }
}
