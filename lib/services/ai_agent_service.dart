import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/expense.dart';
import '../models/category.dart';
import 'config_service.dart';
import '../utils/ai_prompts.dart';

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

  // 处理语音或文本输入，提取记账信息
  Future<Map<String, dynamic>> processRecordInput(String inputText) async {
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
            'content': inputText
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
        voiceRecord: originalVoiceText,
        createdAt: DateTime.now(), // 添加创建时间戳
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
  
  // 分析支出数据并生成报告
  Future<String> generateExpenseReport(List<Expense> expenses) async {
    // 检查网络连接
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception('无网络连接，无法使用AI服务');
    }

    if (apiKey == null || apiUrl == null || model == null) {
      throw Exception('API配置缺失');
    }

    try {
      // 按月份分组支出数据
      final Map<String, List<Expense>> expensesByMonth = {};
      for (var expense in expenses) {
        final monthKey = '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}';
        if (!expensesByMonth.containsKey(monthKey)) {
          expensesByMonth[monthKey] = [];
        }
        expensesByMonth[monthKey]!.add(expense);
      }

      // 计算每月总支出
      final Map<String, double> monthlyTotals = {};
      expensesByMonth.forEach((month, monthExpenses) {
        monthlyTotals[month] = monthExpenses.fold(0.0, (sum, e) => sum + e.amount);
      });

      // 获取当前月份和上个月份
      final now = DateTime.now();
      final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      // 计算上个月的键
      final lastMonth = now.month == 1 ? DateTime(now.year - 1, 12) : DateTime(now.year, now.month - 1);
      final lastMonthKey = '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}';

      // 将支出数据转换为简单的文本格式
      final expensesText = expenses.map((e) => 
        '日期: ${e.date.toString().substring(0, 10)}, 标题: ${e.title}, 金额: ${e.amount}, 分类: ${e.category}, 类型: ${e.type}'
      ).join('\n');

      // 添加月度比较信息
      String monthlyComparisonText = '';
      if (monthlyTotals.containsKey(currentMonthKey) && monthlyTotals.containsKey(lastMonthKey)) {
        final currentMonthTotal = monthlyTotals[currentMonthKey]!;
        final lastMonthTotal = monthlyTotals[lastMonthKey]!;
        final difference = currentMonthTotal - lastMonthTotal;
        final percentChange = (difference / lastMonthTotal) * 100;
        
        monthlyComparisonText = '''
当前月份: $currentMonthKey, 总支出: ¥${currentMonthTotal.toStringAsFixed(2)}
上个月份: $lastMonthKey, 总支出: ¥${lastMonthTotal.toStringAsFixed(2)}
变化: ¥${difference.toStringAsFixed(2)} (${percentChange.toStringAsFixed(2)}%)
''';
      }

      final systemPrompt = AIPrompts.getExpenseReportPrompt();

      final requestBody = {
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': systemPrompt,
          },
          {
            'role': 'user',
            'content': '''以下是我的支出数据，请帮我分析：
$monthlyComparisonText
详细支出记录：
$expensesText'''
          }
        ],
        'temperature': 0.7,
      };

      // 打印请求体
      debugPrint('--- 报告生成请求 ---');
      debugPrint(jsonEncode(requestBody));

      final response = await http.post(
        Uri.parse(apiUrl!),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 60)); // 增加超时时间，因为报告生成可能需要更长时间

      // 打印响应
      debugPrint('--- 报告生成响应 (状态码: ${response.statusCode}) ---');
      debugPrint(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)); // 使用utf8解码以支持中文
        final content = data['choices'][0]['message']['content'];
        return content;
      } else {
        throw Exception('API请求失败: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('生成报告失败: $e'); // 增加错误日志
      throw Exception('生成报告失败: $e');
    }
  }
  
  // 分析车辆支出数据
  Future<Map<String, dynamic>> analyzeVehicleExpense(String voiceText) async {
    // 检查网络连接
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return {'status': 'error', 'message': '无网络连接，无法使用AI服务'};
    }

    if (apiKey == null || apiUrl == null || model == null) {
      return {'status': 'error', 'message': 'API配置缺失'};
    }

    try {
      final systemPrompt = AIPrompts.getVehicleExpensePrompt();

      final requestBody = {
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': systemPrompt,
          },
          {
            'role': 'user',
            'content': voiceText
          }
        ],
        'temperature': 0.5, // 降低温度以获得更确定的结果
      };

      // 打印请求体
      debugPrint('--- 车辆支出分析请求 ---');
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
      debugPrint('--- 车辆支出分析响应 (状态码: ${response.statusCode}) ---');
      debugPrint(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)); // 使用utf8解码以支持中文
        final content = data['choices'][0]['message']['content'];
        
        debugPrint('--- 车辆支出分析返回内容 ---');
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
      debugPrint('车辆支出分析失败: $e'); // 增加错误日志
      return {'status': 'error', 'message': '车辆支出分析失败: $e'};
    }
  }
}