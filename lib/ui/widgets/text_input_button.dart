import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/text_ai_service.dart';
import '../../models/expense.dart';
import 'text_input_dialog.dart';

class TextInputButton extends StatefulWidget {
  final Function(Expense) onTextProcessed;

  const TextInputButton({
    Key? key,
    required this.onTextProcessed,
  }) : super(key: key);

  @override
  _TextInputButtonState createState() => _TextInputButtonState();
}

class _TextInputButtonState extends State<TextInputButton> {
  final TextAIService _textAIService = TextAIService.fromConfig();
  bool _isProcessing = false;

  @override
  void dispose() {
    super.dispose();
  }

  void _showTextInputDialog() {
    Get.dialog(
      TextInputDialog(
        onTextConfirmed: _processText,
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _processText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      Get.snackbar('提示', '请输入内容');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // 调用AI服务处理文本
      final result = await _textAIService.processText(trimmed);
      final expense = _textAIService.createExpenseFromResult(result, trimmed);

      if (expense != null) {
        widget.onTextProcessed(expense);
        Get.snackbar(
          '记账成功', 
          '${expense.title} ¥${expense.amount}',
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade800,
          duration: Duration(seconds: 3),
          icon: Icon(Icons.check_circle, color: Colors.green),
        );
      } else {
        Get.snackbar(
          '无法识别记账信息', 
          result['message'] ?? "请尝试更清晰地描述您的记账信息",
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade800,
          duration: Duration(seconds: 3),
          icon: Icon(Icons.error_outline, color: Colors.red),
        );
      }
    } catch (e) {
      Get.snackbar(
        '处理出错', 
        '处理您的记账信息时出现错误：$e',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        duration: Duration(seconds: 3),
        icon: Icon(Icons.error_outline, color: Colors.red),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'text',
      onPressed: _isProcessing ? null : _showTextInputDialog,
      backgroundColor: _isProcessing ? Colors.grey : Colors.blue,
      tooltip: '文本记账',
      child: _isProcessing
          ? const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
          : const Icon(Icons.text_fields, color: Colors.white),
    );
  }
}