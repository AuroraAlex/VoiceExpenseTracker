import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/sherpa_test_screen.dart';
import 'services/config_service.dart';
import 'services/speech_service.dart';
import 'services/sherpa_model_service.dart';
import 'services/sherpa_onnx_service.dart';
import 'services/app_lifecycle_service.dart';

void _initSpeechServiceInBackground() async {
  try {
    final speechService = SpeechService();
    await speechService.initialize();
    print('后台语音服务初始化完成');
  } catch (e) {
    print('后台语音服务初始化失败: $e');
  }
}

/// 在后台自动初始化Sherpa-ONNX模型和引擎
void _autoInitializeSherpaInBackground(SherpaModelService modelService) async {
  try {
    print('开始后台自动初始化Sherpa-ONNX...');
    
    // 检查并请求必要的权限
    await _checkAndRequestPermissions();
    
    // 使用新的自动初始化方法
    await modelService.autoInitializeModel();
    
    if (modelService.isInitialized) {
      print('Sherpa-ONNX后台初始化成功，应用启动后即可使用语音识别');
      
      // 模型初始化成功后，预加载Sherpa-ONNX模型
      final sherpaOnnxService = SherpaOnnxService();
      print('开始预加载Sherpa-ONNX模型...');
      final preloadSuccess = await sherpaOnnxService.preloadModel();
      if (preloadSuccess) {
        print('Sherpa-ONNX模型预加载成功');
        
        // 预加载成功后，初始化完整的Sherpa-ONNX服务
        print('开始初始化Sherpa-ONNX服务...');
        final success = await sherpaOnnxService.initialize();
        if (success) {
          print('Sherpa-ONNX服务初始化成功，语音识别功能已准备就绪');
        } else {
          print('Sherpa-ONNX服务初始化失败');
        }
      } else {
        print('Sherpa-ONNX模型预加载失败');
      }
    } else {
      print('Sherpa-ONNX后台初始化未完成，可能需要用户手动下载模型');
    }
  } catch (e) {
    print('Sherpa-ONNX后台初始化时发生错误: $e');
  }
}

/// 检查并请求必要的权限
Future<void> _checkAndRequestPermissions() async {
  try {
    print('检查应用所需权限...');
    
    // 检查存储权限
    final storageStatus = await Permission.storage.status;
    print('存储权限状态: $storageStatus');
    
    // 如果没有存储权限，请求权限
    if (!storageStatus.isGranted) {
      print('请求存储权限...');
      final result = await Permission.storage.request();
      print('存储权限请求结果: $result');
    }
    
    // 检查管理外部存储权限（Android 11+）
    if (Platform.isAndroid) {
      final manageExternalStorageStatus = await Permission.manageExternalStorage.status;
      print('管理外部存储权限状态: $manageExternalStorageStatus');
      
      if (!manageExternalStorageStatus.isGranted) {
        print('请求管理外部存储权限...');
        final result = await Permission.manageExternalStorage.request();
        print('管理外部存储权限请求结果: $result');
      }
    }
    
    // 检查麦克风权限（用于语音识别）
    final microphoneStatus = await Permission.microphone.status;
    print('麦克风权限状态: $microphoneStatus');
    
    // 如果没有麦克风权限，请求权限
    if (!microphoneStatus.isGranted) {
      print('请求麦克风权限...');
      final result = await Permission.microphone.request();
      print('麦克风权限请求结果: $result');
    }
    
    print('权限检查完成');
  } catch (e) {
    print('检查权限时出错: $e');
  }
}

/// 初始化应用目录结构
Future<void> _initializeAppDirectories() async {
  try {
    print('开始初始化应用目录结构...');
    
    // 获取应用文档目录
    final appDocDir = await getApplicationDocumentsDirectory();
    print('应用文档目录: ${appDocDir.path}');
    
    // 创建下载目录
    final downloadDir = Directory('${appDocDir.path}/downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
      print('创建下载目录: ${downloadDir.path}');
    } else {
      print('下载目录已存在: ${downloadDir.path}');
    }
    
    // 创建模型目录
    final modelDir = Directory('${appDocDir.path}/models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
      print('创建模型目录: ${modelDir.path}');
    } else {
      print('模型目录已存在: ${modelDir.path}');
    }
    
    // 创建临时目录
    final tempDir = Directory('${appDocDir.path}/temp');
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
      print('创建临时目录: ${tempDir.path}');
    } else {
      print('临时目录已存在: ${tempDir.path}');
    }
    
    print('应用目录结构初始化完成');
  } catch (e) {
    print('初始化应用目录结构时出错: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 为Web平台设置数据库工厂
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  
  // 检查并请求必要的权限
  await _checkAndRequestPermissions();
  
  // 初始化应用目录结构
  await _initializeAppDirectories();
  
  // 加载环境变量
  await dotenv.load(fileName: '.env');
  
  // 初始化配置服务
  final configService = ConfigService();
  await configService.initialize();
  
  // 创建SherpaModelService实例
  final sherpaModelService = SherpaModelService();
  
  runApp(MyApp(sherpaModelService: sherpaModelService));
  
  // 在后台异步初始化语音识别服务，不阻塞应用启动
  _initSpeechServiceInBackground();
  
  // 在后台自动初始化Sherpa-ONNX模型和引擎
  _autoInitializeSherpaInBackground(sherpaModelService);
}

class MyApp extends StatefulWidget {
  final SherpaModelService sherpaModelService;
  
  const MyApp({Key? key, required this.sherpaModelService}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // 延迟初始化生命周期管理，确保Provider已经可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLifecycleService.instance.initialize(context);
    });
  }

  @override
  void dispose() {
    AppLifecycleService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.sherpaModelService),
      ],
      child: GetMaterialApp(
      title: '语音记账',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue,
          secondary: Colors.orangeAccent,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.blue,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue,
          secondary: Colors.orangeAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.blue,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/sherpa_test': (context) => const SherpaTestScreen(),
      },
      ),
    );
  }
}