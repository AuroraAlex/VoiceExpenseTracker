import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'speech_recognition_service.dart';

/// iOS端语音识别服务
/// 使用系统原生SFSpeechRecognizer进行语音识别
class IOSSpeechRecognitionService implements SpeechRecognitionService {
  static final IOSSpeechRecognitionService _instance = IOSSpeechRecognitionService._internal();
  factory IOSSpeechRecognitionService() => _instance;
  IOSSpeechRecognitionService._internal();

  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isInitializing = false;
  StreamController<String>? _resultStreamController;
  
  late stt.SpeechToText _speechToText;
  String _lastRecognizedText = '';
  
  @override
  bool get isInitialized => _isInitialized;
  
  bool get isRecording => _isRecording;
  
  @override
  Stream<String>? get resultStream => _resultStreamController?.stream;

  /// 初始化iOS语音识别服务
  @override
  Future<bool> initialize() async {
    if (_isInitialized) {
      print('iOS语音识别服务已初始化');
      return true;
    }
    
    if (_isInitializing) {
      print('iOS语音识别服务正在初始化中...');
      return false;
    }
    
    _isInitializing = true;
    
    try {
      print('开始初始化iOS语音识别服务...');
      
      _speechToText = stt.SpeechToText();
      
      // 初始化语音识别
      bool available = await _speechToText.initialize(
        onError: (error) {
          print('iOS语音识别错误: ${error.errorMsg}');
        },
        onStatus: (status) {
          print('iOS语音识别状态: $status');
          if (status == 'done' || status == 'notListening') {
            _isRecording = false;
          }
        },
        debugLogging: kDebugMode,
      );
      
      if (!available) {
        print('iOS语音识别不可用');
        _isInitializing = false;
        return false;
      }
      
      // 检查权限
      bool hasPermission = await _speechToText.hasPermission;
      if (!hasPermission) {
        print('iOS语音识别权限未授予');
        _isInitializing = false;
        return false;
      }
      
      _isInitialized = true;
      _isInitializing = false;
      print('iOS语音识别服务初始化完成！');
      return true;
      
    } catch (e) {
      print('iOS语音识别服务初始化失败: $e');
      _isInitialized = false;
      _isInitializing = false;
      return false;
    }
  }

  /// 开始语音识别
  @override
  Future<bool> startRecognition() async {
    if (!_isInitialized) {
      print('iOS语音识别服务未初始化');
      return false;
    }

    if (_isRecording) {
      await stopRecognition();
    }

    try {
      print('开始iOS语音识别...');
      
      // 创建结果流控制器
      _resultStreamController = StreamController<String>.broadcast();
      
      // 重置识别状态
      _lastRecognizedText = '';
      
      // 获取可用的语言列表
      List<stt.LocaleName> locales = await _speechToText.locales();
      stt.LocaleName? chineseLocale;
      
      // 查找中文语言包
      for (var locale in locales) {
        if (locale.localeId.startsWith('zh')) {
          chineseLocale = locale;
          print('找到中文语言包: ${locale.localeId} - ${locale.name}');
          break;
        }
      }
      
      // 开始监听
      bool started = await _speechToText.listen(
        onResult: (result) {
          String recognizedText = result.recognizedWords;
          
          if (recognizedText.isNotEmpty && recognizedText != _lastRecognizedText) {
            _lastRecognizedText = recognizedText;
            print('iOS识别结果: $recognizedText (置信度: ${result.confidence})');
            _resultStreamController?.add(recognizedText);
          }
        },
        listenFor: const Duration(seconds: 30), // 最长监听30秒
        pauseFor: const Duration(seconds: 3),   // 3秒无声音后暂停
        partialResults: true,                   // 启用部分结果
        localeId: chineseLocale?.localeId ?? 'zh-CN', // 使用中文语言包
        onSoundLevelChange: (level) {
          // 可以在这里处理音量级别变化
          if (kDebugMode) {
            print('音量级别: $level');
          }
        },
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation, // 使用确认模式
      );
      
      if (!started) {
        print('iOS语音识别启动失败');
        await _resultStreamController?.close();
        _resultStreamController = null;
        return false;
      }
      
      _isRecording = true;
      print('iOS语音识别启动成功');
      return true;
      
    } catch (e) {
      print('开始iOS语音识别失败: $e');
      await _resultStreamController?.close();
      _resultStreamController = null;
      _isRecording = false;
      return false;
    }
  }

  /// 停止语音识别
  @override
  Future<String> stopRecognition() async {
    if (!_isRecording) return _lastRecognizedText;

    try {
      print('停止iOS语音识别...');
      
      // 停止监听
      await _speechToText.stop();
      
      // 等待一小段时间确保最后的结果被处理
      await Future.delayed(const Duration(milliseconds: 500));
      
      String finalResult = _lastRecognizedText;
      print('iOS语音识别最终结果: $finalResult');
      
      // 添加最终结果到流中
      if (finalResult.isNotEmpty) {
        _resultStreamController?.add(finalResult);
      }
      
      // 关闭流
      await _resultStreamController?.close();
      _resultStreamController = null;
      
      _isRecording = false;
      return finalResult;
      
    } catch (e) {
      print('停止iOS语音识别失败: $e');
      await _resultStreamController?.close();
      _resultStreamController = null;
      _isRecording = false;
      return _lastRecognizedText;
    }
  }

  /// 检查语音识别是否可用
  Future<bool> isAvailable() async {
    if (!_isInitialized) {
      return false;
    }
    
    try {
      return await _speechToText.hasPermission;
    } catch (e) {
      print('检查iOS语音识别可用性失败: $e');
      return false;
    }
  }

  /// 获取支持的语言列表
  Future<List<stt.LocaleName>> getSupportedLocales() async {
    if (!_isInitialized) {
      return [];
    }
    
    try {
      return await _speechToText.locales();
    } catch (e) {
      print('获取iOS支持的语言列表失败: $e');
      return [];
    }
  }

  /// 销毁识别器，释放资源
  @override
  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await stopRecognization();
      }
      
      await _resultStreamController?.close();
      _resultStreamController = null;
      
      _isInitialized = false;
      _isInitializing = false;
      _lastRecognizedText = '';
      
      print('iOS语音识别服务已销毁');
    } catch (e) {
      print('销毁iOS语音识别器失败: $e');
    }
  }

  /// 停止识别的别名方法（兼容性）
  Future<void> stopRecognization() async {
    await stopRecognition();
  }
}