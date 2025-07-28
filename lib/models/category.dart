class Category {
  final int? id;
  final String name;
  final String icon;
  final String color;

  Category({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  // 从JSON映射到对象
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      color: json['color'],
    );
  }

  // 从对象映射到JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
    };
  }

  // 从对象映射到数据库
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
    };
  }

  // 从数据库映射到对象
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      color: map['color'],
    );
  }

  // 预定义的分类
  static List<Category> predefinedCategories = [
    Category(name: '餐饮', icon: 'restaurant', color: '#FF5252'),
    Category(name: '购物', icon: 'shopping_cart', color: '#FF9800'),
    Category(name: '交通', icon: 'directions_car', color: '#2196F3'),
    Category(name: '住宿', icon: 'home', color: '#4CAF50'),
    Category(name: '娱乐', icon: 'movie', color: '#9C27B0'),
    Category(name: '医疗', icon: 'local_hospital', color: '#F44336'),
    Category(name: '教育', icon: 'school', color: '#3F51B5'),
    Category(name: '旅行', icon: 'flight', color: '#00BCD4'),
    Category(name: '汽车', icon: 'directions_car', color: '#607D8B'),
    Category(name: '油/电耗', icon: 'local_gas_station', color: '#FF5722'),
    Category(name: '其他', icon: 'more_horiz', color: '#9E9E9E'),
  ];
}