import 'package:flutter/material.dart';
import 'screens/video_stream.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VisionMate Flutter',
      home: VideoStreamScreen(),
    );
  }
}
