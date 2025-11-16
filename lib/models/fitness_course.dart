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
}

/// 健身记录模型
class FitnessRecord {
  final int? id;
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
      id: map['id'],
      courseId: map['courseId'],
      courseName: map['courseName'],
      completedAt: DateTime.parse(map['completedAt']),
      durationMinutes: map['durationMinutes'],
      caloriesBurned: map['caloriesBurned'],
      petCaloriesBurned: map['petCaloriesBurned'],
      notes: map['notes'],
    );
  }
}
