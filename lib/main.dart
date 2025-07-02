import 'package:agora_test_app/video_call_sreen.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // void handleIncomingCall() {
  //   CallManager.showIncomingCall(
  //     context: context,
  //     callerId: 'caller_id',
  //     currentUserId: 'current_user_id',
  //     appId: 'your_app_id',
  //     token: 'your_token',
  //     channelName: 'channel_name_from_caller',
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          spacing: 16,
          children: [
            // To make a call
            // ElevatedButton(
            //   onPressed:
            //       () => CallManager.makeCall(
            //         context: context,
            //         targetUserId: 'target_user_id',
            //         currentUserId: 'current_user_id',
            //         appId: '6fc544c0c3384328895b4b95c2e48e74',
            //         token:
            //             '007eJxTYDDuO5yy/Xm9TfQGVqfl6t/L1rPMVv0bMqfyoQKvbt6nM3kKDGZpyaYmJskGycbGFibGRhYWlqZJJkmWpslGqSYWqeYmSxwTMxoCGRlcJqgxMjJAIIjPwlCSWlzCwAAAFj0eFQ==',
            //       ),
            //   child: const Text('Start Call'),
            // ),
            ElevatedButton(
              child: const Text('Video Call'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                        // RtmApiDemo(),
                        const VideoCallPage(isHost: true),
                  ),
                );
              },
            ),
            ElevatedButton(
              child: const Text('Video Call For Users '),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                        // RtmApiDemo(),
                        const VideoCallPage(isHost: false),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
