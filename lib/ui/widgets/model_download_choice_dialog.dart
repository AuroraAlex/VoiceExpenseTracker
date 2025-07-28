import 'package:flutter/material.dart';
import '../../services/sherpa_model_service.dart';
import '../../services/system_download_helper.dart';
import 'manual_model_dialog.dart';

/// 模型下载方式选择对话框
class ModelDownloadChoiceDialog extends StatelessWidget {
  final SherpaModelService modelService;

  const ModelDownloadChoiceDialog({
    Key? key,
    required this.modelService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.download, color: Colors.orange),
          SizedBox(width: 8),
          Text('选择下载方式'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '需要下载语音识别模型才能使用语音记账功能',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 16),
          
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '模型大小约40-50MB，请根据网络状况选择下载方式',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // 手动下载按钮
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            showDialog(
              context: context,
              builder: (context) => ManualModelDialog(
                modelName: modelService.modelName,
              ),
            );
          },
          icon: Icon(Icons.folder_open, color: Colors.orange),
          label: Text(
            '手动下载',
            style: TextStyle(color: Colors.orange),
          ),
        ),
        
        // 在线下载按钮
        ElevatedButton.icon(
          onPressed: () async {
            Navigator.of(context).pop();
            await modelService.startOnlineDownload();
          },
          icon: Icon(Icons.cloud_download),
          label: Text('在线下载'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  /// 静态方法：显示选择对话框
  static Future<void> showChoiceDialog(
    BuildContext context,
    SherpaModelService modelService,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // 不允许点击外部关闭
      builder: (BuildContext context) {
        return ModelDownloadChoiceDialog(
          modelService: modelService,
        );
      },
    );
  }
}