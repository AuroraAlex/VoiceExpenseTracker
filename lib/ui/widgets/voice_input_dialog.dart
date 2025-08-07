import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/app_lifecycle_service.dart';
import '../../services/speech_recognition_service.dart';

class VoiceInputDialog extends StatefulWidget {
  final Function(String) onTextConfirmed;

  const VoiceInputDialog({
    Key? key,
    required this.onTextConfirmed,
  }) : super(key: key);

  @override
  _VoiceInputDialogState createState() => _VoiceInputDialogState();
}

class _VoiceInputDialogState extends State<VoiceInputDialog>
    with TickerProviderStateMixin {
  // 使用AppLifecycleService中的共享实例
  late SpeechRecognitionService _speechService;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  // 添加滚动控制器，用于自动滚动
  final ScrollController _scrollController = ScrollController();
  final ScrollController _editScrollController = ScrollController();

  bool _isListening = false;
  bool _isEditing = false;
  String _recognizedText = '';
  Timer? _silenceTimer;
  StreamSubscription? _resultSubscription;
  bool _isPermissionPermanentlyDenied = false;
  
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // 获取共享的SpeechRecognitionService实例
    _speechService = AppLifecycleService.instance.speechRecognitionService;
    
    // 脉动动画控制器
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // 淡入动画控制器
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);

    // 启动淡入动画
    _fadeController.forward();
    
    // 检查并开始语音识别
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndStartListening();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _editScrollController.dispose();
    _silenceTimer?.cancel();
    _resultSubscription?.cancel();
    _speechService.stopRecognition();
    super.dispose();
  }


  Future<void> _checkAndStartListening() async {
    // 检查麦克风权限
    final microphoneStatus = await Permission.microphone.status;
    if (microphoneStatus.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          _recognizedText = '麦克风权限已被永久拒绝。请在系统设置中开启权限以使用语音功能。';
          _isPermissionPermanentlyDenied = true;
        });
      }
      return; // 停止执行
    }

    // 显示准备中状态
    if (mounted) {
      setState(() {
        _recognizedText = '';
      });
    }
    
    // 检查语音服务是否已初始化
    if (_speechService.isInitialized) {
      print('语音服务已初始化，直接开始语音识别');
      _startListening();
    } else {
      // 显示等待初始化的提示
      if (mounted) {
        setState(() {
          _recognizedText = '语音识别服务正在准备中，请稍候...';
        });
      }
      
      // 根据平台调整等待策略
      int attempts = 0;
      int maxAttempts;
      int delayMs;
      
      if (Platform.isIOS) {
        maxAttempts = 30; // iOS平台给予更多等待时间
        delayMs = 200; // iOS平台使用更短的检查间隔
        print('iOS平台：最多等待${maxAttempts}次，每次${delayMs}毫秒');
      } else {
        maxAttempts = 10; // Android平台
        delayMs = 500;
        print('Android平台：最多等待${maxAttempts}次，每次${delayMs}毫秒');
      }
      
      while (!_speechService.isInitialized && attempts < maxAttempts) {
        print('等待语音服务初始化完成，尝试次数: ${attempts + 1}/${maxAttempts}');
        await Future.delayed(Duration(milliseconds: delayMs));
        attempts++;
      }
      
      if (_speechService.isInitialized) {
        print('语音服务已初始化完成，开始语音识别');
        _startListening();
      } else {
        print('Sherpa服务初始化超时，尝试手动初始化');
        
        try {
          // iOS平台特殊处理
          if (Platform.isIOS) {
            print('iOS平台：使用特殊初始化策略');
            
            // 显示更友好的提示
            if (mounted) {
              setState(() {
                _recognizedText = 'iOS设备首次使用需要额外准备，请稍候...';
              });
            }
            
            // 在iOS上尝试多次初始化，每次间隔更长
            bool success = false;
            for (int i = 0; i < 5; i++) { // 增加尝试次数
              print('iOS平台：尝试初始化 #${i+1}');
              try {
                // 每次尝试前先等待一段时间，让系统资源释放
                if (i > 0) {
                  await Future.delayed(const Duration(seconds: 1));
                }
                
                success = await _speechService.initialize();
                if (success) {
                  print('iOS平台：语音服务初始化成功');
                  break;
                } else {
                  print('iOS平台：初始化尝试 #${i+1} 失败');
                  // 增加等待时间
                  await Future.delayed(Duration(seconds: 1 + i));
                }
              } catch (e) {
                print('iOS平台：初始化尝试 #${i+1} 异常: $e');
                // 增加等待时间
                await Future.delayed(Duration(seconds: 1 + i));
              }
            }
            
            if (success) {
              print('iOS平台：Sherpa服务手动初始化成功');
              _startListening();
            } else {
              if (mounted) {
                setState(() {
                  _recognizedText = 'iOS语音识别初始化失败，请尝试重新打开应用或检查模型文件';
                });
              }
            }
          } else {
            // Android平台正常流程
            final success = await _speechService.initialize();
            if (!success) {
              if (mounted) {
                setState(() {
                  _recognizedText = 'Sherpa语音识别初始化失败，请检查麦克风权限或模型文件';
                });
              }
              return;
            }
            print('Sherpa服务手动初始化成功');
            _startListening();
          }
        } catch (e) {
          print('Sherpa服务初始化异常: $e');
          if (mounted) {
            setState(() {
              _recognizedText = 'Sherpa语音识别初始化异常: $e';
            });
          }
        }
      }
    }
  }

  Future<void> _startListening() async {
    if (!_speechService.isInitialized) {
      print('语音服务未初始化，无法开始监听');
      return;
    }

    print('开始Sherpa语音监听...');
    if (mounted) {
      setState(() {
        _isListening = true;
        _isEditing = false;
        _recognizedText = '';
      });
    }

    // 开始脉动动画
    _pulseController.repeat(reverse: true);

    try {
      // 取消之前的订阅
      await _resultSubscription?.cancel();
      
      // 开始识别
      bool success = false;
      
      // iOS平台特殊处理，尝试多次启动
      if (Platform.isIOS) {
        for (int i = 0; i < 3; i++) {
          try {
            success = await _speechService.startRecognition();
            if (success) {
              print('iOS平台：语音识别启动成功');
              break;
            } else {
              print('iOS平台：语音识别启动尝试 #${i+1} 失败');
              await Future.delayed(const Duration(milliseconds: 500));
            }
          } catch (e) {
            print('iOS平台：语音识别启动尝试 #${i+1} 异常: $e');
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      } else {
        // Android平台正常流程
        success = await _speechService.startRecognition();
      }
      
      if (!success) {
        throw Exception('启动语音识别失败');
      }
      
      // 订阅识别结果流
      _resultSubscription = _speechService.resultStream?.listen((result) {
        print('收到识别结果: $result');
        
        // 更新UI
        if (mounted) {
          setState(() {
            _recognizedText = result.isNotEmpty ? result : '未识别到内容';
          });
        }
        
        // 自动滚动到底部
        _scrollToBottom();
        
        // 重置静音计时器
        _resetSilenceTimer();
      }, onError: (e) {
        // 处理流错误
        print('识别结果流错误: $e');
        // 不中断整个识别过程，只记录错误
      });
      
      // 设置静音计时器，iOS平台使用更长的无语音时间
      if (Platform.isIOS) {
        _resetSilenceTimer(5); // iOS平台使用5秒
      } else {
        _resetSilenceTimer(3); // 其他平台使用3秒
      }
      
    } catch (e) {
      print('Sherpa语音识别异常: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
          _recognizedText = 'Sherpa语音识别失败: $e';
        });
      }
      _pulseController.stop();
      _pulseController.reset();
    }
  }
  
  /// 滚动到底部
  void _scrollToBottom() {
    // 确保在下一帧渲染后滚动，以便获取正确的内容高度
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  /// 重置静音计时器
  void _resetSilenceTimer([int seconds = 3]) {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(Duration(seconds: seconds), () {
      print('检测到${seconds}秒无语音，自动停止识别');
      _stopListening();
    });
  }
  
  /// 停止语音识别
  Future<void> _stopListening() async {
    if (!_isListening) return;
    
    print('停止Sherpa语音识别');
    
    // 取消静音计时器
    _silenceTimer?.cancel();
    _silenceTimer = null;
    
    // 停止识别
    String finalResult = '';
    try {
      finalResult = await _speechService.stopRecognition();
    } catch (e) {
      print('停止语音识别时出错: $e');
      // 使用最后一次识别结果
      finalResult = _recognizedText;
    }
    
    // 取消结果流订阅
    await _resultSubscription?.cancel();
    _resultSubscription = null;
    
    // 更新UI
    if (mounted) {
      setState(() {
        _isListening = false;
        if (finalResult.isNotEmpty) {
          _recognizedText = finalResult;
        } else if (_recognizedText.isEmpty) {
          _recognizedText = '未识别到内容';
        }
      });
    }
    
    // 自动滚动到底部
    _scrollToBottom();
    
    // 停止动画
    _pulseController.stop();
    _pulseController.reset();
  }

  void _startEditing() {
    if (mounted) {
      setState(() {
        _isEditing = true;
        _textController.text = _recognizedText;
      });
    }
    
    // 震动反馈
    HapticFeedback.mediumImpact();
    
    // 聚焦到文本框
    _focusNode.requestFocus();
    
    // 延迟滚动到底部，确保编辑框已经渲染完成
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_editScrollController.hasClients) {
        _editScrollController.jumpTo(_editScrollController.position.maxScrollExtent);
      }
    });
  }

  void _confirmText() async {
    // 如果仍在监听，先停止以获取最终结果
    if (_isListening) {
      await _stopListening();
    }

    final text = _isEditing ? _textController.text.trim() : _recognizedText.trim();
    if (text.isNotEmpty && text != '未识别到内容') {
      widget.onTextConfirmed(text);
      Get.back();
    } else {
      Get.snackbar('提示', '请说出或输入记账内容');
    }
  }

  Widget _buildPermissionDeniedState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.mic_off,
          size: 48,
          color: Colors.red.shade400,
        ),
        const SizedBox(height: 16),
        Text(
          _recognizedText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.red.shade800,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: openAppSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('打开设置'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color(0xFFE3F2FD), // 替换Colors.blue.shade50
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0x1A2196F3), // 替换Colors.blue.withOpacity(0.1)
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 关闭按钮
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Get.back(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD), // 替换Colors.blue.shade50
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFBBDEFB), // 替换Colors.blue.shade200
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Color(0xFF1E88E5), // 替换Colors.blue.shade600
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),

              // 语音动画或文字显示区域
              SizedBox(
                height: 120,
                child: _isListening
                    ? _buildListeningAnimation()
                    : _isPermissionPermanentlyDenied
                        ? _buildPermissionDeniedState()
                        : (_recognizedText.isNotEmpty
                            ? _buildTextDisplay()
                            : _buildWaitingState()),
              ),

              const SizedBox(height: 32),

              // 确认按钮
              Container(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _recognizedText.isNotEmpty || _isEditing 
                      ? _confirmText 
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3), // 替换Colors.blue
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: const Color(0x4D2196F3), // 替换Colors.blue.withOpacity(0.3)
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '确认记账',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListeningAnimation() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF64B5F6), // 替换Colors.blue.shade300
                      Color(0xFF1E88E5), // 替换Colors.blue.shade600
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x662196F3), // 替换Colors.blue.withOpacity(0.4)
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.mic,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // 使用Expanded和SingleChildScrollView确保文本可以滚动
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Text(
              _recognizedText.isEmpty ? '请开始说话...' : _recognizedText,
              textAlign: TextAlign.left, // 改为左对齐以优化长文本显示
              style: TextStyle(
                fontSize: 16,
                color: _recognizedText.isEmpty ? const Color(0xFF64B5F6) : const Color(0xFF1565C0), // 使用常量颜色代替Colors.blue.shade400/800
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_off,
            size: 48,
            color: Color(0xFF64B5F6),
          ),
          SizedBox(height: 16),
          Text(
            '语音识别准备中...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF1E88E5),
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextDisplay() {
    if (_isEditing) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2196F3), width: 2), // 替换Colors.blue
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A2196F3), // 替换Colors.blue.withOpacity(0.1)
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _textController,
          focusNode: _focusNode,
          maxLines: null,
          scrollController: _editScrollController,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: '编辑识别的文字...',
            hintStyle: const TextStyle(color: Color(0xFF9E9E9E)), // 替换Colors.grey[500]
          ),
          style: const TextStyle(
            fontSize: 16,
            height: 1.4,
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: _startEditing,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE3F2FD), // 替换Colors.blue.shade50
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBDEFB)), // 替换Colors.blue.shade200
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A2196F3), // 替换Colors.blue.withOpacity(0.1)
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        // 使用Column包裹SingleChildScrollView，确保文本可以滚动
        child: Column(
          children: [
            // 使用Expanded确保文本区域占满可用空间
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Text(
                  _recognizedText,
                  textAlign: TextAlign.left, // 改为左对齐以优化长文本显示
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '长按可编辑',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9E9E9E), // 替换Colors.grey[500]
              ),
            ),
          ],
        ),
      ),
    );
  }
}