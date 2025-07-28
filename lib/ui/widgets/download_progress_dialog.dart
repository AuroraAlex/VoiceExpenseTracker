import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:voice_expense_tracker/services/sherpa_model_service.dart';

/// 下载进度对话框
class DownloadProgressDialog extends StatelessWidget {
  const DownloadProgressDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SherpaModelService>(
      builder: (context, model, child) {
        final downloading = model.progress > 0 && model.progress < 1;
        final unzipping = model.unzipProgress > 0 && model.unzipProgress < 1;
        
        String title = '准备中';
        String message = '正在准备语音识别模型...';
        double progress = 0.0;
        
        if (downloading) {
          title = '下载模型';
          message = '正在下载语音识别模型 (${(model.progress * 100).toStringAsFixed(1)}%)';
          progress = model.progress;
        } else if (unzipping) {
          title = '解压模型';
          message = '正在解压语音识别模型 (${(model.unzipProgress * 100).toStringAsFixed(1)}%)';
          progress = model.unzipProgress;
        }
        
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        );
      },
    );
  }
}