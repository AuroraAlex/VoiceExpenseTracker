import 'dart:async';
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
import 'ui/screens/splash_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/sherpa_test_screen.dart';
import 'ui/screens/text_input_test_screen.dart';
import 'ui/screens/vehicle_expense_detail_screen.dart';
import 'services/config_service.dart';
import 'services/speech_recognition_factory.dart';
import 'services/app_lifecycle_service.dart';

/// 在后台初始化语音识别服务
void _initSpeechRecognitionInBackground() async {
  try {
    print('开始后台初始化语音识别服务...');
    print('当前平台: ${SpeechRecognitionFactory.getCurrentPlatform()}');
    
    // 检查平台是否支持语音识别
    if (!SpeechRecognitionFactory.isPlatformSupported()) {
      print('当前平台不支持语音识别功能');
      return;
    }
    
    // 获取平台对应的语音识别服务
    final speechService = SpeechRecognitionFactory.getInstance();
    
    // 异步初始化语音识别服务
    final success = await speechService.initialize();
    
    if (success) {
      print('语音识别服务后台初始化成功，用户点击语音按钮时可立即使用');
    } else {
      print('语音识别服务后台初始化失败，用户首次使用时可能需要等待');
    }
  } catch (e) {
    print('后台初始化语音识别服务时发生错误: $e');
  }
}

/// 检查并请求必要的权限
Future<void> _checkAndRequestPermissions() async {
  try {
    print('检查应用所需权限...');
    
    // 检查麦克风权限（用于语音识别，Android和iOS都需要）
    final microphoneStatus = await Permission.microphone.status;
    print('麦克风权限状态: $microphoneStatus');
    
    // 如果没有麦克风权限，请求权限
    if (!microphoneStatus.isGranted) {
      print('请求麦克风权限...');
      final result = await Permission.microphone.request();
      print('麦克风权限请求结果: $result');
    }
    
    // Android平台特定权限处理
    if (Platform.isAndroid) {
      // 检查存储权限（Android端需要复制模型文件）
      final storageStatus = await Permission.storage.status;
      print('存储权限状态: $storageStatus');
      
      if (!storageStatus.isGranted) {
        print('请求存储权限...');
        final result = await Permission.storage.request();
        print('存储权限请求结果: $result');
      }
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
    
    // 创建必要的目录
    final directories = ['downloads', 'models', 'temp'];
    
    for (String dirName in directories) {
      final dir = Directory('${appDocDir.path}/$dirName');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        print('创建目录: ${dir.path}');
      } else {
        print('目录已存在: ${dir.path}');
      }
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
  
  runApp(const MyApp());
  
  // 在后台异步初始化语音识别服务，不阻塞应用启动
  // 延迟2秒启动，确保应用UI已经加载完成
  Future.delayed(const Duration(seconds: 2), () {
    _initSpeechRecognitionInBackground();
  });
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

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
    return GetMaterialApp(
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
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/home': (context) => const HomeScreen(),
        '/sherpa_test': (context) => const SherpaTestScreen(),
        '/text_input_test': (context) => const TextInputTestScreen(),
        '/vehicle_expense_detail': (context) => const VehicleExpenseDetailScreen(),
      },
    );
  }
}