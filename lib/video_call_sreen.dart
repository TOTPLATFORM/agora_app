import 'dart:async';
import 'dart:convert';
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
import 'package:permission_handler/permission_handler.dart';

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
  late RtmClient _rtmClient;
  bool _isRtmConnected = false;
  StreamSubscription? _rtmMessageSubscription;
  StreamSubscription? _rtmStateSubscription;

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    await [
      Permission.microphone,
      Permission.camera,
      Permission.bluetooth,
      Permission.bluetoothConnect,
    ].request();

    // Initialize RTC Engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      RtcEngineContext(
        appId: AppConstant.appId,
        areaCode: AreaCode.areaCodeGlob.value(),
      ),
    );

    // Initialize RTM Client
    try {
      final (status, client) = await RTM(AppConstant.appId, widget.userId);
      if (status.error) {
        log('RTM initialization failed: ${status.reason}');
        return;
      }
      _rtmClient = client;
      log('RTM initialized successfully');

      // Set up RTM listeners
      // _rtmMessageSubscription = _rtmClient.onMessage.listen((event) {
      //   log(
      //     'Received message from channel: ${event.channelName}, type: ${event.channelType}',
      //   );
      //   log('Message content: ${utf8.decode(event.message!)}');
      //   _handleRtmMessage(utf8.decode(event.message!));
      // });

      // _rtmStateSubscription = _rtmClient.onLinkState.listen((event) {
      //   log(
      //     'RTM state changed: ${event.previousState} -> ${event.currentState}',
      //   );
      //   log('Reason: ${event.reason}, operation: ${event.operation}');
      // });

      // Login to RTM
      final (loginStatus, _) = await _rtmClient.login(AppConstant.token);
      if (loginStatus.error) {
        log('RTM login failed: ${loginStatus.reason}');
        return;
      }
      log('RTM login successful');
    } catch (e) {
      log('RTM initialization error: $e');
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

  void _handleRtmMessage(String message) {
    // Implement your message handling logic here
    log('Processing RTM message: $message');
    // Example: Parse messages for approval/rejection
    try {
      final parts = message.split(':');
      if (parts.length == 2) {
        final command = parts[0];
        final uid = int.tryParse(parts[1]);

        if (uid != null) {
          if (command == 'APPROVE' && !_remoteUids.contains(uid)) {
            setState(() => _remoteUids.add(uid));
          } else if (command == 'REJECT') {
            // Handle rejection if needed
          }
        }
      }
    } catch (e) {
      log('Error parsing RTM message: $e');
    }
  }

  Future<void> _joinRtmChannel() async {
    try {
      // Subscribe to channel
      final (subscribeStatus, _) = await _rtmClient.subscribe(
        AppConstant.channelName,
      );
      if (subscribeStatus.error) {
        log('RTM subscribe failed: ${subscribeStatus.reason}');
        return;
      }
      log('RTM channel subscribed successfully');
      setState(() => _isRtmConnected = true);

      // Example: Send periodic messages (optional)
      _sendPeriodicMessages();
    } catch (e) {
      log('RTM channel subscription error: $e');
    }
  }

  Future<void> _sendPeriodicMessages() async {
    // Example of sending periodic messages (like in the documentation)
    for (var i = 0; i < 5; i++) {
      // Reduced from 100 to 5 for demo purposes
      try {
        final (status, _) = await _rtmClient.publish(
          AppConstant.channelName,
          'message number: $i',
          channelType: RtmChannelType.message,
          customType: 'PlainText',
        );

        if (status.error) {
          log('Message publish failed: ${status.reason}');
        } else {
          log('Message $i sent successfully');
        }
      } catch (e) {
        log('Message sending error: $e');
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _sendRtmMessage(String message) async {
    try {
      final (status, _) = await _rtmClient.publish(
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
        final (unsubscribeStatus, _) = await _rtmClient.unsubscribe(
          AppConstant.channelName,
        );
        if (unsubscribeStatus.error) {
          log('RTM unsubscribe failed: ${unsubscribeStatus.reason}');
        }

        // Logout
        final (logoutStatus, _) = await _rtmClient.logout();
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
                              backgroundColor:
                                  _isMicOn ? Colors.blue : Colors.red,
                              child: IconButton(
                                icon: Icon(
                                  _isMicOn ? Icons.mic : Icons.mic_off,
                                ),
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
                              backgroundColor:
                                  _isCameraOn ? Colors.blue : Colors.red,
                              child: IconButton(
                                icon: Icon(
                                  _isCameraOn
                                      ? Icons.videocam
                                      : Icons.videocam_off,
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
                                  setState(
                                    () => _isFrontCamera = !_isFrontCamera,
                                  );
                                  cubit.toggleCameraDirection(
                                    _isFrontCamera,
                                    _engine,
                                  );
                                },
                              ),
                            ),
                          CircleAvatar(
                            radius: 25,
                            backgroundColor:
                                _isSpeakerOn ? Colors.blue : Colors.grey,
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
            ),
            floatingActionButton:
                !_isJoined
                    ? FloatingActionButton(
                      onPressed: () => VidoCallHandler(_engine).joinChannel(),
                      child: const Icon(Icons.call),
                    )
                    : null,
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
}
