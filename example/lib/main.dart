import 'dart:async';

import 'package:flutter/material.dart';
import 'package:voice_room_kit/voice_room_kit.dart';

import 'mock_signaling_server.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final server = MockSignalingServer();
  await server.start();

  runApp(VoiceRoomDemoApp(server: server));
}

class VoiceRoomDemoApp extends StatefulWidget {
  const VoiceRoomDemoApp({super.key, required this.server});

  final MockSignalingServer server;

  @override
  State<VoiceRoomDemoApp> createState() => _VoiceRoomDemoAppState();
}

class _VoiceRoomDemoAppState extends State<VoiceRoomDemoApp> {
  late final MockRtcEngineAdapter _rtcEngine;
  late final VoiceRoomClient _client;

  VoiceRoomStatus _status = VoiceRoomStatus.idle;
  List<VoiceRoomParticipant> _participants = const [];
  bool _isMuted = false;
  String? _error;

  StreamSubscription<List<VoiceRoomParticipant>>? _participantsSub;
  StreamSubscription<VoiceRoomStatus>? _statusSub;

  @override
  void initState() {
    super.initState();
    _rtcEngine = MockRtcEngineAdapter();
    _client = VoiceRoomClient(
      signaling: WebSocketSignalingClient(),
      rtcEngine: _rtcEngine,
    );

    _participantsSub = _client.participantsStream.listen((participants) {
      setState(() => _participants = participants);
    });
    _statusSub = _client.statusStream.listen((status) {
      setState(() => _status = status);
    });
  }

  @override
  void dispose() {
    unawaited(_participantsSub?.cancel());
    unawaited(_statusSub?.cancel());
    unawaited(_client.dispose());
    unawaited(widget.server.stop());
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _error = null);
    try {
      await _client.connect(
        const VoiceRoomConfig(
          wsUrl: 'ws://127.0.0.1:8765/signaling',
          channelName: 'demo-room',
          userId: 'demo-user',
          userName: 'Demo User',
          role: VoiceRoomRole.organizer,
        ),
      );
    } on VoiceRoomException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Future<void> _disconnect() async {
    await _client.disconnect();
    setState(() {
      _isMuted = false;
      _participants = const [];
    });
  }

  Future<void> _toggleMute() async {
    final next = !_isMuted;
    await _client.setMuted(next);
    setState(() => _isMuted = next);
  }

  void _simulateSpeaking() {
    _rtcEngine.emitSpeaking('demo-user', true);
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _rtcEngine.emitSpeaking('demo-user', false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _status == VoiceRoomStatus.connected;

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('voice_room_kit demo')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Status: ${_status.name}'),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton(
                    onPressed: _status == VoiceRoomStatus.connecting ||
                            _status == VoiceRoomStatus.connected
                        ? null
                        : _connect,
                    child: const Text('Connect'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: isConnected ? _disconnect : null,
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: isConnected ? _toggleMute : null,
                    child: Text(_isMuted ? 'Unmute' : 'Mute'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: isConnected ? _simulateSpeaking : null,
                    child: const Text('Simulate speaking'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Participants (${_participants.length})'),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _participants.length,
                  itemBuilder: (context, index) {
                    final user = _participants[index];
                    return ListTile(
                      title: Text(user.name),
                      subtitle: Text('${user.role.name} · ${user.id}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (user.isSpeaking)
                            const Icon(Icons.graphic_eq, size: 18),
                          if (user.isMuted)
                            const Icon(Icons.mic_off, size: 18),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
