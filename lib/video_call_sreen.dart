import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoCallPage extends StatefulWidget {
  const VideoCallPage({super.key});

  @override
  _VideoCallPageState createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  final String appId = "6fc544c0c3384328895b4b95c2e48e74";
  final String channelName = "vedio_call";
  final String token =
      "007eJxTYKjbr8761E001/XR2yyVi0ppbx0uyE9vk5sncuBTWZn4wVcKDGZpyaYmJskGycbGFibGRhYWlqZJJkmWpslGqSYWqeYmt0OTMhoCGRnk8vezMjJAIIjPxVCWmpKZH5+cmJPDwAAA3cohDQ==";

  int? _remoteUid;
  bool _isJoined = false;
  late RtcEngine _engine;

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: appId));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() {
            _isJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          setState(() {
            _remoteUid = null;
          });
        },
      ),
    );

    await _engine.enableVideo();
    await _engine.startPreview();
  }

  void joinChannel() async {
    await _engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  void leaveChannel() async {
    await _engine.leaveChannel();
    setState(() {
      _isJoined = false;
      _remoteUid = null;
    });
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agora Video Chat')),
      body: Stack(
        children: [
          Center(child: _remoteVideo()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 100,
                height: 150,
                child: Center(
                  child:
                      _isJoined
                          ? AgoraVideoView(
                            controller: VideoViewController(
                              rtcEngine: _engine,
                              canvas: const VideoCanvas(uid: 0),
                            ),
                          )
                          : const CircularProgressIndicator(),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isJoined ? leaveChannel : joinChannel,
        child: Icon(_isJoined ? Icons.call_end : Icons.call),
      ),
    );
  }

  Widget _remoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: channelName),
        ),
      );
    } else {
      return const Text(
        'Waiting for a remote user to join...',
        textAlign: TextAlign.center,
      );
    }
  }
}
