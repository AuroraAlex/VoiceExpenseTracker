import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/expense.dart';
import '../models/category.dart';
import 'config_service.dart';

class AIAgentService {
  final String? apiKey;
  final String? apiUrl;
  final String? model;

  AIAgentService({this.apiKey, this.apiUrl, this.model});

  // 从配置服务获取API配置
  factory AIAgentService.fromConfig() {
    final config = ConfigService().getAiApiConfig();
    return AIAgentService(
      apiKey: config['apiKey'],
      apiUrl: config['apiUrl'],
      model: config['model'],
    );
  }

  // 处理语音识别文本，提取记账信息
  Future<Map<String, dynamic>> processVoiceText(String voiceText) async {
    // 检查网络连接
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return {'status': 'error', 'message': '无网络连接，无法使用AI服务'};
    }

    if (apiKey == null || apiUrl == null || model == null) {
      return {'status': 'error', 'message': 'API配置缺失'};
    }

    try {
      final requestBody = {
        'model': model,
        'messages': [
          {
              'role': 'system',
              'content': '''
你是一个专业的语音记账助手，帮助用户从语音描述中提取交易信息（支出或收入）。
请分析用户的语音输入，并判断是支出还是收入。

如果输入内容包含记账信息，请按以下JSON格式返回：
{
  "status": "success",
  "data": {
    "title": "交易标题",
    "amount": 金额数字,
    "date": "YYYY-MM-DD格式的日期，如果没有则使用当前日期",
    "type": "交易类型，必须是 'expense' (支出) 或 'income' (收入)",
    "category": "分类名称，对于支出，必须从以下选择一个：餐饮、购物、交通、住宿、娱乐、医疗、教育、旅行、汽车、其他。对于收入，分类可以是：工资、奖金、投资、其他收入",
    "description": "可选的详细描述",
    
    // --- 仅当 category 为 '汽车' 时，才需要包含以下字段 ---
    "mileage": "可选，当前总里程数（数字）",
    "consumption": "可选，加油量（升）或充电量（度）",
    "vehicleType": "可选，车辆类型（例如：汽油车, 电动车）"
  }
}

如果输入内容无法识别为记账信息，请返回：
{
  "status": "error",
  "message": "无法识别记账信息，请重新描述您的支出"
}

如果输入内容与记账无关，请返回：
{
  "status": "unrelated",
  "message": "输入内容与记账无关，请描述您的支出信息"
}
'''
          },
          {
            'role': 'user',
            'content': voiceText
          }
        ],
        'temperature': 0.5, // 降低温度以获得更确定的结果
      };

      // 打印请求体
      debugPrint('--- AI 请求 ---');
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
      debugPrint('--- AI 响应 (状态码: ${response.statusCode}) ---');
      debugPrint(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)); // 使用utf8解码以支持中文
        final content = data['choices'][0]['message']['content'];
        
        debugPrint('--- AI 返回内容 ---');
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
      debugPrint('AI处理失败: $e'); // 增加错误日志
      return {'status': 'error', 'message': 'AI处理失败: $e'};
    }
  }

  // 从处理结果创建支出对象
  Expense? createExpenseFromResult(Map<String, dynamic> result, String originalVoiceText) {
    if (result['status'] == 'success') {
      final data = result['data'];
      
      return Expense(
        title: data['title'] ?? '未命名交易',
        amount: data['amount'] is num ? data['amount'].toDouble() : double.tryParse(data['amount']?.toString() ?? '0') ?? 0,
        date: data['date'] != null ? DateTime.tryParse(data['date']) ?? DateTime.now() : DateTime.now(),
        type: data['type'] ?? 'expense',
        category: data['category'] ?? '其他',
        description: data['description'],
        voiceRecord: originalVoiceText,
        mileage: data['mileage'] is num ? data['mileage'].toDouble() : double.tryParse(data['mileage']?.toString() ?? '0'),
        consumption: data['consumption'] is num ? data['consumption'].toDouble() : double.tryParse(data['consumption']?.toString() ?? '0'),
        vehicleType: data['vehicleType'],
      );
    }
    
    return null;
  }

  // 获取处理结果的状态消息
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