import 'dart:io';
import 'package:flutter/material.dart';
import 'speech_recognition_factory.dart';
import 'speech_recognition_service.dart';

/// 应用生命周期管理服务
class AppLifecycleService extends WidgetsBindingObserver {
  static AppLifecycleService? _instance;
  late final SpeechRecognitionService speechRecognitionService;
  bool _isInitializing = false;
  
  AppLifecycleService._();
  
  static AppLifecycleService get instance {
    _instance ??= AppLifecycleService._();
    return _instance!;
  }
  
  /// 初始化生命周期监听
  void initialize(BuildContext context) {
    // 使用工厂获取平台对应的语音识别服务
    speechRecognitionService = SpeechRecognitionFactory.getInstance();
    
    WidgetsBinding.instance.addObserver(this);
    print('应用生命周期监听已初始化，当前平台: ${SpeechRecognitionFactory.getCurrentPlatform()}');

    // 立即开始初始化语音服务，但使用异步方式不阻塞UI
    _initializeSpeechService();
  }
  
  /// 初始化语音服务
  Future<void> _initializeSpeechService() async {
    if (_isInitializing || speechRecognitionService.isInitialized) return;

    _isInitializing = true;
    print('开始初始化语音服务...');

    try {
      final success = await speechRecognitionService.initialize();
      if (success) {
        print('语音服务初始化成功');
      } else {
        print('语音服务初始化失败');
      }
    } catch (e) {
      print('初始化语音服务时出错: $e');
    } finally {
      _isInitializing = false;
    }
  }
  
  /// 销毁生命周期监听
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    print('应用生命周期监听已销毁');
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        print('应用恢复到前台');
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        print('应用暂停到后台');
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        print('应用即将退出');
        _onAppDetached();
        break;
      case AppLifecycleState.inactive:
        print('应用处于非活跃状态');
        break;
      case AppLifecycleState.hidden:
        print('应用被隐藏');
        break;
    }
  }
  
  /// 应用恢复到前台时的处理
  void _onAppResumed() {
    print('应用恢复，检查语音服务状态...');
    
    // 如果语音服务未初始化，尝试初始化
    if (!speechRecognitionService.isInitialized && !_isInitializing) {
      _initializeSpeechService();
    }
  }
  
  /// 应用暂停到后台时的处理
  void _onAppPaused() {
    print('应用暂停，保持语音服务运行状态');
  }
  
  /// 应用即将退出时的处理
  void _onAppDetached() {
    print('应用即将退出，开始清理资源...');
    
    // 销毁语音服务
    speechRecognitionService.dispose().then((_) {
      print('语音服务已销毁');
    }).catchError((e) {
      print('销毁语音服务时出错: $e');
    });
  }
}