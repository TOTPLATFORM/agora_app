// import 'package:flutter/material.dart';
// import 'call_screen.dart';

// class CallManager {
//   static void makeCall({
//     required BuildContext context,
//     required String targetUserId,
//     required String currentUserId,
//     required String appId,
//     required String token,
//   }) {
//     // In a real app, you would send an invitation via RTM here
//     // For simplicity, we're just navigating to the call screen

//     final channelName =
//         'call_${currentUserId}_${targetUserId}_${DateTime.now().millisecondsSinceEpoch}';

//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder:
//             (context) => CallScreen(
//               channelName: channelName,
//               userId: currentUserId,
//               appId: appId,
//               token: token,
//               isCaller: true,
//             ),
//       ),
//     );
//   }

//   static void showIncomingCall({
//     required BuildContext context,
//     required String callerId,
//     required String currentUserId,
//     required String appId,
//     required String token,
//     required String channelName,
//   }) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder:
//             (context) => CallScreen(
//               channelName: channelName,
//               userId: currentUserId,
//               appId: appId,
//               token: token,
//               isCaller: false,
//             ),
//       ),
//     );
//   }
// }
