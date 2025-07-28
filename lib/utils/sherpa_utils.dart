import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// 将字节数组转换为Float32List
Float32List convertBytesToFloat32(Uint8List bytes, [endian = Endian.little]) {
  final values = Float32List(bytes.length ~/ 2);
  final data = ByteData.view(bytes.buffer);

  for (var i = 0; i < bytes.length; i += 2) {
    if (i + 1 < bytes.length) {
      int short = data.getInt16(i, endian);
      values[i ~/ 2] = short / 32768.0;
    }
  }

  return values;
}

/// 检查模型是否已经从assets复制到应用文档目录
Future<bool> isModelCopied(String modelName) async {
  final Directory directory = await getApplicationDocumentsDirectory();
  final modelPath = join(directory.path, modelName);
  final modelDir = Directory(modelPath);
  
  if (!await modelDir.exists()) {
    return false;
  }
  
  // 根据模型类型检查必要的模型文件是否存在
  switch (modelName) {
    case "sherpa-onnx-streaming-zipformer-small-ctc-zh-2025-04-01":
      final modelFile = File(join(modelPath, 'model.onnx'));
      final tokensFile = File(join(modelPath, 'tokens.txt'));
      
      print('检查模型文件:');
      print('- model.onnx: ${await modelFile.exists() ? '存在' : '不存在'}');
      print('- tokens.txt: ${await tokensFile.exists() ? '存在' : '不存在'}');
      
      // CTC模型只需要model.onnx和tokens.txt
      return await modelFile.exists() && await tokensFile.exists();
             
    default:
      print('不支持的模型名称: $modelName');
      return false;
  }
}

/// 从assets复制模型文件到应用文档目录（已废弃）
/// 现在模型文件不再打包进应用，用户需要在线下载
Future<bool> copyModelFromAssets(String modelName) async {
  print('模型文件不再从assets复制，请使用在线下载功能');
  return false;
}

/// 获取应用内部下载目录
Future<Directory> getAppDownloadDirectory() async {
  final Directory appDir = await getApplicationDocumentsDirectory();
  final Directory downloadDir = Directory('${appDir.path}/downloads');
  
  // 确保下载目录存在
  if (!await downloadDir.exists()) {
    await downloadDir.create(recursive: true);
  }
  
  return downloadDir;
}

/// 检查模型是否需要下载
Future<bool> needsDownload(String modelName) async {
  // 首先检查是否已经从assets复制了模型
  if (await isModelCopied(modelName)) {
    return false;
  }
  
  // 检查是否已经下载了压缩文件
  final Directory directory = await getAppDownloadDirectory();
  final zipFilePath = join(directory.path, '$modelName.tar.bz2');
  final zipFile = File(zipFilePath);
  
  return !await zipFile.exists();
}

/// 检查模型是否需要解压
Future<bool> needsUnZip(String modelName) async {
  // 如果模型已经复制完成，则不需要解压
  if (await isModelCopied(modelName)) {
    return false;
  }
  
  // 检查压缩文件是否存在
  final Directory directory = await getAppDownloadDirectory();
  final zipFilePath = join(directory.path, '$modelName.tar.bz2');
  final zipFile = File(zipFilePath);
  
  return await zipFile.exists();
}

/// 下载并解压模型文件
Future<void> downloadModelAndUnZip(BuildContext context, String modelName) async {
  final Directory directory = await getAppDownloadDirectory();
  final zipFilePath = join(directory.path, '$modelName.tar.bz2');
  final zipFile = File(zipFilePath);
  
  // 模型下载URL
  final modelUrl = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-small-ctc-zh-2025-04-01.tar.bz2';
  
  try {
    // 显示下载进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('下载模型'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在下载语音识别模型，请稍候...'),
            ],
          ),
        );
      },
    );
    
    // 下载模型文件
    final response = await http.get(Uri.parse(modelUrl));
    await zipFile.writeAsBytes(response.bodyBytes);
    
    // 关闭下载对话框
    Navigator.of(context).pop();
    
    // 解压模型文件
    await unzipModelFile(context, modelName);
  } catch (e) {
    // 关闭下载对话框
    Navigator.of(context).pop();
    
    // 显示错误对话框
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('下载失败'),
          content: Text('模型下载失败: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('确定'),
            ),
          ],
        );
      },
    );
  }
}

/// 解压模型文件
Future<bool> unzipModelFile(BuildContext context, String modelName) async {
  final Directory directory = await getAppDownloadDirectory();
  final zipFilePath = join(directory.path, '$modelName.tar.bz2');
  final modelPath = join(await getApplicationDocumentsDirectory().then((dir) => dir.path), modelName);
  final zipFile = File(zipFilePath);
  final modelDir = Directory(modelPath);
  
  try {
    print('开始解压文件: $zipFilePath');
    print('解压目标路径: $modelPath');
    
    // 显示解压进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('解压模型'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在解压语音识别模型，请稍候...'),
            ],
          ),
        );
      },
    );
    
    // 检查压缩文件是否存在
    if (!await zipFile.exists()) {
      print('压缩文件不存在: $zipFilePath');
      Navigator.of(context).pop(); // 关闭对话框
      
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('解压失败'),
            content: Text('模型文件不存在，请重新下载。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('确定'),
              ),
            ],
          );
        },
      );
      return false;
    }
    
    // 创建模型目录
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    
    // 读取压缩文件
    final bytes = await zipFile.readAsBytes();
    print('已读取压缩文件，大小: ${(bytes.length / 1024 / 1024).toStringAsFixed(1)}MB');
    
    // 首先解压bz2
    final bz2Decoder = BZip2Decoder();
    final tarBytes = bz2Decoder.decodeBytes(bytes);
    print('BZ2解压完成，解压后大小: ${(tarBytes.length / 1024 / 1024).toStringAsFixed(1)}MB');
    
    // 然后解压tar
    final tarDecoder = TarDecoder();
    final archive = tarDecoder.decodeBytes(tarBytes);
    print('TAR解压完成，文件数量: ${archive.length}');
    
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        // 提取文件名，去掉目录前缀
        final baseName = basename(filename);
        final filePath = join(modelPath, baseName);
        await File(filePath).create(recursive: true);
        await File(filePath).writeAsBytes(data);
        print('解压文件: $baseName (${(data.length / 1024).toStringAsFixed(1)}KB)');
      }
    }
    
    // 关闭解压对话框
    Navigator.of(context).pop();
    
    // 显示成功对话框
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('解压成功'),
          content: Text('模型文件解压完成！'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('确定'),
            ),
          ],
        );
      },
    );
    
    return true;
  } catch (e) {
    print('解压过程异常: $e');
    print('异常堆栈: $e');
    
    // 关闭解压对话框
    if (context.mounted) {
      Navigator.of(context).pop();
      
      // 显示错误对话框
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('解压失败'),
            content: Text('模型解压失败: $e\n\n请检查网络连接或重新下载模型。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('确定'),
              ),
            ],
          );
        },
      );
    }
    
    return false;
  }
}

/// 获取系统下载目录中的模型文件路径（用于处理用户手动下载的模型）
Future<String?> getSystemDownloadModelFilePath(String modelName) async {
  try {
    // 首先检查应用内部下载目录
    final Directory appDownloadDir = await getAppDownloadDirectory();
    final String appFilePath = join(appDownloadDir.path, '$modelName.tar.bz2');
    final File appFile = File(appFilePath);
    
    if (await appFile.exists()) {
      print('在应用下载目录找到模型文件: $appFilePath');
      return appFilePath;
    }
    
    print('在应用下载目录未找到模型文件，尝试从系统下载目录复制');
    
    // 直接请求存储权限（会弹出系统权限授权窗口）
    final storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      print('请求基本存储权限...');
      final result = await Permission.storage.request();
      if (!result.isGranted) {
        print('基本存储权限被拒绝');
        return null;
      }
      print('基本存储权限已授予');
    } else {
      print('基本存储权限已授予');
    }
    
    // 直接请求管理外部存储权限（Android 11+）
    print('请求管理外部存储权限...');
    final externalResult = await Permission.manageExternalStorage.request();
    if (!externalResult.isGranted) {
      print('管理外部存储权限被拒绝，使用基本权限');
    }
    
    // 尝试从系统下载目录获取文件
    final Directory? downloadDir = await getExternalStorageDirectory();
    if (downloadDir == null) {
      print('无法获取外部存储目录');
      return null;
    }
    
    // 构建系统下载目录路径
    // 通常外部存储目录是 /storage/emulated/0/Android/data/com.example.app/files
    // 我们需要获取到 /storage/emulated/0/Download
    final String systemDownloadPath = downloadDir.path.split('/Android')[0] + '/Download';
    final String systemFilePath = join(systemDownloadPath, '$modelName.tar.bz2');
    final File systemFile = File(systemFilePath);
    
    if (await systemFile.exists()) {
      print('在系统下载目录找到模型文件: $systemFilePath');
      
      // 复制到应用内部目录
      try {
        await systemFile.copy(appFilePath);
        print('已将模型文件从系统下载目录复制到应用内部目录');
        return appFilePath;
      } catch (e) {
        print('复制文件失败: $e');
        // 如果复制失败，仍然返回系统路径，让调用者决定如何处理
        return systemFilePath;
      }
    }
    
    print('在系统下载目录未找到模型文件');
    return null;
  } catch (e) {
    print('获取模型文件路径时出错: $e');
    return null;
  }
}

/// 将用户手动下载的模型文件复制到应用内部目录
Future<bool> copyModelFileToAppDirectory(String sourcePath, String modelName) async {
  try {
    final File sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      print('源文件不存在: $sourcePath');
      return false;
    }
    
    final Directory appDownloadDir = await getAppDownloadDirectory();
    final String destPath = join(appDownloadDir.path, '$modelName.tar.bz2');
    final File destFile = File(destPath);
    
    // 复制文件
    try {
      final bytes = await sourceFile.readAsBytes();
      await destFile.writeAsBytes(bytes);
      print('已将模型文件复制到应用目录: $destPath');
      return true;
    } catch (e) {
      print('复制文件时出错: $e');
      return false;
    }
  } catch (e) {
    print('复制模型文件时出错: $e');
    return false;
  }
}

/// 处理用户手动下载的模型文件
Future<bool> processManualDownloadedModel(BuildContext context, String modelName) async {
  try {
    print('开始处理手动下载的模型文件...');
    
    // 获取模型文件路径
    final String? filePath = await getSystemDownloadModelFilePath(modelName);
    if (filePath == null) {
      print('未找到手动下载的模型文件');
      return false;
    }
    
    print('找到模型文件: $filePath');
    
    // 检查文件是否在应用内部目录
    final Directory appDownloadDir = await getAppDownloadDirectory();
    final bool isInAppDir = filePath.startsWith(appDownloadDir.path);
    
    // 如果不在应用内部目录，尝试复制
    if (!isInAppDir) {
      print('模型文件不在应用内部目录，尝试复制...');
      final bool copied = await copyModelFileToAppDirectory(filePath, modelName);
      if (!copied) {
        print('复制模型文件失败');
        return false;
      }
    }
    
    // 解压模型文件
    await unzipModelFile(context, modelName);
    return true;
  } catch (e) {
    print('处理手动下载模型文件时出错: $e');
    return false;
  }
}

/// 根据模型名称获取模型配置
Future<sherpa_onnx.OnlineModelConfig> getModelConfigByModelName({required String modelName}) async {
  final Directory directory = await getApplicationDocumentsDirectory();
  final modelPath = join(directory.path, modelName);
  
  switch (modelName) {
    case "sherpa-onnx-streaming-zipformer-small-ctc-zh-2025-04-01":
      // 使用正确的CTC模型配置，参考示例程序
      final ctc = sherpa_onnx.OnlineZipformer2CtcModelConfig(
        model: '$modelPath/model.onnx',
      );
      return sherpa_onnx.OnlineModelConfig(
        zipformer2Ctc: ctc,
        tokens: '$modelPath/tokens.txt',
        debug: true,
        numThreads: 1,
      );
    default:
      throw ArgumentError('不支持的模型名称: $modelName');
  }
}

// 全局变量存储Sherpa-ONNX识别器实例
sherpa_onnx.OnlineRecognizer? _globalRecognizer;

/// 初始化Sherpa-ONNX引擎
Future<bool> initializeSherpaOnnx({
  required String modelPath,
  required String tokensPath,
}) async {
  try {
    print('开始初始化Sherpa-ONNX引擎...');
    print('模型路径: $modelPath');
    print('词汇表路径: $tokensPath');
    
    // 检查文件是否存在
    if (!await File(modelPath).exists()) {
      print('模型文件不存在: $modelPath');
      return false;
    }
    
    if (!await File(tokensPath).exists()) {
      print('词汇表文件不存在: $tokensPath');
      return false;
    }
    
    // 创建CTC模型配置
    final ctc = sherpa_onnx.OnlineZipformer2CtcModelConfig(
      model: modelPath,
    );
    
    final modelConfig = sherpa_onnx.OnlineModelConfig(
      zipformer2Ctc: ctc,
      tokens: tokensPath,
      debug: true,
      numThreads: 1,
    );
    
    // 创建特征配置
    final featConfig = sherpa_onnx.FeatureConfig(
      sampleRate: 16000,
      featureDim: 80,
    );
    
    // 创建识别器配置
    final config = sherpa_onnx.OnlineRecognizerConfig(
      feat: featConfig,
      model: modelConfig,
      decodingMethod: 'greedy_search',
      maxActivePaths: 4,
      enableEndpoint: true,
      rule1MinTrailingSilence: 2.4,
      rule2MinTrailingSilence: 1.2,
      rule3MinUtteranceLength: 20.0,
    );
    
    // 创建识别器实例
    _globalRecognizer = sherpa_onnx.OnlineRecognizer(config);
    
    print('Sherpa-ONNX引擎初始化成功');
    return true;
  } catch (e) {
    print('初始化Sherpa-ONNX引擎失败: $e');
    return false;
  }
}

/// 销毁Sherpa-ONNX引擎
Future<void> destroySherpaOnnx() async {
  try {
    if (_globalRecognizer != null) {
      print('开始销毁Sherpa-ONNX引擎...');
      
      // 释放识别器资源
      _globalRecognizer?.free();
      _globalRecognizer = null;
      
      print('Sherpa-ONNX引擎销毁完成');
    } else {
      print('Sherpa-ONNX引擎未初始化，无需销毁');
    }
  } catch (e) {
    print('销毁Sherpa-ONNX引擎时出错: $e');
  }
}

/// 获取全局识别器实例
sherpa_onnx.OnlineRecognizer? getSherpaRecognizer() {
  return _globalRecognizer;
}

/// 检查Sherpa-ONNX引擎是否已初始化
bool isSherpaInitialized() {
  return _globalRecognizer != null;
}

/// 从系统下载目录获取模型文件并处理
Future<bool> handleSystemDownloadedModel(BuildContext context, String modelName) async {
  try {
    print('=== 开始处理系统下载目录中的模型文件 ===');
    
    // 检查存储权限
    final storageStatus = await Permission.storage.status;
    final manageExternalStorageStatus = await Permission.manageExternalStorage.status;
    
    print('存储权限状态: $storageStatus');
    print('管理外部存储权限状态: $manageExternalStorageStatus');
    
    // 直接请求基本存储权限（会弹出系统权限授权窗口）
    if (!storageStatus.isGranted) {
      print('请求基本存储权限...');
      final result = await Permission.storage.request();
      if (!result.isGranted) {
        print('基本存储权限被拒绝');
        
        // 如果权限被拒绝，显示一个简单的提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('需要存储权限才能访问模型文件'),
            action: SnackBarAction(
              label: '去设置',
              onPressed: () => openAppSettings(),
            ),
            duration: Duration(seconds: 5),
          ),
        );
        
        return false;
      }
      print('基本存储权限已授予');
    } else {
      print('基本存储权限已授予');
    }
    
    // 直接请求管理外部存储权限（Android 11+）
    print('请求管理外部存储权限...');
    if (!manageExternalStorageStatus.isGranted) {
      final externalResult = await Permission.manageExternalStorage.request();
      if (!externalResult.isGranted) {
        print('管理外部存储权限被拒绝，使用基本权限');
      }
    }
    
    // 获取系统下载目录
    final downloadDir = Directory('/storage/emulated/0/Download');
    if (!await downloadDir.exists()) {
      print('系统下载目录不存在');
      
      // 显示错误对话框
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('目录不存在'),
            content: Text('系统下载目录不存在，请确保您的设备有正确的存储结构。'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('确定'),
              ),
            ],
          );
        },
      );
      
      return false;
    }
    
    // 查找模型文件
    final String modelFileName = '$modelName.tar.bz2';
    final String modelFilePath = join(downloadDir.path, modelFileName);
    final File modelFile = File(modelFilePath);
    
    if (!await modelFile.exists()) {
      print('在系统下载目录未找到模型文件: $modelFilePath');
      
      // 显示错误对话框
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('文件不存在'),
            content: Text('在系统下载目录未找到模型文件，请确保您已下载模型文件到正确位置。'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('确定'),
              ),
            ],
          );
        },
      );
      
      return false;
    }
    
    print('发现用户下载的模型文件: $modelFilePath');
    print('文件大小: ${(await modelFile.length() / 1024 / 1024).toStringAsFixed(1)}MB');
    
    // 复制到应用内部目录
    final Directory appDownloadDir = await getAppDownloadDirectory();
    final String appModelFilePath = join(appDownloadDir.path, modelFileName);
    final File appModelFile = File(appModelFilePath);
    
    try {
      // 显示复制进度对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('复制模型文件'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在将模型文件复制到应用内部目录，请稍候...'),
              ],
            ),
          );
        },
      );
      
      // 读取系统下载目录中的文件
      final bytes = await modelFile.readAsBytes();
      print('已读取系统下载目录中的模型文件，大小: ${(bytes.length / 1024 / 1024).toStringAsFixed(1)}MB');
      
      // 写入应用内部目录
      await appModelFile.writeAsBytes(bytes);
      print('已将模型文件复制到应用内部目录: $appModelFilePath');
      
      // 关闭复制对话框
      Navigator.of(context).pop();
      
      // 解压模型文件
      final bool unzipResult = await unzipModelFile(context, modelName);
      if (!unzipResult) {
        print('模型文件解压失败');
        return false;
      }
      
      print('=== 系统下载目录中的模型文件处理完成 ===');
      return true;
    } catch (e) {
      // 关闭复制对话框（如果存在）
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      print('复制或解压模型文件时出错: $e');
      
      // 显示错误对话框
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('处理失败'),
            content: Text('复制或解压模型文件时出错: $e'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('确定'),
              ),
            ],
          );
        },
      );
      
      return false;
    }
  } catch (e) {
    print('处理系统下载目录中的模型文件时出错: $e');
    
    // 显示错误对话框
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('处理失败'),
          content: Text('处理系统下载目录中的模型文件时出错: $e'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('确定'),
            ),
          ],
        );
      },
    );
    
    return false;
  }
}
