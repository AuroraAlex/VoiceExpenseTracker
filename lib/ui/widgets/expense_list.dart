import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../models/expense.dart';

class ExpenseList extends StatelessWidget {
  final List<Expense> expenses;
  final Function(Expense) onDelete;
  final Function(Expense) onEdit;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ExpenseList({
    Key? key,
    required this.expenses,
    required this.onDelete,
    required this.onEdit,
    this.shrinkWrap = false,
    this.physics,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1. 按记账日期（createdAt）排序，保证同一天内的顺序精确
    final sortedExpenses = List<Expense>.from(expenses)
      ..sort((a, b) {
        if (a.createdAt != null && b.createdAt != null) {
          return b.createdAt!.compareTo(a.createdAt!);
        }
        return b.date.compareTo(a.date); // 降级使用费用日期
      });

    // 2. 按费用日期（date）进行分组
    final groupedExpenses = _groupExpensesByDate(sortedExpenses);
    final dateKeys = groupedExpenses.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // 按日期降序排序，最新的在前面

    if (expenses.isEmpty) {
      return const Center(child: Text('当前时间段无记录'));
    }

    return ListView.builder(
      itemCount: dateKeys.length,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemBuilder: (context, index) {
        final date = dateKeys[index];
        final expensesOnDate = groupedExpenses[date]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期标题
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                _formatDateHeader(date),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
            // 当天的支出列表
            ...expensesOnDate.map((expense) => _buildExpenseItem(context, expense)),
          ],
        );
      },
    );
  }

  // 按费用日期分组的辅助方法
  Map<DateTime, List<Expense>> _groupExpensesByDate(List<Expense> expenses) {
    final Map<DateTime, List<Expense>> grouped = {};
    for (var expense in expenses) {
      // 标准化日期，忽略时间部分
      final dateKey = DateTime(expense.date.year, expense.date.month, expense.date.day);
      if (grouped[dateKey] == null) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(expense);
    }
    return grouped;
  }

  // 格式化日期标题
  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '今天';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      return '昨天';
    } else {
      return DateFormat('yyyy-MM-dd').format(date);
    }
  }

  Widget _buildExpenseItem(BuildContext context, Expense expense) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Slidable(
        key: ValueKey(expense.id),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onEdit(expense),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: '编辑',
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            SlidableAction(
              onPressed: (_) => onDelete(expense),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: '删除',
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: expense.type == 'income' 
                ? Colors.green.withOpacity(0.1) 
                : Colors.red.withOpacity(0.1),
            child: Icon(
              expense.type == 'income' ? Icons.arrow_upward : Icons.arrow_downward,
              color: expense.type == 'income' ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
          title: Text(
            expense.title, 
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis, // 添加溢出处理
            maxLines: 1,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                expense.category,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDateTime(expense),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          trailing: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${expense.type == 'income' ? '+' : '-'}¥${expense.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: expense.type == 'income' ? Colors.green : Colors.red,
              ),
            ),
          ),
          onTap: () => _showExpenseDetails(context, expense),
        ),
      ),
    );
  }

  void _showExpenseDetails(BuildContext context, Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(expense.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('类型', expense.type == 'income' ? '收入' : '支出'),
            _buildDetailRow('金额', '¥${expense.amount.toStringAsFixed(2)}'),
            _buildDetailRow('日期', DateFormat('yyyy-MM-dd').format(expense.date)),
            if (expense.createdAt != null)
              _buildDetailRow('创建时间', DateFormat('yyyy-MM-dd HH:mm:ss').format(expense.createdAt!)),
            _buildDetailRow('分类', expense.category),
            if (expense.description != null && expense.description!.isNotEmpty)
              _buildDetailRow('描述', expense.description!, isMultiLine: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onEdit(expense);
            },
            child: const Text('编辑'),
          ),
        ],
      ),
    );
  }

  // 格式化时间显示
  String _formatDateTime(Expense expense) {
    final now = DateTime.now();
    final targetDate = expense.createdAt ?? expense.date;
    final difference = now.difference(targetDate);
    
    // 如果是今天
    if (targetDate.year == now.year && 
        targetDate.month == now.month && 
        targetDate.day == now.day) {
      if (difference.inMinutes < 1) {
        return '刚刚';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}分钟前';
      } else {
        return '今天 ${DateFormat('HH:mm').format(targetDate)}';
      }
    }
    // 如果是昨天
    else if (difference.inDays == 1) {
      return '昨天 ${DateFormat('HH:mm').format(targetDate)}';
    }
    // 如果是本年
    else if (targetDate.year == now.year) {
      return DateFormat('MM-dd HH:mm').format(targetDate);
    }
    // 其他情况显示完整日期
    else {
      return DateFormat('yyyy-MM-dd HH:mm').format(targetDate);
    }
  }

  Widget _buildDetailRow(String label, String value, {bool isMultiLine = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              overflow: isMultiLine ? TextOverflow.visible : TextOverflow.ellipsis,
              maxLines: isMultiLine ? null : 1,
            ),
          ),
        ],
      ),
    );
  }
}