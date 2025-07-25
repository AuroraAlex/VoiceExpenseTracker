import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../services/speech_service.dart';

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
  final SpeechService _speechService = SpeechService();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isListening = false;
  bool _isEditing = false;
  String _recognizedText = '';
  
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
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
    _speechService.stopListening();
    super.dispose();
  }


  Future<void> _checkAndStartListening() async {
    // 如果语音服务未初始化，先初始化
    if (!_speechService.isInitialized) {
      print('语音服务未初始化，开始初始化...');
      try {
        final success = await _speechService.initialize();
        if (!success) {
          setState(() {
            _recognizedText = '语音识别初始化失败，请检查麦克风权限';
          });
          return;
        }
        print('语音服务初始化成功');
      } catch (e) {
        print('语音服务初始化异常: $e');
        setState(() {
          _recognizedText = '语音识别初始化异常: $e';
        });
        return;
      }
    }
    
    // 开始语音识别
    _startListening();
  }

  Future<void> _startListening() async {
    if (!_speechService.isInitialized) {
      print('语音服务未初始化，无法开始监听');
      return;
    }

    print('开始语音监听...');
    setState(() {
      _isListening = true;
      _isEditing = false;
      _recognizedText = '';
    });

    // 开始脉动动画
    _pulseController.repeat(reverse: true);

    try {
      await _speechService.startListening(
        onResult: (result) {
          print('收到最终结果: $result');
          setState(() {
            _recognizedText = result.isNotEmpty ? result : '未识别到内容';
            _isListening = false;
          });
          _pulseController.stop();
          _pulseController.reset();
        },
        onPartialResult: (partialResult) {
          print('收到部分结果: $partialResult');
          if (partialResult.isNotEmpty) {
            setState(() {
              _recognizedText = partialResult;
            });
          }
        },
      );
    } catch (e) {
      print('语音识别异常: $e');
      setState(() {
        _isListening = false;
        _recognizedText = '语音识别失败: $e';
      });
      _pulseController.stop();
      _pulseController.reset();
    }
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
                  width: 80,
                  height: 80,
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
                    size: 36,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            _recognizedText.isEmpty ? '请开始说话...' : _recognizedText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: _recognizedText.isEmpty ? Colors.blue.shade400 : Colors.blue.shade800,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
        padding: const EdgeInsets.all(20),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _recognizedText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
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