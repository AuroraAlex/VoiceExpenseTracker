import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:voice_expense_tracker/utils/sherpa_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Sherpa-ONNX语音识别服务
/// 
/// 提供基于Sherpa-ONNX的流式语音识别功能，仅支持安卓平台
class SherpaOnnxService {
  static final SherpaOnnxService _instance = SherpaOnnxService._internal();
  factory SherpaOnnxService() => _instance;
  SherpaOnnxService._internal();
  
  bool _isInitialized = false;
  bool _isRecording = false;
  StreamController<String>? _resultStreamController;
  
  sherpa_onnx.OnlineRecognizer? _recognizer;
  sherpa_onnx.OnlineStream? _stream;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  StreamSubscription? _recordingDataSubscription;
  StreamController<Uint8List>? _audioDataController;
  
  int _sampleRate = 16000;
  String _modelName = "sherpa-onnx-streaming-zipformer-small-ctc-zh-2025-04-01";
  String _last = '';
  int _index = 0;

  /// 当前识别器是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 当前是否正在录音识别
  bool get isRecording => _isRecording;
  
  /// 识别结果流，可以订阅此流来获取实时识别结果
  Stream<String>? get resultStream => _resultStreamController?.stream;

  // 模型配置预加载
  sherpa_onnx.OnlineModelConfig? _preloadedModelConfig;
  bool _isPreloading = false;
  Completer<bool>? _preloadCompleter;

  /// 预加载模型配置
  /// 
  /// 在应用启动时调用此方法，提前加载模型配置，减少用户等待时间
  Future<bool> preloadModel() async {
    if (_isInitialized || _isPreloading || _preloadedModelConfig != null) {
      print('模型已预加载或正在预加载中，跳过');
      return _preloadCompleter?.future ?? Future.value(true);
    }

    _isPreloading = true;
    _preloadCompleter = Completer<bool>();

    try {
      print('开始预加载Sherpa-ONNX模型配置');
      
      // 初始化Sherpa-ONNX
      sherpa_onnx.initBindings();
      
      // 检查模型是否需要下载
      final needsDownloadVal = await needsDownload(_modelName);
      final needsUnZipVal = await needsUnZip(_modelName);
      
      if (needsDownloadVal || needsUnZipVal) {
        print('模型文件不存在，需要先下载或解压模型');
        _isPreloading = false;
        _preloadCompleter?.complete(false);
        return false;
      }
      
      // 预加载模型配置
      print('正在预加载模型配置...');
      _preloadedModelConfig = await getModelConfigByModelName(modelName: _modelName);
      print('模型配置预加载成功');
      
      _isPreloading = false;
      _preloadCompleter?.complete(true);
      return true;
    } catch (e) {
      print('预加载模型配置异常: $e');
      _isPreloading = false;
      _preloadCompleter?.completeError(e);
      return false;
    }
  }

  /// 初始化Sherpa-ONNX识别器
  /// 
  /// 在使用其他功能前必须先调用此方法
  /// 返回初始化是否成功
  Future<bool> initialize() async {
    if (_isInitialized) {
      print('Sherpa-ONNX识别器已经初始化，跳过重复初始化');
      return true;
    }

    try {
      print('开始初始化Sherpa-ONNX识别器');
      
      // 检查麦克风权限
      final permission = await Permission.microphone.status;
      print('当前麦克风权限状态: $permission');
      
      if (!permission.isGranted) {
        print('请求麦克风权限...');
        final result = await Permission.microphone.request();
        print('权限请求结果: $result');
        
        if (!result.isGranted) {
          print('麦克风权限被拒绝');
          return false;
        }
      }

      // 如果模型配置未预加载，则等待预加载完成或直接加载
      if (_preloadedModelConfig == null && !_isPreloading) {
        print('模型配置未预加载，开始加载模型配置');
        await preloadModel();
      } else if (_isPreloading) {
        print('模型配置正在预加载中，等待完成...');
        await _preloadCompleter?.future;
      }
      
      // 如果预加载失败，再次检查模型是否存在
      if (_preloadedModelConfig == null) {
        print('模型配置预加载失败，重新检查模型文件');
        
        // 检查模型是否需要下载
        final needsDownloadVal = await needsDownload(_modelName);
        final needsUnZipVal = await needsUnZip(_modelName);
        
        if (needsDownloadVal || needsUnZipVal) {
          print('模型文件不存在，需要先下载或解压模型');
          return false;
        }
        
        // 加载模型配置
        _preloadedModelConfig = await getModelConfigByModelName(modelName: _modelName);
      }
      
      // 创建识别器
      print('正在创建语音识别器...');
      final config = sherpa_onnx.OnlineRecognizerConfig(
        model: _preloadedModelConfig!,
        ruleFsts: '',
      );
      
      _recognizer = sherpa_onnx.OnlineRecognizer(config);
      print('语音识别器创建成功');
      
      // 初始化录音器
      print('正在初始化录音器...');
      await _recorder.openRecorder();
      await _recorder.setSubscriptionDuration(const Duration(milliseconds: 200));
      print('录音器初始化成功');
      
      _isInitialized = true;
      print('Sherpa-ONNX识别器初始化完成！');
      return true;
    } catch (e) {
      print('Sherpa-ONNX识别器初始化异常: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// 开始语音识别
  /// 
  /// 开始录音并进行实时语音识别
  /// 识别结果会通过[resultStream]流返回
  Future<bool> startRecognition() async {
    if (!_isInitialized) {
      print('语音识别器未初始化，无法开始识别');
      throw Exception('Sherpa-ONNX识别器未初始化，请等待应用启动完成');
    }

    if (_isRecording) {
      await stopRecognition();
    }

    try {
      print('开始语音识别');
      print('应用设置: 模型=$_modelName, 语言=zh, 灵敏度=0.5, 自动停止=true');
      
      // 创建结果流控制器
      _resultStreamController = StreamController<String>.broadcast();
      
      // 重置识别状态
      _last = '';
      _stream = _recognizer?.createStream();
      
      // 检查录音器状态
      if (_recorder.isStopped) {
        _audioDataController = StreamController<Uint8List>();
        
        // 用于累积音频数据的缓冲区
        List<int> _audioBuffer = [];
        int _bufferSize = 3200; // 累积0.2秒的数据 (16000Hz * 0.2s * 2bytes)
        
        _recordingDataSubscription = _audioDataController!.stream.listen((audioData) {
          print('收到音频数据: ${audioData.length} 字节');
          
          // 将新数据添加到缓冲区
          _audioBuffer.addAll(audioData);
          
          // 当缓冲区达到一定大小时，处理数据
          if (_audioBuffer.length >= _bufferSize) {
            // 取出要处理的数据
            final dataToProcess = _audioBuffer.take(_bufferSize).toList();
            _audioBuffer = _audioBuffer.skip(_bufferSize).toList();
            
            print('处理音频数据: ${dataToProcess.length} 字节');
            
            final samplesFloat32 = convertBytesToFloat32(Uint8List.fromList(dataToProcess));
            print('转换后的Float32数据长度: ${samplesFloat32.length}');
            
            if (_stream != null && _recognizer != null) {
              _stream!.acceptWaveform(samples: samplesFloat32, sampleRate: _sampleRate);
              print('音频数据已传递给识别器');
              
              while (_recognizer!.isReady(_stream!)) {
                _recognizer!.decode(_stream!);
                print('正在解码...');
              }
              
              final text = _recognizer!.getResult(_stream!).text;
              print('当前识别结果: "$text"');
              
              if (text.isNotEmpty && text != _last) {
                _last = text;
                print('识别到新文本: $text');
                _resultStreamController?.add(text);
              }

              if (_recognizer!.isEndpoint(_stream!)) {
                print('检测到语音终点，重置识别器');
                _recognizer!.reset(_stream!);
                _last = '';
              }
            }
          }
        });

        await _recorder.startRecorder(
          toStream: _audioDataController!.sink,
          codec: Codec.pcm16,
          numChannels: 1,
          sampleRate: _sampleRate,
        );

        _isRecording = true;
        print('语音识别启动成功: ${_recorder.isRecording}');
      }
      
      return true;
    } catch (e) {
      print('开始语音识别失败: $e');
      await _resultStreamController?.close();
      _resultStreamController = null;
      _isRecording = false;
      return false;
    }
  }

  /// 停止语音识别
  /// 
  /// 停止录音并获取最终识别结果
  /// 返回最终识别结果文本
  Future<String> stopRecognition() async {
    if (!_isRecording) return '';

    try {
      print('停止语音识别');
      
      // 取消处理定时器
      // 停止录音
      await _recorder.stopRecorder();
      print('录音已停止');

      // 停止录音
      await _recorder.stopRecorder();
      print('录音已停止');

      // 取消音频流订阅
      await _recordingDataSubscription?.cancel();
      _recordingDataSubscription = null;
      await _audioDataController?.close();
      _audioDataController = null;
      
      // 获取最终识别结果
      String finalResult = '';
      if (_stream != null && _recognizer != null) {
        // 确保所有数据都被处理
        while (_recognizer!.isReady(_stream!)) {
          _recognizer!.decode(_stream!);
        }
        
        finalResult = _recognizer!.getResult(_stream!).text;
        print('识别结果流结束');
        print('语音识别最终结果: $finalResult');
        
        // 释放流
        _stream!.free();
        _stream = null;
      }
      
      // 添加最终结果到流中
      if (finalResult.isNotEmpty) {
        _resultStreamController?.add(finalResult);
      }
      
      // 关闭流
      await _resultStreamController?.close();
      _resultStreamController = null;
      
      _isRecording = false;
      return finalResult;
    } catch (e) {
      print('停止语音识别失败: $e');
      await _recordingDataSubscription?.cancel();
      _recordingDataSubscription = null;
      await _audioDataController?.close();
      _audioDataController = null;
      await _resultStreamController?.close();
      _resultStreamController = null;
      _isRecording = false;
      return '';
    }
  }

  /// 测试音频文件识别
  /// 
  /// 使用指定的音频文件测试语音识别功能
  /// 返回识别结果文本
  Future<String> testAudioFileRecognition(String audioFileName) async {
    if (!_isInitialized) {
      print('语音识别器未初始化，无法进行音频文件测试');
      throw Exception('Sherpa-ONNX识别器未初始化，请等待应用启动完成');
    }

    try {
      print('开始测试音频文件识别: $audioFileName');
      
      // 从assets复制音频文件到临时目录
      final tempDir = await getTemporaryDirectory();
      final tempAudioPath = path.join(tempDir.path, audioFileName);
      final tempAudioFile = File(tempAudioPath);
      
      // 从assets读取音频文件
      final assetPath = 'assets/models/$_modelName/test_wavs/$audioFileName';
      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      
      // 写入到临时文件
      await tempAudioFile.writeAsBytes(bytes);
      print('音频文件已复制到: $tempAudioPath');
      print('音频文件大小: ${bytes.length} 字节');
      
      // 创建新的识别流
      _stream = _recognizer?.createStream();
      
      if (_stream == null || _recognizer == null) {
        throw Exception('识别器未正确初始化');
      }
      
      // 读取音频文件并转换为Float32List
      // 注意：这里假设是16位PCM格式，采样率16000Hz
      // 对于WAV文件，需要跳过文件头（通常是44字节）
      final audioBytes = await tempAudioFile.readAsBytes();
      print('读取音频文件，总大小: ${audioBytes.length} 字节');
      
      // 跳过WAV文件头（44字节）
      final audioData = audioBytes.sublist(44);
      print('跳过WAV文件头后，音频数据大小: ${audioData.length} 字节');
      
      // 转换为Float32List
      final samplesFloat32 = convertBytesToFloat32(Uint8List.fromList(audioData));
      print('转换后的Float32数据长度: ${samplesFloat32.length}');
      
      // 将音频数据分块传递给识别器
      const chunkSize = 1600; // 每次处理0.1秒的数据（16000Hz * 0.1s）
      for (int i = 0; i < samplesFloat32.length; i += chunkSize) {
        final end = (i + chunkSize < samplesFloat32.length) ? i + chunkSize : samplesFloat32.length;
        final chunk = samplesFloat32.sublist(i, end);
        
        _stream!.acceptWaveform(samples: chunk, sampleRate: _sampleRate);
        
        while (_recognizer!.isReady(_stream!)) {
          _recognizer!.decode(_stream!);
        }
        
        final partialResult = _recognizer!.getResult(_stream!).text;
        if (partialResult.isNotEmpty) {
          print('部分识别结果: $partialResult');
        }
      }
      
      // 获取最终识别结果
      final finalResult = _recognizer!.getResult(_stream!).text;
      print('最终识别结果: $finalResult');
      
      // 清理临时文件
      if (await tempAudioFile.exists()) {
        await tempAudioFile.delete();
      }
      
      // 释放流
      _stream!.free();
      _stream = null;
      
      return finalResult;
    } catch (e) {
      print('测试音频文件识别失败: $e');
      _stream?.free();
      _stream = null;
      return '';
    }
  }

  /// 销毁识别器，释放资源
  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await stopRecognition();
      }
      
      await _recordingDataSubscription?.cancel();
      _recordingDataSubscription = null;
      await _audioDataController?.close();
      _audioDataController = null;
      
      _stream?.free();
      _stream = null;
      
      _recognizer?.free();
      _recognizer = null;
      
      await _recorder.closeRecorder();
      
      _isInitialized = false;
    } catch (e) {
      print('销毁识别器失败: $e');
    }
  }
}
