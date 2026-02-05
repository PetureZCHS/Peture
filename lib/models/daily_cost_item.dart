/// 宠物消费品日均成本数据模型
class DailyCostItem {
  final String? id; // 改为 String? 以支持 Supabase UUID
  final String itemName; // 物品名称
  final double totalPrice; // 总价格
  final String purchaseDate; // 购买日期（格式：yyyy-MM-dd）
  final String? finishDate; // 用完日期（可选，格式：yyyy-MM-dd）
  final String? petId; // 关联的宠物ID
  final String? petName; // 宠物名称（用于显示）
  final String? imagePath; // 物品图片路径（可选）
  final String? note; // 备注（可选）
  final String createdAt; // 创建时间

  DailyCostItem({
    this.id,
    required this.itemName,
    required this.totalPrice,
    required this.purchaseDate,
    this.finishDate,
    this.petId,
    this.petName,
    this.imagePath,
    this.note,
    required this.createdAt,
  });

  /// 计算使用天数
  /// 如果有用完日期，则计算两个日期之间的天数
  /// 如果没有用完日期，则计算从购买日期到今天的天数
  int get usageDays {
    final purchase = DateTime.parse(purchaseDate);
    final finish =
        finishDate != null ? DateTime.parse(finishDate!) : DateTime.now();

    final difference = finish.difference(purchase).inDays;
    // 至少算1天，避免除以0
    return difference > 0 ? difference : 1;
  }

  /// 计算日均成本
  double get dailyCost {
    return totalPrice / usageDays;
  }

  /// 转换为 Map（用于数据库存储）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemName': itemName,
      'totalPrice': totalPrice,
      'purchaseDate': purchaseDate,
      'finishDate': finishDate,
      'petId': petId,
      'petName': petName,
      'imagePath': imagePath,
      'note': note,
      'createdAt': createdAt,
    };
  }

  /// 从 Map 创建对象（从数据库读取）
  factory DailyCostItem.fromMap(Map<String, dynamic> map) {
    return DailyCostItem(
      id: map['id']?.toString(), // 支持 int 和 String
      itemName: map['itemName'] as String,
      totalPrice: (map['totalPrice'] as num).toDouble(),
      purchaseDate: map['purchaseDate'] as String,
      finishDate: map['finishDate'] as String?,
      petId: map['petId']?.toString(),
      petName: map['petName'] as String?,
      imagePath: map['imagePath'] as String?,
      note: map['note'] as String?,
      createdAt: map['createdAt'] as String,
    );
  }

  /// 复制对象（用于编辑）
  DailyCostItem copyWith({
    String? id,
    String? itemName,
    double? totalPrice,
    String? purchaseDate,
    String? finishDate,
    String? petId,
    String? petName,
    String? imagePath,
    String? note,
    String? createdAt,
  }) {
    return DailyCostItem(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      totalPrice: totalPrice ?? this.totalPrice,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      finishDate: finishDate ?? this.finishDate,
      petId: petId ?? this.petId,
      petName: petName ?? this.petName,
      imagePath: imagePath ?? this.imagePath,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
