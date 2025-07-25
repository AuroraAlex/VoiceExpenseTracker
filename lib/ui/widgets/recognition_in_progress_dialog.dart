import 'package:flutter/material.dart';

class RecognitionInProgressDialog extends StatelessWidget {
  final ValueNotifier<String>? recognizedTextNotifier;
  final VoidCallback? onStopListening;

  const RecognitionInProgressDialog({
    Key? key,
    this.recognizedTextNotifier,
    this.onStopListening,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            const Text(
              '语音识别中...',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // 麦克风动画图标
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic,
                size: 40,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            
            // 识别到的文字
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: recognizedTextNotifier != null
                  ? ValueListenableBuilder<String>(
                      valueListenable: recognizedTextNotifier!,
                      builder: (context, text, child) {
                        return Text(
                          text.isEmpty ? '请说话...' : text,
                          style: TextStyle(
                            fontSize: 16,
                            color: text.isEmpty ? Colors.grey[600] : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                    )
                  : Text(
                      '请说话...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(height: 24),
            
            // 提示文字
            Text(
              '请清晰地说出您的消费记录\n例如："买菜花了50元"',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // 停止按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStopListening,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '停止录音',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}