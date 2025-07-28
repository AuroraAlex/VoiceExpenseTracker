import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/ai_agent_service.dart';
import '../../models/expense.dart';
import 'voice_input_dialog.dart';

class VoiceInputButton extends StatefulWidget {
  final Function(Expense) onVoiceProcessed;

  const VoiceInputButton({
    Key? key,
    required this.onVoiceProcessed,
  }) : super(key: key);

  @override
  _VoiceInputButtonState createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  final AIAgentService _aiAgentService = AIAgentService.fromConfig();
  bool _isProcessing = false;

  @override
  void dispose() {
    super.dispose();
  }

  void _showVoiceInputDialog() {
    Get.dialog(
      VoiceInputDialog(
        onTextConfirmed: _processText,
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _processText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      Get.snackbar('提示', '未识别到内容');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _aiAgentService.processRecordInput(trimmed);
      final expense = _aiAgentService.createExpenseFromResult(result, trimmed);

      if (expense != null) {
        widget.onVoiceProcessed(expense);
        Get.snackbar('成功', '记账添加成功：${expense.title} ¥${expense.amount}');
      } else {
        Get.snackbar('错误', '解析失败: ${result['message'] ?? "请重试"}');
      }
    } catch (e) {
      Get.snackbar('错误', '处理时出错：$e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'voice',
      onPressed: _isProcessing ? null : _showVoiceInputDialog,
      backgroundColor: _isProcessing ? Colors.grey : Colors.red,
      tooltip: '语音记账',
      child: _isProcessing
          ? const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
          : const Icon(Icons.mic, color: Colors.white),
    );
  }
}