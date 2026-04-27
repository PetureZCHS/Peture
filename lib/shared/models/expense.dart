import 'package:flutter/material.dart';

/// 宠物账单数据模型
class Expense {
  final String? id; // 改为 String? 以支持 Supabase UUID
  final double amount; // 金额
  final String category; // 分类（食品、医疗、玩具、洗护、用品等）
  final String date; // 日期（格式：yyyy-MM-dd）
  final int? petId; // 宠物ID（可选，如果用户有多只宠物）
  final String? petName; // 宠物名称（用于显示）
  final String? note; // 备注
  final String? photoPath; // 照片路径（可选）
  final String createdAt; // 创建时间

  Expense({
    this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.petId,
    this.petName,
    this.note,
    this.photoPath,
    required this.createdAt,
  });

  /// 转换为 Map（用于数据库存储）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'date': date,
      'petId': petId,
      'petName': petName,
      'note': note,
      'photoPath': photoPath,
      'createdAt': createdAt,
    };
  }

  /// 从 Map 创建对象（从数据库读取）
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id']?.toString(), // 支持 int 和 String
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      date: map['date'] as String,
      petId: map['petId'] as int?,
      petName: map['petName'] as String?,
      note: map['note'] as String?,
      photoPath: map['photoPath'] as String?,
      createdAt: map['createdAt'] as String,
    );
  }

  /// 复制对象（用于编辑）
  Expense copyWith({
    String? id,
    double? amount,
    String? category,
    String? date,
    int? petId,
    String? petName,
    String? note,
    String? photoPath,
    String? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      petId: petId ?? this.petId,
      petName: petName ?? this.petName,
      note: note ?? this.note,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 消费分类定义
class ExpenseCategory {
  final String name; // 分类名称
  final int icon; // 图标代码点 (IconData 的 codePoint)
  final int color; // 颜色值 (ARGB 格式的整数)

  const ExpenseCategory({
    required this.name,
    required this.icon,
    required this.color,
  });

  /// 默认分类列表
  static final List<ExpenseCategory> defaultCategories = [
    ExpenseCategory(
      name: '宠物食品',
      icon: Icons.restaurant.codePoint,
      color: 0xFFFF8A65,
    ),
    ExpenseCategory(
      name: '医疗/兽医',
      icon: Icons.local_hospital.codePoint,
      color: 0xFF4FC3F7,
    ),
    ExpenseCategory(
      name: '美容/洗护',
      icon: Icons.bathtub.codePoint,
      color: 0xFF81C784,
    ),
    ExpenseCategory(
      name: '玩具/娱乐',
      icon: Icons.toys.codePoint,
      color: 0xFFFFD54F,
    ),
    ExpenseCategory(
      name: '用品/配件',
      icon: Icons.shopping_bag.codePoint,
      color: 0xFFBA68C8,
    ),
    ExpenseCategory(
      name: '寄养/服务',
      icon: Icons.store.codePoint,
      color: 0xFFFF8A80,
    ),
    ExpenseCategory(
      name: '其他',
      icon: Icons.more_horiz.codePoint,
      color: 0xFF90A4AE,
    ),
  ];

  /// 根据分类名称获取分类信息
  static ExpenseCategory? getCategoryByName(String name) {
    try {
      return defaultCategories.firstWhere((cat) => cat.name == name);
    } catch (e) {
      // 尝试匹配旧分类名到新分类
      if (name == '食品') return defaultCategories[0]; // 宠物食品
      if (name == '医疗') return defaultCategories[1]; // 医疗/兽医
      if (name == '洗护') return defaultCategories[2]; // 美容/洗护
      if (name == '玩具') return defaultCategories[3]; // 玩具/娱乐
      if (name == '用品') return defaultCategories[4]; // 用品/配件
      if (name == '寄养') return defaultCategories[5]; // 寄养/服务
      return defaultCategories.last; // 其他
    }
  }
}
