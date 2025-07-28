import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/config_service.dart';
import '../../services/webdav_service.dart';
import '../../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ConfigService _configService = ConfigService();
  final _speechApiKeyController = TextEditingController();
  final _speechApiUrlController = TextEditingController();
  final _aiApiKeyController = TextEditingController();
  final _aiApiUrlController = TextEditingController();
  final _aiModelController = TextEditingController();
  final _webdavUrlController = TextEditingController();
  final _webdavUsernameController = TextEditingController();
  final _webdavPasswordController = TextEditingController();
  bool _isLoading = true;
  bool _obscureApiKeys = true;
  bool _obscureWebDavPassword = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _configService.initialize();
      
      // 加载语音API配置
      final speechConfig = _configService.getSpeechApiConfig();
      _speechApiKeyController.text = speechConfig['apiKey'] ?? '';
      _speechApiUrlController.text = speechConfig['apiUrl'] ?? '';
      
      // 加载AI API配置
      final aiConfig = _configService.getAiApiConfig();
      _aiApiKeyController.text = aiConfig['apiKey'] ?? '';
      _aiApiUrlController.text = aiConfig['apiUrl'] ?? '';
      _aiModelController.text = aiConfig['model'] ?? '';
      
      // 加载WebDAV配置
      final webdavConfig = _configService.getWebDavConfig();
      _webdavUrlController.text = webdavConfig['url'] ?? '';
      _webdavUsernameController.text = webdavConfig['username'] ?? '';
      _webdavPasswordController.text = webdavConfig['password'] ?? '';
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar('错误', '加载配置失败: $e');
    }
  }

  Future<void> _saveSpeechApiConfig() async {
    try {
      await _configService.setSpeechApiConfig(
        _speechApiKeyController.text,
        _speechApiUrlController.text,
      );
      Get.snackbar('成功', '语音API配置已保存');
    } catch (e) {
      Get.snackbar('错误', '保存语音API配置失败: $e');
    }
  }

  Future<void> _saveAiApiConfig() async {
    try {
      await _configService.setAiApiConfig(
        _aiApiKeyController.text,
        _aiApiUrlController.text,
        _aiModelController.text,
      );
      Get.snackbar('成功', 'AI API配置已保存');
    } catch (e) {
      Get.snackbar('错误', '保存AI API配置失败: $e');
    }
  }

  Future<void> _saveWebDavConfig() async {
    try {
      await _configService.setWebDavConfig(
        _webdavUrlController.text,
        _webdavUsernameController.text,
        _webdavPasswordController.text,
      );
      Get.snackbar('成功', 'WebDAV配置已保存');
    } catch (e) {
      Get.snackbar('错误', '保存WebDAV配置失败: $e');
    }
  }

  Future<void> _testWebDavConnection() async {
    try {
      final webdavService = WebDavService(
        webdavUrl: _webdavUrlController.text,
        username: _webdavUsernameController.text,
        password: _webdavPasswordController.text,
      );
      
      final result = await webdavService.initialize();
      if (result) {
        Get.snackbar('成功', 'WebDAV连接测试成功');
      } else {
        Get.snackbar('错误', 'WebDAV连接测试失败');
      }
    } catch (e) {
      Get.snackbar('错误', 'WebDAV连接测试失败: $e');
    }
  }

  Future<void> _exportData() async {
    try {
      final webdavService = WebDavService(
        webdavUrl: _webdavUrlController.text,
        username: _webdavUsernameController.text,
        password: _webdavPasswordController.text,
      );
      
      await webdavService.initialize();
      
      final databaseService = DatabaseService();
      final expenses = await databaseService.getExpenses();
      
      await webdavService.exportExpenses(expenses);
      
      Get.snackbar('成功', '数据导出成功');
    } catch (e) {
      Get.snackbar('错误', '数据导出失败: $e');
    }
  }

  Future<void> _importData() async {
    try {
      final webdavService = WebDavService(
        webdavUrl: _webdavUrlController.text,
        username: _webdavUsernameController.text,
        password: _webdavPasswordController.text,
      );
      
      await webdavService.initialize();
      
      final expenses = await webdavService.importExpenses();
      
      final databaseService = DatabaseService();
      
      // 清除现有数据
      for (var expense in await databaseService.getExpenses()) {
        await databaseService.deleteExpense(expense.id!);
      }
      
      // 导入新数据
      for (var expense in expenses) {
        await databaseService.insertExpense(expense);
      }
      
      Get.snackbar('成功', '数据导入成功');
    } catch (e) {
      Get.snackbar('错误', '数据导入失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 语音API配置
                  _buildSectionTitle('语音识别API配置'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _speechApiKeyController,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureApiKeys ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _obscureApiKeys = !_obscureApiKeys;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureApiKeys,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _speechApiUrlController,
                    decoration: const InputDecoration(
                      labelText: 'API URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSpeechApiConfig,
                      child: const Text('保存语音API配置'),
                    ),
                  ),
                  const Divider(height: 32),
                  
                  // AI API配置
                  _buildSectionTitle('大模型API配置'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _aiApiKeyController,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureApiKeys ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _obscureApiKeys = !_obscureApiKeys;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureApiKeys,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _aiApiUrlController,
                    decoration: const InputDecoration(
                      labelText: 'API URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _aiModelController,
                    decoration: const InputDecoration(
                      labelText: '模型名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveAiApiConfig,
                      child: const Text('保存大模型API配置'),
                    ),
                  ),
                  const Divider(height: 32),
                  
                  // WebDAV配置
                  _buildSectionTitle('WebDAV配置'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _webdavUrlController,
                    decoration: const InputDecoration(
                      labelText: 'WebDAV URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _webdavUsernameController,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _webdavPasswordController,
                    decoration: InputDecoration(
                      labelText: '密码',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureWebDavPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _obscureWebDavPassword = !_obscureWebDavPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureWebDavPassword,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveWebDavConfig,
                          child: const Text('保存WebDAV配置'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _testWebDavConnection,
                          child: const Text('测试连接'),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  
                  // 数据导入导出
                  _buildSectionTitle('数据同步'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _exportData,
                          child: const Text('导出数据'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _importData,
                          child: const Text('导入数据'),
                        ),
                      ),
                    ],
                  ),
                  
                  const Divider(height: 32),
                  
                  // 测试功能
                  _buildSectionTitle('测试功能'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Get.toNamed('/sherpa_test'),
                          child: const Text('语音识别测试'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Get.toNamed('/text_input_test'),
                          child: const Text('文本输入测试'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  void dispose() {
    _speechApiKeyController.dispose();
    _speechApiUrlController.dispose();
    _aiApiKeyController.dispose();
    _aiApiUrlController.dispose();
    _aiModelController.dispose();
    _webdavUrlController.dispose();
    _webdavUsernameController.dispose();
    _webdavPasswordController.dispose();
    super.dispose();
  }
}