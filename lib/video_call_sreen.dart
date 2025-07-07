import 'dart:developer';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_test_app/constant.dart';
import 'package:agora_test_app/vido_call_handler.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoCallPage extends StatefulWidget {
  final bool isHost;
  const VideoCallPage({super.key, this.isHost = false});

  @override
  _VideoCallPageState createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  final List<int> _remoteUids = [];
  final List<int> _pendingUsers = [];
  final List<Widget> _remoteViews = [];
  bool _isJoined = false;
  bool _isMicOn = true;
  bool _isCameraOn = true;
  bool _isSpeakerOn = true;
  bool _isFrontCamera = true;
  late bool _isHost;
  late RtcEngine _engine;

  @override
  void initState() {
    _isHost = widget.isHost;
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: AppConstant.appId));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          log("Joined channel. Host status: $_isHost");
          setState(() => _isJoined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          log("User $remoteUid joined. I am host: $_isHost");

          if (_isHost) {
            log("Host: Showing approval dialog for $remoteUid");
            setState(() => _pendingUsers.add(remoteUid));
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showUserApprovalDialog(remoteUid);
            });
          } else {
            log("Participant: Automatically showing $remoteUid");
            setState(() {
              _remoteUids.add(remoteUid);
              _updateRemoteViews();
            });
          }
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          setState(() {
            _remoteUids.remove(remoteUid);
            _pendingUsers.remove(remoteUid);
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

  void _showUserApprovalDialog(int remoteUid) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("New Participant Request"),
            content: Text("User $remoteUid wants to join the call"),
            actions: [
              TextButton(
                onPressed: () {
                  _rejectUser(remoteUid);
                  Navigator.pop(context);
                },
                child: const Text("Reject"),
              ),
              TextButton(
                onPressed: () {
                  _approveUser(remoteUid);
                  Navigator.pop(context);
                },
                child: const Text("Approve"),
              ),
            ],
          ),
    );
  }

  void _approveUser(int remoteUid) {
    log("Approving user $remoteUid");
    setState(() {
      _pendingUsers.remove(remoteUid);
      if (!_remoteUids.contains(remoteUid)) {
        _remoteUids.add(remoteUid);
      }
      _updateRemoteViews();
    });
  }

  void _rejectUser(int remoteUid) {
    log("Rejecting user $remoteUid");
    setState(() {
      _pendingUsers.remove(remoteUid);
    });
  }

  void _updateRemoteViews() {
    log("Updating views for UIDs: $_remoteUids");
    _remoteViews.clear();
    for (var uid in _remoteUids) {
      _remoteViews.add(
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.all(8),
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine,
              canvas: VideoCanvas(uid: uid),
              connection: RtcConnection(channelId: AppConstant.channelName),
            ),
          ),
        ),
      );
    }
    setState(() {});
  }

  //! toggle mic
  Future<void> toggleMic() async {
    setState(() {
      _isMicOn = !_isMicOn;
    });
    await _engine.muteLocalAudioStream(!_isMicOn);
  }

  //! toggle camera
  Future<void> toggleCamera() async {
    setState(() {
      _isCameraOn = !_isCameraOn;
    });
    await _engine.muteLocalVideoStream(!_isCameraOn);
    if (_isCameraOn) {
      await _engine.startPreview();
    }
  }

  //! toggle camera direction (front/back)
  Future<void> toggleCameraDirection() async {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    await _engine.switchCamera();
  }

  //! toggle speaker
  Future<void> toggleSpeaker() async {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    await _engine.setEnableSpeakerphone(_isSpeakerOn);
  }

  //! leave channel
  Future<void> leaveChannel() async {
    await _engine.leaveChannel();
    setState(() {
      _isJoined = false;
      _remoteUids.clear();
      _remoteViews.clear();
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isHost ? 'Hosting Video Call' : 'Video Call'),
      ),
      body: Stack(
        children: [
          _remoteUids.isEmpty
              ? Center(
                child: Text(
                  _isJoined
                      ? _isHost
                          ? 'You are the host. Waiting for participants...'
                          : 'Connected to call'
                      : 'Press call button to start',
                ),
              )
              : GridView.count(
                crossAxisCount: VidoCallHandler(
                  _engine,
                ).calculateGridCount(_remoteUids),
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

          if (_isHost && _pendingUsers.isNotEmpty)
            Positioned(
              top: 50,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Pending: ${_pendingUsers.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),

          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_isJoined)
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: _isMicOn ? Colors.blue : Colors.red,
                        child: IconButton(
                          icon: Icon(_isMicOn ? Icons.mic : Icons.mic_off),
                          color: Colors.white,
                          onPressed: toggleMic,
                        ),
                      ),
                    if (_isJoined)
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
                    if (_isJoined)
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.green,
                        child: IconButton(
                          icon: const Icon(Icons.cameraswitch),
                          color: Colors.white,
                          onPressed: toggleCameraDirection,
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
                const SizedBox(height: 16),
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
                onPressed: () {
                  VidoCallHandler(_engine).joinChannel();
                },
                child: const Icon(Icons.call),
              )
              : null,
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }
}
