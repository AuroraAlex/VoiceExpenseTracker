import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sherpa_model_service.dart';
import 'sherpa_onnx_service.dart';

/// 应用生命周期管理服务
class AppLifecycleService extends WidgetsBindingObserver {
  static AppLifecycleService? _instance;
  SherpaModelService? _sherpaModelService;
  final SherpaOnnxService _sherpaOnnxService = SherpaOnnxService();
  bool _isInitializing = false;
  
  AppLifecycleService._();
  
  static AppLifecycleService get instance {
    _instance ??= AppLifecycleService._();
    return _instance!;
  }
  
  /// 初始化生命周期监听
  void initialize(BuildContext context) {
    _sherpaModelService = Provider.of<SherpaModelService>(context, listen: false);
    WidgetsBinding.instance.addObserver(this);
    print('应用生命周期监听已初始化');
    
    // 立即开始初始化Sherpa-ONNX服务，但使用异步方式不阻塞UI
    _initializeSherpaOnnxService();
  }
  
  /// 初始化Sherpa-ONNX服务
  Future<void> _initializeSherpaOnnxService() async {
    if (_isInitializing || _sherpaOnnxService.isInitialized) return;
    
    _isInitializing = true;
    print('开始初始化Sherpa-ONNX服务...');
    
    try {
      // 检查模型是否准备好
      if (_sherpaModelService != null && await _sherpaModelService!.checkModelReady()) {
        // 先预加载模型配置
        print('开始预加载Sherpa-ONNX模型配置...');
        final preloadSuccess = await _sherpaOnnxService.preloadModel();
        if (preloadSuccess) {
          print('Sherpa-ONNX模型配置预加载成功');
          
          // 然后初始化完整的Sherpa-ONNX服务
          print('开始初始化完整的Sherpa-ONNX服务...');
          final success = await _sherpaOnnxService.initialize();
          if (success) {
            print('Sherpa-ONNX服务初始化成功');
          } else {
            print('Sherpa-ONNX服务初始化失败');
          }
        } else {
          print('Sherpa-ONNX模型配置预加载失败');
        }
      } else {
        print('模型未准备好，无法初始化Sherpa-ONNX服务');
      }
    } catch (e) {
      print('初始化Sherpa-ONNX服务时出错: $e');
    } finally {
      _isInitializing = false;
    }
  }
  
  /// 获取Sherpa-ONNX服务实例
  SherpaOnnxService get sherpaOnnxService => _sherpaOnnxService;
  
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
    print('应用恢复，检查Sherpa引擎状态...');
    
    // 如果Sherpa-ONNX服务未初始化，尝试初始化
    if (!_sherpaOnnxService.isInitialized && !_isInitializing) {
      _initializeSherpaOnnxService();
    }
  }
  
  /// 应用暂停到后台时的处理
  void _onAppPaused() {
    // 应用暂停时可以释放一些资源，但保持Sherpa引擎运行
    print('应用暂停，保持Sherpa引擎运行状态');
  }
  
  /// 应用即将退出时的处理
  void _onAppDetached() {
    print('应用即将退出，开始清理资源...');
    
    // 销毁Sherpa引擎
    if (_sherpaModelService != null) {
      _sherpaModelService!.destroySherpaEngine().then((_) {
        print('Sherpa引擎已销毁');
      }).catchError((e) {
        print('销毁Sherpa引擎时出错: $e');
      });
    }
    
    // 销毁Sherpa-ONNX服务
    _sherpaOnnxService.dispose().then((_) {
      print('Sherpa-ONNX服务已销毁');
    }).catchError((e) {
      print('销毁Sherpa-ONNX服务时出错: $e');
    });
  }
}