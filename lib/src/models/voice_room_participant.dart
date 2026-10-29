/// Role of a participant inside a voice room.
enum VoiceRoomRole {
  organizer,
  participant,
}

/// A user present in a voice room.
class VoiceRoomParticipant {
  const VoiceRoomParticipant({
    required this.id,
    required this.name,
    required this.role,
    this.isMuted = false,
    this.isSpeaking = false,
  });

  final String id;
  final String name;
  final VoiceRoomRole role;
  final bool isMuted;
  final bool isSpeaking;

  VoiceRoomParticipant copyWith({
    String? id,
    String? name,
    VoiceRoomRole? role,
    bool? isMuted,
    bool? isSpeaking,
  }) {
    return VoiceRoomParticipant(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VoiceRoomParticipant &&
        other.id == id &&
        other.name == name &&
        other.role == role &&
        other.isMuted == isMuted &&
        other.isSpeaking == isSpeaking;
  }

  @override
  int get hashCode => Object.hash(id, name, role, isMuted, isSpeaking);

  @override
  String toString() {
    return 'VoiceRoomParticipant(id: $id, name: $name, role: $role, '
        'isMuted: $isMuted, isSpeaking: $isSpeaking)';
  }
}
