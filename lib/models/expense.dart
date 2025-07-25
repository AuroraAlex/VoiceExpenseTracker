class Expense {
  final int? id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String type; // 'expense' or 'income'
  final String? description;
  final String? voiceRecord;

  // 车辆相关可选字段
  final double? mileage; // 里程数
  final double? consumption; // 消耗量（升/度）
  final String? vehicleType; // 车辆类型：汽油车/电动车

  Expense({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.type = 'expense', // Default to expense
    this.description,
    this.voiceRecord,
    this.mileage,
    this.consumption,
    this.vehicleType,
  });

  // 从JSON映射到对象
  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      title: json['title'],
      amount: json['amount'],
      date: DateTime.parse(json['date']),
      category: json['category'],
      type: json['type'] ?? 'expense',
      description: json['description'],
      voiceRecord: json['voiceRecord'],
      mileage: json['mileage'],
      consumption: json['consumption'],
      vehicleType: json['vehicleType'],
    );
  }

  // 从对象映射到JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'type': type,
      'description': description,
      'voiceRecord': voiceRecord,
      'mileage': mileage,
      'consumption': consumption,
      'vehicleType': vehicleType,
    };
  }

  // 从对象映射到数据库
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'type': type,
      'description': description,
      'voiceRecord': voiceRecord,
      'mileage': mileage,
      'consumption': consumption,
      'vehicleType': vehicleType,
    };
  }

  // 从数据库映射到对象
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      category: map['category'],
      type: map['type'] ?? 'expense',
      description: map['description'],
      voiceRecord: map['voiceRecord'],
      mileage: map['mileage'],
      consumption: map['consumption'],
      vehicleType: map['vehicleType'],
    );
  }

  // 复制对象并修改部分属性
  Expense copyWith({
    int? id,
    String? title,
    double? amount,
    DateTime? date,
    String? category,
    String? type,
    String? description,
    String? voiceRecord,
    double? mileage,
    double? consumption,
    String? vehicleType,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      type: type ?? this.type,
      description: description ?? this.description,
      voiceRecord: voiceRecord ?? this.voiceRecord,
      mileage: mileage ?? this.mileage,
      consumption: consumption ?? this.consumption,
      vehicleType: vehicleType ?? this.vehicleType,
    );
  }
}