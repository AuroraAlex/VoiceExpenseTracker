abstract class SpeechRecognitionService {
  Future<bool> initialize();
  Future<bool> startRecognition();
  Future<String> stopRecognition();
  Stream<String>? get resultStream;
  bool get isInitialized;
  Future<void> dispose();
}
