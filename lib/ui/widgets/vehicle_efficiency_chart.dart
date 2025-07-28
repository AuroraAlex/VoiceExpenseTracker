import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import 'dart:math';

class VehicleEfficiencyChart extends StatelessWidget {
  final List<Expense> expenses;
  final bool showConsumption; // true: 显示油/电耗, false: 显示油/电费

  const VehicleEfficiencyChart({
    Key? key,
    required this.expenses,
    this.showConsumption = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sortedExpenses = List<Expense>.from(expenses)
      ..sort((a, b) => a.date.compareTo(b.date));

    final spots = <FlSpot>[];
    final dates = <DateTime>[];

    final mileageRecords = sortedExpenses
        .where((e) => e.mileage != null && e.mileage! > 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final fuelCosts = sortedExpenses
        .where((e) => e.category == '油/电耗' || e.expenseSubtype == '油/电耗')
        .toList();

    print("--- 开始计算图表数据 ---");
    print("模式: ${showConsumption ? '百公里油/电耗' : '百公里油/电费'}");
    print("找到 ${mileageRecords.length} 条有效里程记录。");
    print("找到 ${fuelCosts.length} 条油/电费支出记录。");

    if (mileageRecords.length >= 2) {
      for (int i = 1; i < mileageRecords.length; i++) {
        final currentRecord = mileageRecords[i];
        final previousRecord = mileageRecords[i - 1];

        print("\n--- 计算点 ${spots.length + 1} (日期: ${DateFormat('yyyy-MM-dd').format(currentRecord.date)}) ---");

        final distance = currentRecord.mileage! - previousRecord.mileage!;
        if (distance <= 0) {
          print("警告: 里程差为 ${distance}，跳过此计算点。");
          continue;
        }
        print("里程段: ${previousRecord.mileage}km -> ${currentRecord.mileage}km, 里程差: $distance km");

        double? value;

        if (showConsumption) {
          // --- 新的百公里油/电耗计算逻辑 ---
          // 查找这个里程段内的所有消耗量
          final consumptionExpenses = fuelCosts
              .where((e) =>
                  e.consumption != null &&
                  e.consumption! > 0 &&
                  !e.date.isBefore(previousRecord.date) && // >= 上一个点
                  e.date.isBefore(currentRecord.date))     // < 当前点
              .toList();
          
          if (consumptionExpenses.isNotEmpty) {
            final totalSegmentConsumption = consumptionExpenses.fold(0.0, (sum, e) => sum + e.consumption!);
            print("找到里程段内的总消耗量: $totalSegmentConsumption L/度");
            
            value = (totalSegmentConsumption / distance) * 100;
            print("【计算公式】百公里油/电耗 = (里程段内总消耗量 / 里程差) * 100");
            print("= ($totalSegmentConsumption / $distance) * 100 = $value L/100km");
          } else {
            print("警告: 未在里程段 (${DateFormat('yyyy-MM-dd').format(previousRecord.date)} -> ${DateFormat('yyyy-MM-dd').format(currentRecord.date)}) 内找到消耗量数据。");
          }
        } else {
          // --- 累计百公里油/电费 (逻辑不变) ---
          final firstRecord = mileageRecords[0];
          final totalDistance = currentRecord.mileage! - firstRecord.mileage!;
          
          if (totalDistance > 0) {
            final periodExpenses = fuelCosts
                .where((e) =>
                    !e.date.isBefore(firstRecord.date) &&
                    !e.date.isAfter(currentRecord.date))
                .toList();
            
            final totalCost = periodExpenses.fold(0.0, (sum, e) => sum + e.amount);
            
            print("总行驶里程: ${currentRecord.mileage} - ${firstRecord.mileage} = $totalDistance km");
            print("期间总油/电费: $totalCost 元 (从 ${DateFormat('yyyy-MM-dd').format(firstRecord.date)} 到 ${DateFormat('yyyy-MM-dd').format(currentRecord.date)})");

            if (totalCost > 0) {
              value = (totalCost / totalDistance) * 100;
              print("【计算公式】累计百公里油/电费 = (期间总费用 / 总行驶里程) * 100");
              print("= ($totalCost / $totalDistance) * 100 = $value ¥/100km");
            } else {
              print("警告: 期间总费用为0。");
            }
          } else {
            print("警告: 总行驶里程为0。");
          }
        }

        if (value != null && value.isFinite) {
          print("最终图表值: $value");
          spots.add(FlSpot(spots.length.toDouble(), value));
          dates.add(currentRecord.date);
        } else {
          print("最终值为 null 或无效，不添加到图表。");
        }
      }
    } else {
      print("里程记录不足2条，无法计算趋势。");
    }
    
    print("--- 计算结束，共生成 ${spots.length} 个图表点 ---");

    if (spots.isEmpty) {
      return const Center(child: Text('数据不足，无法生成图表'));
    }

    // --- Dynamic Y-Axis Interval Calculation ---
    final minY = spots.map((e) => e.y).reduce(min);
    final maxY = spots.map((e) => e.y).reduce(max);
    final range = (maxY - minY).abs();

    // Aim for about 5 grid lines
    double yInterval = 1;
    if (range > 0) {
      yInterval = (range / 5).ceilToDouble();
    }
    
    // Snap to a "nice" number for better readability
    if (yInterval > 1) {
      final pow10 = pow(10, (log(yInterval) / log(10)).floor());
      final normalizedInterval = yInterval / pow10;
      if (normalizedInterval > 5) {
        yInterval = (10 * pow10).toDouble();
      } else if (normalizedInterval > 2) {
        yInterval = (5 * pow10).toDouble();
      } else if (normalizedInterval > 1) {
        yInterval = (2 * pow10).toDouble();
      } else {
        yInterval = pow10.toDouble();
      }
    }
    
    print("图表 Y 轴范围: [$minY, $maxY], 动态间隔: $yInterval");

    // Chart UI
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: yInterval,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: spots.length > 5 ? (spots.length / 5).ceil().toDouble() : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < dates.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('MM/dd').format(dates[index]),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: (minY / yInterval).floor() * yInterval, // Align min Y to the grid
        maxY: (maxY / yInterval).ceil() * yInterval,   // Align max Y to the grid
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.8),
                Colors.blue,
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: Colors.blue,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.2),
                  Colors.blue.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final index = barSpot.x.toInt();
                final date = dates[index];
                return LineTooltipItem(
                  '${DateFormat('yyyy-MM-dd').format(date)}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: '${barSpot.y.toStringAsFixed(2)} ${showConsumption ? 'L/100km' : '¥/100km'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}