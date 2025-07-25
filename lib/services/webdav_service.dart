import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webdav_client/webdav_client.dart';
import 'package:path_provider/path_provider.dart';
import '../models/expense.dart';

class WebDavService {
  late Client _client;
  final String? webdavUrl;
  final String? username;
  final String? password;
  bool _isInitialized = false;

  WebDavService({this.webdavUrl, this.username, this.password});

  // 从环境变量获取WebDAV配置
  factory WebDavService.fromEnv() {
    return WebDavService(
      webdavUrl: dotenv.env['WEBDAV_URL'],
      username: dotenv.env['WEBDAV_USERNAME'],
      password: dotenv.env['WEBDAV_PASSWORD'],
    );
  }

  // 初始化WebDAV客户端
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    if (webdavUrl == null || username == null || password == null) {
      throw Exception('WebDAV配置缺失');
    }

    try {
      _client = newClient(
        webdavUrl!,
        user: username ?? '',
        password: password ?? '',
        debug: false,
      );
      
      // 测试连接
      await _client.ping();
      _isInitialized = true;
      return true;
    } catch (e) {
      throw Exception('WebDAV初始化失败: $e');
    }
  }

  // 导出支出数据到WebDAV
  Future<void> exportExpenses(List<Expense> expenses) async {
    if (!_isInitialized) await initialize();

    try {
      // 将支出数据转换为JSON
      final jsonData = jsonEncode(expenses.map((e) => e.toJson()).toList());
      
      // 创建临时文件
      final tempDir = await getTemporaryDirectory();
      final tempFile = io.File('${tempDir.path}/expenses.json');
      await tempFile.writeAsString(jsonData);
      
      // 上传到WebDAV
      await _client.writeFromFile(
        tempFile.path,
        '/expenses.json',
        onProgress: (count, total) {
          print('上传进度: $count / $total');
        },
      );
      
      // 删除临时文件
      await tempFile.delete();
    } catch (e) {
      throw Exception('导出支出数据失败: $e');
    }
  }

  // 从WebDAV导入支出数据
  Future<List<Expense>> importExpenses() async {
    if (!_isInitialized) await initialize();

    try {
      // 创建临时文件
      final tempDir = await getTemporaryDirectory();
      final tempFile = io.File('${tempDir.path}/expenses.json');
      
      // 从WebDAV下载
      final content = await _client.read('/expenses.json');
      await tempFile.writeAsBytes(content);
      
      // 读取JSON数据
      final jsonData = await tempFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonData);
      
      // 转换为支出对象
      final expenses = jsonList.map((json) => Expense.fromJson(json)).toList();
      
      // 删除临时文件
      await tempFile.delete();
      
      return expenses;
    } catch (e) {
      throw Exception('导入支出数据失败: $e');
    }
  }
}