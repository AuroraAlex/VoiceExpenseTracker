enum TimePeriodType {
  today,
  thisWeek,
  thisMonth,
  thisYear,
  custom,
}

class TimePeriod {
  final TimePeriodType type;
  final DateTime startDate;
  final DateTime endDate;
  final String displayName;

  TimePeriod({
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.displayName,
  });

  // 创建预定义时间周期
  static TimePeriod today() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    
    return TimePeriod(
      type: TimePeriodType.today,
      startDate: startOfDay,
      endDate: endOfDay,
      displayName: '今日',
    );
  }

  static TimePeriod thisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final endOfWeek = startOfWeekDay.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
    
    return TimePeriod(
      type: TimePeriodType.thisWeek,
      startDate: startOfWeekDay,
      endDate: endOfWeek,
      displayName: '本周',
    );
  }

  static TimePeriod thisMonth() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
    
    return TimePeriod(
      type: TimePeriodType.thisMonth,
      startDate: startOfMonth,
      endDate: endOfMonth,
      displayName: '本月',
    );
  }

  static TimePeriod thisYear() {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final endOfYear = DateTime(now.year + 1, 1, 1).subtract(const Duration(milliseconds: 1));
    
    return TimePeriod(
      type: TimePeriodType.thisYear,
      startDate: startOfYear,
      endDate: endOfYear,
      displayName: '本年',
    );
  }

  static TimePeriod custom(DateTime startDate, DateTime endDate) {
    // 确保开始时间是当天的00:00:00
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    // 确保结束时间是当天的23:59:59
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    
    return TimePeriod(
      type: TimePeriodType.custom,
      startDate: start,
      endDate: end,
      displayName: _formatCustomPeriodName(start, end),
    );
  }

  static String _formatCustomPeriodName(DateTime start, DateTime end) {
    final startStr = '${start.month}/${start.day}';
    final endStr = '${end.month}/${end.day}';
    
    if (start.year == end.year) {
      if (start.month == end.month && start.day == end.day) {
        return '${start.month}月${start.day}日';
      }
      return '$startStr - $endStr';
    } else {
      return '${start.year}/$startStr - ${end.year}/$endStr';
    }
  }

  // 获取所有预定义时间周期
  static List<TimePeriod> getAllPredefinedPeriods() {
    return [
      today(),
      thisWeek(),
      thisMonth(),
      thisYear(),
    ];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimePeriod &&
        other.type == type &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode {
    return type.hashCode ^ startDate.hashCode ^ endDate.hashCode;
  }
}