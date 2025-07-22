import 'dart:developer';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_rtm/agora_rtm.dart';
import 'package:permission_handler/permission_handler.dart';

import 'constant.dart';

class VidoCallHandler {
  final RtcEngine _engine;

  VidoCallHandler(this._engine);

  //! Join channel
  Future<void> joinChannel() async {
    await _engine.joinChannel(
      token: AppConstant.token,
      channelId: AppConstant.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: true,
      ),
    );
  }

  //! Calculate grid count
  int calculateGridCount(final List<int> remoteUids) {
    if (remoteUids.isEmpty) return 1;
    if (remoteUids.length == 1) return 1;
    if (remoteUids.length <= 4) return 2;
    return 3;
  }

  //! request permission
  Future<void> requestPermissions() async {
    await [
      Permission.microphone,
      Permission.camera,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.storage,
      Permission.notification,
    ].request();
  }

  //!  RTM Initialization
  Future<void> initRTM({required String userId, RtmClient? rtmClient}) async {
    try {
      final (status, client) = await RTM(
        AppConstant.appId,
        userId,
        config: RtmConfig(),
      );
      if (status.error) {
        log("RTM init failed: ${status.reason}");
      }
      rtmClient = client;
      final (loginStatus, _) = await rtmClient.login(AppConstant.token);
      if (loginStatus.error) {
        log('RTM login failed: ${loginStatus.reason}');
        return;
      }
      log('RTM login successful');
    } catch (e) {
      log("RTM Error: $e");
    }
  }

  //! Send RTM message

  Future<void> sendPeriodicMessages({required RtmClient rtmClient}) async {
    for (var i = 0; i < 5; i++) {
      try {
        final (status, _) = await rtmClient.publish(
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
}
