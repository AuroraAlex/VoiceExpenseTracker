import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../services/system_download_helper.dart';
import '../../services/sherpa_model_service.dart';
import '../../utils/sherpa_utils.dart';

/// 手动模型下载对话框
class ManualModelDialog extends StatefulWidget {
  final String modelName;
  
  const ManualModelDialog({
    Key? key,
    required this.modelName,
  }) : super(key: key);

  @override
  State<ManualModelDialog> createState() => _ManualModelDialogState();
}

class _ManualModelDialogState extends State<ManualModelDialog> {
  String _instructions = '加载中...';
  bool _isDownloading = false;
  bool _isExtracting = false;
  bool _isProcessing = false;
  String _modelFilePath = '';
  String _modelFileSize = '';
  bool _modelFileExists = false;
  
  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoad();
  }
  
  /// 检查权限并加载内容
  Future<void> _checkPermissionsAndLoad() async {
    // 检查存储权限
    final storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      // 请求存储权限
      final result = await Permission.storage.request();
      if (!result.isGranted) {
        // 如果权限被拒绝，显示提示
        if (mounted) {
          setState(() {
            _instructions = '无法访问存储，请在设置中授予应用存储权限。';
          });
          
          // 显示权限设置提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('需要存储权限才能访问模型文件'),
              action: SnackBarAction(
                label: '设置',
                onPressed: () {
                  openAppSettings();
                },
              ),
            ),
          );
        }
        return;
      }
    }
    
    // 加载说明和检查文件
    _loadInstructions();
    _checkModelFile();
  }
  
  /// 加载手动下载说明
  Future<void> _loadInstructions() async {
    final instructions = await SystemDownloadHelper.getManualDownloadInstructions();
    if (mounted) {
      setState(() {
        _instructions = instructions;
      });
    }
  }
  
  /// 检查模型文件是否存在
  Future<void> _checkModelFile() async {
    final modelInfo = await SystemDownloadHelper.checkSystemDownloadedModel(widget.modelName);
    
    if (mounted) {
      setState(() {
        _modelFileExists = modelInfo['exists'] ?? false;
        _modelFilePath = modelInfo['path'] ?? '';
        _modelFileSize = modelInfo['size'] ?? '';
      });
    }
  }
  
  /// 处理模型文件
  Future<void> _processModelFile() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    final success = await SystemDownloadHelper.processSystemDownloadedModel(
      context, 
      widget.modelName,
      onModelProcessed: () async {
        // 更新UI，通知主界面模型已准备就绪
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _modelFileExists = false; // 重置状态，因为文件已被处理
          });
          
          // 初始化Sherpa-ONNX引擎
          try {
            // 获取SherpaModelService实例
            final modelService = Provider.of<SherpaModelService>(context, listen: false);
            
            // 检查模型是否已准备好
            final modelReady = await modelService.checkModelReady();
            
            if (modelReady) {
              // 初始化Sherpa-ONNX引擎
              await modelService.autoInitializeModel();
              
              // 更新状态
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('语音识别模型已成功初始化，可以开始使用语音识别功能了'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          } catch (e) {
            print('初始化Sherpa-ONNX引擎失败: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('初始化语音识别引擎失败: $e'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        }
      }
    );
    
    if (mounted && !success) {
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('手动下载模型'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Markdown(
                data: _instructions,
                shrinkWrap: true,
              ),
            ),
            const SizedBox(height: 16),
            if (_modelFileExists) ...[
              const Text('已找到模型文件:'),
              Text(_modelFilePath, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('文件大小: $_modelFileSize MB'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isProcessing ? null : _processModelFile,
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('处理模型文件'),
              ),
            ] else ...[
              const Text('未找到模型文件，请先下载或检查文件位置'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _checkModelFile,
                    child: const Text('检查模型文件'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      await openAppSettings();
                    },
                    child: const Text('打开设置'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
      ],
    );
  }
}