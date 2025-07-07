import 'package:agora_rtc_engine/agora_rtc_engine.dart';

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
}
