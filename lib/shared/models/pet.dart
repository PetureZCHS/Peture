class Pet {
  final String? id; // 从 int? 改为 String? 以支持 UUID
  final String type;
  final String name;
  final String age;
  final String gender;
  final String breed;
  final String? avatar; // 宠物头像路径
  final String? birthDate; // 出生日期 (ISO 8601 格式)
  final String? neuterStatus; // 绝育状态: '已绝育' 或 '未绝育'
  final double? weight; // 体重 (kg)
  final String? ownerNickname; // 宠物对主人的自定义称呼
  final bool useCustomNickname; // 是否使用自定义称呼（false 时使用用户默认称呼）
  final String? lifePhoto; // 生活照 URL or local path

  Pet({
    this.id,
    required this.type,
    required this.name,
    required this.age,
    required this.gender,
    required this.breed,
    this.avatar,
    this.lifePhoto,
    this.birthDate,
    this.neuterStatus,
    this.weight,
    this.ownerNickname,
    this.useCustomNickname = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'age': age,
      'gender': gender,
      'breed': breed,
      'avatar': avatar,
      'life_photo': lifePhoto,
      'birth_date': birthDate, // 数据库字段名使用下划线
      'neuter_status': neuterStatus, // 数据库字段名使用下划线
      'weight': weight,
      'owner_nickname': ownerNickname,
      'use_custom_nickname': useCustomNickname,
    };
  }

  factory Pet.fromMap(Map<String, dynamic> map) {
    return Pet(
      id: map['id']?.toString(), // 确保转换为 String
      type: map['type'],
      name: map['name'],
      age: map['age'],
      gender: map['gender'],
      breed: map['breed'],
      avatar: map['avatar'],
      lifePhoto: map['life_photo'],
      birthDate: map['birth_date'], // 从数据库字段名映射
      neuterStatus: map['neuter_status'], // 从数据库字段名映射
      weight: map['weight'] != null ? (map['weight'] as num).toDouble() : null,
      ownerNickname: map['owner_nickname'],
      useCustomNickname: map['use_custom_nickname'] ?? false,
    );
  }
}
