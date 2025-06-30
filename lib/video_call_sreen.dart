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

  final List<int> _remoteUids = [];
  final List<Widget> _remoteViews = [];
  bool _isJoined = false;
  bool _isMicOn = true;
  bool _isCameraOn = true;
  bool _isSpeakerOn = true;
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
            if (!_remoteUids.contains(remoteUid)) {
              _remoteUids.add(remoteUid);
              _updateRemoteViews();
            }
          });
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          setState(() {
            _remoteUids.remove(remoteUid);
            _updateRemoteViews();
          });
        },
      ),
    );

    await _engine.enableVideo();

    await _engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 640, height: 480),
        frameRate: 30,
        bitrate: 0,
      ),
    );
    await _engine.startPreview();
  }

  void _updateRemoteViews() {
    _remoteViews.clear();
    for (var uid in _remoteUids) {
      _remoteViews.add(
        Container(
          padding: EdgeInsets.all(8),
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine,
              canvas: VideoCanvas(uid: uid),
              connection: RtcConnection(channelId: channelName),
            ),
          ),
        ),
      );
    }
    setState(() {});
  }

  Future<void> joinChannel() async {
    await _engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: true,
      ),
    );
  }

  Future<void> toggleMic() async {
    setState(() {
      _isMicOn = !_isMicOn;
    });
    await _engine.muteLocalAudioStream(!_isMicOn);
  }

  Future<void> toggleCamera() async {
    setState(() {
      _isCameraOn = !_isCameraOn;
    });
    await _engine.muteLocalVideoStream(!_isCameraOn);
    if (_isCameraOn) {
      await _engine.startPreview();
    }
  }

  Future<void> toggleSpeaker() async {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    await _engine.setEnableSpeakerphone(_isSpeakerOn);
  }

  void leaveChannel() async {
    await _engine.leaveChannel();
    setState(() {
      _isJoined = false;
      _remoteUids.clear();
      _remoteViews.clear();
    });
    Navigator.pop(context);
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
          _remoteUids.isEmpty
              ? Center(
                child: Text(
                  _isJoined
                      ? 'Waiting for participants...'
                      : 'Press call button to start',
                ),
              )
              : GridView.count(
                crossAxisCount: _calculateGridCount(),
                children: _remoteViews,
              ),
          if (_isCameraOn && _isJoined)
            Positioned(
              top: 20,
              right: 20,
              child: SizedBox(
                width: 120,
                height: 180,
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              spacing: 16,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: _isMicOn ? Colors.blue : Colors.red,
                      child: IconButton(
                        icon: Icon(_isMicOn ? Icons.mic : Icons.mic_off),
                        color: Colors.white,
                        onPressed: toggleMic,
                      ),
                    ),
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: _isCameraOn ? Colors.blue : Colors.red,
                      child: IconButton(
                        icon: Icon(
                          _isCameraOn ? Icons.videocam : Icons.videocam_off,
                        ),
                        color: Colors.white,
                        onPressed: toggleCamera,
                      ),
                    ),
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: _isSpeakerOn ? Colors.blue : Colors.grey,
                      child: IconButton(
                        icon: const Icon(Icons.volume_up),
                        color: Colors.white,
                        onPressed: toggleSpeaker,
                      ),
                    ),
                  ],
                ),
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.red,
                  child: IconButton(
                    icon: const Icon(Icons.call_end),
                    color: Colors.white,
                    onPressed: leaveChannel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton:
          !_isJoined
              ? FloatingActionButton(
                onPressed: joinChannel,
                child: const Icon(Icons.call),
              )
              : null,
    );
  }

  int _calculateGridCount() {
    if (_remoteUids.isEmpty) return 1;
    if (_remoteUids.length == 1) return 1;
    if (_remoteUids.length <= 4) return 2;
    return 3;
  }
}
