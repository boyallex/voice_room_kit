import 'dart:async';

import 'models/voice_room_config.dart';
import 'models/voice_room_participant.dart';
import 'models/voice_room_status.dart';
import 'rtc/rtc_engine_adapter.dart';
import 'signaling/signaling_client.dart';

/// High-level voice room client coordinating signaling and RTC.
class VoiceRoomClient {
  VoiceRoomClient({
    required SignalingClient signaling,
    required RtcEngineAdapter rtcEngine,
  })  : _signaling = signaling,
        _rtcEngine = rtcEngine;

  final SignalingClient _signaling;
  final RtcEngineAdapter _rtcEngine;

  final _participantsController =
      StreamController<List<VoiceRoomParticipant>>.broadcast();
  final _statusController = StreamController<VoiceRoomStatus>.broadcast();

  StreamSubscription<SignalingEvent>? _signalingSubscription;
  StreamSubscription<(String userId, bool isSpeaking)>? _speakingSubscription;

  VoiceRoomConfig? _config;
  List<VoiceRoomParticipant> _participants = const [];
  VoiceRoomStatus _status = VoiceRoomStatus.idle;

  /// Current participant list.
  List<VoiceRoomParticipant> get participants => List.unmodifiable(_participants);

  /// Current session status.
  VoiceRoomStatus get status => _status;

  /// Emits whenever the participant list changes.
  Stream<List<VoiceRoomParticipant>> get participantsStream =>
      _participantsController.stream;

  /// Emits whenever the session status changes.
  Stream<VoiceRoomStatus> get statusStream => _statusController.stream;

  /// Joins a voice room using [config].
  Future<void> connect(VoiceRoomConfig config) async {
    if (_status == VoiceRoomStatus.connecting ||
        _status == VoiceRoomStatus.connected) {
      return;
    }

    _config = config;
    _setStatus(VoiceRoomStatus.connecting);

    _signalingSubscription ??= _signaling.events.listen(_handleSignalingEvent);
    _speakingSubscription ??=
        _rtcEngine.speakingEvents.listen(_handleSpeakingEvent);

    try {
      await _rtcEngine.join(
        channelName: config.channelName,
        userId: config.userId,
        token: config.token,
      );

      await _signaling.connect(
        wsUrl: config.wsUrl,
        channelName: config.channelName,
        userId: config.userId,
        userName: config.userName,
        token: config.token,
        role: config.role,
      );
    } on Object catch (error) {
      _setStatus(VoiceRoomStatus.error);
      await _cleanupSession();
      throw VoiceRoomException('Failed to connect: $error');
    }
  }

  /// Leaves the voice room and resets state.
  Future<void> disconnect() async {
    if (_status == VoiceRoomStatus.idle ||
        _status == VoiceRoomStatus.disconnected) {
      return;
    }

    await _cleanupSession();
    _participants = const [];
    _participantsController.add(_participants);
    _setStatus(VoiceRoomStatus.disconnected);
  }

  /// Mutes or unmutes the local user.
  Future<void> setMuted(bool muted) async {
    final config = _config;
    if (config == null) {
      return;
    }

    await _rtcEngine.muteLocalAudio(muted);
    await _signaling.sendMuteUpdate(userId: config.userId, isMuted: muted);
    _updateLocalParticipant(
      config.userId,
      (participant) => participant.copyWith(isMuted: muted, isSpeaking: false),
    );
  }

  /// Releases all resources. The client cannot be reused after dispose.
  Future<void> dispose() async {
    await disconnect();
    await _signalingSubscription?.cancel();
    await _speakingSubscription?.cancel();
    _signalingSubscription = null;
    _speakingSubscription = null;
    await _signaling.dispose();
    await _rtcEngine.dispose();
    await _participantsController.close();
    await _statusController.close();
  }

  void _handleSignalingEvent(SignalingEvent event) {
    switch (event) {
      case SignalingParticipantsUpdated(:final participants):
        _participants = participants;
        _participantsController.add(_participants);
        if (_status == VoiceRoomStatus.connecting) {
          _setStatus(VoiceRoomStatus.connected);
        }
      case SignalingError():
        _setStatus(VoiceRoomStatus.error);
        unawaited(_cleanupSession());
      case SignalingDisconnected():
        _setStatus(VoiceRoomStatus.disconnected);
        unawaited(_cleanupSession());
    }
  }

  void _handleSpeakingEvent((String userId, bool isSpeaking) event) {
    final (userId, isSpeaking) = event;
    _updateLocalParticipant(
      userId,
      (participant) => participant.copyWith(isSpeaking: isSpeaking),
    );

    final config = _config;
    if (config != null && config.userId == userId) {
      unawaited(
        _signaling.sendSpeakingUpdate(
          userId: userId,
          isSpeaking: isSpeaking,
        ),
      );
    }
  }

  void _updateLocalParticipant(
    String userId,
    VoiceRoomParticipant Function(VoiceRoomParticipant participant) update,
  ) {
    final index = _participants.indexWhere((user) => user.id == userId);
    if (index == -1) {
      return;
    }

    final updated = List<VoiceRoomParticipant>.from(_participants);
    updated[index] = update(updated[index]);
    _participants = updated;
    _participantsController.add(_participants);
  }

  Future<void> _cleanupSession() async {
    await _signaling.disconnect();
    await _rtcEngine.leave();
    _config = null;
  }

  void _setStatus(VoiceRoomStatus status) {
    _status = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }
}

/// Thrown when a voice room operation fails.
class VoiceRoomException implements Exception {
  VoiceRoomException(this.message);

  final String message;

  @override
  String toString() => 'VoiceRoomException: $message';
}
