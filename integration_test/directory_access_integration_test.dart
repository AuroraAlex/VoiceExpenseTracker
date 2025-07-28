import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart';
// 有条件地导入integration_test包
import 'package:flutter/foundation.dart';
// ignore: unused_import
import 'package:integration_test/integration_test.dart' if (kIsWeb) 'package:flutter_test/flutter_test.dart' as integration;
import 'package:path_provider/path_provider.dart';
import 'package:voice_expense_tracker/services/system_download_helper.dart';
import 'package:voice_expense_tracker/utils/sherpa_utils.dart';

void main() {
  // 有条件地初始化集成测试绑定
  if (!kIsWeb) {
    try {
      integration.IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    } catch (e) {
      print('无法初始化集成测试绑定: $e');
      // 回退到普通的测试绑定
      TestWidgetsFlutterBinding.ensureInitialized();
    }
  } else {
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  group('目录访问集成测试', () {
    testWidgets('应用内部下载目录创建测试', (WidgetTester tester) async {
      // 获取应用内部下载目录
      final appDownloadDir = await SystemDownloadHelper.getAppDownloadDirectory();
      expect(appDownloadDir, isNotNull);
      expect(await appDownloadDir.exists(), isTrue);
      print('应用内部下载目录: ${appDownloadDir.path}');
      
      // 在目录中创建测试文件
      final testFile = File('${appDownloadDir.path}/test_file.txt');
      await testFile.writeAsString('测试内容');
      
      // 验证文件是否创建成功
      expect(await testFile.exists(), isTrue);
      expect(await testFile.readAsString(), equals('测试内容'));
      
      // 清理测试文件
      if (await testFile.exists()) {
        await testFile.delete();
      }
    });

    testWidgets('应用文档目录访问测试', (WidgetTester tester) async {
      // 获取应用文档目录
      final appDocDir = await getApplicationDocumentsDirectory();
      expect(appDocDir, isNotNull);
      expect(await appDocDir.exists(), isTrue);
      print('应用文档目录: ${appDocDir.path}');
      
      // 在目录中创建测试文件
      final testFile = File('${appDocDir.path}/test_file.txt');
      await testFile.writeAsString('测试内容');
      
      // 验证文件是否创建成功
      expect(await testFile.exists(), isTrue);
      expect(await testFile.readAsString(), equals('测试内容'));
      
      // 清理测试文件
      if (await testFile.exists()) {
        await testFile.delete();
      }
    });
    
    testWidgets('sherpa_utils.getAppDownloadDirectory 测试', (WidgetTester tester) async {
      // 测试 sherpa_utils.dart 中的 getAppDownloadDirectory 方法
      final appDownloadDir = await getAppDownloadDirectory();
      expect(appDownloadDir, isNotNull);
      expect(await appDownloadDir.exists(), isTrue);
      print('sherpa_utils.getAppDownloadDirectory: ${appDownloadDir.path}');
      
      // 在目录中创建测试文件
      final testFile = File('${appDownloadDir.path}/test_file.txt');
      await testFile.writeAsString('测试内容');
      
      // 验证文件是否创建成功
      expect(await testFile.exists(), isTrue);
      expect(await testFile.readAsString(), equals('测试内容'));
      
      // 清理测试文件
      if (await testFile.exists()) {
        await testFile.delete();
      }
    });
  });
}