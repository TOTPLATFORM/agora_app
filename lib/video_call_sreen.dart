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
import 'widget/show_accept_or_reject_dialog.dart';

class VideoCallPage extends StatefulWidget {
  final bool isHost;
  final String userId;
  const VideoCallPage({super.key, this.isHost = false, required this.userId});

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
  bool _isHost = false;
  int? _hostUid;
  late RtcEngine _engine;
  RtmClient? _rtmClient;
  bool _isRtmConnected = false;
  StreamSubscription? _rtmMessageSubscription;
  StreamSubscription? _rtmStateSubscription;
  bool _isSessionCreated = false;

  @override
  void initState() {
    super.initState();
    initAgora();
    VidoCallHandler(_engine).requestPermissions();
  }

  Future<void> initAgora() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: AppConstant.appId));
    if (widget.isHost) {
      await _createSession();
    } else {
      _initializeAsParticipant();
    }

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          log("Joined channel. Host status: $_isHost");
          setState(() => _isJoined = true);
          if (_remoteUids.isEmpty) {
            setState(() {
              _isHost = true;
              _hostUid = 0;
            });
          }
          _joinRtmChannel();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          log("User $remoteUid joined. I am host: $_isHost");

          if (_isHost) {
            log("Host: Showing approval dialog for $remoteUid");
            setState(() => _pendingUsers.add(remoteUid));
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                showUserApprovalDialog(
                  remoteUid: remoteUid,
                  context: context,
                  accept: () {
                    _approveUser(remoteUid);
                    Navigator.pop(context);
                  },
                  reject: () {
                    _rejectUser(remoteUid);
                    Navigator.pop(context);
                  },
                );
              }
            });
          } else {
            log("Participant: Automatically showing $remoteUid");
            setState(() {
              _remoteUids.add(remoteUid);
              updateRemoteViews(
                engine: _engine,
                remoteUids: _remoteUids,
                remoteViews: _remoteViews,
              );
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

  //! Create session
  Future<void> _createSession() async {
    try {
      // Initialize RTM first
      final (status, client) = await RTM(
        AppConstant.appId,
        widget.userId,
        config: RtmConfig(),
      );
      if (status.error) throw Exception(status.reason);

      _rtmClient = client;
      await _rtmClient!.login(AppConstant.token);

      // Create session channel
      await _rtmClient!.subscribe(AppConstant.channelName);

      setState(() {
        _isSessionCreated = true;
        _isHost = true;
        _hostUid = 0; // Host always has UID 0
      });

      // Host automatically joins RTC channel after session creation
      await _engine.joinChannel(
        token: AppConstant.token,
        channelId: AppConstant.channelName,
        uid: 0,
        options: const ChannelMediaOptions(),
      );
    } catch (e) {
      log('Session creation failed: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  //! initialize as participant
  Future<void> _initializeAsParticipant() async {
    try {
      // Initialize RTM
      final (status, client) = await RTM(
        AppConstant.appId,
        widget.userId,
        config: RtmConfig(),
      );
      if (status.error) throw Exception(status.reason);

      _rtmClient = client;
      await _rtmClient!.login(AppConstant.token);

      // Send join request to host
      await _rtmClient!.publish(
        AppConstant.channelName,
        'JOIN_REQUEST:${widget.userId}',
        channelType: RtmChannelType.message,
      );

      // Show waiting UI
      setState(() => _isJoined = false);
    } catch (e) {
      log('Participant initialization failed: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  void _handleRtmMessage(String message) {
    if (!_isHost) return;

    final parts = message.split(':');
    if (parts.length == 2 && parts[0] == 'JOIN_REQUEST') {
      final userId = parts[1];

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: Text('Join Request from $userId'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        _sendRtmMessage('APPROVE:$userId');
                        Navigator.pop(ctx);
                      },
                      child: const Text('Approve'),
                    ),
                    TextButton(
                      onPressed: () {
                        _sendRtmMessage('REJECT:$userId');
                        Navigator.pop(ctx);
                      },
                      child: const Text('Reject'),
                    ),
                  ],
                ),
          );
        }
      });
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
      log('RTM channel subscribed successfully');
      setState(() => _isRtmConnected = true);

      VidoCallHandler(_engine).sendPeriodicMessages(rtmClient: _rtmClient!);
    } catch (e) {
      log('RTM channel subscription error: $e');
    }
  }

  Future<void> _sendRtmMessage(String message) async {
    try {
      final (status, _) = await _rtmClient!.publish(
        AppConstant.channelName,
        message,
        channelType: RtmChannelType.message,
        customType: 'PlainText',
      );

      if (status.error) {
        log('Failed to send RTM message: ${status.reason}');
      }
    } catch (e) {
      log('RTM message sending error: $e');
    }
  }

  void _approveUser(int remoteUid) {
    log("Approving user $remoteUid");
    _sendRtmMessage('APPROVE:$remoteUid');

    setState(() {
      _pendingUsers.remove(remoteUid);
      if (!_remoteUids.contains(remoteUid)) {
        _remoteUids.add(remoteUid);
      }
      updateRemoteViews(
        engine: _engine,
        remoteUids: _remoteUids,
        remoteViews: _remoteViews,
      );
    });
  }

  void _rejectUser(int remoteUid) {
    log("Rejecting user $remoteUid");
    _sendRtmMessage('REJECT:$remoteUid');
    setState(() => _pendingUsers.remove(remoteUid));
  }

  Future<void> leaveChannel() async {
    await _cleanupResources();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _cleanupResources() async {
    // Leave RTC channel
    await _engine.leaveChannel();

    // Clean up RTM
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
        // Unsubscribe from channel
        final (unsubscribeStatus, _) = await _rtmClient!.unsubscribe(
          AppConstant.channelName,
        );
        if (unsubscribeStatus.error) {
          log('RTM unsubscribe failed: ${unsubscribeStatus.reason}');
        }

        // Logout
        final (logoutStatus, _) = await _rtmClient!.logout();
        if (logoutStatus.error) {
          log('RTM logout failed: ${logoutStatus.reason}');
        }

        setState(() => _isRtmConnected = false);
      }

      // Cancel subscriptions
      await _rtmMessageSubscription?.cancel();
      await _rtmStateSubscription?.cancel();
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
            appBar: AppBar(
              title: Text(_isHost ? 'Hosting Video Call' : 'Video Call'),
            ),
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
    if (_isHost && !_isSessionCreated) {
      return Center(
        child: ElevatedButton(
          onPressed: _createSession,
          child: const Text('Create Session'),
        ),
      );
    }

    if (!_isHost && !_isJoined) {
      return const Center(child: Text('Waiting for host approval...'));
    }

    return Stack(
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
                        onPressed: () {
                          setState(() => _isMicOn = !_isMicOn);
                          cubit.toggleMic(_isMicOn, _engine);
                        },
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
                        onPressed: () {
                          setState(() => _isCameraOn = !_isCameraOn);
                          cubit.toggleCamera(_isCameraOn, _engine);
                        },
                      ),
                    ),
                  if (_isJoined)
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
    if (_isHost && !_isSessionCreated) {
      return Text("This 5ra Not Work Do Search Again ");
    }

    if (!_isJoined) {
      return FloatingActionButton(
        onPressed: () => _initializeAsParticipant(),
        child: const Icon(Icons.call),
      );
    }

    return Text("This 5ra Not Work Do Search Again ");
  }
}
