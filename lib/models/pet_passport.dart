/// 宠物身份证模型
class PetPassport {
  final int? id;
  final String petId; // 关联的宠物ID

  // 基础信息
  final String? photoPath; // 宠物照片
  final String? ownerName; // 主人姓名
  final DateTime? adoptionDate; // 领养日期

  // 性格特征
  final String? mbtiType; // MBTI类型 (如: ENFP, ISTJ等)
  final String? mbtiDescription; // MBTI描述

  // 兴趣标签
  final List<String> interestTags; // 兴趣标签列表

  // 成就徽章
  final List<Achievement> achievements; // 成就徽章列表

  // 社交信息
  final String? bio; // 个人简介
  final int? friendCount; // 好友数量

  // 时间戳
  final DateTime createdAt;
  final DateTime updatedAt;

  PetPassport({
    this.id,
    required this.petId,
    this.photoPath,
    this.ownerName,
    this.adoptionDate,
    this.mbtiType,
    this.mbtiDescription,
    this.interestTags = const [],
    this.achievements = const [],
    this.bio,
    this.friendCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pet_id': petId,
      'photo_path': photoPath,
      'owner_name': ownerName,
      'adoption_date': adoptionDate?.toIso8601String(),
      'mbti_type': mbtiType,
      'mbti_description': mbtiDescription,
      'interest_tags': interestTags.join(','),
      'achievements': achievements.map((a) => a.toMap()).toList(),
      'bio': bio,
      'friend_count': friendCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PetPassport.fromMap(Map<String, dynamic> map) {
    return PetPassport(
      id: map['id'],
      petId: map['pet_id'],
      photoPath: map['photo_path'],
      ownerName: map['owner_name'],
      adoptionDate: map['adoption_date'] != null
          ? DateTime.parse(map['adoption_date'])
          : null,
      mbtiType: map['mbti_type'],
      mbtiDescription: map['mbti_description'],
      interestTags:
          map['interest_tags'] != null && map['interest_tags'].isNotEmpty
          ? (map['interest_tags'] as String).split(',')
          : [],
      achievements: map['achievements'] != null
          ? (map['achievements'] as List)
                .map((a) => Achievement.fromMap(a))
                .toList()
          : [],
      bio: map['bio'],
      friendCount: map['friend_count'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  PetPassport copyWith({
    int? id,
    String? petId,
    String? photoPath,
    String? ownerName,
    DateTime? adoptionDate,
    String? mbtiType,
    String? mbtiDescription,
    List<String>? interestTags,
    List<Achievement>? achievements,
    String? bio,
    int? friendCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PetPassport(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      photoPath: photoPath ?? this.photoPath,
      ownerName: ownerName ?? this.ownerName,
      adoptionDate: adoptionDate ?? this.adoptionDate,
      mbtiType: mbtiType ?? this.mbtiType,
      mbtiDescription: mbtiDescription ?? this.mbtiDescription,
      interestTags: interestTags ?? this.interestTags,
      achievements: achievements ?? this.achievements,
      bio: bio ?? this.bio,
      friendCount: friendCount ?? this.friendCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 成就徽章模型
class Achievement {
  final String id; // 成就ID
  final String name; // 成就名称
  final String description; // 成就描述
  final String iconName; // 图标名称
  final String category; // 分类：health(健康), social(社交), skill(技能), special(特殊)
  final DateTime unlockedAt; // 解锁时间

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.category,
    DateTime? unlockedAt,
  }) : unlockedAt = unlockedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_name': iconName,
      'category': category,
      'unlocked_at': unlockedAt.toIso8601String(),
    };
  }

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      iconName: map['icon_name'],
      category: map['category'],
      unlockedAt: DateTime.parse(map['unlocked_at']),
    );
  }
}

/// MBTI类型定义
class MBTITypes {
  static const Map<String, Map<String, String>> types = {
    'ENFP': {
      'name': '热情探险家',
      'description': '活泼好动，充满好奇心，喜欢探索新事物',
      'traits': '友善、爱玩、适应力强',
    },
    'INFP': {
      'name': '温柔梦想家',
      'description': '安静敏感，喜欢独处，对主人忠诚',
      'traits': '温和、细腻、富有同情心',
    },
    'ENTP': {
      'name': '聪明机灵鬼',
      'description': '聪明伶俐，喜欢学习新技能和解决问题',
      'traits': '好奇、灵活、创新',
    },
    'INTP': {
      'name': '独立思考者',
      'description': '独立自主，喜欢观察和思考',
      'traits': '独立、理性、观察力强',
    },
    'ENFJ': {
      'name': '社交达人',
      'description': '热爱社交，喜欢和其他宠物及人类互动',
      'traits': '外向、友好、领导力',
    },
    'INFJ': {
      'name': '忠诚守护者',
      'description': '深情专一，对主人极度忠诚',
      'traits': '忠诚、直觉、保护欲强',
    },
    'ENTJ': {
      'name': '领袖气质',
      'description': '自信果断，喜欢掌控局面',
      'traits': '自信、果断、有主见',
    },
    'INTJ': {
      'name': '战略规划师',
      'description': '聪明独立，做事有条理',
      'traits': '独立、聪明、有计划性',
    },
    'ESFP': {
      'name': '活力派对王',
      'description': '精力充沛，喜欢玩耍和运动',
      'traits': '活泼、爱玩、充满活力',
    },
    'ISFP': {
      'name': '艺术气质',
      'description': '温柔安静，喜欢美好的事物',
      'traits': '温柔、安静、审美力强',
    },
    'ESTP': {
      'name': '运动健将',
      'description': '爱运动，反应敏捷，冒险精神',
      'traits': '活跃、敏捷、冒险',
    },
    'ISTP': {
      'name': '冷静观察家',
      'description': '冷静沉着，善于观察和应对',
      'traits': '冷静、务实、适应力强',
    },
    'ESFJ': {
      'name': '贴心小棉袄',
      'description': '善解人意，喜欢照顾他人',
      'traits': '体贴、友善、责任感强',
    },
    'ISFJ': {
      'name': '温暖陪伴者',
      'description': '安静温暖，是最好的陪伴',
      'traits': '温暖、可靠、忠诚',
    },
    'ESTJ': {'name': '纪律执行官', 'description': '守规矩，容易训练', 'traits': '有纪律、负责、可靠'},
    'ISTJ': {'name': '稳重守卫', 'description': '稳重可靠，作息规律', 'traits': '稳重、可靠、有条理'},
  };

  static Map<String, String>? getTypeInfo(String type) {
    return types[type.toUpperCase()];
  }
}

/// 预定义的兴趣标签
class InterestTags {
  static const List<String> allTags = [
    '玩飞盘',
    '游泳',
    '跑步',
    '抓球',
    '挖洞',
    '攀爬',
    '晒太阳',
    '午睡',
    '美食家',
    '社交达人',
    '独处爱好者',
    '学习能力强',
    '看电视',
    '听音乐',
    '玩具收藏家',
    '户外探险',
    '室内宅家',
    '撒娇高手',
    '卖萌专家',
    '看门能手',
  ];
}

/// 预定义的成就徽章
class PredefinedAchievements {
  static final List<Achievement> achievements = [
    Achievement(
      id: 'first_checkup',
      name: '首次体检',
      description: '完成第一次健康体检',
      iconName: 'health_and_safety',
      category: 'health',
    ),
    Achievement(
      id: 'vaccinated',
      name: '疫苗小勇士',
      description: '完成全部疫苗接种',
      iconName: 'vaccines',
      category: 'health',
    ),
    Achievement(
      id: 'social_butterfly',
      name: '社交达人',
      description: '结交10位好友',
      iconName: 'groups',
      category: 'social',
    ),
    Achievement(
      id: 'first_diary',
      name: '日记新星',
      description: '发布第一篇宠物日记',
      iconName: 'book',
      category: 'social',
    ),
    Achievement(
      id: 'skill_master',
      name: '技能大师',
      description: '学会5个以上技能',
      iconName: 'military_tech',
      category: 'skill',
    ),
    Achievement(
      id: 'one_year',
      name: '一周年纪念',
      description: '陪伴主人一周年',
      iconName: 'celebration',
      category: 'special',
    ),
    Achievement(
      id: 'good_eater',
      name: '干饭达人',
      description: '连续7天按时吃饭',
      iconName: 'restaurant',
      category: 'health',
    ),
    Achievement(
      id: 'sport_lover',
      name: '运动健将',
      description: '累计运动100小时',
      iconName: 'sports_score',
      category: 'health',
    ),
  ];

  static Achievement? getAchievementById(String id) {
    try {
      return achievements.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }
}
