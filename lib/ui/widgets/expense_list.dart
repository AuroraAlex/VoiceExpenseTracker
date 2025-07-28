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
    // 按日期排序，最新的在前面
    final sortedExpenses = List<Expense>.from(expenses)
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      itemCount: sortedExpenses.length,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemBuilder: (context, index) {
        final expense = sortedExpenses[index];
        return _buildExpenseItem(context, expense);
      },
    );
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
          subtitle: Text(
            '${expense.category} - ${DateFormat('MM-dd').format(expense.date)}',
            overflow: TextOverflow.ellipsis, // 添加溢出处理
            maxLines: 1,
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