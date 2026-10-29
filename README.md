# voice_room_kit

Minimal Flutter SDK for voice rooms using WebSocket signaling and a pluggable RTC adapter.

Inspired by the Agora RTC + WebSocket signaling pattern, without bundling a specific RTC vendor.

## Features

- `VoiceRoomClient` — coordinates signaling and RTC with participant/status streams
- `VoiceRoomParticipant` — room member model (`id`, `name`, `role`, `isMuted`, `isSpeaking`)
- `VoiceRoomStatus` — session lifecycle (`idle`, `connecting`, `connected`, `disconnected`, `error`)
- `SignalingClient` — abstract signaling API with `WebSocketSignalingClient`
- `RtcEngineAdapter` — abstract RTC API with `MockRtcEngineAdapter` for tests and demos
- `VoiceRoomConfig` — connection settings (`wsUrl`, `channelName`, `userId`, `userName`, `token`)

## Quick start

```dart
import 'package:voice_room_kit/voice_room_kit.dart';

final client = VoiceRoomClient(
  signaling: WebSocketSignalingClient(),
  rtcEngine: MockRtcEngineAdapter(),
);

await client.connect(
  const VoiceRoomConfig(
    wsUrl: 'ws://localhost:8765',
    channelName: 'demo-room',
    userId: 'user-1',
    userName: 'Alice',
    token: 'optional-rtc-token',
  ),
);

client.participantsStream.listen((users) {
  print('Participants: ${users.length}');
});

await client.setMuted(true);
await client.disconnect();
await client.dispose();
```

## Signaling protocol

JSON messages over WebSocket:

**Client → server**

- `join` — `{ "type": "join", "channel", "userId", "userName", "token", "role" }`
- `mute` — `{ "type": "mute", "userId", "isMuted" }`
- `speaking` — `{ "type": "speaking", "userId", "isSpeaking" }`

**Server → client**

- `participants` — `{ "type": "participants", "users": [...] }`
- `error` — `{ "type": "error", "message" }`

## Example

See `example/` for a mock signaling server and demo UI.

```bash
cd example
flutter run
```

## Integrating a real RTC engine

Implement `RtcEngineAdapter` for your provider (e.g. Agora) and pass it to `VoiceRoomClient`:

```dart
class AgoraRtcEngineAdapter implements RtcEngineAdapter {
  // join / leave / muteLocalAudio / speakingEvents / dispose
}
```

Keep vendor SDKs in the app or a separate adapter package — `voice_room_kit` stays vendor-neutral.

## License

MIT — see [LICENSE](LICENSE).
