import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart';
// 有条件地导入integration_test包
import 'package:flutter/foundation.dart';
// ignore: unused_import
import 'package:integration_test/integration_test.dart' if (kIsWeb) 'package:flutter_test/flutter_test.dart' as integration;
import 'package:voice_expense_tracker/main.dart' as app;

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

  group('应用启动测试', () {
    testWidgets('应用正常启动', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      
      // 验证应用是否正常启动
      expect(find.byType(MaterialApp), findsOneWidget);
      
      // 等待一段时间，确保应用初始化完成
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      
      // 验证应用是否显示主页面
      expect(find.text('语音记账'), findsOneWidget);
    });
  });
}