import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_room_kit/voice_room_kit.dart';

void main() {
  group('VoiceRoomParticipant', () {
    test('copyWith updates selected fields', () {
      const participant = VoiceRoomParticipant(
        id: '1',
        name: 'Alice',
        role: VoiceRoomRole.participant,
      );

      final updated = participant.copyWith(isMuted: true, isSpeaking: true);

      expect(updated.isMuted, isTrue);
      expect(updated.isSpeaking, isTrue);
      expect(updated.id, participant.id);
    });
  });

  group('MockRtcEngineAdapter', () {
    test('join, mute, leave lifecycle', () async {
      final rtc = MockRtcEngineAdapter();

      await rtc.join(
        channelName: 'demo',
        userId: 'user-1',
        token: 'token',
      );
      expect(rtc.isJoined, isTrue);

      await rtc.muteLocalAudio(true);
      expect(rtc.isMuted, isTrue);

      await rtc.leave();
      expect(rtc.isJoined, isFalse);

      await rtc.dispose();
    });

    test('emits speaking events', () async {
      final rtc = MockRtcEngineAdapter();
      final events = <(String, bool)>[];
      final subscription = rtc.speakingEvents.listen(events.add);

      rtc.emitSpeaking('user-1', true);
      rtc.emitSpeaking('user-1', false);

      await Future<void>.delayed(Duration.zero);
      expect(events, [('user-1', true), ('user-1', false)]);

      await subscription.cancel();
      await rtc.dispose();
    });
  });

  group('VoiceRoomClient', () {
    test('connect updates status and participants', () async {
      final signaling = _FakeSignalingClient();
      final rtc = MockRtcEngineAdapter();
      final client = VoiceRoomClient(signaling: signaling, rtcEngine: rtc);

      final statuses = <VoiceRoomStatus>[];
      final participants = <List<VoiceRoomParticipant>>[];
      final statusSub = client.statusStream.listen(statuses.add);
      final participantSub = client.participantsStream.listen(participants.add);

      await client.connect(
        const VoiceRoomConfig(
          wsUrl: 'ws://localhost:8765',
          channelName: 'room-a',
          userId: 'user-1',
          userName: 'Alice',
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(statuses, contains(VoiceRoomStatus.connecting));
      expect(statuses.last, VoiceRoomStatus.connected);
      expect(client.participants, hasLength(1));
      expect(client.participants.first.name, 'Alice');

      await client.setMuted(true);
      expect(client.participants.first.isMuted, isTrue);

      await client.disconnect();
      expect(client.status, VoiceRoomStatus.disconnected);

      await statusSub.cancel();
      await participantSub.cancel();
      await client.dispose();
    });
  });
}

class _FakeSignalingClient implements SignalingClient {
  final _eventsController = StreamController<SignalingEvent>.broadcast();

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
    _eventsController.add(
      SignalingParticipantsUpdated([
        VoiceRoomParticipant(
          id: userId,
          name: userName,
          role: role,
        ),
      ]),
    );
  }

  @override
  Future<void> sendMuteUpdate({
    required String userId,
    required bool isMuted,
  }) async {}

  @override
  Future<void> sendSpeakingUpdate({
    required String userId,
    required bool isSpeaking,
  }) async {}

  @override
  Future<void> disconnect() async {
    _eventsController.add(SignalingDisconnected());
  }

  @override
  Future<void> dispose() async {
    await _eventsController.close();
  }
}
