import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models/expense.dart';
import '../../services/database_service.dart';
import '../../services/ai_agent_service.dart';
import '../widgets/vehicle_metric_card.dart';
import '../widgets/vehicle_efficiency_chart.dart';
import '../widgets/expense_list.dart';

class VehicleExpenseDetailScreen extends StatefulWidget {
  const VehicleExpenseDetailScreen({Key? key}) : super(key: key);

  @override
  State<VehicleExpenseDetailScreen> createState() => _VehicleExpenseDetailScreenState();
}

class _VehicleExpenseDetailScreenState extends State<VehicleExpenseDetailScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Expense> _vehicleExpenses = [];
  bool _isLoading = true;
  bool _isGeneratingReport = false;
  String _aiReport = '';
  
  // 统计数据
  double _totalMileage = 0;
  double _avgFuelEfficiency = 0;
  double _avgFuelConsumption = 0; // 百公里油/电耗（L或°/100km）
  double _totalFuelExpense = 0;
  double _userAdjustedFuelExpense = 0; // 用户自定校准的油/电费支出
  
  // 显示模式切换
  bool _showConsumption = false; // 默认显示百公里油/电费，true时显示百公里油/电耗
  
  // 周期选择
  String _selectedPeriod = '月'; // 默认按月统计
  final List<String> _periods = ['周', '月', '季', '年'];
  
  // 子分类过滤
  String? _selectedSubtype;
  final List<String> _subtypes = ['全部', '油/电耗', '汽车'];

  @override
  void initState() {
    super.initState();
    _loadVehicleExpenses();
  }

  Future<void> _loadVehicleExpenses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 从主数据源筛选车辆支出
      final allExpenses = await _databaseService.getExpenses();
      final vehicleExpenses = allExpenses.where((e) => 
        e.category == '汽车' || e.category == '油/电耗').toList();
      
      setState(() {
        _vehicleExpenses = vehicleExpenses;
        _calculateStatistics();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar('错误', '加载车辆支出数据失败: $e');
    }
  }

  void _calculateStatistics() {
    // 重置统计数据
    _avgFuelEfficiency = 0;
    _avgFuelConsumption = 0;
    _totalFuelExpense = 0;
    
    // 筛选当前周期内的支出
    final filteredExpenses = _filterExpensesByPeriod(_vehicleExpenses, _selectedPeriod);
    
    // 计算表显里程 - 找到最近一条有里程记录的数据
    final mileageExpenses = _vehicleExpenses.where((e) => e.mileage != null).toList();
    if (mileageExpenses.isNotEmpty) {
      mileageExpenses.sort((a, b) => b.date.compareTo(a.date));
      _totalMileage = mileageExpenses.first.mileage!;
    }
    
    // 计算油/电费总支出
    final allFuelExpenses = filteredExpenses.where((e) => 
      e.category == '油/电耗' || e.expenseSubtype == '油/电耗').toList();
    _totalFuelExpense = allFuelExpenses.fold(0.0, (sum, e) => sum + e.amount);
    
    // 加载用户自定校准的油/电费支出
    _loadUserAdjustedFuelExpense();
    
    // --- 开始计算统计指标 ---
    final allMileageRecords = _vehicleExpenses
        .where((e) => e.mileage != null && e.mileage! > 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // --- 1. 计算累计百公里油/电费 ---
    if (allMileageRecords.length >= 2) {
      final firstRecord = allMileageRecords.first;
      final lastRecord = allMileageRecords.last;
      final totalDistance = lastRecord.mileage! - firstRecord.mileage!;

      if (totalDistance > 0) {
        final periodFuelExpenses = _vehicleExpenses.where((e) =>
            (e.category == '油/电耗' || e.expenseSubtype == '油/电耗') &&
            !e.date.isBefore(firstRecord.date) &&
            !e.date.isAfter(lastRecord.date));
        final totalPeriodCost = periodFuelExpenses.fold(0.0, (sum, e) => sum + e.amount);

        if (totalPeriodCost > 0) {
          _avgFuelEfficiency = (totalPeriodCost / totalDistance) * 100;
          print("--- 指标卡 百公里油/电费 计算 (精确) ---");
          print("总行驶里程: ${lastRecord.mileage} - ${firstRecord.mileage} = $totalDistance km");
          print("期间总费用: $totalPeriodCost 元");
          print("【计算公式】累计百公里油/电费 = (期间总费用 / 总行驶里程) * 100 = ($totalPeriodCost / $totalDistance) * 100 = $_avgFuelEfficiency ¥/100km");
        }
      }
    } else if (allMileageRecords.length == 1) {
      final record = allMileageRecords.first;
      final mileageValue = record.mileage!;
      // 查找此里程记录之后的所有费用
      final periodFuelExpenses = _vehicleExpenses.where((e) =>
          (e.category == '油/电耗' || e.expenseSubtype == '油/电耗') &&
          !e.date.isBefore(record.date));
      final totalPeriodCost = periodFuelExpenses.fold(0.0, (sum, e) => sum + e.amount);

      if (mileageValue > 0 && totalPeriodCost > 0) {
        _avgFuelEfficiency = (totalPeriodCost / mileageValue) * 100;
        print("--- 指标卡 百公里油/电费 计算 (估算) ---");
        print("警告: 只有一个里程记录，基于该记录的总里程进行估算。");
        print("总里程: $mileageValue km");
        print("期间总费用: $totalPeriodCost 元");
        print("【计算公式】估算百公里油/电费 = (期间总费用 / 总里程) * 100 = ($totalPeriodCost / $mileageValue) * 100 = $_avgFuelEfficiency ¥/100km");
      }
    }

    // --- 2. 计算平均百公里油/电耗 ---
    if (allMileageRecords.length >= 2) {
      final List<double> consumptionCalculations = [];
      final fuelConsumptionRecords = _vehicleExpenses.where((e) => e.consumption != null && e.consumption! > 0).toList();

      for (int i = 1; i < allMileageRecords.length; i++) {
        final current = allMileageRecords[i];
        final previous = allMileageRecords[i - 1];
        final distanceSegment = current.mileage! - previous.mileage!;

        if (distanceSegment > 0) {
          final consumptionExpenses = fuelConsumptionRecords.where((e) =>
              !e.date.isBefore(previous.date) &&
              e.date.isBefore(current.date)
          ).toList();

          if (consumptionExpenses.isNotEmpty) {
            final totalSegmentConsumption = consumptionExpenses.fold(0.0, (sum, e) => sum + e.consumption!);
            final consumptionPer100km = (totalSegmentConsumption / distanceSegment) * 100;
            consumptionCalculations.add(consumptionPer100km);
            print("--- 指标卡 百公里油/电耗 计算点 ---");
            print("里程段: ${current.mileage} - ${previous.mileage} = $distanceSegment km");
            print("找到里程段内的总消耗量: $totalSegmentConsumption L/度");
            print("【计算公式】百公里油/电耗 = (里程段内总消耗量 / 里程差) * 100 = ($totalSegmentConsumption / $distanceSegment) * 100 = $consumptionPer100km L/100km");
          }
        }
      }

      if (consumptionCalculations.isNotEmpty) {
        _avgFuelConsumption = consumptionCalculations.reduce((a, b) => a + b) / consumptionCalculations.length;
        print("平均百公里油/电耗: $_avgFuelConsumption L/100km (基于 ${consumptionCalculations.length} 个计算点)");
      }
    }
    
    // --- 3. 备用计算 ---
    if (_avgFuelConsumption == 0 && _avgFuelEfficiency > 0) {
      _avgFuelConsumption = _avgFuelEfficiency / 7.0; // 估算
      print("警告: 未能精确计算百公里油/电耗，使用估算值: $_avgFuelConsumption L/100km");
    }
  }
  
  // 加载用户自定校准的油/电费支出
  Future<void> _loadUserAdjustedFuelExpense() async {
    try {
      final allExpenses = await _databaseService.getExpenses();
      final adjustmentExpenses = allExpenses.where((e) => 
        e.category == '油/电耗' && e.expenseSubtype == '校准').toList();
      
      if (adjustmentExpenses.isNotEmpty) {
        // 获取最新的校准记录
        final latestAdjustment = adjustmentExpenses.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
        setState(() {
          _userAdjustedFuelExpense = latestAdjustment.amount;
          _totalFuelExpense += _userAdjustedFuelExpense;
        });
      }
    } catch (e) {
      print('加载用户调整的油/电费支出失败: $e');
    }
  }

  List<Expense> _filterExpensesByPeriod(List<Expense> expenses, String period) {
    final now = DateTime.now();
    DateTime startDate;
    
    switch (period) {
      case '周':
        // 计算本周的开始日期（周一）
        final weekday = now.weekday;
        startDate = now.subtract(Duration(days: weekday - 1));
        break;
      case '月':
        // 本月的开始日期
        startDate = DateTime(now.year, now.month, 1);
        break;
      case '季':
        // 本季度的开始日期
        final quarter = (now.month - 1) ~/ 3;
        startDate = DateTime(now.year, quarter * 3 + 1, 1);
        break;
      case '年':
        // 本年的开始日期
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
    }
    
    // 只保留开始日期之后的支出
    return expenses.where((e) => !e.date.isBefore(startDate)).toList();
  }

  List<Expense> _filterExpensesBySubtype(List<Expense> expenses, String? subtype) {
    if (subtype == null || subtype == '全部') {
      return expenses;
    }
    
    if (subtype == '油/电耗') {
      return expenses.where((e) => e.category == '油/电耗').toList();
    } else if (subtype == '汽车') {
      return expenses.where((e) => e.category == '汽车').toList();
    }
    
    return expenses;
  }

  Future<void> _generateAIReport() async {
    if (_vehicleExpenses.isEmpty) {
      Get.snackbar('提示', '没有车辆支出数据可供分析');
      return;
    }

    setState(() {
      _isGeneratingReport = true;
    });

    try {
      final aiService = AIAgentService.fromConfig();
      
      // 筛选当前周期内的支出
      final filteredExpenses = _filterExpensesByPeriod(_vehicleExpenses, _selectedPeriod);
      
      final report = await aiService.generateExpenseReport(filteredExpenses);
      
      setState(() {
        _aiReport = report;
        _isGeneratingReport = false;
      });
    } catch (e) {
      setState(() {
        _isGeneratingReport = false;
      });
      Get.snackbar('错误', '生成AI报告失败: $e');
    }
  }

  void _showAdjustFuelExpenseDialog() {
    final statisticalExpenseController = TextEditingController();
    final userAdjustmentController = TextEditingController(text: _userAdjustedFuelExpense.toString());
    
    // 计算统计的油/电费支出（不包括用户调整部分）
    final filteredExpenses = _filterExpensesByPeriod(_vehicleExpenses, _selectedPeriod);
    final fuelExpenses = filteredExpenses.where((e) => e.category == '油/电耗').toList();
    final statisticalExpense = fuelExpenses.fold(0.0, (sum, e) => sum + e.amount);
    
    statisticalExpenseController.text = statisticalExpense.toString();
    
    Get.dialog(
      AlertDialog(
        title: const Text('调整油/电费支出'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: statisticalExpenseController,
              enabled: false, // 统计的费用不能编辑
              decoration: const InputDecoration(
                labelText: '统计的油/电费支出',
                suffixText: '¥',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: userAdjustmentController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '自定校准费用',
                suffixText: '¥',
                border: OutlineInputBorder(),
                helperText: '用于添加未记录的费用',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final newValue = double.tryParse(userAdjustmentController.text);
              if (newValue != null) {
                // 立即更新UI
                setState(() {
                  _userAdjustedFuelExpense = newValue;
                  _calculateStatistics(); // 重新计算统计数据
                });
                
                // 保存到本地存储
                _saveUserAdjustedFuelExpense(newValue);
                
                // 关闭对话框
                Get.back();
                
                // 显示成功提示
                Get.snackbar('成功', '油/电费支出已更新', 
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green.withOpacity(0.1),
                  colorText: Colors.green);
              } else {
                Get.snackbar('错误', '请输入有效的数值',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red.withOpacity(0.1),
                  colorText: Colors.red);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
  
  // 保存用户自定校准的油/电费支出
  Future<void> _saveUserAdjustedFuelExpense(double value) async {
    try {
      // 创建一个特殊的记录来保存用户调整的值
      final adjustmentExpense = Expense(
        title: '油/电费用校准',
        amount: value,
        date: DateTime.now(),
        type: 'expense',
        category: '油/电耗',
        description: '用户手动校准的油/电费用',
        expenseSubtype: '校准',
      );
      
      // 查找是否已有校准记录
      final allExpenses = await _databaseService.getExpenses();
      final adjustmentExpenses = allExpenses.where((e) => 
        e.category == '油/电耗' && e.expenseSubtype == '校准').toList();
      
      if (adjustmentExpenses.isNotEmpty) {
        // 更新现有记录
        final latestAdjustment = adjustmentExpenses.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
        final updatedExpense = latestAdjustment.copyWith(amount: value, date: DateTime.now());
        await _databaseService.updateExpense(updatedExpense);
      } else {
        // 创建新记录
        await _databaseService.insertExpense(adjustmentExpense);
      }
    } catch (e) {
      print('保存用户调整的油/电费支出失败: $e');
    }
  }

  void _showEditDialog(String title, double? value, String unit, Function(double) onSave) {
    final controller = TextEditingController(text: value?.toString() ?? '');
    
    Get.dialog(
      AlertDialog(
        title: Text('编辑$title'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: title,
            suffixText: unit,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final newValue = double.tryParse(controller.text);
              if (newValue != null) {
                // 立即更新UI
                setState(() {
                  if (title == '表显里程') {
                    _totalMileage = newValue;
                  } else if (title == '百公里油/电耗') {
                    _avgFuelEfficiency = newValue;
                  } else if (title == '油/电费支出') {
                    _totalFuelExpense = newValue;
                  }
                });
                
                // 保存数据
                onSave(newValue);
                
                // 关闭对话框
                Get.back();
                
                // 显示成功提示
                Get.snackbar('成功', '$title已更新', 
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green.withOpacity(0.1),
                  colorText: Colors.green);
                  
                // 刷新数据
                _loadVehicleExpenses();
              } else {
                Get.snackbar('错误', '请输入有效的数值',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red.withOpacity(0.1),
                  colorText: Colors.red);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('车辆支出详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _isGeneratingReport ? null : _generateAIReport,
            tooltip: 'AI分析',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vehicleExpenses.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadVehicleExpenses,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetricsSection(),
                        _buildPeriodSelector(),
                        _buildEfficiencyChart(),
                        _buildExpenseListSection(),
                        if (_aiReport.isNotEmpty) _buildAIReportSection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.directions_car, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('暂无车辆支出记录', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          const Text('通过语音或手动添加"汽车"或"油/电耗"分类的支出', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          VehicleMetricCard(
            title: '表显里程',
            value: _totalMileage,
            unit: 'km',
            icon: Icons.speed,
            color: Colors.blue,
            onLongPress: () => _showEditDialog('表显里程', _totalMileage, 'km', (value) async {
              // 立即更新UI
              setState(() {
                _totalMileage = value;
              });
              
              // 获取当前表显里程作为上一次里程
              double previousMileage = _totalMileage;
              
              // 更新最新的里程记录
              if (_vehicleExpenses.isNotEmpty) {
                try {
                  // 查找最新的里程记录
                  final mileageRecords = _vehicleExpenses
                      .where((e) => e.mileage != null)
                      .toList();
                  
                  if (mileageRecords.isNotEmpty) {
                    // 优先使用有更新时间的记录
                    final userUpdatedMileages = mileageRecords
                        .where((e) => e.mileageUpdateTime != null)
                        .toList();
                    
                    if (userUpdatedMileages.isNotEmpty) {
                      userUpdatedMileages.sort((a, b) => 
                          b.mileageUpdateTime!.compareTo(a.mileageUpdateTime!));
                      previousMileage = userUpdatedMileages.first.mileage!;
                    } else {
                      // 如果没有用户更新记录，使用最新的里程记录
                      mileageRecords.sort((a, b) => b.date.compareTo(a.date));
                      previousMileage = mileageRecords.first.mileage!;
                    }
                  }
                  
                  // 创建新的里程记录
                  final newExpense = Expense(
                    title: '里程更新',
                    amount: 0,
                    date: DateTime.now(),
                    type: 'expense',
                    category: '汽车',
                    mileage: value,
                    previousMileage: previousMileage,
                    mileageUpdateTime: DateTime.now()
                  );
                  await _databaseService.insertExpense(newExpense);
                  
                  print('里程更新: 当前=${value}, 上一次=${previousMileage}');
                } catch (e) {
                  print('更新里程记录失败: $e');
                  // 创建新记录
                  final newExpense = Expense(
                    title: '里程记录',
                    amount: 0,
                    date: DateTime.now(),
                    type: 'expense',
                    category: '汽车',
                    mileage: value,
                    previousMileage: previousMileage,
                    mileageUpdateTime: DateTime.now()
                  );
                  await _databaseService.insertExpense(newExpense);
                }
              } else {
                // 如果没有任何记录，创建一个新的记录
                final newExpense = Expense(
                  title: '里程记录',
                  amount: 0,
                  date: DateTime.now(),
                  type: 'expense',
                  category: '汽车',
                  mileage: value,
                  previousMileage: 0, // 第一次记录，上一次里程为0
                  mileageUpdateTime: DateTime.now()
                );
                await _databaseService.insertExpense(newExpense);
              }
              
              // 刷新数据
              _loadVehicleExpenses();
            }),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () {
              setState(() {
                _showConsumption = !_showConsumption;
              });
            },
            child: VehicleMetricCard(
              title: _showConsumption ? '百公里油/电耗' : '百公里油/电费',
              value: _showConsumption ? _avgFuelConsumption : _avgFuelEfficiency,
              unit: _showConsumption ? 'L/100km' : '¥/100km',
              icon: Icons.local_gas_station,
              color: Colors.orange,
              onLongPress: () {
                // 百公里油/电费不能直接编辑，只能通过计算获取
                Get.snackbar(
                  '提示', 
                  '${_showConsumption ? "百公里油/电耗" : "百公里油/电费"}是根据加油/充电费用和里程自动计算的，不能直接编辑。点击可切换显示模式。',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  colorText: Colors.blue
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          VehicleMetricCard(
            title: '油/电费支出',
            value: _totalFuelExpense,
            unit: '¥',
            icon: Icons.attach_money,
            color: Colors.green,
            onLongPress: () => _showAdjustFuelExpenseDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('统计周期：', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Wrap(
            spacing: 8,
            children: _periods.map((period) {
              return ChoiceChip(
                label: Text(period),
                selected: _selectedPeriod == period,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedPeriod = period;
                      _calculateStatistics();
                    });
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 尝试从图表数据中获取百公里油/电费和油/电耗
  void _tryGetEfficiencyFromChartData() {
    // 筛选有油/电耗数据的支出
    final fuelExpenses = _vehicleExpenses
        .where((e) => e.category == '油/电耗' && e.date != null)
        .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    
    // 找出所有有里程记录的支出
    final mileageRecords = _vehicleExpenses
        .where((e) => e.mileage != null)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    // 如果有足够的里程记录，计算百公里油/电费
    if (mileageRecords.length >= 2) {
      double totalEfficiency = 0;
      int count = 0;
      
      for (int i = 1; i < mileageRecords.length; i++) {
        final currentRecord = mileageRecords[i];
        final previousRecord = mileageRecords[i-1];
        
        // 计算里程差
        final distance = currentRecord.mileage! - previousRecord.mileage!;
        
        if (distance > 0) {
          // 找出这段时间内的所有油/电费支出
          final startDate = previousRecord.date;
          final endDate = currentRecord.date;
          
          final periodExpenses = fuelExpenses.where((e) => 
            e.date.isAfter(startDate) && 
            !e.date.isAfter(endDate)).toList();
          
          // 计算总费用
          final totalCost = periodExpenses.fold(0.0, (sum, e) => sum + e.amount);
          
          if (totalCost > 0) {
            // 计算百公里油/电费
            final efficiency = (totalCost / distance) * 100;
            totalEfficiency += efficiency;
            count++;
            
            print('图表计算点: 日期=${currentRecord.date}, 距离=$distance, 费用=$totalCost, 百公里油/电费=$efficiency');
          }
        }
      }
      
      // 计算平均百公里油/电费
      if (count > 0) {
        _avgFuelEfficiency = totalEfficiency / count;
        _avgFuelConsumption = _avgFuelEfficiency / 7.0; // 假设油价7元/L
        print('从图表数据计算的平均百公里油/电费: $_avgFuelEfficiency');
        print('从图表数据计算的平均百公里油/电耗: $_avgFuelConsumption');
      }
    }
    
    // 如果仍然没有计算出百公里油/电费，尝试使用单次支出数据
    if (_avgFuelEfficiency == 0) {
      for (final expense in fuelExpenses) {
        if (expense.fuelEfficiency != null && expense.fuelEfficiency! > 0) {
          _avgFuelEfficiency = expense.fuelEfficiency!;
          print('使用现有油/电耗数据: ${expense.date} - ${expense.fuelEfficiency}');
          break;
        } 
        else if (expense.consumption != null && expense.consumption! > 0 && expense.amount > 0) {
          // 使用单次支出金额和消耗量计算
          _avgFuelEfficiency = (expense.amount / expense.consumption!) * 100;
          print('使用单次支出计算百公里油/电费: $_avgFuelEfficiency');
          break;
        }
      }
    }
    
    // 如果所有方法都失败，但有总费用和总里程，尝试简单计算
    if (_avgFuelEfficiency == 0 && _totalFuelExpense > 0 && _totalMileage > 0) {
      _avgFuelEfficiency = (_totalFuelExpense / _totalMileage) * 100;
      print('使用总费用和总里程计算百公里油/电费: $_avgFuelEfficiency');
    }
  }

  Widget _buildEfficiencyChart() {
    // 筛选有油/电耗数据的支出
    final fuelExpenses = _vehicleExpenses
        .where((e) => e.category == '油/电耗' && e.date != null)
        .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    
    // 为每个支出计算油/电耗
    for (int i = 0; i < fuelExpenses.length; i++) {
      if (fuelExpenses[i].fuelEfficiency == null && i < fuelExpenses.length - 1) {
        if (fuelExpenses[i].consumption != null && 
            fuelExpenses[i].mileage != null && 
            fuelExpenses[i + 1].mileage != null) {
          final distance = fuelExpenses[i].mileage! - fuelExpenses[i + 1].mileage!;
          if (distance > 0) {
            final efficiency = (fuelExpenses[i].consumption! / distance) * 100;
            fuelExpenses[i] = fuelExpenses[i].copyWith(fuelEfficiency: efficiency);
          }
        }
      }
    }
    
    // 只保留有油/电耗数据的支出
    final efficiencyData = fuelExpenses
        .where((e) => e.fuelEfficiency != null || e.consumption != null)
        .toList();
    
    return Container(
      margin: const EdgeInsets.all(16),
      height: 240,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showConsumption = !_showConsumption;
                  });
                },
                child: Text(
                  _showConsumption ? '油/电耗趋势' : '油/电费趋势',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: efficiencyData.isEmpty
                    ? const Center(child: Text('暂无油/电耗数据'))
                    : VehicleEfficiencyChart(
                        expenses: _vehicleExpenses,
                        showConsumption: _showConsumption,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseListSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '支出明细',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _subtypes.map((subtype) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(subtype),
                    selected: _selectedSubtype == subtype,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSubtype = selected ? subtype : null;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          ExpenseList(
            expenses: _filterExpensesBySubtype(_vehicleExpenses, _selectedSubtype),
            onDelete: (expense) async {
              await _databaseService.deleteExpense(expense.id!);
              _loadVehicleExpenses();
            },
            onEdit: (expense) {
              Get.toNamed('/add_expense', arguments: expense)?.then((_) => _loadVehicleExpenses());
            },
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
        ],
      ),
    );
  }

  Widget _buildAIReportSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AI分析报告',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _isGeneratingReport
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _generateAIReport,
                          tooltip: '刷新报告',
                        ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.all(12.0),
                child: MarkdownBody(
                  data: _aiReport,
                  styleSheet: MarkdownStyleSheet(
                    h1: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                    h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    h3: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    p: const TextStyle(fontSize: 14),
                    listBullet: const TextStyle(fontSize: 14),
                    strong: const TextStyle(fontWeight: FontWeight.bold),
                    blockquote: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                    tableBody: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}