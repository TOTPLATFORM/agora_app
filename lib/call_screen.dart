// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:flutter/material.dart';
// import 'agora_manager.dart';

// class CallScreen extends StatefulWidget {
//   final String channelName;
//   final String userId;
//   final String appId;
//   final String token;
//   final bool isCaller;

//   const CallScreen({
//     super.key,
//     required this.channelName,
//     required this.userId,
//     required this.appId,
//     required this.token,
//     this.isCaller = false,
//   });

//   @override
//   _CallScreenState createState() => _CallScreenState();
// }

// class _CallScreenState extends State<CallScreen> {
//   late AgoraManager _agoraManager;
//   CallState _currentCallState = CallState.ringing;
//   bool _isMuted = false;
//   bool _isVideoDisabled = false;
//   bool _isFrontCamera = true;
//   final List<String> _messages = [];

//   @override
//   void initState() {
//     super.initState();
//     _initAgora();
//   }

//   Future<void> _initAgora() async {
//     _agoraManager = AgoraManager(
//       appId: widget.appId,
//       userId: widget.userId,
//       token: widget.token,
//     );

//     await _agoraManager.initialize();
//     await _agoraManager.joinChannel(
//       widget.channelName,
//       //  isCaller: widget.isCaller,
//     );

//     _agoraManager.callState.listen((state) {
//       setState(() {
//         _currentCallState = state;
//       });

//       if (state == CallState.ended || state == CallState.rejected) {
//         Navigator.pop(context);
//       }
//     });

//     _agoraManager.messages.listen((message) {
//       setState(() {
//         _messages.add(message);
//       });
//     });
//   }

//   void _toggleMute() {
//     setState(() {
//       _isMuted = !_isMuted;
//     });
//     _agoraManager.rtcEngine.muteLocalAudioStream(_isMuted);
//   }

//   void _toggleVideo() {
//     setState(() {
//       _isVideoDisabled = !_isVideoDisabled;
//     });
//     _agoraManager.rtcEngine.muteLocalVideoStream(_isVideoDisabled);
//   }

//   void _switchCamera() {
//     setState(() {
//       _isFrontCamera = !_isFrontCamera;
//     });
//     _agoraManager.rtcEngine.switchCamera();
//   }

//   void _endCall() {
//     _agoraManager.leaveChannel();
//     Navigator.pop(context);
//   }

//   void _rejectCall() {
//     if (!widget.isCaller) {
//       _agoraManager.sendPeerMessage(
//         widget.isCaller
//             ? widget.userId
//             : 'otherUserId', // You need to manage peer IDs
//         'call_rejected',
//       );
//     }
//     _agoraManager.leaveChannel();
//   }

//   void _acceptCall() {
//     _agoraManager.sendPeerMessage(
//       widget.isCaller ? widget.userId : 'otherUserId',
//       'call_accepted',
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           // Remote video
//           if (_agoraManager.remoteUids.isNotEmpty)
//             AgoraVideoView(
//               controller: VideoViewController.remote(
//                 rtcEngine: _agoraManager.rtcEngine,
//                 canvas: VideoCanvas(uid: _agoraManager.remoteUids.first),
//                 connection: RtcConnection(channelId: widget.channelName),
//               ),
//             ),

//           // Local preview
//           Positioned(
//             top: 20,
//             right: 20,
//             child: SizedBox(
//               width: 120,
//               height: 160,
//               child: AgoraVideoView(
//                 controller: VideoViewController(
//                   rtcEngine: _agoraManager.rtcEngine,
//                   canvas: const VideoCanvas(uid: 0),
//                 ),
//               ),
//             ),
//           ),

//           // Call status
//           if (_currentCallState == CallState.ringing ||
//               _currentCallState == CallState.calling)
//             Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Text(
//                     widget.isCaller ? 'Calling...' : 'Incoming Call',
//                     style: const TextStyle(color: Colors.white, fontSize: 24),
//                   ),
//                   const SizedBox(height: 20),
//                   if (!widget.isCaller)
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         IconButton(
//                           icon: const Icon(Icons.call_end, color: Colors.red),
//                           onPressed: _rejectCall,
//                         ),
//                         const SizedBox(width: 40),
//                         IconButton(
//                           icon: const Icon(Icons.call, color: Colors.green),
//                           onPressed: _acceptCall,
//                         ),
//                       ],
//                     ),
//                 ],
//               ),
//             ),

//           // Call controls
//           if (_currentCallState == CallState.connected)
//             Align(
//               alignment: Alignment.bottomCenter,
//               child: Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     IconButton(
//                       icon: Icon(
//                         _isMuted ? Icons.mic_off : Icons.mic,
//                         color: Colors.white,
//                       ),
//                       onPressed: _toggleMute,
//                     ),
//                     IconButton(
//                       icon: Icon(
//                         _isVideoDisabled ? Icons.videocam_off : Icons.videocam,
//                         color: Colors.white,
//                       ),
//                       onPressed: _toggleVideo,
//                     ),
//                     IconButton(
//                       icon: const Icon(
//                         Icons.switch_camera,
//                         color: Colors.white,
//                       ),
//                       onPressed: _switchCamera,
//                     ),
//                     IconButton(
//                       icon: const Icon(Icons.call_end, color: Colors.red),
//                       onPressed: _endCall,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _agoraManager.dispose();
//     super.dispose();
//   }
// }
