/// Pluggable RTC engine used for audio transport (e.g. Agora, LiveKit).
abstract class RtcEngineAdapter {
  /// Emits `(userId, isSpeaking)` when a participant starts or stops speaking.
  Stream<(String userId, bool isSpeaking)> get speakingEvents;

  /// Joins the RTC channel.
  Future<void> join({
    required String channelName,
    required String userId,
    required String token,
  });

  /// Leaves the RTC channel and releases resources.
  Future<void> leave();

  /// Mutes or unmutes the local microphone.
  Future<void> muteLocalAudio(bool muted);

  /// Releases native resources.
  Future<void> dispose();
}
