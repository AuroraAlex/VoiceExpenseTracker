import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/text_ai_service.dart';
import '../../models/expense.dart';

/// 文本输入测试页面
class TextInputTestScreen extends StatefulWidget {
  const TextInputTestScreen({Key? key}) : super(key: key);

  @override
  _TextInputTestScreenState createState() => _TextInputTestScreenState();
}

class _TextInputTestScreenState extends State<TextInputTestScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextAIService _textAIService = TextAIService.fromConfig();
  
  bool _isProcessing = false;
  String _resultText = '';
  Expense? _expense;
  
  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
  
  Future<void> _processText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      Get.snackbar('提示', '请输入测试文本');
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _resultText = '处理中...';
      _expense = null;
    });
    
    try {
      final result = await _textAIService.processText(text);
      final expense = _textAIService.createExpenseFromResult(result, text);
      
      setState(() {
        _resultText = '处理结果：\n${result.toString()}';
        _expense = expense;
      });
    } catch (e) {
      setState(() {
        _resultText = '处理出错：$e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文本输入测试'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 说明文本
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '文本输入测试',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '在下方输入框中输入记账信息，点击"处理"按钮测试AI服务是否能正确识别记账信息。',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '示例：今天午餐花了35元、昨天买衣服花了299元、收到工资5000元',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 输入区域
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: '输入记账信息',
                hintText: '例如：今天午餐花了35元',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () => _textController.clear(),
                ),
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 16),
            
            // 处理按钮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processText,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isProcessing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('处理中...'),
                        ],
                      )
                    : Text('处理'),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 分割线
            Divider(thickness: 1),
            
            const SizedBox(height: 16),
            
            // 结果显示
            Text(
              '处理结果',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 原始结果
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _resultText,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 解析后的支出信息
            if (_expense != null) ...[
              Text(
                '解析后的支出信息',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 支出卡片
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _expense!.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '¥${_expense!.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _expense!.type == 'expense' ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.category, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                _expense!.category,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${_expense!.date.year}-${_expense!.date.month.toString().padLeft(2, '0')}-${_expense!.date.day.toString().padLeft(2, '0')}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      if (_expense!.description != null && _expense!.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Divider(),
                        const SizedBox(height: 8),
                        Text(
                          _expense!.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                      
                      // 如果是车辆支出，显示额外信息
                      if (_expense!.category == '汽车' && 
                          (_expense!.mileage != null || 
                           _expense!.consumption != null || 
                           _expense!.vehicleType != null)) ...[
                        const SizedBox(height: 12),
                        Divider(),
                        const SizedBox(height: 8),
                        Text(
                          '车辆信息',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_expense!.vehicleType != null)
                          Text('车辆类型: ${_expense!.vehicleType}'),
                        if (_expense!.mileage != null)
                          Text('里程数: ${_expense!.mileage}'),
                        if (_expense!.consumption != null)
                          Text('消耗量: ${_expense!.consumption}'),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}