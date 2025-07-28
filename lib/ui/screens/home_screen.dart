import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../widgets/expense_list.dart';
import '../widgets/voice_input_button.dart';
import '../widgets/manual_model_dialog.dart';
import '../widgets/model_download_choice_dialog.dart';
import '../../services/database_service.dart';
import '../../services/sherpa_model_service.dart';
import '../../models/expense.dart';
import 'add_expense_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'vehicle_expense_screen.dart';

// 1. GetX控制器
class HomeController extends GetxController {
  final DatabaseService _databaseService = DatabaseService();
  
  final isLoading = true.obs;
  final expenses = <Expense>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    isLoading.value = true;

    try {
      expenses.assignAll(await _databaseService.getExpenses());
    } catch (e) {
      Get.snackbar('错误', '加载支出数据失败: $e');
    } finally {
      isLoading.value = false;
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
        .fold(0.0, (sum, e) => sum + e.amount);
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
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get monthlyBalance => monthlyIncome - monthlyExpense;
}

// 2. HomeScreen 使用 GetBuilder
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasCheckedModel = false;

  @override
  void initState() {
    super.initState();
    // 延迟检查模型状态，确保界面完全加载后再弹出对话框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkModelStatus();
    });
  }

  Future<void> _checkModelStatus() async {
    if (_hasCheckedModel) return;
    _hasCheckedModel = true;

    final modelService = Provider.of<SherpaModelService>(context, listen: false);
    
    // 检查模型是否准备好
    final isReady = await modelService.checkModelReady();
    
    if (!isReady && mounted) {
      // 检查是否有手动文件
      final hasManualFile = await modelService.checkManualModelFile();
      
      if (hasManualFile) {
        // 如果有手动文件，自动使用
        await modelService.useManualModelFile();
      } else {
        // 如果没有模型文件，弹出选择对话框
        await ModelDownloadChoiceDialog.showChoiceDialog(
          context,
          modelService,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 将 GetX 作为根组件，以响应式地监听状态变化
    return GetX<HomeController>(
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
                icon: const Icon(Icons.mic),
                onPressed: () => Get.toNamed('/sherpa_test'),
                tooltip: 'Sherpa语音测试',
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
    return Column(
      children: [
        // 模型下载状态显示
        Consumer<SherpaModelService>(
          builder: (context, modelService, child) {
            if (modelService.isDownloading || modelService.isUnzipping) {
              return _buildDownloadStatusCard(modelService);
            } else if (modelService.errorMessage.isNotEmpty) {
              return _buildErrorStatusCard(modelService);
            } else if (!modelService.isModelReady) {
              return _buildModelNotReadyCard(modelService);
            }
            return const SizedBox.shrink();
          },
        ),
        
        // 原有的内容
        Expanded(
          child: _buildMainContent(controller),
        ),
      ],
    );
  }

  Widget _buildMainContent(HomeController controller) {
    if (controller.isLoading.value) {
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

  Widget _buildDownloadStatusCard(SherpaModelService modelService) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.download, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    modelService.isDownloading ? '正在下载语音模型...' : '正在解压语音模型...',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: modelService.isDownloading 
                    ? modelService.progress 
                    : modelService.unzipProgress,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 8),
              Text(
                '${((modelService.isDownloading ? modelService.progress : modelService.unzipProgress) * 100).toStringAsFixed(1)}%',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorStatusCard(SherpaModelService modelService) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text(
                    '语音模型下载失败',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                modelService.errorMessage,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  await modelService.downloadAndPrepareModel();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('重试下载'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelNotReadyCard(SherpaModelService modelService) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text(
                    '语音模型未准备好',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '需要下载语音识别模型才能使用语音记账功能',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              
              // 选择下载方式
              const Text(
                '请选择下载方式：',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              
              // 在线下载按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await modelService.startOnlineDownload();
                  },
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('在线下载（约40-50MB）'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // 手动下载按钮
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: Get.context!,
                      builder: (context) => ManualModelDialog(
                        modelName: "sherpa-onnx-streaming-zipformer-small-ctc-zh-2025-04-01",
                      ),
                    );
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('手动下载（推荐网络较慢时使用）'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 提示信息
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, 
                         color: Colors.blue.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '如果在线下载速度较慢，建议选择手动下载',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
