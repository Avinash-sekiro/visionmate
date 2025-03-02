import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  final WebSocketChannel _channel = WebSocketChannel.connect(
    Uri.parse('ws://192.168.1.8:8000/ws/video-stream/'),
  );

  void sendFrame(String base64Image) {
    _channel.sink.add(jsonEncode({"frame": base64Image}));
  }

  Stream get messages => _channel.stream;

  void close() {
    _channel.sink.close();
  }
}
