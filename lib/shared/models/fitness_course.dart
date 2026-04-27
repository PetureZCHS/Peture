/// 健身课程模型
class FitnessCourse {
  final String id;
  final String name;
  final String description;
  final int durationMinutes; // 5, 10, 20分钟
  final String intensity; // low, medium, high
  final String petType; // dog, cat
  final int caloriesEstimate; // 预估卡路里消耗
  final int petCaloriesEstimate; // 宠物预估消耗（用罐头数表示）
  final List<FitnessAction> actions;
  final String iconEmoji;
  final List<String> tags; // 例如: ['燃脂', '心肺', '追逐']

  FitnessCourse({
    required this.id,
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.intensity,
    required this.petType,
    required this.caloriesEstimate,
    required this.petCaloriesEstimate,
    required this.actions,
    required this.iconEmoji,
    required this.tags,
  });

  String get intensityLabel {
    switch (intensity) {
      case 'low':
        return '低 - 拉伸与平静';
      case 'medium':
        return '中 - 塑形与核心';
      case 'high':
        return '高 - 燃脂与心肺';
      default:
        return '未知';
    }
  }

  String get petTypeLabel {
    switch (petType) {
      case 'dog':
        return '狗狗专属';
      case 'cat':
        return '猫咪专属';
      default:
        return '通用';
    }
  }

  // 新增：JSON序列化（用于缓存）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'durationMinutes': durationMinutes,
      'intensity': intensity,
      'petType': petType,
      'caloriesEstimate': caloriesEstimate,
      'petCaloriesEstimate': petCaloriesEstimate,
      'iconEmoji': iconEmoji,
      'tags': tags,
      'actions': actions.map((action) => action.toJson()).toList(),
    };
  }

  factory FitnessCourse.fromJson(Map<String, dynamic> json) {
    // 数据验证和默认值处理
    return FitnessCourse(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      intensity: json['intensity'] as String? ?? 'medium',
      petType: json['petType'] as String? ?? 'dog',
      caloriesEstimate: (json['caloriesEstimate'] as num?)?.toInt() ?? 0,
      petCaloriesEstimate: (json['petCaloriesEstimate'] as num?)?.toInt() ?? 0,
      iconEmoji: json['iconEmoji'] as String? ?? '🏃',
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List) : [],
      actions: json['actions'] != null
          ? (json['actions'] as List)
              .map((action) =>
                  FitnessAction.fromJson(action as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  // 新增：从Supabase JSON创建对象
  factory FitnessCourse.fromSupabaseJson(Map<String, dynamic> json) {
    return FitnessCourse(
      id: json['course_id'] as String? ?? '', // 注意：使用course_id作为id
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      intensity: json['intensity'] as String? ?? 'medium',
      petType: json['pet_type'] as String? ?? 'dog',
      caloriesEstimate: (json['calories_estimate'] as num?)?.toInt() ?? 0,
      petCaloriesEstimate:
          (json['pet_calories_estimate'] as num?)?.toInt() ?? 0,
      iconEmoji: json['icon_emoji'] as String? ?? '🏃',
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List) : [],
      actions: (json['actions'] as List<dynamic>? ?? [])
          .map((action) =>
              FitnessAction.fromSupabaseJson(action as Map<String, dynamic>))
          .toList(),
    );
  }

  // 转换为Supabase格式
  Map<String, dynamic> toSupabaseJson() {
    return {
      'course_id': id,
      'name': name,
      'description': description,
      'duration_minutes': durationMinutes,
      'intensity': intensity,
      'pet_type': petType,
      'calories_estimate': caloriesEstimate,
      'pet_calories_estimate': petCaloriesEstimate,
      'icon_emoji': iconEmoji,
      'tags': tags,
      'actions': actions.map((action) => action.toSupabaseJson()).toList(),
      'is_active': true,
      'sort_order': 0,
    };
  }
}

/// 健身动作模型
class FitnessAction {
  final String name;
  final String audioGuide; // 音频指导文本
  final int durationSeconds;
  final String demonstration; // 动作演示说明
  final String benefit; // 对主人的益处
  final String petBenefit; // 对宠物的益处

  FitnessAction({
    required this.name,
    required this.audioGuide,
    required this.durationSeconds,
    required this.demonstration,
    required this.benefit,
    required this.petBenefit,
  });

  // 新增：JSON序列化
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'audioGuide': audioGuide,
      'durationSeconds': durationSeconds,
      'demonstration': demonstration,
      'benefit': benefit,
      'petBenefit': petBenefit,
    };
  }

  factory FitnessAction.fromJson(Map<String, dynamic> json) {
    // 数据验证和默认值处理
    return FitnessAction(
      name: json['name'] as String? ?? '',
      audioGuide: json['audioGuide'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      demonstration: json['demonstration'] as String? ?? '',
      benefit: json['benefit'] as String? ?? '',
      petBenefit: json['petBenefit'] as String? ?? '',
    );
  }

  // 新增：Supabase JSON转换
  factory FitnessAction.fromSupabaseJson(Map<String, dynamic> json) {
    return FitnessAction(
      name: json['name'] as String? ?? '',
      audioGuide: json['audioGuide'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      demonstration: json['demonstration'] as String? ?? '',
      benefit: json['benefit'] as String? ?? '',
      petBenefit: json['petBenefit'] as String? ?? '',
    );
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'name': name,
      'audioGuide': audioGuide,
      'durationSeconds': durationSeconds,
      'demonstration': demonstration,
      'benefit': benefit,
      'petBenefit': petBenefit,
    };
  }
}

/// 健身记录模型
class FitnessRecord {
  final String? id; // 改为 String? 以支持 Supabase UUID
  final String courseId;
  final String courseName;
  final DateTime completedAt;
  final int durationMinutes;
  final int caloriesBurned;
  final int petCaloriesBurned;
  final String? notes;

  FitnessRecord({
    this.id,
    required this.courseId,
    required this.courseName,
    required this.completedAt,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.petCaloriesBurned,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'courseName': courseName,
      'completedAt': completedAt.toIso8601String(),
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'petCaloriesBurned': petCaloriesBurned,
      'notes': notes,
    };
  }

  factory FitnessRecord.fromMap(Map<String, dynamic> map) {
    return FitnessRecord(
      id: map['id']?.toString(), // 支持 int 和 String
      courseId: map['courseId'] as String,
      courseName: map['courseName'] as String,
      completedAt: DateTime.parse(map['completedAt'] as String),
      durationMinutes: (map['durationMinutes'] as num).toInt(),
      caloriesBurned: (map['caloriesBurned'] as num).toInt(),
      petCaloriesBurned: (map['petCaloriesBurned'] as num).toInt(),
      notes: map['notes'] as String?,
    );
  }
}
