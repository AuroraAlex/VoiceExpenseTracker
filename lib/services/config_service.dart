import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  factory ConfigService() {
    return _instance;
  }

  ConfigService._internal();

  // 初始化配置服务
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // 加载.env文件
    await dotenv.load();
    
    // 初始化SharedPreferences
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  // 获取语音API配置
  Map<String, String?> getSpeechApiConfig() {
    return {
      'apiKey': _prefs.getString('speech_api_key') ?? dotenv.env['SPEECH_API_KEY'],
      'apiUrl': _prefs.getString('speech_api_url') ?? dotenv.env['SPEECH_API_URL'],
    };
  }

  // 设置语音API配置
  Future<void> setSpeechApiConfig(String apiKey, String apiUrl) async {
    await _prefs.setString('speech_api_key', apiKey);
    await _prefs.setString('speech_api_url', apiUrl);
  }

  // 获取AI API配置
  Map<String, String?> getAiApiConfig() {
    return {
      'apiKey': _prefs.getString('ai_api_key') ?? dotenv.env['AI_API_KEY'],
      'apiUrl': _prefs.getString('ai_api_url') ?? dotenv.env['AI_API_URL'],
      'model': _prefs.getString('ai_model') ?? dotenv.env['AI_MODEL'] ?? 'gpt-3.5-turbo', // 提供一个默认模型
    };
  }

  // 设置AI API配置
  Future<void> setAiApiConfig(String apiKey, String apiUrl, String model) async {
    await _prefs.setString('ai_api_key', apiKey);
    await _prefs.setString('ai_api_url', apiUrl);
    await _prefs.setString('ai_model', model);
  }

  // 获取WebDAV配置
  Map<String, String?> getWebDavConfig() {
    return {
      'url': _prefs.getString('webdav_url') ?? dotenv.env['WEBDAV_URL'],
      'username': _prefs.getString('webdav_username') ?? dotenv.env['WEBDAV_USERNAME'],
      'password': _prefs.getString('webdav_password') ?? dotenv.env['WEBDAV_PASSWORD'],
    };
  }

  // 设置WebDAV配置
  Future<void> setWebDavConfig(String url, String username, String password) async {
    await _prefs.setString('webdav_url', url);
    await _prefs.setString('webdav_username', username);
    await _prefs.setString('webdav_password', password);
  }

  // 清除所有配置
  Future<void> clearAllConfig() async {
    await _prefs.clear();
  }

  // 检查配置是否完整
  bool isSpeechApiConfigured() {
    final config = getSpeechApiConfig();
    return config['apiKey'] != null && config['apiKey']!.isNotEmpty &&
           config['apiUrl'] != null && config['apiUrl']!.isNotEmpty;
  }

  bool isAiApiConfigured() {
    final config = getAiApiConfig();
    return config['apiKey'] != null && config['apiKey']!.isNotEmpty &&
           config['apiUrl'] != null && config['apiUrl']!.isNotEmpty;
  }

  bool isWebDavConfigured() {
    final config = getWebDavConfig();
    return config['url'] != null && config['url']!.isNotEmpty &&
           config['username'] != null && config['username']!.isNotEmpty &&
           config['password'] != null && config['password']!.isNotEmpty;
  }
}