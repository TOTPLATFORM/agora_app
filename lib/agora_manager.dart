// import 'dart:async';
// import 'dart:developer';
// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:agora_rtm/agora_rtm.dart';
// import 'package:permission_handler/permission_handler.dart';

// class AgoraManager {
//   final String appId;
//   final String userId;
//   final String token;
//   // final RTMChannel? _rtmChannel;
//   late RtcEngine rtcEngine;
//   late RtmClient rtmClient;
//   final RtmChannelType rtmChannelType = RtmChannelType.message;

//   final _remoteUids = <int>[];
//   final _messages = StreamController<String>.broadcast();
//   final _callState = StreamController<CallState>.broadcast();

//   AgoraManager({
//     required this.appId,
//     required this.userId,
//     required this.token,
//   });

//   Stream<String> get messages => _messages.stream;
//   Stream<CallState> get callState => _callState.stream;
//   List<int> get remoteUids => _remoteUids;

//   Future<void> initialize() async {
//     await _initRtm();
//     await _initRtc();
//   }

//   Future<void> _initRtm() async {
//     try {
//       // Create RTM client instance
//       final (status, client) = await RTM(appId, userId);
//       if (status.error) {
//         log(
//           '[error] errorCode: ${status.errorCode}, operation: ${status.operation}, reason: ${status.reason}',
//         );
//         return;
//       }
//       rtmClient = client;

//       // Login to RTM
//       await rtmClient.login(token);

//       rtmClient.addListener(
//         linkState: (event) {
//           log('[linkState] ${event.toJson()}');
//         },
//         message: (event) {
//           log('[message] event: ${event.toJson()}');
//         },
//         presence: (event) {
//           log('[presence] event: ${event.toJson()}');
//         },
//         topic: (event) {
//           log('[topic] event: ${event.toJson()}');
//         },
//         lock: (event) {
//           log('[lock] event: ${event.toJson()}');
//         },
//         storage: (event) {
//           log('[storage] event: ${event.toJson()}');
//         },
//         token: (channelName) {
//           log('[token] channelName: $channelName');
//         },
//       );
//       await rtmClient.setParameters('{"rtm.log_filter":2063}');
//     } catch (e) {
//       log('Error initializing RTM: $e');
//       rethrow;
//     }
//   }

//   Future<void> _initRtc() async {
//     await [Permission.microphone, Permission.camera].request();

//     rtcEngine = createAgoraRtcEngine();
//     await rtcEngine.initialize(RtcEngineContext(appId: appId));

//     rtcEngine.registerEventHandler(
//       RtcEngineEventHandler(
//         onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
//           _callState.add(CallState.connected);
//           log('Joined channel successfully');
//         },
//         onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
//           _remoteUids.add(remoteUid);
//           _callState.add(CallState.remoteUserJoined);
//         },
//         onUserOffline: (
//           RtcConnection connection,
//           int remoteUid,
//           UserOfflineReasonType reason,
//         ) {
//           _remoteUids.remove(remoteUid);
//           _callState.add(CallState.remoteUserLeft);
//         },
//         onLeaveChannel: (RtcConnection connection, RtcStats stats) {
//           _remoteUids.clear();
//           _callState.add(CallState.ended);
//         },
//       ),
//     );

//     await rtcEngine.enableVideo();
//     await rtcEngine.startPreview();
//     await rtcEngine.setChannelProfile(
//       ChannelProfileType.channelProfileLiveBroadcasting,
//     );
//   }

//   Future<void> joinChannel(String channelId, {bool isCaller = false}) async {
//     // await _rtmChannel?.leave();
//     // _rtmChannel = await rtmClient.createChannel(channelId);

//     // _rtmChannel.onMemberJoined = (String memberId) {
//     //   _messages.add('Member joined: $memberId');
//     //   if (!isCaller) {
//     //     _callState.add(CallState.remoteUserJoined);
//     //   }
//     // };

//     // _rtmChannel.onMemberLeft = (String memberId) {
//     //   _messages.add('Member left: $memberId');
//     //   _callState.add(CallState.remoteUserLeft);
//     // };

//     // await _rtmChannel.join();
//     await rtcEngine.joinChannel(
//       token: token,
//       channelId: channelId,
//       uid: 0,
//       options: ChannelMediaOptions(
//         channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
//         clientRoleType: ClientRoleType.clientRoleBroadcaster,
//       ),
//     );

//     _callState.add(isCaller ? CallState.calling : CallState.ringing);
//   }

//   Future<void> sendMessage(String message) async {
//     // await _rtmChannel.sendMessage(RtmMessage.fromText(message));
//   }

//   Future<void> sendPeerMessage(String peerId, String message) async {
//     // await rtmClient.sendMessageToPeer(peerId, RtmMessage.fromText(message));
//   }

//   Future<void> leaveChannel() async {
//     //  await _rtmChannel.leave();
//     await rtcEngine.leaveChannel();
//     _callState.add(CallState.ended);
//   }

//   Future<void> dispose() async {
//     await rtcEngine.release();
//     await rtmClient.logout();
//     await rtmClient.release();
//     await _messages.close();
//     await _callState.close();
//   }
// }

// enum CallState {
//   calling,
//   ringing,
//   connected,
//   remoteUserJoined,
//   remoteUserLeft,
//   ended,
//   rejected,
// }
