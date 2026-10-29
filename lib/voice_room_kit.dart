/// Minimal voice room SDK with WebSocket signaling and pluggable RTC adapters.
library;

export 'src/models/voice_room_config.dart';
export 'src/models/voice_room_participant.dart';
export 'src/models/voice_room_status.dart';
export 'src/rtc/mock_rtc_engine_adapter.dart';
export 'src/rtc/rtc_engine_adapter.dart';
export 'src/signaling/signaling_client.dart';
export 'src/signaling/websocket_signaling_client.dart';
export 'src/voice_room_client.dart';
