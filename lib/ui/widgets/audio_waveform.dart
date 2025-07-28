import 'dart:math';
import 'package:flutter/material.dart';

/// 音频波形可视化组件
///
/// 显示实时音频波形，支持动画效果
class AudioWaveform extends StatefulWidget {
  /// 是否正在录音
  final bool isRecording;
  
  /// 波形颜色
  final Color waveColor;
  
  /// 波形高度
  final double height;
  
  /// 波形宽度
  final double width;
  
  /// 波形线条数量
  final int lineCount;

  const AudioWaveform({
    Key? key,
    required this.isRecording,
    this.waveColor = const Color(0xFF2196F3),
    this.height = 100,
    this.width = double.infinity,
    this.lineCount = 40,
  }) : super(key: key);

  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<double> _waveHeights = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _animationController.addListener(() {
      if (widget.isRecording) {
        _updateWaveHeights();
      }
    });
    
    _initWaveHeights();
  }

  @override
  void didUpdateWidget(AudioWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
        _resetWaveHeights();
      }
    }
    
    if (widget.lineCount != oldWidget.lineCount) {
      _initWaveHeights();
    }
  }

  void _initWaveHeights() {
    _waveHeights.clear();
    for (int i = 0; i < widget.lineCount; i++) {
      _waveHeights.add(0.1);
    }
  }

  void _resetWaveHeights() {
    setState(() {
      for (int i = 0; i < _waveHeights.length; i++) {
        _waveHeights[i] = 0.1;
      }
    });
  }

  void _updateWaveHeights() {
    if (!mounted) return;
    
    setState(() {
      for (int i = 0; i < _waveHeights.length; i++) {
        if (widget.isRecording) {
          // 生成随机波形高度
          _waveHeights[i] = _random.nextDouble() * 0.8 + 0.2;
        } else {
          _waveHeights[i] = 0.1;
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: widget.width,
      child: CustomPaint(
        painter: _WaveformPainter(
          waveHeights: _waveHeights,
          waveColor: widget.waveColor,
          isRecording: widget.isRecording,
        ),
        size: Size(widget.width, widget.height),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> waveHeights;
  final Color waveColor;
  final bool isRecording;

  _WaveformPainter({
    required this.waveHeights,
    required this.waveColor,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waveColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final lineSpacing = size.width / (waveHeights.length - 1);
    final centerY = size.height / 2;

    for (int i = 0; i < waveHeights.length; i++) {
      final x = i * lineSpacing;
      final height = waveHeights[i] * size.height * 0.8;
      
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.isRecording != isRecording ||
           oldDelegate.waveColor != waveColor ||
           oldDelegate.waveHeights != waveHeights;
  }
}