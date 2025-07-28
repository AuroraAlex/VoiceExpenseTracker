import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/expense.dart';
import 'config_service.dart';
import '../utils/ai_prompts.dart';

/// 文本AI服务，用于处理文本输入并提取记账信息
class TextAIService {
  final String? apiKey;
  final String? apiUrl;
  final String? model;

  TextAIService({this.apiKey, this.apiUrl, this.model});

  /// 从配置服务获取API配置
  factory TextAIService.fromConfig() {
    final config = ConfigService().getAiApiConfig();
    return TextAIService(
      apiKey: config['apiKey'],
      apiUrl: config['apiUrl'],
      model: config['model'],
    );
  }

  /// 处理文本输入，提取记账信息
  Future<Map<String, dynamic>> processRecordInput(String text) async {
    // 检查网络连接
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return {'status': 'error', 'message': '无网络连接，无法使用AI服务'};
    }

    if (apiKey == null || apiUrl == null || model == null) {
      return {'status': 'error', 'message': 'API配置缺失'};
    }

    try {
      final now = DateTime.now();
      final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final systemPrompt = AIPrompts.getVoiceExpensePrompt(formattedDate);

      final requestBody = {
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': systemPrompt,
          },
          {
            'role': 'user',
            'content': text
          }
        ],
        'temperature': 0.5, // 降低温度以获得更确定的结果
      };

      // 打印请求体
      debugPrint('--- 文本AI请求 ---');
      debugPrint(jsonEncode(requestBody));

      final response = await http.post(
        Uri.parse(apiUrl!),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30)); // 添加30秒超时

      // 打印响应
      debugPrint('--- 文本AI响应 (状态码: ${response.statusCode}) ---');
      debugPrint(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)); // 使用utf8解码以支持中文
        final content = data['choices'][0]['message']['content'];
        
        debugPrint('--- 文本AI返回内容 ---');
        debugPrint(content);
        
        try {
          // 使用正则表达式从返回内容中提取纯净的JSON字符串
          final regex = RegExp(r'```json\s*([\s\S]*?)\s*```');
          final match = regex.firstMatch(content);
          
          String jsonString;
          if (match != null) {
            // 如果找到了Markdown代码块，就提取其中的内容
            jsonString = match.group(1)!;
          } else {
            // 如果没有找到，就假定整个内容是JSON（以防万一）
            jsonString = content;
          }

          final Map<String, dynamic> result = jsonDecode(jsonString);
          return result;
        } catch (e) {
          throw Exception('无法解析AI返回的JSON内容: $e');
        }
      } else {
        throw Exception('API请求失败: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('文本AI处理失败: $e'); // 增加错误日志
      return {'status': 'error', 'message': '文本AI处理失败: $e'};
    }
  }

  /// 从处理结果创建支出对象
  Expense? createExpenseFromResult(Map<String, dynamic> result, String originalText) {
    if (result['status'] == 'success') {
      final data = result['data'];
      
      // 优先使用AI返回的日期，如果为空或解析失败，则使用当前日期作为备用
      final finalDate = data['date'] != null
          ? DateTime.tryParse(data['date']) ?? DateTime.now()
          : DateTime.now();

      return Expense(
        title: data['title'] ?? '未命名交易',
        amount: data['amount'] is num ? data['amount'].toDouble() : double.tryParse(data['amount']?.toString() ?? '0') ?? 0,
        date: finalDate,
        type: data['type'] ?? 'expense',
        category: data['category'] ?? '其他',
        description: data['description'],
        voiceRecord: originalText, // 使用原始文本作为记录
        mileage: data['mileage'] is num ? data['mileage'].toDouble() : double.tryParse(data['mileage']?.toString() ?? '0'),
        consumption: data['consumption'] is num ? data['consumption'].toDouble() : double.tryParse(data['consumption']?.toString() ?? '0'),
        vehicleType: data['vehicleType'],
      );
    }
    
    return null;
  }

  /// 获取处理结果的状态消息
  String getStatusMessage(Map<String, dynamic> result) {
    if (result['status'] == 'success') {
      final data = result['data'];
      return '已识别: ${data['title']} - ¥${data['amount']}';
    } else if (result['status'] == 'error' || result['status'] == 'unrelated') {
      return result['message'] ?? '处理失败';
    } else {
      return '未知状态';
    }
  }
}