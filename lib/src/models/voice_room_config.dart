import 'voice_room_participant.dart';

/// Connection parameters for joining a voice room.
class VoiceRoomConfig {
  const VoiceRoomConfig({
    required this.wsUrl,
    required this.channelName,
    required this.userId,
    required this.userName,
    this.token = '',
    this.role = VoiceRoomRole.participant,
  });

  final String wsUrl;
  final String channelName;
  final String userId;
  final String userName;
  final String token;
  final VoiceRoomRole role;
}
