import 'dart:convert';
import 'dart:developer';

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
  final bool _isMicOn = true;
  final bool _isCameraOn = true;
  final bool _isSpeakerOn = true;
  final bool _isFrontCamera = true;
  bool _isHost = false;
  int? _hostUid;
  late RtcEngine _engine;
  late RtmClient _rtmClient;
  final bool _isRtmConnected = false;

  @override
  void initState() {
    //_isHost = widget.isHost;
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: AppConstant.appId));

    try {
      final (status, client) = await RTM(AppConstant.appId, widget.userId);
      if (status.error == true) {
        log(
          '${status.operation} failed due to ${status.reason}, error code: ${status.errorCode}',
        );
      } else {
        _rtmClient = client;
        log('Initialize success!');
      }
    } catch (e) {
      log('Initialize failed!:$e');
    }

    _rtmClient.addListener(
      message: (event) {
        log(
          'received a message from channel: ${event.channelName}, channel type : ${event.channelType}',
        );
        log(
          'message content: ${utf8.decode(event.message!)}, custome type: ${event.customType}',
        );
      },

      linkState: (event) {
        log(
          'link state changed from ${event.previousState} to ${event.currentState}',
        );
        log('reason: ${event.reason}, due to operation ${event.operation}');
      },
    );

    try {
      // Login to Signaling
      var (status, response) = await _rtmClient.login(AppConstant.token);
      if (status.error == true) {
        log(
          '${status.operation} failed due to ${status.reason}, error code: ${status.errorCode}',
        );
      } else {
        log('login RTM success!');
      }
    } catch (e) {
      log('Failed to login: $e');
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
    await _engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 640, height: 480),
        frameRate: 30,
        bitrate: 0,
      ),
    );
    await _engine.startPreview();
  }

  void _joinRtmChannel() async {
    for (var i = 0; i < 100; i++) {
      try {
        var (status, response) = await _rtmClient.publish(
          AppConstant.channelName,
          'message number : $i',
          channelType: RtmChannelType.message,
          customType: 'PlainText',
        );
        if (status.error == true) {
          log(
            '${status.operation} failed, errorCode: ${status.errorCode}, due to ${status.reason}',
          );
        } else {
          log('${status.operation} success! message number:$i');
        }
      } catch (e) {
        log('Failed to publish message: $e');
      }
      await Future.delayed(Duration(seconds: 1));
    }

    try {
      var (status, response) = await _rtmClient.subscribe(
        AppConstant.channelName,
      );
      if (status.error == true) {
        log(
          '${status.operation} failed due to ${status.reason}, error code: ${status.errorCode}',
        );
      } else {
        log('subscribe channel: ${AppConstant.channelName} success!');
      }
    } catch (e) {
      log('Failed to subscribe channel: $e');
    }
  }

  void _approveUser(int remoteUid) {
    log("Approving user $remoteUid");
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
    setState(() {
      _pendingUsers.remove(remoteUid);
    });
  }

  //! toggle mic

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
                      onPressed: () {
                        VidoCallHandler(_engine).joinChannel();
                      },
                      child: const Icon(Icons.call),
                    )
                    : null,
          );
        },
      ),
    );
  }

  @override
  void dispose() async {
    _engine.leaveChannel();
    _engine.release();
    try {
      var (status, response) = await _rtmClient.unsubscribe(
        AppConstant.channelName,
      );
      if (status.error == true) {
        log(
          '${status.operation} failed due to ${status.reason}, error code: ${status.errorCode}',
        );
      } else {
        log('unsubscribe success!');
      }
    } catch (e) {
      log('something went wrong with logout: $e');
    }

    try {
      var (status, response) = await _rtmClient.logout();
      if (status.error == true) {
        log(
          '${status.operation} failed due to ${status.reason}, error code: ${status.errorCode}',
        );
      } else {
        log('logout RTM success!');
      }
    } catch (e) {
      log('something went wrong with logout: $e');
    }
    super.dispose();
  }
}
