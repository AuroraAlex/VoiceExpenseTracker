import 'dart:io';
import 'speech_recognition_service.dart';
import 'android_speech_recognition_service.dart';
import 'ios_speech_recognition_service.dart';
import 'sherpa_onnx_service.dart';

/// 语音识别服务工厂
/// 根据平台返回相应的语音识别服务实现
class SpeechRecognitionFactory {
  static SpeechRecognitionService? _instance;
  
  /// 获取平台对应的语音识别服务实例
  static SpeechRecognitionService getInstance() {
    if (_instance != null) {
      return _instance!;
    }
    
    if (Platform.isAndroid) {
      print('创建Android语音识别服务实例');
      _instance = AndroidSpeechRecognitionService();
    } else if (Platform.isIOS) {
      print('创建iOS语音识别服务实例');
      _instance = IOSSpeechRecognitionService();
    } else {
      // 其他平台使用默认的Sherpa-ONNX服务
      print('创建默认Sherpa-ONNX语音识别服务实例');
      _instance = SherpaOnnxService();
    }
    
    return _instance!;
  }
  
  /// 重置服务实例（用于测试或重新初始化）
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
  
  /// 获取当前平台名称
  static String getCurrentPlatform() {
    if (Platform.isAndroid) {
      return 'Android';
    } else if (Platform.isIOS) {
      return 'iOS';
    } else if (Platform.isWindows) {
      return 'Windows';
    } else if (Platform.isMacOS) {
      return 'macOS';
    } else if (Platform.isLinux) {
      return 'Linux';
    } else {
      return 'Unknown';
    }
  }
  
  /// 检查当前平台是否支持语音识别
  static bool isPlatformSupported() {
    return Platform.isAndroid || Platform.isIOS;
  }
}