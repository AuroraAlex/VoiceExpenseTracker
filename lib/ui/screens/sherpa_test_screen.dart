import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:voice_expense_tracker/services/speech_recognition_factory.dart';
import 'package:voice_expense_tracker/services/sherpa_onnx_service.dart';
import 'package:voice_expense_tracker/services/speech_recognition_service.dart';
import 'package:voice_expense_tracker/ui/widgets/audio_waveform.dart';
import 'package:voice_expense_tracker/ui/widgets/download_progress_dialog.dart';
import 'package:voice_expense_tracker/ui/widgets/sherpa_settings_dialog.dart';
import 'package:voice_expense_tracker/utils/sherpa_utils.dart';

/// Sherpa-ONNX语音识别测试页面
class SherpaTestScreen extends StatefulWidget {
  const SherpaTestScreen({Key? key}) : super(key: key);

  @override
  State<SherpaTestScreen> createState() => _SherpaTestScreenState();
}

class _SherpaTestScreenState extends State<SherpaTestScreen> {
  // 使用语音识别服务
  late SpeechRecognitionService _speechService;
  final TextEditingController _resultController = TextEditingController();
  
  bool _isSherpaServiceAvailable = false;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isCopyingModel = false;
  String _statusText = '准备中';
  String _errorMessage = '';
  
  // 语音识别设置
  final SherpaSettings _settings = SherpaSettings();

  @override
  void initState() {
    super.initState();
    _speechService = SpeechRecognitionFactory.getInstance();
    setState(() {
      _isSherpaServiceAvailable = true;
    });
    _checkInitialization();
  }
  
  // 检查初始化状态
  Future<void> _checkInitialization() async {
    if (_speechService.isInitialized) {
      print('语音识别服务已初始化，无需重新初始化');
      setState(() {
        _isInitialized = true;
        _statusText = '就绪';
        _errorMessage = '';
      });
    } else {
      await _initializeSpeechService();
    }
  }

  Future<void> _initializeSpeechService() async {
    try {
      print('开始初始化语音识别服务');
      setState(() {
        _statusText = '正在初始化...';
        _errorMessage = '';
      });
      
      final success = await _speechService.initialize();
      
      print('语音识别服务初始化结果: $success');
      setState(() {
        _isInitialized = success;
        _statusText = success ? '就绪' : '初始化失败';
        _errorMessage = success ? '' : '无法初始化语音识别服务';
      });
    } catch (e) {
      print('语音识别服务初始化异常: $e');
      setState(() {
        _isInitialized = false;
        _statusText = '初始化错误';
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isInitialized) {
      await _initializeSpeechService();
      if (!_isInitialized) return;
    }

    if (_isRecording) {
      await _stopRecognition();
    } else {
      await _startRecognition();
    }
  }

  Future<void> _startRecognition() async {
    try {
      print('开始语音识别');
      setState(() {
        _statusText = '正在启动...';
        _errorMessage = '';
      });

      // 应用当前设置
      print('应用设置: 模型=${_settings.modelName}, 语言=${_settings.language}, '
            '灵敏度=${_settings.sensitivity}, 自动停止=${_settings.autoStop}');
      
      final success = await _speechService.startRecognition();
      print('语音识别启动结果: $success');
      
      if (success) {
        setState(() {
          _isRecording = true;
          _statusText = '正在聆听';
        });
        
        // 监听识别结果
        _speechService.resultStream?.listen(
          (result) {
            print('收到识别结果: $result');
            setState(() {
              _resultController.text = result;
            });
          },
          onError: (error) {
            print('识别结果流错误: $error');
            setState(() {
              _errorMessage = '识别过程出错: $error';
            });
          },
          onDone: () {
            print('识别结果流结束');
          },
        );
      } else {
        setState(() {
          _statusText = '启动失败';
          _errorMessage = '无法启动语音识别';
        });
      }
    } catch (e) {
      print('启动语音识别异常: $e');
      setState(() {
        _isRecording = false;
        _statusText = '错误';
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _stopRecognition() async {
    try {
      print('停止语音识别');
      setState(() {
        _statusText = '正在处理...';
      });
      
      final result = await _speechService.stopRecognition();
      print('语音识别最终结果: $result');
      
      setState(() {
        _isRecording = false;
        _statusText = '就绪';
        if (result.isNotEmpty) {
          _resultController.text = result;
        }
      });
    } catch (e) {
      print('停止语音识别异常: $e');
      setState(() {
        _isRecording = false;
        _statusText = '错误';
        _errorMessage = e.toString();
      });
    }
  }

  void _clearResult() {
    setState(() {
      _resultController.clear();
    });
  }

  // 复制模型文件
  Future<void> _copyModelFiles() async {
    try {
      setState(() {
        _isCopyingModel = true;
        _statusText = '正在复制模型文件...';
        _errorMessage = '';
      });

      print('开始复制模型文件');
      final success = await copyModelFromAssets('sherpa-onnx-streaming-zipformer-small-ctc-zh-2025-04-01');
      
      if (success) {
        setState(() {
          _statusText = '模型文件复制成功';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('模型文件复制成功，可以开始使用语音识别功能')),
        );
        
        // 重新初始化
        await _initializeSpeechService();
      } else {
        setState(() {
          _statusText = '模型文件复制失败';
          _errorMessage = '无法复制模型文件到应用目录';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('模型文件复制失败')),
        );
      }
    } catch (e) {
      print('复制模型文件失败: $e');
      setState(() {
        _statusText = '复制失败';
        _errorMessage = e.toString();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('复制失败: $e')),
      );
    } finally {
      setState(() {
        _isCopyingModel = false;
      });
    }
  }

  // 测试音频文件识别
  Future<void> _testAudioFile() async {
    if (!_isInitialized) {
      await _initializeSpeechService();
      if (!_isInitialized) return;
    }

    try {
      setState(() {
        _statusText = '正在测试音频文件...';
        _errorMessage = '';
      });

      print('开始测试音频文件识别');
      
      // 对于通用的语音识别服务，我们只能显示一个提示
      setState(() {
        _statusText = '测试完成';
        _resultController.text = '音频文件测试功能仅在Sherpa-ONNX服务中可用';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('音频文件测试功能仅在Sherpa-ONNX服务中可用')),
      );
    } catch (e) {
      print('测试音频文件识别失败: $e');
      setState(() {
        _statusText = '测试失败';
        _errorMessage = e.toString();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('测试失败: $e')),
      );
    }
  }
  
  // 保存识别结果
  void _saveRecognitionResult(String result) {
    // 这里只是模拟保存功能
    // 在实际应用中，可以将结果保存到数据库或文件中
    print('保存识别结果: $result');
    
    // 可以在这里添加实际的保存逻辑
    // 例如，将结果保存到数据库或文件中
  }
  
  // 显示设置对话框
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => SherpaSettingsDialog(
        settings: _settings,
        onSettingsChanged: (newSettings) {
          // 应用新设置
          setState(() {
            // 更新本地设置
            _settings.modelName = newSettings.modelName;
            _settings.language = newSettings.language;
            _settings.sensitivity = newSettings.sensitivity;
            _settings.autoStop = newSettings.autoStop;
            
            // 如果正在录音，需要先停止
            if (_isRecording) {
              _stopRecognition().then((_) {
                _applySettings();
              });
            } else {
              _applySettings();
            }
          });
        },
      ),
    );
  }
  
  // 应用设置到识别器
  void _applySettings() {
    // 在实际应用中，这里需要将设置应用到识别器
    // 例如，可以通过MethodChannel向原生层传递设置参数
    
    print('应用设置: 模型=${_settings.modelName}, 语言=${_settings.language}, '
          '灵敏度=${_settings.sensitivity}, 自动停止=${_settings.autoStop}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设置已更新')),
    );
  }

  @override
  void dispose() {
    // 不再在这里释放SherpaOnnxService，而是在应用退出时释放
    _resultController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSherpaServiceAvailable) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sherpa-ONNX Test'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'This test screen is only available for the Sherpa-ONNX service, which is not active on this platform (iOS).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sherpa-ONNX语音识别测试'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: '语音识别设置',
          ),
        ],
      ),
      body: Column(
        children: [
          // 状态区域
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Column(
              children: [
                Text(
                  _statusText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // 麦克风按钮
          GestureDetector(
            onTap: _toggleRecording,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red : Colors.blue,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                size: 50,
                color: Colors.white,
              ),
            ),
          ),
          
          // 波形可视化
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: AudioWaveform(
              isRecording: _isRecording,
              height: 100,
              width: MediaQuery.of(context).size.width - 32,
              waveColor: Colors.blue,
              lineCount: 50,
            ),
          ),
          
          // 识别结果区域
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '识别结果',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.content_copy),
                        onPressed: () {
                          if (_resultController.text.isNotEmpty) {
                            // 复制文本到剪贴板
                            Clipboard.setData(ClipboardData(text: _resultController.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制到剪贴板')),
                            );
                          }
                        },
                        tooltip: '复制结果',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TextField(
                      controller: _resultController,
                      maxLines: null,
                      readOnly: true,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '语音识别结果将显示在这里...',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 底部控制按钮
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 第一行按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toggleRecording,
                      icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                      label: Text(_isRecording ? '停止' : '开始'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRecording ? Colors.red : Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _clearResult,
                      icon: const Icon(Icons.clear),
                      label: const Text('清除'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_resultController.text.isNotEmpty) {
                          // 保存识别结果
                          _saveRecognitionResult(_resultController.text);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('识别结果已保存')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('没有可保存的识别结果')),
                          );
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('保存'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 第二行：复制模型文件按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isCopyingModel ? null : _copyModelFiles,
                    icon: _isCopyingModel 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(_isCopyingModel ? '正在复制模型文件...' : '复制模型文件'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 第三行：测试按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _testAudioFile,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('测试音频文件 (0.wav)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}