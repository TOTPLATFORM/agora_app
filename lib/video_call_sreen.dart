import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_rtm/agora_rtm.dart';
import 'package:agora_test_app/constant.dart';
import 'package:agora_test_app/cubit/video_cubit.dart';
import 'package:agora_test_app/cubit/video_state.dart';
import 'package:agora_test_app/vido_call_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'widget/custom_update_remote_view.dart';

class VideoCallPage extends StatefulWidget {
  final String userId;
  const VideoCallPage({super.key, required this.userId});

  @override
  _VideoCallPageState createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  final List<int> _remoteUids = [];
  final List<Widget> _remoteViews = [];
  bool _isJoined = false;
  bool _isMicOn = true;
  bool _isCameraOn = true;
  bool _isSpeakerOn = true;
  bool _isFrontCamera = true;
  late RtcEngine _engine;
  RtmClient? _rtmClient;
  bool _isRtmConnected = false;
  StreamSubscription? _rtmMessageSubscription;

  @override
  void initState() {
    super.initState();
    initAgora();
    VidoCallHandler(_engine).requestPermissions();
  }

  Future<void> initAgora() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: AppConstant.appId));
    _initializeAsParticipant();

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() => _isJoined = true);
          _joinRtmChannel();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() {
            _remoteUids.add(remoteUid);
            updateRemoteViews(
              engine: _engine,
              remoteUids: _remoteUids,
              remoteViews: _remoteViews,
            );
          });
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          setState(() {
            _remoteUids.remove(remoteUid);
            updateRemoteViews(
              engine: _engine,
              remoteUids: _remoteUids,
              remoteViews: _remoteViews,
            );
          });
        },
      ),
    );

    await _engine.enableVideo();
    if (Platform.isAndroid) {
      await _engine.setChannelProfile(
        ChannelProfileType.channelProfileLiveBroadcasting,
      );
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    }
    await _engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 640, height: 480),
        frameRate: 30,
        bitrate: 0,
      ),
    );
    await _engine.startPreview();
  }

  Future<void> _initializeAsParticipant() async {
    try {
      final (status, client) = await RTM(
        AppConstant.appId,
        widget.userId,
        config: RtmConfig(),
      );
      if (status.error) throw Exception(status.reason);

      _rtmClient = client;
      await _rtmClient!.login(AppConstant.token);
      await _engine.joinChannel(
        token: AppConstant.token,
        channelId: AppConstant.channelName,
        uid: 0,
        options: const ChannelMediaOptions(),
      );
    } catch (e) {
      log('Participant initialization failed: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _joinRtmChannel() async {
    try {
      final (subscribeStatus, _) = await _rtmClient!.subscribe(
        AppConstant.channelName,
      );
      if (subscribeStatus.error) {
        log('RTM subscribe failed: ${subscribeStatus.reason}');
        return;
      }
      setState(() => _isRtmConnected = true);
    } catch (e) {
      log('RTM channel subscription error: $e');
    }
  }

  Future<void> leaveChannel() async {
    await _cleanupResources();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _cleanupResources() async {
    await _engine.leaveChannel();
    await _cleanupRtm();
    setState(() {
      _isJoined = false;
      _remoteUids.clear();
      _remoteViews.clear();
    });
  }

  Future<void> _cleanupRtm() async {
    try {
      if (_isRtmConnected) {
        await _rtmClient!.unsubscribe(AppConstant.channelName);
        await _rtmClient!.logout();
        setState(() => _isRtmConnected = false);
      }
      await _rtmMessageSubscription?.cancel();
    } catch (e) {
      log('RTM cleanup error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => VideoCubit(),
      child: BlocBuilder<VideoCubit, VideoState>(
        builder: (context, state) {
          final cubit = context.read<VideoCubit>();
          return Scaffold(
            appBar: AppBar(title: const Text('Video Call')),
            body: _buildMainContent(cubit),
            floatingActionButton: _buildFloatingActionButton(),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _cleanupResources();
    _engine.release();
    super.dispose();
  }

  Widget _buildMainContent(VideoCubit cubit) {
    if (!_isJoined) {
      return const Center(child: Text('Connecting to call...'));
    }

    return Stack(
      children: [
        _remoteUids.isEmpty
            ? const Center(child: Text('Connected to call'))
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
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Column(
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
                      onPressed: () {
                        setState(() => _isMicOn = !_isMicOn);
                        cubit.toggleMic(_isMicOn, _engine);
                      },
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
                      onPressed: () {
                        setState(() => _isCameraOn = !_isCameraOn);
                        cubit.toggleCamera(_isCameraOn, _engine);
                      },
                    ),
                  ),
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.green,
                    child: IconButton(
                      icon: const Icon(Icons.cameraswitch),
                      color: Colors.white,
                      onPressed: () {
                        setState(() => _isFrontCamera = !_isFrontCamera);
                        cubit.toggleCameraDirection(_isFrontCamera, _engine);
                      },
                    ),
                  ),
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: _isSpeakerOn ? Colors.blue : Colors.grey,
                    child: IconButton(
                      icon: const Icon(Icons.volume_up),
                      color: Colors.white,
                      onPressed: () {
                        setState(() => _isSpeakerOn = !_isSpeakerOn);
                        cubit.toggleSpeaker(_isSpeakerOn, _engine);
                      },
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
    );
  }

  Widget _buildFloatingActionButton() {
    if (!_isJoined) {
      return FloatingActionButton(
        onPressed: _initializeAsParticipant,
        child: const Icon(Icons.call),
      );
    }
    return const SizedBox();
  }
}
