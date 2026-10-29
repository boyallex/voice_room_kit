import 'dart:async';

import 'rtc_engine_adapter.dart';

/// In-memory RTC adapter for tests and example apps.
class MockRtcEngineAdapter implements RtcEngineAdapter {
  MockRtcEngineAdapter();

  final _speakingController =
      StreamController<(String userId, bool isSpeaking)>.broadcast();

  String? _joinedChannel;
  String? _userId;
  bool _isMuted = false;

  @override
  Stream<(String userId, bool isSpeaking)> get speakingEvents =>
      _speakingController.stream;

  bool get isJoined => _joinedChannel != null;
  bool get isMuted => _isMuted;
  String? get joinedChannel => _joinedChannel;
  String? get userId => _userId;

  @override
  Future<void> join({
    required String channelName,
    required String userId,
    required String token,
  }) async {
    _joinedChannel = channelName;
    _userId = userId;
  }

  @override
  Future<void> leave() async {
    _joinedChannel = null;
    _userId = null;
    _isMuted = false;
  }

  @override
  Future<void> muteLocalAudio(bool muted) async {
    _isMuted = muted;
    if (muted) {
      emitSpeaking(userId ?? '', false);
    }
  }

  @override
  Future<void> dispose() async {
    await leave();
    await _speakingController.close();
  }

  /// Simulates a speaking event for tests and demos.
  void emitSpeaking(String userId, bool isSpeaking) {
    if (!_speakingController.isClosed) {
      _speakingController.add((userId, isSpeaking));
    }
  }
}
