import 'package:flutter/material.dart';

/// Sherpa-ONNX语音识别设置对话框
class SherpaSettingsDialog extends StatefulWidget {
  /// 当前设置
  final SherpaSettings settings;
  
  /// 设置变更回调
  final Function(SherpaSettings) onSettingsChanged;

  const SherpaSettingsDialog({
    Key? key,
    required this.settings,
    required this.onSettingsChanged,
  }) : super(key: key);

  @override
  State<SherpaSettingsDialog> createState() => _SherpaSettingsDialogState();
}

class _SherpaSettingsDialogState extends State<SherpaSettingsDialog> {
  late SherpaSettings _settings;

  @override
  void initState() {
    super.initState();
    // 复制设置，避免直接修改原始设置
    _settings = widget.settings.copy();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('语音识别设置'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 模型选择
            const Text('模型选择', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _settings.modelName,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'paraformer-zh-small', child: Text('Paraformer中文小模型')),
                DropdownMenuItem(value: 'paraformer-zh-large', child: Text('Paraformer中文大模型')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _settings.modelName = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            
            // 语言选择
            const Text('识别语言', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _settings.language,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'zh', child: Text('中文')),
                DropdownMenuItem(value: 'en', child: Text('英文')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _settings.language = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            
            // 灵敏度调节
            const Text('麦克风灵敏度', style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _settings.sensitivity,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              label: _settings.sensitivity.toStringAsFixed(1),
              onChanged: (value) {
                setState(() {
                  _settings.sensitivity = value;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // 自动停止
            SwitchListTile(
              title: const Text('自动停止识别', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('检测到语音结束后自动停止识别'),
              value: _settings.autoStop,
              onChanged: (value) {
                setState(() {
                  _settings.autoStop = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSettingsChanged(_settings);
            Navigator.of(context).pop();
          },
          child: const Text('应用'),
        ),
      ],
    );
  }
}

/// Sherpa-ONNX语音识别设置
class SherpaSettings {
  /// 模型名称
  String modelName;
  
  /// 识别语言
  String language;
  
  /// 麦克风灵敏度
  double sensitivity;
  
  /// 自动停止识别
  bool autoStop;

  SherpaSettings({
    this.modelName = 'paraformer-zh-small',
    this.language = 'zh',
    this.sensitivity = 0.5,
    this.autoStop = true,
  });

  /// 创建设置副本
  SherpaSettings copy() {
    return SherpaSettings(
      modelName: modelName,
      language: language,
      sensitivity: sensitivity,
      autoStop: autoStop,
    );
  }
}