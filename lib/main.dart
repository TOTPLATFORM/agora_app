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
      // RtmApiDemo(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  //  final bool _isHost = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Call App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text('Start Video Call'),
              onPressed: () {
                // showDialog(
                //   context: context,
                //   builder:
                //       (context) => AlertDialog(
                //         title: const Text('Select Role'),
                //         content: const Text(
                //           'Do you want to join as host or participant?',
                //         ),
                //         actions: [
                //           TextButton(
                //             onPressed: () {
                //               Navigator.pop(context);
                //               setState(() => _isHost = true);
                //               _navigateToCallScreen();
                //             },
                //             child: const Text('Host'),
                //           ),
                //           TextButton(
                //             onPressed: () {
                //               Navigator.pop(context);
                //               setState(() => _isHost = false);
                //               _navigateToCallScreen();
                //             },
                //             child: const Text('Participant'),
                //           ),
                //         ],
                //       ),
                // );
                _navigateToCallScreen();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCallScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
            //VideoCallTest(),
            VideoCallPage(
              //isHost: _isHost
              userId: "test_user_123",
            ),
      ),
    );
  }
}
