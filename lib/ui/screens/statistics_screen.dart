import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import '../../services/database_service.dart';
import '../../services/ai_agent_service.dart';
import '../../services/config_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final ConfigService _configService = ConfigService();
  List<Expense> _expenses = [];
  bool _isLoading = true;
  bool _isGeneratingReport = false;
  String _aiReport = '';
  
  // 统计数据
  double _totalExpense = 0;
  Map<String, double> _categoryExpenses = {};
  Map<DateTime, double> _dailyExpenses = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _configService.initialize();
      final expenses = await _databaseService.getExpenses();
      
      setState(() {
        _expenses = expenses;
        _calculateStatistics();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar('错误', '加载数据失败: $e');
    }
  }

  void _calculateStatistics() {
    _totalExpense = 0;
    _categoryExpenses = {};
    _dailyExpenses = {};
    
    for (var expense in _expenses) {
      // 计算总支出
      _totalExpense += expense.amount;
      
      // 按分类统计
      if (_categoryExpenses.containsKey(expense.category)) {
        _categoryExpenses[expense.category] = _categoryExpenses[expense.category]! + expense.amount;
      } else {
        _categoryExpenses[expense.category] = expense.amount;
      }
      
      // 按日期统计
      final date = DateTime(expense.date.year, expense.date.month, expense.date.day);
      if (_dailyExpenses.containsKey(date)) {
        _dailyExpenses[date] = _dailyExpenses[date]! + expense.amount;
      } else {
        _dailyExpenses[date] = expense.amount;
      }
    }
  }

  Future<void> _generateAIReport() async {
    if (_expenses.isEmpty) {
      Get.snackbar('提示', '没有支出数据可供分析');
      return;
    }

    setState(() {
      _isGeneratingReport = true;
    });

    try {
      // 使用AIAgentService替代AIService
      final aiService = AIAgentService.fromConfig();
      
      final report = await aiService.generateExpenseReport(_expenses);
      
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('支出统计'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bar_chart, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('暂无支出数据', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text('添加一些支出后再来查看统计', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      _buildCategoryChart(),
                      const SizedBox(height: 16),
                      _buildTimeChart(),
                      const SizedBox(height: 24),
                      _buildAIReportSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '支出摘要',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('总支出'),
                Text(
                  '¥${_totalExpense.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('记录数量'),
                Text(
                  '${_expenses.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (_expenses.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('平均每笔'),
                  Text(
                    '¥${(_totalExpense / _expenses.length).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '分类统计',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: _categoryExpenses.isEmpty
                  ? const Center(child: Text('暂无分类数据'))
                  : PieChart(
                      PieChartData(
                        sections: _getCategorySections(),
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Column(
              children: _categoryExpenses.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getCategoryColor(entry.key),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(entry.key),
                        ],
                      ),
                      Text(
                        '¥${entry.value.toStringAsFixed(2)} (${(entry.value / _totalExpense * 100).toStringAsFixed(1)}%)',
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _getCategorySections() {
    return _categoryExpenses.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value,
        title: '${(entry.value / _totalExpense * 100).toStringAsFixed(1)}%',
        color: _getCategoryColor(entry.key),
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Color _getCategoryColor(String category) {
    final colors = {
      '餐饮': Colors.red,
      '购物': Colors.orange,
      '交通': Colors.blue,
      '住宿': Colors.green,
      '娱乐': Colors.purple,
      '医疗': Colors.pink,
      '教育': Colors.indigo,
      '旅行': Colors.cyan,
      '汽车': Colors.blueGrey,
      '其他': Colors.grey,
    };
    
    return colors[category] ?? Colors.grey;
  }

  Widget _buildTimeChart() {
    // 对日期进行排序
    final sortedDates = _dailyExpenses.keys.toList()
      ..sort((a, b) => a.compareTo(b));
    
    if (sortedDates.isEmpty) {
      return const SizedBox();
    }
    
    // 获取最早和最晚的日期
    final firstDate = sortedDates.first;
    final lastDate = sortedDates.last;
    
    // 创建完整的日期范围
    final allDates = <DateTime>[];
    for (var date = firstDate;
         date.isBefore(lastDate) || date.isAtSameMomentAs(lastDate);
         date = date.add(const Duration(days: 1))) {
      allDates.add(date);
    }
    
    // 创建图表数据
    final spots = allDates.map((date) {
      final amount = _dailyExpenses[date] ?? 0.0;
      final x = date.difference(firstDate).inDays.toDouble();
      return FlSpot(x, amount);
    }).toList();
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '时间趋势',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('¥${value.toInt()}');
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final date = firstDate.add(Duration(days: value.toInt()));
                          if (allDates.length <= 7 || 
                              value.toInt() % (allDates.length ~/ 5) == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(DateFormat('MM/dd').format(date)),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIReportSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'AI分析报告',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: _isGeneratingReport ? null : _generateAIReport,
                  child: _isGeneratingReport
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('生成报告'),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _aiReport.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('点击"生成报告"按钮获取AI分析'),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(_aiReport),
                  ),
          ],
        ),
      ),
    );
  }
}