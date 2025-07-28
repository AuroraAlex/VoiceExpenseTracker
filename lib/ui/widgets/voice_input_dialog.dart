import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../services/app_lifecycle_service.dart';
import '../../services/sherpa_onnx_service.dart';

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
  late SherpaOnnxService _sherpaService;
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
  
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // 获取共享的SherpaOnnxService实例
    _sherpaService = AppLifecycleService.instance.sherpaOnnxService;
    
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
    _sherpaService.stopRecognition();
    super.dispose();
  }


  Future<void> _checkAndStartListening() async {
    // 显示准备中状态
    setState(() {
      _recognizedText = '';
    });
    
    // 检查Sherpa服务是否已初始化
    if (_sherpaService.isInitialized) {
      print('Sherpa服务已初始化，直接开始语音识别');
      _startListening();
    } else {
      // 显示等待初始化的提示
      setState(() {
        _recognizedText = '语音识别服务正在准备中，请稍候...';
      });
      
      // 等待初始化完成
      int attempts = 0;
      const maxAttempts = 10; // 最多等待10次，每次500毫秒
      
      while (!_sherpaService.isInitialized && attempts < maxAttempts) {
        print('等待Sherpa服务初始化完成，尝试次数: ${attempts + 1}');
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }
      
      if (_sherpaService.isInitialized) {
        print('Sherpa服务已初始化完成，开始语音识别');
        _startListening();
      } else {
        print('Sherpa服务初始化超时，尝试手动初始化');
        
        try {
          final success = await _sherpaService.initialize();
          if (!success) {
            setState(() {
              _recognizedText = 'Sherpa语音识别初始化失败，请检查麦克风权限或模型文件';
            });
            return;
          }
          print('Sherpa服务手动初始化成功');
          _startListening();
        } catch (e) {
          print('Sherpa服务初始化异常: $e');
          setState(() {
            _recognizedText = 'Sherpa语音识别初始化异常: $e';
          });
        }
      }
    }
  }

  Future<void> _startListening() async {
    if (!_sherpaService.isInitialized) {
      print('Sherpa服务未初始化，无法开始监听');
      return;
    }

    print('开始Sherpa语音监听...');
    setState(() {
      _isListening = true;
      _isEditing = false;
      _recognizedText = '';
    });

    // 开始脉动动画
    _pulseController.repeat(reverse: true);

    try {
      // 取消之前的订阅
      await _resultSubscription?.cancel();
      
      // 开始识别
      final success = await _sherpaService.startRecognition();
      if (!success) {
        throw Exception('启动语音识别失败');
      }
      
      // 订阅识别结果流
      _resultSubscription = _sherpaService.resultStream?.listen((result) {
        print('收到识别结果: $result');
        
        // 更新UI
        setState(() {
          _recognizedText = result.isNotEmpty ? result : '未识别到内容';
        });
        
        // 自动滚动到底部
        _scrollToBottom();
        
        // 重置静音计时器
        _resetSilenceTimer();
      });
      
      // 设置静音计时器，3秒无语音则停止识别
      _resetSilenceTimer();
      
    } catch (e) {
      print('Sherpa语音识别异常: $e');
      setState(() {
        _isListening = false;
        _recognizedText = 'Sherpa语音识别失败: $e';
      });
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
  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 3), () {
      print('检测到3秒无语音，自动停止识别');
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
    final finalResult = await _sherpaService.stopRecognition();
    
    // 更新UI
    setState(() {
      _isListening = false;
      if (finalResult.isNotEmpty) {
        _recognizedText = finalResult;
      } else if (_recognizedText.isEmpty) {
        _recognizedText = '未识别到内容';
      }
    });
    
    // 自动滚动到底部
    _scrollToBottom();
    
    // 停止动画
    _pulseController.stop();
    _pulseController.reset();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _textController.text = _recognizedText;
    });
    
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

  void _confirmText() {
    final text = _isEditing ? _textController.text.trim() : _recognizedText.trim();
    if (text.isNotEmpty) {
      widget.onTextConfirmed(text);
      Get.back();
    } else {
      Get.snackbar('提示', '请说出或输入记账内容');
    }
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.blue.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.1),
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
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue.shade200,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),

              // 语音动画或文字显示区域
              Container(
                height: 120,
                child: _isListening
                    ? _buildListeningAnimation()
                    : (_recognizedText.isNotEmpty ? _buildTextDisplay() : _buildWaitingState()),
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
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: Colors.blue.withOpacity(0.3),
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
    return Center(
      child: Column(
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
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade300,
                        Colors.blue.shade600,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.4),
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
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: _recognizedText.isEmpty ? Colors.blue.shade400 : Colors.blue.shade800,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
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
            color: Colors.blue.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '语音识别准备中...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.blue.shade600,
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
          border: Border.all(color: Colors.blue, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
            hintStyle: TextStyle(color: Colors.grey[500]),
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
                  textAlign: TextAlign.center,
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}