import 'dart:typed_data';
import 'package:flutter/services.dart';

/// 离线语音识别服务，使用 Sherpa-ONNX 本地库进行流式识别
class OfflineSherpaService {
  static const MethodChannel _channel =
      MethodChannel('com.example.voice_expense_tracker/sherpa');

  /// 初始化 Sherpa-ONNX 识别器
  ///
  /// 必须在使用其他方法前调用
  Future<bool> initRecognizer() async {
    final bool? success = await _channel.invokeMethod('initRecognizer');
    return success ?? false;
  }

  /// 开始一个新的识别流
  Future<void> startStream() async {
    await _channel.invokeMethod('startStream');
  }

  /// 将音频数据块发送到原生层进行识别
  ///
  /// [audioChunk] 必须是 PCM 16-bit 的音频数据
  Future<void> feedAudio(Uint8List audioChunk) async {
    await _channel.invokeMethod('feedAudio', audioChunk);
  }

  /// 停止当前的识别流并获取最终结果
  Future<String> stopStream() async {
    final String? result = await _channel.invokeMethod('stopStream');
    return result ?? '';
  }

  /// 销毁识别器，释放原生资源
  Future<void> destroyRecognizer() async {
    await _channel.invokeMethod('destroyRecognizer');
  }
}