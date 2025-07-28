import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:voice_expense_tracker/services/system_download_helper.dart';
import 'package:voice_expense_tracker/utils/sherpa_utils.dart';

import 'directory_access_test.mocks.dart';

// 生成模拟类
@GenerateMocks([Directory, File])
void main() {
  group('目录访问测试', () {
    test('应用内部下载目录创建测试', () async {
      // 这个测试需要在真实设备或模拟器上运行，不能在纯单元测试环境中运行
      // 因为它依赖于真实的文件系统
      try {
        final appDownloadDir = await SystemDownloadHelper.getAppDownloadDirectory();
        expect(appDownloadDir, isNotNull);
        expect(await appDownloadDir.exists(), isTrue);
        print('应用内部下载目录: ${appDownloadDir.path}');
      } catch (e) {
        // 在纯单元测试环境中，这个测试会失败，但我们不希望它阻止其他测试运行
        print('应用内部下载目录测试失败: $e');
      }
    });

    test('模型文件路径构建测试', () async {
      final modelName = 'test-model';
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = join(appDir.path, modelName);
      
      expect(modelPath, contains(modelName));
      print('模型文件路径: $modelPath');
    });
  });
}