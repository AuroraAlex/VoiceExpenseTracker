import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'speech_recognition_service.dart';

/// Android端语音识别服务
/// 使用Paraformer ONNX模型进行语音识别
class AndroidSpeechRecognitionService implements SpeechRecognitionService {
  static final AndroidSpeechRecognitionService _instance = AndroidSpeechRecognitionService._internal();
  factory AndroidSpeechRecognitionService() => _instance;
  AndroidSpeechRecognitionService._internal();

  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isInitializing = false;
  StreamController<String>? _resultStreamController;
  
  sherpa_onnx.OnlineRecognizer? _recognizer;
  sherpa_onnx.OnlineStream? _stream;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  StreamSubscription? _recordingDataSubscription;
  StreamController<Uint8List>? _audioDataController;
  
  int _sampleRate = 16000;
  String _last = '';
  
  // 模型文件路径
  late String _modelDir;
  static const String _encoderFileName = 'encoder.int8.onnx';
  static const String _decoderFileName = 'decoder.int8.onnx';
  static const String _tokensFileName = 'tokens.txt';

  @override
  bool get isInitialized => _isInitialized;
  
  bool get isRecording => _isRecording;
  
  @override
  Stream<String>? get resultStream => _resultStreamController?.stream;

  /// 检查模型文件是否已复制到应用目录
  Future<bool> _checkModelFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _modelDir = path.join(appDir.path, 'paraformer_models');
      
      final encoderFile = File(path.join(_modelDir, _encoderFileName));
      final decoderFile = File(path.join(_modelDir, _decoderFileName));
      final tokensFile = File(path.join(_modelDir, _tokensFileName));
      
      return await encoderFile.exists() && 
             await decoderFile.exists() && 
             await tokensFile.exists();
    } catch (e) {
      print('检查模型文件时出错: $e');
      return false;
    }
  }

  /// 从assets复制模型文件到应用目录
  Future<bool> _copyModelFiles() async {
    try {
      print('开始复制Paraformer模型文件到应用目录...');
      
      final appDir = await getApplicationDocumentsDirectory();
      _modelDir = path.join(appDir.path, 'paraformer_models');
      
      // 创建模型目录
      final modelDirObj = Directory(_modelDir);
      if (!await modelDirObj.exists()) {
        await modelDirObj.create(recursive: true);
      }
      
      // 复制模型文件
      final filesToCopy = [_encoderFileName, _decoderFileName, _tokensFileName];
      
      for (String fileName in filesToCopy) {
        print('正在复制文件: $fileName');
        
        try {
          // 从assets读取文件
          final assetPath = 'assets/models/$fileName';
          final ByteData data = await rootBundle.load(assetPath);
          final List<int> bytes = data.buffer.asUint8List();
          
          // 写入到应用目录
          final targetFile = File(path.join(_modelDir, fileName));
          await targetFile.writeAsBytes(bytes);
          
          print('文件复制成功: $fileName (${bytes.length} 字节)');
        } catch (e) {
          print('复制文件失败: $fileName, 错误: $e');
          return false;
        }
      }
      
      print('所有模型文件复制完成');
      return true;
    } catch (e) {
      print('复制模型文件时出错: $e');
      return false;
    }
  }

  /// 初始化语音识别服务
  @override
  Future<bool> initialize() async {
    if (_isInitialized) {
      print('Android语音识别服务已初始化');
      return true;
    }
    
    if (_isInitializing) {
      print('Android语音识别服务正在初始化中...');
      return false;
    }
    
    _isInitializing = true;
    
    try {
      print('开始初始化Android语音识别服务...');
      
      // 检查麦克风权限
      final permission = await Permission.microphone.status;
      if (!permission.isGranted) {
        print('请求麦克风权限...');
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          print('麦克风权限被拒绝');
          _isInitializing = false;
          return false;
        }
      }
      
      // 检查模型文件是否存在，如果不存在则复制
      bool modelFilesExist = await _checkModelFiles();
      if (!modelFilesExist) {
        print('模型文件不存在，开始复制...');
        bool copySuccess = await _copyModelFiles();
        if (!copySuccess) {
          print('复制模型文件失败');
          _isInitializing = false;
          return false;
        }
      } else {
        print('模型文件已存在，跳过复制');
      }
      
      // 初始化Sherpa-ONNX
      print('初始化Sherpa-ONNX绑定...');
      sherpa_onnx.initBindings();
      
      // 创建Paraformer模型配置
      print('创建Paraformer模型配置...');
      final paraformerConfig = sherpa_onnx.OnlineParaformerModelConfig(
        encoder: path.join(_modelDir, _encoderFileName),
        decoder: path.join(_modelDir, _decoderFileName),
      );
      
      final modelConfig = sherpa_onnx.OnlineModelConfig(
        paraformer: paraformerConfig,
        tokens: path.join(_modelDir, _tokensFileName),
        numThreads: 2,
        provider: 'cpu',
        modelType: 'paraformer',
      );
      
      // 创建识别器配置
      final config = sherpa_onnx.OnlineRecognizerConfig(
        model: modelConfig,
        ruleFsts: '',
        hotwordsFile: '',
        hotwordsScore: 1.5,
        ctcFstDecoderConfig: sherpa_onnx.OnlineCtcFstDecoderConfig(),
      );
      
      // 创建识别器
      print('创建语音识别器...');
      _recognizer = sherpa_onnx.OnlineRecognizer(config);
      
      // 初始化录音器
      print('初始化录音器...');
      await _recorder.openRecorder();
      await _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
      
      _isInitialized = true;
      _isInitializing = false;
      print('Android语音识别服务初始化完成！');
      return true;
      
    } catch (e) {
      print('Android语音识别服务初始化失败: $e');
      _isInitialized = false;
      _isInitializing = false;
      return false;
    }
  }

  /// 开始语音识别
  @override
  Future<bool> startRecognition() async {
    if (!_isInitialized) {
      print('Android语音识别服务未初始化');
      return false;
    }

    if (_isRecording) {
      await stopRecognition();
    }

    try {
      print('开始Android语音识别...');
      
      // 创建结果流控制器
      _resultStreamController = StreamController<String>.broadcast();
      
      // 重置识别状态
      _last = '';
      _stream = _recognizer?.createStream();
      
      if (_recorder.isStopped) {
        _audioDataController = StreamController<Uint8List>();
        
        // 音频数据处理
        List<int> _audioBuffer = [];
        const int _bufferSize = 3200; // 0.2秒的数据
        
        _recordingDataSubscription = _audioDataController!.stream.listen((audioData) {
          _audioBuffer.addAll(audioData);
          
          if (_audioBuffer.length >= _bufferSize) {
            final dataToProcess = _audioBuffer.take(_bufferSize).toList();
            _audioBuffer = _audioBuffer.skip(_bufferSize).toList();
            
            try {
              final samplesFloat32 = _convertBytesToFloat32(Uint8List.fromList(dataToProcess));
              
              if (_stream != null && _recognizer != null) {
                _stream!.acceptWaveform(samples: samplesFloat32, sampleRate: _sampleRate);
                
                while (_recognizer!.isReady(_stream!)) {
                  _recognizer!.decode(_stream!);
                }
                
                final text = _recognizer!.getResult(_stream!).text;
                
                if (text.isNotEmpty && text != _last) {
                  _last = text;
                  print('识别结果: $text');
                  _resultStreamController?.add(text);
                }

                if (_recognizer!.isEndpoint(_stream!)) {
                  print('检测到语音终点，重置识别器');
                  _recognizer!.reset(_stream!);
                  _last = '';
                }
              }
            } catch (e) {
              print('处理音频数据时出错: $e');
            }
          }
        });

        // 开始录音
        await _recorder.startRecorder(
          toStream: _audioDataController!.sink,
          codec: Codec.pcm16,
          numChannels: 1,
          sampleRate: _sampleRate,
        );

        _isRecording = true;
        print('Android语音识别启动成功');
      }
      
      return true;
    } catch (e) {
      print('开始Android语音识别失败: $e');
      await _resultStreamController?.close();
      _resultStreamController = null;
      _isRecording = false;
      return false;
    }
  }

  /// 停止语音识别
  @override
  Future<String> stopRecognition() async {
    if (!_isRecording) return '';

    try {
      print('停止Android语音识别...');
      
      // 停止录音
      await _recorder.stopRecorder();
      
      // 取消音频流订阅
      await _recordingDataSubscription?.cancel();
      _recordingDataSubscription = null;
      await _audioDataController?.close();
      _audioDataController = null;
      
      // 获取最终识别结果
      String finalResult = '';
      if (_stream != null && _recognizer != null) {
        try {
          while (_recognizer!.isReady(_stream!)) {
            _recognizer!.decode(_stream!);
          }
          
          finalResult = _recognizer!.getResult(_stream!).text;
          print('Android语音识别最终结果: $finalResult');
          
          _stream!.free();
          _stream = null;
        } catch (e) {
          print('获取最终识别结果时出错: $e');
          finalResult = _last;
        }
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
      print('停止Android语音识别失败: $e');
      _isRecording = false;
      return '';
    }
  }

  /// 将字节数据转换为Float32List
  Float32List _convertBytesToFloat32(Uint8List bytes) {
    final int16List = Int16List.view(bytes.buffer);
    final float32List = Float32List(int16List.length);
    
    for (int i = 0; i < int16List.length; i++) {
      float32List[i] = int16List[i] / 32768.0;
    }
    
    return float32List;
  }

  /// 销毁识别器，释放资源
  @override
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
      _isInitializing = false;
    } catch (e) {
      print('销毁Android语音识别器失败: $e');
    }
  }
}