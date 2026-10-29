import '../models/voice_room_participant.dart';

/// Events emitted by a [SignalingClient].
sealed class SignalingEvent {}

class SignalingParticipantsUpdated extends SignalingEvent {
  SignalingParticipantsUpdated(this.participants);

  final List<VoiceRoomParticipant> participants;
}

class SignalingError extends SignalingEvent {
  SignalingError(this.message);

  final String message;
}

class SignalingDisconnected extends SignalingEvent {}

/// WebSocket-based signaling for room presence and mute state.
abstract class SignalingClient {
  Stream<SignalingEvent> get events;

  Future<void> connect({
    required String wsUrl,
    required String channelName,
    required String userId,
    required String userName,
    required String token,
    VoiceRoomRole role = VoiceRoomRole.participant,
  });

  Future<void> sendMuteUpdate({
    required String userId,
    required bool isMuted,
  });

  Future<void> sendSpeakingUpdate({
    required String userId,
    required bool isSpeaking,
  });

  Future<void> disconnect();

  Future<void> dispose();
}
