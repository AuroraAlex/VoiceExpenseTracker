import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:archive/archive.dart';
import 'package:flutter_proxy_native/flutter_proxy_native.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/sherpa_utils.dart';
import 'system_download_helper.dart';

/// Sherpa-ONNX模型管理服务
class SherpaModelService extends ChangeNotifier {
  String _modelName = "sherpa-onnx-streaming-zipformer-small-ctc-zh-2025-04-01";
  double _progress = 0.0;
  double _unzipProgress = 0.0;
  bool _isDownloading = false;
  bool _isUnzipping = false;
  bool _isModelReady = false;
  bool _isInitializing = false;
  bool _isInitialized = false;
  String _errorMessage = '';

  /// 当前选择的模型名称
  String get modelName => _modelName;

  /// 下载进度，范围[0.0, 1.0]
  double get progress => _progress;

  /// 解压进度，范围[0.0, 1.0]
  double get unzipProgress => _unzipProgress;

  /// 是否正在下载
  bool get isDownloading => _isDownloading;

  /// 是否正在解压
  bool get isUnzipping => _isUnzipping;

  /// 模型是否已准备好
  bool get isModelReady => _isModelReady;

  /// 是否正在初始化
  bool get isInitializing => _isInitializing;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 错误信息
  String get errorMessage => _errorMessage;

  /// 设置模型名称
  void setModelName(String modelName) {
    _modelName = modelName;
    notifyListeners();
  }

  /// 设置下载进度
  void setProgress(double progress) {
    _progress = progress;
    notifyListeners();
  }

  /// 设置解压进度
  void setUnzipProgress(double progress) {
    _unzipProgress = progress;
    notifyListeners();
  }

  /// 重置进度
  void resetProgress() {
    _progress = 0.0;
    _unzipProgress = 0.0;
    notifyListeners();
  }

  /// 检查模型是否已准备好
  Future<bool> checkModelReady() async {
    try {
      _isModelReady = await isModelCopied(_modelName);
      notifyListeners();
      return _isModelReady;
    } catch (e) {
      _errorMessage = '检查模型状态失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 应用启动时自动初始化模型
  Future<void> autoInitializeModel() async {
    if (_isInitializing || _isInitialized) {
      print('模型已在初始化中或已初始化，跳过');
      return;
    }

    print('=== 开始应用启动时的模型自动初始化 ===');
    _isInitializing = true;
    notifyListeners();

    try {
      // 检查模型是否已存在
      final modelExists = await checkModelReady();
      
      if (modelExists) {
        print('发现已存在的模型，开始初始化Sherpa-ONNX引擎...');
        
        // 初始化Sherpa-ONNX引擎
        final success = await _initializeSherpaEngine();
        
        if (success) {
          print('Sherpa-ONNX引擎初始化成功');
          _isInitialized = true;
          _isModelReady = true;
        } else {
          print('Sherpa-ONNX引擎初始化失败');
          _isInitialized = false;
          _isModelReady = false;
          _errorMessage = 'Sherpa-ONNX引擎初始化失败';
        }
      } else {
        print('未发现模型文件，等待用户手动下载');
        _isInitialized = false;
        _isModelReady = false;
      }
    } catch (e) {
      print('模型自动初始化异常: $e');
      _isInitialized = false;
      _isModelReady = false;
      _errorMessage = '模型自动初始化失败: $e';
    } finally {
      _isInitializing = false;
      notifyListeners();
      print('=== 模型自动初始化完成 ===');
    }
  }

  /// 初始化Sherpa-ONNX引擎
  Future<bool> _initializeSherpaEngine() async {
    try {
      print('开始初始化Sherpa-ONNX引擎...');
      
      // 获取模型路径
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory(join(appDir.path, _modelName));
      
      if (!await modelDir.exists()) {
        print('模型目录不存在: ${modelDir.path}');
        return false;
      }
      
      // 检查关键文件
      final modelFile = File(join(modelDir.path, 'model.onnx'));
      final tokensFile = File(join(modelDir.path, 'tokens.txt'));
      
      if (!await modelFile.exists() || !await tokensFile.exists()) {
        print('关键模型文件缺失');
        return false;
      }
      
      print('模型文件验证通过，初始化引擎...');
      
      // 调用sherpa_utils中的初始化方法
      final success = await initializeSherpaOnnx(
        modelPath: modelFile.path,
        tokensPath: tokensFile.path,
      );
      
      if (success) {
        print('Sherpa-ONNX引擎初始化成功');
        return true;
      } else {
        print('Sherpa-ONNX引擎初始化失败');
        return false;
      }
    } catch (e) {
      print('初始化Sherpa-ONNX引擎异常: $e');
      return false;
    }
  }

  /// 销毁Sherpa-ONNX引擎
  Future<void> destroySherpaEngine() async {
    if (!_isInitialized) {
      print('引擎未初始化，无需销毁');
      return;
    }

    try {
      print('开始销毁Sherpa-ONNX引擎...');
      
      // 调用sherpa_utils中的销毁方法
      await destroySherpaOnnx();
      
      _isInitialized = false;
      notifyListeners();
      
      print('Sherpa-ONNX引擎销毁完成');
    } catch (e) {
      print('销毁Sherpa-ONNX引擎异常: $e');
    }
  }

  /// 检测VPN是否可用
  Future<String?> _detectVpnProxy() async {
    try {
      print('正在检测系统代理设置...');
      
      // 使用 flutter_proxy_native 获取系统代理设置
      final flutterProxyPlugin = FlutterProxyNative();
      final systemProxy = await flutterProxyPlugin.getSystemProxy();
      
      if (systemProxy != null && systemProxy.isNotEmpty && systemProxy != 'Unknown system proxy') {
        print('检测到系统代理设置: $systemProxy');
        
        // 解析代理地址
        String? proxyAddress = _parseProxyAddress(systemProxy);
        
        if (proxyAddress != null) {
          // 测试代理是否可用
          if (await _testProxyConnection(proxyAddress)) {
            print('系统代理可用: $proxyAddress');
            return proxyAddress;
          }
        }
      }
      
      print('系统代理不可用，尝试检测常见VPN端口...');
      
      // 如果系统代理不可用，尝试常见的VPN端口
      final commonVpnPorts = [
        '127.0.0.1:7890', // Clash Meta
        '127.0.0.1:1087', // Clash
        '127.0.0.1:8080', // HTTP代理
        '127.0.0.1:1080', // SOCKS5
      ];

      for (final proxyAddress in commonVpnPorts) {
        print('测试VPN代理连接: $proxyAddress');
        
        if (await _testProxyConnection(proxyAddress)) {
          print('VPN代理可用: $proxyAddress');
          return proxyAddress;
        }
      }
      
      print('未检测到可用的VPN代理');
      return null;
    } catch (e) {
      print('代理检测失败: $e');
      
      // 如果原生代理检测失败，回退到手动检测常见端口
      print('回退到手动检测VPN端口...');
      final commonVpnPorts = [
        '127.0.0.1:7890', // Clash Meta
        '127.0.0.1:1087', // Clash
        '127.0.0.1:8080', // HTTP代理
        '127.0.0.1:1080', // SOCKS5
      ];

      for (final proxyAddress in commonVpnPorts) {
        print('测试VPN代理连接: $proxyAddress');
        
        if (await _testProxyConnection(proxyAddress)) {
          print('VPN代理可用: $proxyAddress');
          return proxyAddress;
        }
      }
      
      return null;
    }
  }

  /// 解析代理地址
  String? _parseProxyAddress(String systemProxy) {
    try {
      // 系统代理可能的格式：
      // "PROXY 127.0.0.1:7890"
      // "127.0.0.1:7890"
      // "http://127.0.0.1:7890"
      
      if (systemProxy.contains('PROXY ')) {
        return systemProxy.replaceFirst('PROXY ', '');
      } else if (systemProxy.contains('://')) {
        final uri = Uri.parse(systemProxy);
        return '${uri.host}:${uri.port}';
      } else if (systemProxy.contains(':')) {
        return systemProxy;
      }
      
      return null;
    } catch (e) {
      print('解析代理地址失败: $e');
      return null;
    }
  }

  /// 测试代理连接是否可用
  Future<bool> _testProxyConnection(String proxyAddress) async {
    try {
      final testClient = HttpClient();
      
      // 完全禁用SSL验证，解决代理SSL握手问题
      testClient.badCertificateCallback = (cert, host, port) => true;
      
      // 设置较短的超时时间，快速测试
      testClient.connectionTimeout = Duration(seconds: 3);
      testClient.idleTimeout = Duration(seconds: 5);
      
      testClient.findProxy = (uri) => 'PROXY $proxyAddress';
      
      // 测试连接到一个简单的HTTP网站，避免HTTPS握手问题
      try {
        final request = await testClient.getUrl(Uri.parse('http://httpbin.org/ip'));
        final response = await request.close();
        testClient.close();
        return response.statusCode == 200;
      } catch (httpsError) {
        // 如果HTTP也失败，尝试HTTPS但忽略所有SSL错误
        try {
          final httpsRequest = await testClient.getUrl(Uri.parse('https://httpbin.org/ip'));
          final httpsResponse = await httpsRequest.close();
          testClient.close();
          return httpsResponse.statusCode == 200;
        } catch (e) {
          testClient.close();
          throw e;
        }
      }
    } catch (e) {
      print('代理测试失败 $proxyAddress: $e');
      return false;
    }
  }

  /// 请求存储权限
  Future<bool> _requestStoragePermission() async {
    try {
      // Android 13+ 需要请求不同的权限
      if (Platform.isAndroid) {
        // 检查Android版本，Android 13+需要特殊处理
        var storageStatus = await Permission.storage.status;
        var manageExternalStorageStatus = await Permission.manageExternalStorage.status;
        
        print('存储权限状态: $storageStatus');
        print('管理外部存储权限状态: $manageExternalStorageStatus');
        
        // 先尝试请求基本存储权限
        if (storageStatus.isDenied) {
          print('请求基本存储权限...');
          storageStatus = await Permission.storage.request();
        }
        
        // 如果基本权限被授予，检查是否需要管理外部存储权限
        if (storageStatus.isGranted) {
          print('基本存储权限已授予');
          
          // 尝试请求管理外部存储权限（Android 11+）
          if (manageExternalStorageStatus.isDenied) {
            print('请求管理外部存储权限...');
            manageExternalStorageStatus = await Permission.manageExternalStorage.request();
          }
          
          if (manageExternalStorageStatus.isGranted) {
            print('管理外部存储权限已授予');
            return true;
          } else if (manageExternalStorageStatus.isPermanentlyDenied) {
            print('管理外部存储权限被永久拒绝');
            // 即使管理外部存储权限被拒绝，也可以尝试使用基本权限
            return true;
          } else {
            print('管理外部存储权限被拒绝，使用基本权限');
            return true;
          }
        } else if (storageStatus.isPermanentlyDenied) {
          print('存储权限被永久拒绝，请在设置中手动开启');
          return false;
        } else {
          print('存储权限被拒绝');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      print('请求存储权限失败: $e');
      return false;
    }
  }

  /// 获取应用内部下载目录路径
  Future<String> getDownloadDirectory() async {
    try {
      // 使用应用内部下载目录
      final appDir = await getApplicationDocumentsDirectory();
      final appDownloadsDir = Directory(join(appDir.path, 'downloads'));
      
      if (!await appDownloadsDir.exists()) {
        await appDownloadsDir.create(recursive: true);
        print('创建应用内部下载目录: ${appDownloadsDir.path}');
      } else {
        print('使用已存在的应用内部下载目录: ${appDownloadsDir.path}');
      }
      
      return appDownloadsDir.path;
    } catch (e) {
      print('获取应用内部下载目录失败: $e');
      // 最后的回退方案
      final appDir = await getApplicationDocumentsDirectory();
      return appDir.path;
    }
  }

  /// 检查用户下载目录中是否有模型文件
  Future<bool> checkManualModelFile() async {
    try {
      final downloadDir = await getDownloadDirectory();
      final fileName = '$_modelName.tar.bz2';
      final manualFile = File(join(downloadDir, fileName));
      
      if (await manualFile.exists()) {
        final fileSize = await manualFile.length();
        print('发现用户下载的模型文件: ${manualFile.path}');
        print('文件大小: ${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB');
        return true;
      }
      
      return false;
    } catch (e) {
      print('检查下载目录模型文件失败: $e');
      return false;
    }
  }

  /// 处理手动模型文件
  Future<bool> useManualModelFile() async {
    print('=== 开始处理手动模型文件 ===');
    print('当前状态 - 下载中: $_isDownloading, 解压中: $_isUnzipping');
    
    // 防止与在线下载冲突
    if (_isDownloading || _isUnzipping) {
      print('模型正在处理中，请等待当前操作完成...');
      _errorMessage = '模型正在处理中，请等待当前操作完成';
      notifyListeners();
      return false;
    }
    
    try {
      // 设置处理状态
      _isUnzipping = true;
      _unzipProgress = 0.0;
      _errorMessage = '';
      notifyListeners();
      print('已设置处理状态，开始获取文件信息...');
      
      // 首先尝试从应用内部下载目录获取文件
      final appDownloadDir = await getDownloadDirectory();
      final fileName = '$_modelName.tar.bz2';
      final appModelFile = File(join(appDownloadDir, fileName));
      
      // 如果应用内部目录没有文件，尝试从系统下载目录复制
      if (!await appModelFile.exists()) {
        print('应用内部下载目录中没有找到模型文件，尝试从系统下载目录复制');
        
        // 尝试使用SystemDownloadHelper复制文件
        final result = await SystemDownloadHelper.checkSystemDownloadedModel(_modelName);
        
        if (result['exists'] == true && result['inAppDir'] == false) {
          print('在系统下载目录找到模型文件: ${result['path']}');
          
          // 复制文件到应用内部目录
          try {
            final sourceFile = File(result['path']);
            final bytes = await sourceFile.readAsBytes();
            await appModelFile.writeAsBytes(bytes);
            print('已将模型文件从系统下载目录复制到应用内部目录: ${appModelFile.path}');
          } catch (e) {
            print('复制模型文件失败: $e');
            _errorMessage = '复制模型文件失败: $e';
            _isUnzipping = false;
            notifyListeners();
            return false;
          }
        } else {
          print('未找到模型文件');
          _errorMessage = '未找到模型文件: $fileName\n请下载模型文件或将文件复制到应用内部目录';
          _isUnzipping = false;
          notifyListeners();
          return false;
        }
      }
      
      // 验证文件
      if (!await appModelFile.exists()) {
        print('应用内部下载目录中没有找到模型文件');
        _errorMessage = '应用内部下载目录中没有找到模型文件: $fileName';
        _isUnzipping = false;
        notifyListeners();
        return false;
      }
      
      final fileSize = await appModelFile.length();
      print('找到模型文件，大小: ${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB');
      
      // 验证文件大小是否合理（应该在40-100MB之间）
      if (fileSize < 40 * 1024 * 1024 || fileSize > 100 * 1024 * 1024) {
        print('警告: 文件大小异常，可能文件不完整');
        _errorMessage = '文件大小异常，可能下载不完整。预期40-100MB，实际${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB';
        _isUnzipping = false;
        notifyListeners();
        return false;
      }
      
      print('开始处理模型文件...');
      
      // 解压文件到应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      
      print('开始解压文件...');
      
      // 解压模型文件
      final success = await _extractTarBz2(appModelFile.path, appDir.path);
      
      if (success) {
        print('模型文件解压成功，正在验证...');
        final modelReady = await checkModelReady();
        if (modelReady) {
          print('模型文件验证成功，模型已准备就绪');
          _isModelReady = true;
          
          // 删除下载目录中的原文件
          if (await appModelFile.exists()) {
            await appModelFile.delete();
            print('已删除下载目录中的原文件');
          }
        } else {
          print('模型文件验证失败');
          _isModelReady = false;
          _errorMessage = '模型文件验证失败，可能解压不完整';
        }
      } else {
        print('模型文件解压失败');
        _isModelReady = false;
        _errorMessage = '模型文件解压失败，请检查文件是否完整';
      }
      
      _isUnzipping = false;
      notifyListeners();
      
      print('=== 手动模型文件处理完成，结果: ${_isModelReady ? '成功' : '失败'} ===');
      return _isModelReady;
      
    } catch (e) {
      print('处理模型文件异常: $e');
      print('异常堆栈: ${StackTrace.current}');
      _isUnzipping = false;
      _errorMessage = '处理模型文件失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 准备模型（只检查状态，不自动下载）
  Future<bool> prepareModel() async {
    // 如果正在下载或解压，直接返回
    if (_isDownloading || _isUnzipping) {
      print('模型正在准备中，请稍候...');
      return false;
    }
    
    // 首先检查模型是否已经存在
    if (await checkModelReady()) {
      print('模型已存在，无需重复下载');
      return true;
    }
    
    // 检查用户是否手动放置了模型文件，但不自动处理
    print('检查用户是否手动放置了模型文件...');
    if (await checkManualModelFile()) {
      print('发现用户手动放置的模型文件，等待用户手动触发处理');
      // 不自动处理，让用户手动选择
    }
    
    // 模型不存在，返回false让UI显示选择界面
    print('模型不存在，等待用户选择下载方式...');
    _isModelReady = false;
    notifyListeners();
    return false;
  }

  /// 开始在线下载（由用户主动触发）
  Future<bool> startOnlineDownload() async {
    print('用户选择在线下载，开始下载流程...');
    
    // 先检测VPN状态
    print('正在检测VPN状态...');
    final vpnProxy = await _detectVpnProxy();
    
    if (vpnProxy != null) {
      print('检测到可用VPN，将使用VPN下载: $vpnProxy');
    } else {
      print('未检测到VPN，将尝试直连下载');
    }
    
    // 执行完整的下载和准备流程
    final success = await downloadAndPrepareModel(vpnProxy: vpnProxy);
    
    if (success) {
      print('模型准备完成，可以开始使用语音识别功能');
      _isModelReady = true;
      notifyListeners();
    } else {
      print('模型准备失败，请检查网络连接或重试');
      _isModelReady = false;
      notifyListeners();
    }
    
    return success;
  }

  /// 获取手动模型文件目录路径（显示用户友好的应用目录）
  Future<String> getManualModelDirectory() async {
    try {
      print('开始获取手动模型目录路径...');
      
      final downloadDir = await getDownloadDirectory();
      print('返回应用下载目录: $downloadDir');
      return downloadDir;
    } catch (e) {
      print('获取下载目录路径失败: $e');
      final appDir = await getApplicationDocumentsDirectory();
      return appDir.path;
    }
  }

  /// 获取手动下载模型文件的说明信息
  Future<String> getManualModelInstructions() async {
    final appDownloadDir = await getDownloadDirectory();
    final fileName = '$_modelName.tar.bz2';
    
    return '''
请按以下步骤手动下载模型文件：

1. 下载地址：
   https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$fileName

2. 下载完成后，应用将自动从系统下载目录复制文件到应用内部目录。
   如果自动复制失败，请点击"检查手动文件"按钮重试。

3. 确保文件名为：$fileName

4. 点击"检查手动文件"按钮，系统将自动解压并验证文件

注意事项：
• 文件必须是完整的 .tar.bz2 格式
• 文件大小约为 40-50MB
• 请确保文件下载完整，没有损坏
• 应用会自动处理文件复制和解压过程
''';
  }

  /// 在线下载并准备模型
  Future<bool> downloadAndPrepareModel({String? vpnProxy}) async {
    if (_isDownloading || _isUnzipping) {
      print('模型正在准备中，请等待当前操作完成...');
      return false;
    }
    if (await checkModelReady()) {
      print('模型已准备就绪');
      return true;
    }

    try {
      print('开始模型下载和准备流程...');
      _isDownloading = true;
      _progress = 0.0;
      _errorMessage = '';
      notifyListeners();

      // 下载模型文件
      final Directory directory = await getApplicationDocumentsDirectory();
      final fileName = '$_modelName.tar.bz2';
      final filePath = join(directory.path, fileName);

      // 只使用GitHub官方下载地址
      final modelUrl = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$fileName';
      
      print('从GitHub官方下载: $modelUrl');
      
      bool downloadSuccess = false;
      String lastError = '';
      
      // 使用GitHub官方地址下载
      print('开始从GitHub官方下载模型...');
        
      try {
        print('使用原生HttpClient下载，完全绕过Dio...');
        
        // 使用原生HttpClient，完全控制SSL和代理设置
        final httpClient = HttpClient();
        
        // 完全禁用SSL证书验证
        httpClient.badCertificateCallback = (cert, host, port) {
          print('忽略SSL证书验证: $host:$port');
          return true;
        };
        
        // 设置超时
        httpClient.connectionTimeout = Duration(seconds: 60);
        httpClient.idleTimeout = Duration(seconds: 120);
        
        // 配置代理
        if (vpnProxy != null) {
          print('使用VPN代理下载: $vpnProxy');
          httpClient.findProxy = (uri) => 'PROXY $vpnProxy';
        } else {
          print('使用直连下载');
          httpClient.findProxy = (uri) => 'DIRECT';
        }
        
        // 创建请求
        print('开始从GitHub官方下载: $modelUrl');
        final request = await httpClient.getUrl(Uri.parse(modelUrl));
        
        // 设置请求头
        request.headers.set('User-Agent', 'Mozilla/5.0 (Android; Mobile; rv:40.0) Gecko/40.0 Firefox/40.0');
        request.headers.set('Accept', '*/*');
        request.headers.set('Connection', 'keep-alive');
        
        // 发送请求
        final response = await request.close();
        
        if (response.statusCode == 200) {
          final contentLength = response.contentLength;
          var downloadedBytes = 0;
          
          final file = File(filePath);
          final sink = file.openWrite();
          
          print('开始接收数据，文件大小: ${contentLength > 0 ? contentLength : "未知"}');
          
          await response.listen(
            (chunk) {
              sink.add(chunk);
              downloadedBytes += chunk.length;
              if (contentLength > 0) {
                _progress = downloadedBytes / contentLength;
                notifyListeners();
                if (downloadedBytes % (1024 * 1024) == 0) { // 每MB打印一次进度
                  print('已下载: ${(downloadedBytes / 1024 / 1024).toStringAsFixed(1)}MB / ${(contentLength / 1024 / 1024).toStringAsFixed(1)}MB');
                }
              }
            },
            onDone: () async {
              await sink.close();
              httpClient.close();
              print('下载完成，总大小: ${(downloadedBytes / 1024 / 1024).toStringAsFixed(1)}MB');
            },
            onError: (error) {
              sink.close();
              httpClient.close();
              throw error;
            },
          ).asFuture();
          
          downloadSuccess = true;
          print('GitHub官方下载成功: $modelUrl');
          
        } else {
          httpClient.close();
          throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
        }
        
      } catch (e) {
        lastError = e.toString();
        print('GitHub官方下载失败: $e');
        
        // 提供更详细的错误信息
        if (e.toString().contains('HandshakeException')) {
          lastError = 'SSL握手失败，请检查网络连接或VPN设置';
        } else if (e.toString().contains('SocketException')) {
          lastError = '网络连接失败，请检查网络状态';
        } else if (e.toString().contains('TimeoutException')) {
          lastError = '下载超时，请稍后重试';
        } else {
          lastError = '下载失败: $e';
        }
      }
      
      if (!downloadSuccess) {
        throw Exception('GitHub官方下载失败。\n$lastError');
      }

      _isDownloading = false;
      _isUnzipping = true;
      _unzipProgress = 0.0;
      notifyListeners();

      print('下载完成，开始解压...');

      // 解压模型文件
      final success = await _extractTarBz2(filePath, directory.path);
      
      _isUnzipping = false;
      notifyListeners();

      if (success) {
        print('模型解压成功，正在验证模型文件...');
        
        // 验证模型文件是否正确解压
        final modelReady = await checkModelReady();
        if (modelReady) {
          print('模型文件验证成功，模型已准备就绪');
          _isModelReady = true;
        } else {
          print('模型文件验证失败，可能解压不完整');
          _isModelReady = false;
        }
      } else {
        print('模型解压失败');
        _isModelReady = false;
      }
      
      notifyListeners();

      // 删除下载的压缩文件
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('已删除临时下载文件');
      }

      return _isModelReady;
    } catch (e) {
      _isDownloading = false;
      _isUnzipping = false;
      _errorMessage = '在线下载模型失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 解压 tar.bz2 文件
  Future<bool> _extractTarBz2(String filePath, String extractPath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('解压失败: 源文件不存在 $filePath');
        return false;
      }
      
      final fileSize = await file.length();
      print('开始解压文件: $filePath (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB)');
      print('解压目标路径: $extractPath');
      
      final bytes = await file.readAsBytes();
      print('文件读取完成，开始BZ2解压...');
      
      // 解压 bz2
      final bz2Decoder = BZip2Decoder();
      List<int> tarBytes;
      
      try {
        tarBytes = bz2Decoder.decodeBytes(bytes);
        print('BZ2解压完成，TAR数据大小: ${(tarBytes.length / 1024 / 1024).toStringAsFixed(1)}MB');
      } catch (e) {
        print('BZ2解压失败: $e');
        return false;
      }
      
      // 解压 tar
      final tarDecoder = TarDecoder();
      Archive archive;
      
      try {
        archive = tarDecoder.decodeBytes(tarBytes);
        print('TAR解析完成');
      } catch (e) {
        print('TAR解析失败: $e');
        return false;
      }
      
      var processedFiles = 0;
      final totalFiles = archive.files.length;
      
      print('压缩包中包含 $totalFiles 个文件');
      
      // 创建模型目录
      final modelDir = Directory(join(extractPath, _modelName));
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
        print('创建模型目录: ${modelDir.path}');
      }
      
      for (final archiveFile in archive.files) {
        final filename = archiveFile.name;
        
        if (archiveFile.isFile) {
          final data = archiveFile.content as List<int>;
          
          // 提取文件名，去掉目录前缀
          final baseName = filename.split('/').last;
          final outputPath = join(modelDir.path, baseName);
          
          try {
            final outputFile = File(outputPath);
            await outputFile.create(recursive: true);
            await outputFile.writeAsBytes(data);
            
            print('解压文件: $baseName (${(data.length / 1024).toStringAsFixed(1)}KB)');
          } catch (e) {
            print('写入文件失败 $baseName: $e');
            return false;
          }
        } else if (archiveFile.isDirectory) {
          print('跳过目录: $filename');
        }
        
        processedFiles++;
        // 解压进度从30%开始到90%
        _unzipProgress = 0.3 + (processedFiles / totalFiles) * 0.6;
        notifyListeners();
      }
      
      print('解压完成，共处理 $processedFiles 个文件');
      
      // 验证关键文件是否存在
      final modelFile = File(join(modelDir.path, 'model.onnx'));
      final tokensFile = File(join(modelDir.path, 'tokens.txt'));
      
      final modelExists = await modelFile.exists();
      final tokensExists = await tokensFile.exists();
      
      print('验证解压结果:');
      print('- 模型目录: ${modelDir.path}');
      print('- model.onnx: ${modelExists ? '存在' : '不存在'}');
      print('- tokens.txt: ${tokensExists ? '存在' : '不存在'}');
      
      if (modelExists) {
        final modelSize = await modelFile.length();
        print('- model.onnx 大小: ${(modelSize / 1024 / 1024).toStringAsFixed(1)}MB');
      }
      
      if (tokensExists) {
        final tokensSize = await tokensFile.length();
        print('- tokens.txt 大小: ${(tokensSize / 1024).toStringAsFixed(1)}KB');
      }
      
      // 列出模型目录中的所有文件
      try {
        final dirContents = await modelDir.list().toList();
        print('模型目录内容:');
        for (final item in dirContents) {
          if (item is File) {
            final size = await item.length();
            print('  - ${item.path.split('/').last}: ${(size / 1024).toStringAsFixed(1)}KB');
          }
        }
      } catch (e) {
        print('列出目录内容失败: $e');
      }
      
      _unzipProgress = 1.0;
      notifyListeners();
      
      return modelExists && tokensExists;
    } catch (e) {
      print('解压过程异常: $e');
      print('异常堆栈: ${e.toString()}');
      return false;
    }
  }
}

/// 获取SherpaModelService实例
SherpaModelService getSherpaModelService(BuildContext context) {
  return Provider.of<SherpaModelService>(context, listen: false);
}
