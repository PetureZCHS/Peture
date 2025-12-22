import '../models/fitness_course.dart';

/// 预设的健身课程数据
class FitnessCoursesData {
  static List<FitnessCourse> getAllCourses() {
    return [
      // ========== 狗狗课程 ==========
      // 高强度
      FitnessCourse(
        id: 'dog_high_chase',
        name: '你追我赶变速跑',
        description: 'HIIT高强度间歇训练，与狗狗一起燃脂！快速冲刺+拔河游戏的完美结合。',
        durationMinutes: 4,
        intensity: 'high',
        petType: 'dog',
        caloriesEstimate: 120,
        petCaloriesEstimate: 2,
        iconEmoji: '🏃‍♂️',
        tags: ['燃脂', '心肺', '追逐', 'HIIT'],
        actions: [
          FitnessAction(
            name: '热身慢跑',
            audioGuide: '准备好了吗？拿起狗狗最爱的玩具！让我们先慢跑30秒热身。',
            durationSeconds: 30,
            demonstration: '牵着狗狗慢跑，让它适应节奏',
            benefit: '激活肌肉，提高心率',
            petBenefit: '热身准备，兴奋情绪',
          ),
          FitnessAction(
            name: '冲刺跑 Round 1',
            audioGuide: '3, 2, 1, 冲刺跑！扔出玩具，全速奔跑！',
            durationSeconds: 15,
            demonstration: '扔出玩具，和狗狗一起冲刺追逐',
            benefit: '爆发力训练，快速燃脂',
            petBenefit: '满足追逐本能，释放能量',
          ),
          FitnessAction(
            name: '拔河游戏',
            audioGuide: '好！停下！和它玩拔河游戏，保持力量对抗！',
            durationSeconds: 30,
            demonstration: '与狗狗进行拔河，保持核心稳定',
            benefit: '上肢力量，核心稳定性',
            petBenefit: '咬合力训练，互动乐趣',
          ),
          FitnessAction(
            name: '冲刺跑 Round 2',
            audioGuide: '再次！冲刺跑！',
            durationSeconds: 15,
            demonstration: '第二轮全速冲刺',
            benefit: '持续燃脂，心肺提升',
            petBenefit: '持续释放精力',
          ),
          FitnessAction(
            name: '慢走恢复',
            audioGuide: '放慢速度，深呼吸，和狗狗一起慢走。',
            durationSeconds: 40,
            demonstration: '牵着狗狗慢走，调整呼吸',
            benefit: '心率恢复，防止受伤',
            petBenefit: '平静情绪，享受散步',
          ),
          FitnessAction(
            name: '冲刺跑 Round 3',
            audioGuide: '最后一轮！给我看看你的全力！冲刺！',
            durationSeconds: 15,
            demonstration: '最后一次全力冲刺',
            benefit: '突破极限，最大燃脂',
            petBenefit: '终极能量释放',
          ),
          FitnessAction(
            name: '整理放松',
            audioGuide: '太棒了！让我们慢慢走动，放松肌肉。轻轻抚摸你的狗狗，它做得很好！',
            durationSeconds: 60,
            demonstration: '慢走并抚摸狗狗',
            benefit: '肌肉放松，防止酸痛',
            petBenefit: '获得奖励和赞美',
          ),
        ],
      ),

      // 中强度 - 核心训练
      FitnessCourse(
        id: 'dog_medium_core',
        name: '核心轰炸平板撑',
        description: '锻炼核心力量的同时，让狗狗参与你的训练，增加趣味性和难度！',
        durationMinutes: 4,
        intensity: 'medium',
        petType: 'dog',
        caloriesEstimate: 80,
        petCaloriesEstimate: 1,
        iconEmoji: '💪',
        tags: ['核心', '塑形', '平板支撑'],
        actions: [
          FitnessAction(
            name: '平板支撑基础',
            audioGuide: '让我们开始！进入平板支撑姿势，保持核心收紧。',
            durationSeconds: 30,
            demonstration: '标准平板支撑姿势',
            benefit: '核心力量基础训练',
            petBenefit: '观察主人',
          ),
          FitnessAction(
            name: '狗狗钻洞',
            audioGuide: '保持住！现在，呼唤你的狗狗，让它从你的肚子下面钻过去！',
            durationSeconds: 40,
            demonstration: '保持平板支撑，引导狗狗从身下钻过',
            benefit: '核心稳定性提升，抗干扰训练',
            petBenefit: '敏捷性训练，服从性提升',
          ),
          FitnessAction(
            name: '侧平板支撑（左）',
            audioGuide: '转换到左侧平板支撑，狗狗在你面前，和它对视！',
            durationSeconds: 30,
            demonstration: '左侧平板支撑，与狗狗互动',
            benefit: '侧腹肌锻炼',
            petBenefit: '眼神交流，情感连接',
          ),
          FitnessAction(
            name: '侧平板支撑（右）',
            audioGuide: '换到右侧！保持呼吸，核心收紧！',
            durationSeconds: 30,
            demonstration: '右侧平板支撑',
            benefit: '平衡锻炼两侧',
            petBenefit: '持续互动',
          ),
          FitnessAction(
            name: '平板支撑击掌',
            audioGuide: '回到标准平板支撑，让狗狗坐在你面前，教它"握手"！',
            durationSeconds: 40,
            demonstration: '平板支撑状态下与狗狗击掌',
            benefit: '单臂支撑，核心强化',
            petBenefit: '服从训练，社交技能',
          ),
          FitnessAction(
            name: '婴儿式放松',
            audioGuide: '太好了！进入婴儿式，深呼吸，抚摸你的狗狗。',
            durationSeconds: 50,
            demonstration: '婴儿式拉伸，抚摸狗狗',
            benefit: '背部放松，缓解疲劳',
            petBenefit: '获得抚摸奖励',
          ),
        ],
      ),

      // 中强度 - 力量训练
      FitnessCourse(
        id: 'dog_medium_strength',
        name: '深蹲宠物火箭',
        description: '下肢力量训练结合狗狗服从性训练，一举两得！',
        durationMinutes: 5,
        intensity: 'medium',
        petType: 'dog',
        caloriesEstimate: 90,
        petCaloriesEstimate: 1,
        iconEmoji: '🦵',
        tags: ['力量', '下肢', '服从训练'],
        actions: [
          FitnessAction(
            name: '热身深蹲',
            audioGuide: '双脚与肩同宽，让我们做10个标准深蹲热身。',
            durationSeconds: 30,
            demonstration: '标准深蹲姿势',
            benefit: '激活腿部肌肉',
            petBenefit: '观察主人',
          ),
          FitnessAction(
            name: '深蹲+握手',
            audioGuide: '每次下蹲时，命令狗狗"握手"；起身时，命令"放下"！',
            durationSeconds: 60,
            demonstration: '深蹲配合狗狗握手指令',
            benefit: '腿部力量+节奏控制',
            petBenefit: '服从性训练，节奏感培养',
          ),
          FitnessAction(
            name: '弓步蹲（左腿）',
            audioGuide: '左腿向前弓步蹲，下蹲时命令狗狗"坐下"！',
            durationSeconds: 40,
            demonstration: '左腿弓步蹲+狗狗坐下',
            benefit: '单腿力量，平衡训练',
            petBenefit: '服从指令训练',
          ),
          FitnessAction(
            name: '弓步蹲（右腿）',
            audioGuide: '换右腿！保持平衡，命令狗狗"趴下"！',
            durationSeconds: 40,
            demonstration: '右腿弓步蹲+狗狗趴下',
            benefit: '平衡锻炼',
            petBenefit: '不同指令训练',
          ),
          FitnessAction(
            name: '深蹲跳跃',
            audioGuide: '增加难度！深蹲跳跃，落地时狗狗也跳起来击掌！',
            durationSeconds: 30,
            demonstration: '爆发式深蹲跳+狗狗跳跃',
            benefit: '爆发力，燃脂',
            petBenefit: '跳跃训练，兴奋互动',
          ),
          FitnessAction(
            name: '拉伸放松',
            audioGuide: '做得好！双腿前后拉伸，同时让狗狗在你身边趴下休息。',
            durationSeconds: 60,
            demonstration: '腿部拉伸+狗狗休息',
            benefit: '防止肌肉紧张',
            petBenefit: '平静休息',
          ),
        ],
      ),

      // 低强度 - 瑜伽
      FitnessCourse(
        id: 'dog_low_yoga',
        name: '人宠瑜伽放松',
        description: '与狗狗一起享受平静的瑜伽时光，身心放松，情感连接。',
        durationMinutes: 5,
        intensity: 'low',
        petType: 'dog',
        caloriesEstimate: 40,
        petCaloriesEstimate: 0,
        iconEmoji: '🧘',
        tags: ['瑜伽', '放松', '拉伸', '情感连接'],
        actions: [
          FitnessAction(
            name: '呼吸冥想',
            audioGuide: '坐下，闭上眼睛，深呼吸。让狗狗坐在你旁边，感受它的陪伴。',
            durationSeconds: 60,
            demonstration: '盘腿坐姿，深呼吸，轻抚狗狗',
            benefit: '平静心神，减压',
            petBenefit: '感受主人平静情绪',
          ),
          FitnessAction(
            name: '下犬式',
            audioGuide: '进入下犬式，感受背部的拉伸。看看你的狗狗是不是在好奇地闻你的脸？',
            durationSeconds: 40,
            demonstration: '瑜伽下犬式',
            benefit: '背部、腿部拉伸',
            petBenefit: '好奇互动',
          ),
          FitnessAction(
            name: '猫牛式',
            audioGuide: '四肢着地，做猫牛式呼吸。狗狗可能会钻到你身下，享受这个有趣的瞬间！',
            durationSeconds: 50,
            demonstration: '猫牛式脊柱波动',
            benefit: '脊柱灵活性',
            petBenefit: '探索互动',
          ),
          FitnessAction(
            name: '战士式',
            audioGuide: '站起来，做战士二式。强壮而稳定，就像保护狗狗的战士！',
            durationSeconds: 40,
            demonstration: '战士二式，狗狗在身旁',
            benefit: '腿部力量，身心合一',
            petBenefit: '安全感',
          ),
          FitnessAction(
            name: '树式平衡',
            audioGuide: '单腿站立，进入树式。狗狗在你脚边，成为你的"根基"。',
            durationSeconds: 40,
            demonstration: '树式平衡',
            benefit: '平衡力，专注力',
            petBenefit: '静态陪伴',
          ),
          FitnessAction(
            name: '婴儿式',
            audioGuide: '最后，进入婴儿式，全身放松。轻轻抚摸你身边的狗狗，感受它的呼吸。',
            durationSeconds: 70,
            demonstration: '婴儿式放松+抚摸狗狗',
            benefit: '深度放松，缓解疲劳',
            petBenefit: '享受抚摸，情感满足',
          ),
        ],
      ),

      // ========== 猫咪课程 ==========
      // 中强度 - 核心
      FitnessCourse(
        id: 'cat_medium_core',
        name: '核心轰炸猫诱惑',
        description: '用逗猫棒配合仰卧起坐，在锻炼核心的同时与猫咪玩耍！',
        durationMinutes: 4,
        intensity: 'medium',
        petType: 'cat',
        caloriesEstimate: 75,
        petCaloriesEstimate: 1,
        iconEmoji: '🐱',
        tags: ['核心', '腹肌', '互动'],
        actions: [
          FitnessAction(
            name: '热身卷腹',
            audioGuide: '平躺，双手拿起逗猫棒。让我们先做10个标准卷腹。',
            durationSeconds: 30,
            demonstration: '标准卷腹动作',
            benefit: '激活腹肌',
            petBenefit: '观察逗猫棒',
          ),
          FitnessAction(
            name: '仰卧起坐+猫咪扑击',
            audioGuide: '每次起身时，把逗猫棒举到最高点，吸引猫咪来扑！',
            durationSeconds: 60,
            demonstration: '仰卧起坐，最高点挥动逗猫棒',
            benefit: '腹肌持续收缩，核心力量',
            petBenefit: '狩猎本能满足，跳跃扑击',
          ),
          FitnessAction(
            name: '俄罗斯转体',
            audioGuide: '坐姿，双脚抬起，左右转动逗猫棒，让猫咪跟随！',
            durationSeconds: 50,
            demonstration: '俄罗斯转体+逗猫',
            benefit: '侧腹肌，腰部灵活性',
            petBenefit: '追踪训练，颈部灵活',
          ),
          FitnessAction(
            name: '腿部抬升',
            audioGuide: '平躺，双腿抬起，逗猫棒在腿上方移动，猫咪会跳起来扑！',
            durationSeconds: 40,
            demonstration: '抬腿+逗猫',
            benefit: '下腹肌锻炼',
            petBenefit: '跳跃高度挑战',
          ),
          FitnessAction(
            name: '放松拉伸',
            audioGuide: '太好了！放下逗猫棒，做拉伸。猫咪可能会来蹭你，享受这个温柔时刻。',
            durationSeconds: 60,
            demonstration: '腹肌拉伸+抚摸猫咪',
            benefit: '肌肉放松',
            petBenefit: '获得抚摸奖励',
          ),
        ],
      ),

      // 低强度 - 瑜伽
      FitnessCourse(
        id: 'cat_low_yoga',
        name: '人宠瑜伽猫式',
        description: '猫咪天生就是瑜伽大师！一起做猫式拉伸，享受平静时光。',
        durationMinutes: 5,
        intensity: 'low',
        petType: 'cat',
        caloriesEstimate: 35,
        petCaloriesEstimate: 0,
        iconEmoji: '🧘‍♀️',
        tags: ['瑜伽', '放松', '猫式', '呼噜声'],
        actions: [
          FitnessAction(
            name: '呼吸冥想',
            audioGuide: '盘腿坐下，深呼吸。如果猫咪愿意，让它坐在你的腿上。',
            durationSeconds: 60,
            demonstration: '冥想坐姿+猫咪在腿上',
            benefit: '心灵平静',
            petBenefit: '享受温暖怀抱',
          ),
          FitnessAction(
            name: '猫牛式',
            audioGuide: '四肢着地，做"猫式"拱背和"牛式"塌腰。观察你的猫咪，它是不是也在伸懒腰？',
            durationSeconds: 50,
            demonstration: '猫牛式呼吸',
            benefit: '脊柱灵活性，背部放松',
            petBenefit: '模仿主人伸展',
          ),
          FitnessAction(
            name: '下犬式',
            audioGuide: '进入下犬式。猫咪可能会从你身下走过，或者钻进你的"帐篷"里。',
            durationSeconds: 40,
            demonstration: '下犬式+猫咪探索',
            benefit: '全身拉伸',
            petBenefit: '探索游戏',
          ),
          FitnessAction(
            name: '婴儿式',
            audioGuide: '坐在脚跟上，额头贴地，进入婴儿式。感受背部的拉伸。',
            durationSeconds: 50,
            demonstration: '婴儿式放松',
            benefit: '深度放松',
            petBenefit: '猫咪可能会跳到背上',
          ),
          FitnessAction(
            name: '仰卧放松',
            audioGuide: '最后，平躺，全身放松。轻轻抚摸你身边的猫咪，感受它的呼噜声，这是最好的冥想音乐。',
            durationSeconds: 80,
            demonstration: '仰卧放松+抚摸猫咪',
            benefit: '彻底放松，减压',
            petBenefit: '呼噜声治愈，情感连接',
          ),
        ],
      ),

      // 中强度 - 灵活性
      FitnessCourse(
        id: 'cat_medium_flexibility',
        name: '灵活猫咪拉伸',
        description: '向猫咪学习柔韧性！一系列拉伸动作帮你提升身体灵活度。',
        durationMinutes: 5,
        intensity: 'medium',
        petType: 'cat',
        caloriesEstimate: 50,
        petCaloriesEstimate: 1,
        iconEmoji: '🤸',
        tags: ['柔韧', '拉伸', '灵活性'],
        actions: [
          FitnessAction(
            name: '颈部拉伸',
            audioGuide: '站立或坐姿，轻柔转动颈部。观察猫咪，它的颈部多么灵活！',
            durationSeconds: 40,
            demonstration: '颈部360度转动',
            benefit: '颈部灵活性，缓解僵硬',
            petBenefit: '观察主人',
          ),
          FitnessAction(
            name: '侧身拉伸',
            audioGuide: '站立，一只手臂举过头顶，向侧面弯曲。像猫咪侧身拉伸一样！',
            durationSeconds: 50,
            demonstration: '侧身大幅度拉伸',
            benefit: '侧腰、侧腹拉伸',
            petBenefit: '猫咪模仿伸展',
          ),
          FitnessAction(
            name: '前屈触地',
            audioGuide: '双腿伸直，向前弯腰，尽量触碰脚尖。猫咪可能会钻到你身下！',
            durationSeconds: 50,
            demonstration: '站姿前屈',
            benefit: '腿后侧、背部拉伸',
            petBenefit: '探索互动',
          ),
          FitnessAction(
            name: '蝴蝶式',
            audioGuide: '坐下,脚掌相对，膝盖向外。把猫咪玩具放在中间，吸引它靠近。',
            durationSeconds: 50,
            demonstration: '蝴蝶式+逗猫',
            benefit: '髋部、大腿内侧拉伸',
            petBenefit: '玩具互动',
          ),
          FitnessAction(
            name: '脊柱扭转',
            audioGuide: '坐姿脊柱扭转，左右各一次。猫咪的脊柱超级灵活，你也可以！',
            durationSeconds: 60,
            demonstration: '坐姿扭转',
            benefit: '脊柱灵活性，排毒',
            petBenefit: '观察主人',
          ),
          FitnessAction(
            name: '全身放松',
            audioGuide: '平躺，四肢伸展，像猫咪晒太阳一样彻底放松。',
            durationSeconds: 50,
            demonstration: '大字型放松',
            benefit: '全身放松',
            petBenefit: '可能会趴在主人身上',
          ),
        ],
      ),
    ];
  }

  /// 根据筛选条件获取课程
  static List<FitnessCourse> getFilteredCourses({
    int? durationMinutes,
    String? intensity,
    String? petType,
  }) {
    var courses = getAllCourses();

    if (durationMinutes != null) {
      courses = courses
          .where((c) => c.durationMinutes == durationMinutes)
          .toList();
    }

    if (intensity != null && intensity.isNotEmpty) {
      courses = courses.where((c) => c.intensity == intensity).toList();
    }

    if (petType != null && petType.isNotEmpty) {
      courses = courses.where((c) => c.petType == petType).toList();
    }

    return courses;
  }
}
