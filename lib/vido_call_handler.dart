import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import 'constant.dart';

class VidoCallHandler {
  final RtcEngine _engine;

  VidoCallHandler(this._engine);

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
}
