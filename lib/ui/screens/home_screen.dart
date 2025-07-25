import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/expense_list.dart';
import '../widgets/voice_input_button.dart';
import '../../services/database_service.dart';
import '../../models/expense.dart';
import 'add_expense_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'vehicle_expense_screen.dart';

// 1. GetX控制器
class HomeController extends GetxController {
  final DatabaseService _databaseService = DatabaseService();
  
  bool isLoading = true;
  List<Expense> expenses = [];

  @override
  void onInit() {
    super.onInit();
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    isLoading = true;
    update(); // 通知UI开始加载

    try {
      expenses = await _databaseService.getExpenses();
    } catch (e) {
      Get.snackbar('错误', '加载支出数据失败: $e');
    } finally {
      isLoading = false;
      update(); // 通知UI加载完成
    }
  }

  Future<void> addExpense(Expense expense) async {
    await _databaseService.insertExpense(expense);
    loadExpenses();
  }

  Future<void> deleteExpense(int id) async {
    await _databaseService.deleteExpense(id);
    loadExpenses();
  }

  double get monthlyExpense {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final firstDayOfNextMonth = DateTime(now.year, now.month + 1, 1);
    
    return expenses
        .where((e) => 
            e.type == 'expense' && 
            !e.date.isBefore(firstDayOfMonth) && 
            e.date.isBefore(firstDayOfNextMonth))
        .fold(0, (sum, e) => sum + e.amount);
  }

  double get monthlyIncome {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final firstDayOfNextMonth = DateTime(now.year, now.month + 1, 1);
    
    return expenses
        .where((e) => 
            e.type == 'income' && 
            !e.date.isBefore(firstDayOfMonth) && 
            e.date.isBefore(firstDayOfNextMonth))
        .fold(0, (sum, e) => sum + e.amount);
  }

  double get monthlyBalance => monthlyIncome - monthlyExpense;
}

// 2. HomeScreen 使用 GetBuilder
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 将 GetBuilder 作为根组件，确保 controller 在整个 Scaffold 中都可用
    return GetBuilder<HomeController>(
      init: HomeController(), // 正确初始化控制器
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('语音记账'),
            elevation: 0,
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.bar_chart),
                onPressed: () => Get.to(() => const StatisticsScreen()),
                tooltip: '统计分析',
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Get.to(() => const SettingsScreen()),
                tooltip: '设置',
              ),
            ],
          ),
          body: _buildBody(controller), // 使用辅助方法构建 body
          floatingActionButton: _buildFloatingActionButtons(controller), // 将 controller 传递下去
        );
      },
    );
  }

  // Body 的构建逻辑
  Widget _buildBody(HomeController controller) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.expenses.isEmpty) {
      return _buildEmptyState(controller);
    }

    return Column(
      children: [
        _buildSummaryCard(controller),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.loadExpenses,
            child: ExpenseList(
              expenses: controller.expenses,
              onDelete: (expense) async {
                await controller.deleteExpense(expense.id!);
              },
              onEdit: (expense) {
                Get.to(() => AddExpenseScreen(expense: expense))
                    ?.then((_) => controller.loadExpenses());
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(HomeController controller) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBalanceInfo('本月结余', '¥${controller.monthlyBalance.toStringAsFixed(2)}', Colors.blue, isTotal: true),
              const Spacer(),
              _buildBalanceInfo('本月支出', '¥${controller.monthlyExpense.toStringAsFixed(2)}', Colors.red, icon: Icons.arrow_downward),
              const SizedBox(width: 24),
              _buildBalanceInfo('本月收入', '¥${controller.monthlyIncome.toStringAsFixed(2)}', Colors.green, icon: Icons.arrow_upward),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceInfo(String label, String amount, Color color, {IconData? icon, bool isTotal = false}) {
    return Column(
      crossAxisAlignment: isTotal ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            if (icon != null) ...[Icon(icon, color: color, size: 16), const SizedBox(width: 4)],
            Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        if (isTotal) const SizedBox(height: 4),
        Text(amount, style: TextStyle(fontSize: isTotal ? 24 : 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildEmptyState(HomeController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long, size: 80, color: Colors.blue),
          ),
          const SizedBox(height: 24),
          const Text('暂无交易记录', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('点击下方按钮添加交易', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Get.to(() => const AddExpenseScreen())?.then((_) => controller.loadExpenses()),
            icon: const Icon(Icons.add),
            label: const Text('手动添加'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons(HomeController controller) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: 'vehicle',
          onPressed: () => Get.to(() => const VehicleExpenseScreen())?.then((_) => controller.loadExpenses()),
          backgroundColor: Colors.blue,
          tooltip: '车辆支出',
          child: const Icon(Icons.directions_car),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'add',
          onPressed: () => Get.to(() => const AddExpenseScreen())?.then((_) => controller.loadExpenses()),
          backgroundColor: Colors.green,
          tooltip: '手动添加',
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: 16),
        VoiceInputButton(
          onVoiceProcessed: (expense) {
            controller.addExpense(expense);
          },
        ),
      ],
    );
  }
}
