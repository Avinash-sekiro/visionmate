import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class VideoStreamScreen extends StatefulWidget {
  @override
  _VideoStreamScreenState createState() => _VideoStreamScreenState();
}

class _VideoStreamScreenState extends State<VideoStreamScreen> {
  CameraController? _controller;
  bool _isStreaming = false;
  List<dynamic> _obstacles = [];
  WebSocketChannel? _channel;
  bool _isWebSocketConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _connectWebSocket();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print("No cameras found");
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(backCamera, ResolutionPreset.medium);
      await _controller!.initialize();

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      print("Error initializing camera: $e");
    }
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://192.168.1.8:8000/ws/video-stream/'),
      );

      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (data.containsKey('detected_objects')) {
            setState(() {
              _obstacles = data['detected_objects'];
            });

            if (_obstacles.isNotEmpty) {
              _showObstacleAlert();
            }
          }
        },
        onDone: () {
          print("WebSocket disconnected");
          _isWebSocketConnected = false;
        },
        onError: (error) {
          print("WebSocket error: $error");
          _isWebSocketConnected = false;
        },
      );

      _isWebSocketConnected = true;
    } catch (e) {
      print("Error connecting WebSocket: $e");
      _isWebSocketConnected = false;
    }
  }

  void _showObstacleAlert() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Obstacle Detected!"),
          content: Text("Watch out for objects in front."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _startStreaming() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      print("Camera not initialized");
      return;
    }
    if (!_isWebSocketConnected) {
      print("WebSocket not connected!");
      return;
    }

    setState(() => _isStreaming = true);

    while (_isStreaming) {
      try {
        final XFile? imageFile = await _captureFrame();
        if (imageFile != null) {
          final bytes = await imageFile.readAsBytes();
          final base64Image = base64Encode(bytes);

          _channel!.sink.add(jsonEncode({"frame": base64Image}));
        }
      } catch (e) {
        print("Error capturing frame: $e");
      }
      await Future.delayed(Duration(milliseconds: 200));
    }
  }

  Future<XFile?> _captureFrame() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      print("Camera not initialized");
      return null;
    }

    try {
      final XFile imageFile = await _controller!.takePicture();
      print("Captured frame: ${imageFile.path}");
      return imageFile;
    } catch (e) {
      print("Error taking picture: $e");
      return null;
    }
  }

  void _stopStreaming() {
    setState(() => _isStreaming = false);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _channel?.sink.close(status.goingAway);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Live Video Stream')),
      body: Column(
        children: [
          Expanded(
            child: _controller != null && _controller!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  )
                : Center(child: CircularProgressIndicator()),
          ),

          SizedBox(height: 20),

          ElevatedButton(
            onPressed: _isStreaming ? _stopStreaming : _startStreaming,
            child: Text(_isStreaming ? "Stop Streaming" : "Start Streaming"),
          ),

          SizedBox(height: 10),

          ElevatedButton(
            onPressed: () {
              if (_isWebSocketConnected) {
                _channel!.sink.add(jsonEncode({"enable_transformer": true}));
              } else {
                print("WebSocket is not connected!");
              }
            },
            child: Text("Enable Full Object Detection"),
          ),

          SizedBox(height: 20),

          Text("Obstacle Detection Active...", style: TextStyle(fontSize: 18)),

          _obstacles.isNotEmpty
              ? Text("Detected Objects: ${_obstacles.join(", ")}", style: TextStyle(color: Colors.red))
              : Text("No obstacles detected"),
        ],
      ),
    );
  }
}
