import 'dart:async';
import 'package:flutter/services.dart';
import 'speech_recognition_service.dart';

class IosSpeechRecognitionService implements SpeechRecognitionService {
  static const MethodChannel _channel = MethodChannel('com.example.voice_expense_tracker/speech');
  final StreamController<String> _resultStreamController = StreamController.broadcast();
  bool _isInitialized = false;

  @override
  Stream<String>? get resultStream => _resultStreamController.stream;

  @override
  bool get isInitialized => _isInitialized;

  IosSpeechRecognitionService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case "onRecognitionResult":
        final result = call.arguments as String;
        _resultStreamController.add(result);
        break;
      default:
        print('Unknown method ${call.method}');
    }
  }

  @override
  Future<bool> initialize() async {
    try {
      final bool? result = await _channel.invokeMethod('initialize');
      _isInitialized = result ?? false;
      return _isInitialized;
    } on PlatformException catch (e) {
      print("Failed to initialize speech recognition: '${e.message}'.");
      _isInitialized = false;
      return false;
    }
  }

  @override
  Future<bool> startRecognition() async {
    if (!_isInitialized) {
      print("Speech recognition not initialized.");
      return false;
    }
    try {
      final bool? result = await _channel.invokeMethod('startRecognition');
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to start recognition: '${e.message}'.");
      return false;
    }
  }

  @override
  Future<String> stopRecognition() async {
    if (!_isInitialized) {
      print("Speech recognition not initialized.");
      return "";
    }
    try {
      final String? result = await _channel.invokeMethod('stopRecognition');
      return result ?? "";
    } on PlatformException catch (e) {
      print("Failed to stop recognition: '${e.message}'.");
      return "";
    }
  }

  @override
  Future<void> dispose() async {
    await _resultStreamController.close();
  }
}
