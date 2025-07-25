import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import '../../services/database_service.dart';
import '../widgets/expense_list.dart'; // 复用主列表

class VehicleExpenseScreen extends StatefulWidget {
  const VehicleExpenseScreen({Key? key}) : super(key: key);

  @override
  State<VehicleExpenseScreen> createState() => _VehicleExpenseScreenState();
}

class _VehicleExpenseScreenState extends State<VehicleExpenseScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Expense> _vehicleExpenses = [];
  bool _isLoading = true;

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
      final vehicleExpenses = allExpenses.where((e) => e.category == '汽车').toList();
      
      setState(() {
        _vehicleExpenses = vehicleExpenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar('错误', '加载车辆支出数据失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('车辆支出'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: _showEfficiencyChart,
            tooltip: '效率统计',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vehicleExpenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.directions_car, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('暂无车辆支出记录', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text('通过语音或手动添加“汽车”分类的支出', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadVehicleExpenses,
                  // 直接复用主支出列表进行展示
                  child: ExpenseList(
                    expenses: _vehicleExpenses,
                    onDelete: (expense) async {
                      await _databaseService.deleteExpense(expense.id!);
                      _loadVehicleExpenses();
                    },
                    onEdit: (expense) {
                      // 跳转到主编辑页面
                      Get.toNamed('/add_expense', arguments: expense)?.then((_) => _loadVehicleExpenses());
                    },
                  ),
                ),
    );
  }

  void _showEfficiencyChart() {
    if (_vehicleExpenses.isEmpty) {
      Get.snackbar('提示', '暂无车辆支出数据');
      return;
    }

    // 过滤出有消耗量数据的记录用于计算效率
    final validExpenses = _vehicleExpenses.where((e) => e.consumption != null && e.consumption! > 0 && e.mileage != null).toList();

    if (validExpenses.isEmpty) {
      Get.snackbar('提示', '没有足够的效率数据');
      return;
    }

    // 按车辆类型分组
    final gasExpenses = validExpenses.where((e) => e.vehicleType == '汽油车').toList();
    final electricExpenses = validExpenses.where((e) => e.vehicleType == '电动车').toList();
    
    // 计算平均效率
    double avgGasEfficiency = gasExpenses.isNotEmpty ? gasExpenses.map((e) => e.mileage! / e.consumption!).reduce((a, b) => a + b) / gasExpenses.length : 0;
    double avgElectricEfficiency = electricExpenses.isNotEmpty ? electricExpenses.map((e) => e.mileage! / e.consumption!).reduce((a, b) => a + b) / electricExpenses.length : 0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('效率统计'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (gasExpenses.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(Icons.local_gas_station, color: Colors.orange),
                  title: const Text('汽油车平均效率'),
                  subtitle: Text('${avgGasEfficiency.toStringAsFixed(2)} 公里/升'),
                ),
                const Divider(),
              ],
              if (electricExpenses.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(Icons.electric_car, color: Colors.blue),
                  title: const Text('电动车平均效率'),
                  subtitle: Text('${avgElectricEfficiency.toStringAsFixed(2)} 公里/度'),
                ),
                const Divider(),
              ],
              if (validExpenses.isEmpty)
                const Text('没有足够的效率数据可供分析。')
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}