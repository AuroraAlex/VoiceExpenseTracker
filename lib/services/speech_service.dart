import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // 检查麦克风权限
      final permission = await Permission.microphone.status;
      print('当前麦克风权限状态: $permission');
      
      if (!permission.isGranted) {
        print('请求麦克风权限...');
        final result = await Permission.microphone.request();
        print('权限请求结果: $result');
        
        if (!result.isGranted) {
          print('麦克风权限被拒绝');
          return false;
        }
      }

      // 检查语音识别是否可用
      final available = await _speech.hasPermission;
      print('语音识别权限检查: $available');
      
      if (!available) {
        print('设备不支持语音识别或权限不足');
        return false;
      }

      print('开始初始化语音识别...');
      _isInitialized = await _speech.initialize(
        onError: (error) {
          print('语音识别错误: ${error.errorMsg}');
        },
        onStatus: (status) {
          print('语音识别状态: $status');
          _isListening = status == 'listening';
        },
        debugLogging: true,
      );
      
      if (_isInitialized) {
        print('语音识别初始化成功');
        
        // 检查可用的语言
        final locales = await _speech.locales();
        print('可用语言: ${locales.map((l) => l.localeId).join(', ')}');
      } else {
        print('语音识别初始化失败');
      }
      
      return _isInitialized;
    } catch (e) {
      print('语音识别初始化异常: $e');
      return false;
    }
  }

  Future<void> startListening({
    required Function(String) onResult,
    Function(String)? onPartialResult,
  }) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) {
        throw Exception('语音识别初始化失败');
      }
    }

    if (_isListening) {
      await stopListening();
    }

    try {
      await _speech.listen(
        onResult: (result) {
          final recognizedText = result.recognizedWords;
          print('语音识别结果: $recognizedText, 是否最终结果: ${result.finalResult}');
          if (result.finalResult) {
            onResult(recognizedText);
          } else if (onPartialResult != null) {
            onPartialResult(recognizedText);
          }
        },
        listenFor: const Duration(seconds: 60), // 增加监听时间
        pauseFor: const Duration(seconds: 5), // 增加暂停时间
        partialResults: true,
        localeId: 'zh_CN', // 中文识别
        cancelOnError: false, // 不要在错误时取消
        listenMode: stt.ListenMode.dictation, // 改为听写模式
      );
    } catch (e) {
      print('开始语音识别失败: $e');
      throw Exception('开始语音识别失败: $e');
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  void dispose() {
    _speech.cancel();
    _isListening = false;
  }
}