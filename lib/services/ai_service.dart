import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/expense.dart';
import '../models/category.dart';

class AIService {
  final String? apiKey;
  final String? apiUrl;

  AIService({this.apiKey, this.apiUrl});

  // 从环境变量获取API配置
  factory AIService.fromEnv() {
    return AIService(
      apiKey: dotenv.env['AI_API_KEY'],
      apiUrl: dotenv.env['AI_API_URL'],
    );
  }

  // 分析语音内容并提取支出信息
  Future<Map<String, dynamic>> analyzeExpenseFromVoice(String voiceText) async {
    if (apiKey == null || apiUrl == null) {
      throw Exception('API配置缺失');
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl!),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': '你是一个财务助手，帮助用户从语音描述中提取支出信息。请提取以下信息：标题、金额、日期（如果没有则使用当前日期）、分类（从以下分类中选择最匹配的一个：餐饮、购物、交通、住宿、娱乐、医疗、教育、旅行、汽车、其他）、描述（可选）。请以JSON格式返回结果。'
            },
            {
              'role': 'user',
              'content': voiceText
            }
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        // 尝试解析AI返回的JSON内容
        try {
          final Map<String, dynamic> expenseData = jsonDecode(content);
          return expenseData;
        } catch (e) {
          throw Exception('无法解析AI返回的内容: $e');
        }
      } else {
        throw Exception('API请求失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('AI分析失败: $e');
    }
  }

  // 分析支出数据并生成报告
  Future<String> generateExpenseReport(List<Expense> expenses) async {
    if (apiKey == null || apiUrl == null) {
      throw Exception('API配置缺失');
    }

    try {
      // 将支出数据转换为简单的文本格式
      final expensesText = expenses.map((e) => 
        '日期: ${e.date.toString().substring(0, 10)}, 标题: ${e.title}, 金额: ${e.amount}, 分类: ${e.category}'
      ).join('\n');

      final response = await http.post(
        Uri.parse(apiUrl!),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': '你是一个财务分析师，帮助用户分析他们的支出数据并提供有用的见解。请分析以下支出数据，并提供一份简短的报告，包括总支出、按分类的支出分布、最大的支出项目、支出趋势以及可能的节省建议。'
            },
            {
              'role': 'user',
              'content': '以下是我的支出数据，请帮我分析：\n$expensesText'
            }
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return content;
      } else {
        throw Exception('API请求失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('生成报告失败: $e');
    }
  }

  // 分析车辆支出数据
  Future<Map<String, dynamic>> analyzeVehicleExpense(String voiceText) async {
    if (apiKey == null || apiUrl == null) {
      throw Exception('API配置缺失');
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl!),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': '你是一个汽车支出分析助手，帮助用户从语音描述中提取车辆支出信息。请提取以下信息：标题、金额、日期（如果没有则使用当前日期）、里程数、消耗量（升/度）、车辆类型（汽油车/电动车）、描述（可选）。请以JSON格式返回结果。'
            },
            {
              'role': 'user',
              'content': voiceText
            }
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        // 尝试解析AI返回的JSON内容
        try {
          final Map<String, dynamic> vehicleData = jsonDecode(content);
          return vehicleData;
        } catch (e) {
          throw Exception('无法解析AI返回的内容: $e');
        }
      } else {
        throw Exception('API请求失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('AI分析失败: $e');
    }
  }
}