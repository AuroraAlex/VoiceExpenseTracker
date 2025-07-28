import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:archive/archive.dart';

/// 系统下载助手类，用于处理系统下载目录和应用内部目录之间的文件操作
class SystemDownloadHelper {
  /// 获取应用内部下载目录
  static Future<Directory> getAppDownloadDirectory() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory downloadDir = Directory('${appDir.path}/downloads');
    
    // 确保下载目录存在
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    
    return downloadDir;
  }
  
  /// 获取手动下载说明
  static Future<String> getManualDownloadInstructions() async {
    try {
      print('开始加载手动下载说明...');
      
      // 检查存储权限
      final storageStatus = await Permission.storage.status;
      final manageExternalStorageStatus = await Permission.manageExternalStorage.status;
      
      print('存储权限状态: $storageStatus');
      print('管理外部存储权限状态: $manageExternalStorageStatus');
      
      // 请求基本存储权限
      if (!storageStatus.isGranted) {
        print('请求基本存储权限...');
        final result = await Permission.storage.request();
        if (result.isGranted) {
          print('基本存储权限已授予');
        } else {
          print('基本存储权限被拒绝');
          return '无法访问存储，请在设置中授予应用存储权限。';
        }
      } else {
        print('基本存储权限已授予');
      }
      
      // 请求管理外部存储权限（Android 11+）
      print('请求管理外部存储权限...');
      final externalResult = await Permission.manageExternalStorage.request();
      if (!externalResult.isGranted) {
        print('管理外部存储权限被拒绝，使用基本权限');
      }
      
      // 获取应用下载目录
      final Directory appDownloadDir = await getAppDownloadDirectory();
      print('返回应用下载目录: ${appDownloadDir.path}');
      
      // 获取手动下载目录
      final String manualDownloadDir = appDownloadDir.path;
      print('获取到的手动下载目录: $manualDownloadDir');
      
      // 构建下载说明
      final String instructions = '''
# 手动下载语音识别模型说明

## 下载链接
请从以下链接下载语音识别模型文件：
https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-small-ctc-zh-2025-04-01.tar.bz2

## 下载后操作
1. 下载完成后，请将文件保存到应用内部下载目录：
   $manualDownloadDir
   
2. 如果您无法直接保存到上述目录，请先下载到您的设备下载目录，然后在应用中点击"检查模型文件"按钮，应用将自动将文件复制到正确位置。

3. 为了确保应用能够正常访问文件，请确保已授予应用存储权限。

## 注意事项
- 模型文件大小约为83MB，请确保有足够的存储空间。
- 下载过程可能需要几分钟，请耐心等待。
- 如果下载失败，请检查网络连接后重试。
- 如果您使用的是Android 11或更高版本，系统可能会限制应用访问外部存储，建议直接下载到应用内部目录。
''';

      print('手动下载说明加载完成');
      return instructions;
    } catch (e) {
      print('获取手动下载说明时出错: $e');
      return '获取下载说明失败: $e';
    }
  }
  
  /// 检查系统下载目录中的模型文件
  static Future<Map<String, dynamic>> checkSystemDownloadedModel(String modelName) async {
    try {
      // 检查存储权限
      final storageStatus = await Permission.storage.status;
      final manageExternalStorageStatus = await Permission.manageExternalStorage.status;
      
      print('存储权限状态: $storageStatus');
      print('管理外部存储权限状态: $manageExternalStorageStatus');
      
      // 请求基本存储权限
      if (!storageStatus.isGranted) {
        print('请求基本存储权限...');
        final result = await Permission.storage.request();
        if (!result.isGranted) {
          print('基本存储权限被拒绝');
          return {'exists': false, 'message': '无法访问存储，请在设置中授予应用存储权限。'};
        }
        print('基本存储权限已授予');
      } else {
        print('基本存储权限已授予');
      }
      
      // 请求管理外部存储权限（Android 11+）
      print('请求管理外部存储权限...');
      final externalResult = await Permission.manageExternalStorage.request();
      if (!externalResult.isGranted) {
        print('管理外部存储权限被拒绝，使用基本权限');
      }
      
      // 首先检查应用内部下载目录
      final Directory appDownloadDir = await getAppDownloadDirectory();
      final String appModelFilePath = join(appDownloadDir.path, '$modelName.tar.bz2');
      final File appModelFile = File(appModelFilePath);
      
      if (await appModelFile.exists()) {
        final fileSize = await appModelFile.length();
        final fileSizeMB = (fileSize / 1024 / 1024).toStringAsFixed(1);
        print('在应用下载目录找到模型文件: $appModelFilePath (${fileSizeMB}MB)');
        return {
          'exists': true, 
          'path': appModelFilePath, 
          'size': fileSizeMB,
          'inAppDir': true
        };
      }
      
      // 然后检查系统下载目录
      final String systemDownloadPath = '/storage/emulated/0/Download';
      final String systemModelFilePath = join(systemDownloadPath, '$modelName.tar.bz2');
      final File systemModelFile = File(systemModelFilePath);
      
      if (await systemModelFile.exists()) {
        final fileSize = await systemModelFile.length();
        final fileSizeMB = (fileSize / 1024 / 1024).toStringAsFixed(1);
        print('在系统下载目录找到模型文件: $systemModelFilePath (${fileSizeMB}MB)');
        return {
          'exists': true, 
          'path': systemModelFilePath, 
          'size': fileSizeMB,
          'inAppDir': false
        };
      }
      
      print('未找到模型文件');
      return {'exists': false, 'message': '未找到模型文件，请先下载。\n\n请将模型文件下载到应用内部下载目录: ${appDownloadDir.path}'};
    } catch (e) {
      print('检查模型文件时出错: $e');
      return {'exists': false, 'message': '检查模型文件时出错: $e'};
    }
  }
  
  /// 解压模型文件
  static Future<bool> unzipModelFile(BuildContext context, String modelName) async {
    try {
      // 获取应用内部下载目录
      final Directory appDownloadDir = await getAppDownloadDirectory();
      final String zipFilePath = join(appDownloadDir.path, '$modelName.tar.bz2');
      
      // 获取应用文档目录
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String modelPath = join(appDocDir.path, modelName);
      
      // 检查文件是否存在
      final File zipFile = File(zipFilePath);
      if (!await zipFile.exists()) {
        print('压缩文件不存在: $zipFilePath');
        return false;
      }
      
      // 显示解压进度对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: Text('解压模型'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在解压语音识别模型，请稍候...'),
                ],
              ),
            ),
          );
        },
      );
      
      // 创建模型目录
      final Directory modelDir = Directory(modelPath);
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }
      
      // 使用计算隔离区(Isolate)在后台线程执行解压操作
      bool success = false;
      try {
        // 读取压缩文件
        final bytes = await zipFile.readAsBytes();
        print('已读取压缩文件，大小: ${(bytes.length / 1024 / 1024).toStringAsFixed(1)}MB');
        
        // 在后台线程中执行解压操作
        final result = await compute(_unzipInBackground, {
          'bytes': bytes,
          'modelPath': modelPath,
        });
        
        success = result['success'] as bool;
        print('解压操作完成，结果: $success');
        
        // 关闭解压进度对话框
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        
        return success;
      } catch (e) {
        print('解压过程异常: $e');
        
        // 关闭解压对话框
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        
        // 显示错误对话框
        if (context.mounted) {
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
    } catch (e) {
      print('解压模型文件时出错: $e');
      return false;
    }
  }
  
  /// 在后台线程中执行解压操作
  static Future<Map<String, dynamic>> _unzipInBackground(Map<String, dynamic> params) async {
    try {
      final Uint8List bytes = params['bytes'] as Uint8List;
      final String modelPath = params['modelPath'] as String;
      
      // 首先解压bz2
      final bz2Decoder = BZip2Decoder();
      final tarBytes = bz2Decoder.decodeBytes(bytes);
      print('BZ2解压完成，解压后大小: ${(tarBytes.length / 1024 / 1024).toStringAsFixed(1)}MB');
      
      // 然后解压tar
      final tarDecoder = TarDecoder();
      final archiveFiles = tarDecoder.decodeBytes(tarBytes);
      print('TAR解压完成，文件数量: ${archiveFiles.length}');
      
      for (final file in archiveFiles) {
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
      
      return {'success': true};
    } catch (e) {
      print('后台解压过程异常: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// 处理系统下载目录中的模型文件
  static Future<bool> processSystemDownloadedModel(BuildContext context, String modelName, {Function? onModelProcessed}) async {
    try {
      // 检查模型文件
      final modelInfo = await checkSystemDownloadedModel(modelName);
      
      if (!modelInfo['exists']) {
        // 显示错误对话框
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('未找到模型文件'),
              content: Text(modelInfo['message']),
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
      
      // 如果文件在系统下载目录，复制到应用内部目录
      if (!modelInfo['inAppDir']) {
        // 显示复制进度对话框
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                title: Text('复制模型文件'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在将模型文件复制到应用内部目录，请稍候...'),
                  ],
                ),
              ),
            );
          },
        );
        
        try {
          // 在后台线程中执行文件复制操作
          final result = await compute(_copyFileInBackground, {
            'sourcePath': modelInfo['path'],
            'destPath': (await getAppDownloadDirectory()).path + '/$modelName.tar.bz2',
          });
          
          // 关闭复制对话框
          if (context.mounted) {
            Navigator.of(context).pop();
          }
          
          if (result['success']) {
            print('已将模型文件复制到应用内部目录: ${result['destPath']}');
            
            // 解压模型文件
            final unzipSuccess = await unzipModelFile(context, modelName);
            
            if (unzipSuccess) {
              // 显示成功对话框并关闭当前对话框
              if (context.mounted) {
                await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('处理成功'),
                      content: Text('模型文件已成功解压并准备就绪！现在您可以使用语音识别功能了。'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // 关闭成功对话框
                            Navigator.of(context).pop(true); // 关闭手动模型对话框
                          },
                          child: Text('确定'),
                        ),
                      ],
                    );
                  },
                );
                
                // 调用回调函数更新UI
                if (onModelProcessed != null) {
                  onModelProcessed();
                }
              }
            }
            
            return unzipSuccess;
          } else {
            // 显示错误对话框
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('复制失败'),
                    content: Text('复制模型文件失败: ${result['error']}\n\n请确保应用有足够的存储权限。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('确定'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          openAppSettings();
                        },
                        child: Text('打开设置'),
                      ),
                    ],
                  );
                },
              );
            }
            return false;
          }
        } catch (e) {
          // 关闭复制对话框
          if (context.mounted) {
            Navigator.of(context).pop();
          }
          
          // 显示错误对话框
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('复制失败'),
                  content: Text('复制模型文件失败: $e\n\n请确保应用有足够的存储权限。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('确定'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        openAppSettings();
                      },
                      child: Text('打开设置'),
                    ),
                  ],
                );
              },
            );
          }
          return false;
        }
      } else {
        // 文件已在应用内部目录，直接解压
        final unzipSuccess = await unzipModelFile(context, modelName);
        
        if (unzipSuccess) {
          // 显示成功对话框并关闭当前对话框
          if (context.mounted) {
            await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('处理成功'),
                  content: Text('模型文件已成功解压并准备就绪！现在您可以使用语音识别功能了。'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // 关闭成功对话框
                        Navigator.of(context).pop(true); // 关闭手动模型对话框
                      },
                      child: Text('确定'),
                    ),
                  ],
                );
              },
            );
            
            // 调用回调函数更新UI
            if (onModelProcessed != null) {
              onModelProcessed();
            }
          }
        }
        
        return unzipSuccess;
      }
    } catch (e) {
      print('处理模型文件时出错: $e');
      
      // 显示错误对话框
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('处理失败'),
              content: Text('处理模型文件时出错: $e'),
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
  
  /// 在后台线程中执行文件复制操作
  static Future<Map<String, dynamic>> _copyFileInBackground(Map<String, dynamic> params) async {
    try {
      final String sourcePath = params['sourcePath'] as String;
      final String destPath = params['destPath'] as String;
      
      // 读取源文件
      final File sourceFile = File(sourcePath);
      final bytes = await sourceFile.readAsBytes();
      print('已读取系统下载目录中的模型文件，大小: ${(bytes.length / 1024 / 1024).toStringAsFixed(1)}MB');
      
      // 写入目标文件
      final File destFile = File(destPath);
      await destFile.writeAsBytes(bytes);
      
      return {
        'success': true,
        'destPath': destPath,
      };
    } catch (e) {
      print('后台复制文件时出错: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}