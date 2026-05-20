import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/design_system/peture_design_system.dart';
import '../../../shared/models/pet.dart';
import '../../../services/supabase_service.dart';

enum _PetType { cat, dog }

class PetPersonalityTestPage extends StatefulWidget {
  const PetPersonalityTestPage({super.key});

  @override
  State<PetPersonalityTestPage> createState() => _PetPersonalityTestPageState();
}

class _PetPersonalityTestPageState extends State<PetPersonalityTestPage> {
  final SupabaseService _supabaseService = SupabaseService();
  _PetType _selectedType = _PetType.cat;
  bool _started = false;
  int _currentQuestion = 0;
  List<int?> _answers = List<int?>.filled(12, null);
  _TestResult? _result;
  bool _viewingResult = false;
  final GlobalKey _shareCardKey = GlobalKey();
  List<Pet> _pets = const [];
  final Map<String, _SavedResult> _savedResultsByPetId = {};
  Pet? _pickedPet;
  Pet? _selectedPet;
  bool _isLoadingPets = false;
  String _userNickname = '用户';

  static const List<_QuizQuestion> _catQuestions = [
    _QuizQuestion('你回家时，它通常会怎么做？', [
      '完全不理我，像没看见',
      '抬头看一眼，继续忙自己的',
      '会走过来蹭蹭或叫几声',
      '会立刻跑来迎接、绕脚、喵喵叫',
      '像投诉一样大声叫，仿佛我迟到了',
    ]),
    _QuizQuestion('它会不会主动坐到你身边、腿上或键盘上？', [
      '几乎不会，它有自己的世界',
      '偶尔靠近，但不喜欢被打扰',
      '经常待在附近，但保持距离',
      '喜欢贴着我、踩奶、趴腿',
      '必须占据键盘、枕头、胸口等关键位置',
    ]),
    _QuizQuestion('饭点到了但你还没喂，它会怎么提醒？', [
      '没什么反应',
      '会在饭碗附近等',
      '会喵喵叫或盯着我',
      '会一路跟着我、催促我',
      '会拍东西、扒门、咬袋子或直接开闹',
    ]),
    _QuizQuestion('它对陌生人来家里的反应通常是？', [
      '立刻躲起来，直到人走',
      '躲一会儿再观察',
      '保持距离围观',
      '会主动闻闻、靠近',
      '像房东一样审查对方',
    ]),
    _QuizQuestion('它是否喜欢探索纸箱、袋子、柜子、抽屉等新空间？', [
      '几乎不感兴趣',
      '偶尔看看',
      '经常钻进去检查',
      '新东西一出现必须第一个调查',
      '会强行占领并宣布所有权',
    ]),
    _QuizQuestion('它会不会在半夜跑酷、蹦迪或突然暴走？', [
      '几乎不会，作息很稳',
      '偶尔会',
      '每周都有几次',
      '经常半夜冲刺',
      '每晚像在举办运动会',
    ]),
    _QuizQuestion('它对玩具的态度更接近哪一种？', [
      '大部分玩具都不感兴趣',
      '新玩具玩一会儿就腻',
      '固定喜欢几种玩具',
      '很容易被逗猫棒、球、激光吸引',
      '会自己找东西玩，甚至把家当游乐场',
    ]),
    _QuizQuestion('它是否会“记仇”或对不喜欢的事做出反应？', [
      '基本不记仇，过会儿就好',
      '会短暂不理人',
      '会躲开或保持距离',
      '会用眼神审判、冷战',
      '会报复性拍东西、咬人、乱尿等',
    ]),
    _QuizQuestion('它是否允许你摸肚子、剪指甲、抱抱或梳毛？', [
      '完全不允许',
      '只能摸特定部位',
      '心情好时可以',
      '大多数时候可以',
      '怎么摸都行，甚至主动要求',
    ]),
    _QuizQuestion('它在家里是否有固定“王座”或地盘？', [
      '没有明显固定地盘',
      '有几个常待的位置',
      '特别喜欢某个位置',
      '不喜欢别人或其他宠物靠近它的位置',
      '家里每个高处、纸箱、床位都是它的',
    ]),
    _QuizQuestion('它对其他猫、狗或小动物的态度如何？', [
      '非常害怕或排斥',
      '会躲开，不主动接触',
      '可以共处，但保持距离',
      '愿意闻闻、互动',
      '会主动压制、抢地盘或抢关注',
    ]),
    _QuizQuestion('如果它能发一条朋友圈，最可能是哪种语气？', [
      '“今天也不想上班，主要是我本来也不上。”',
      '“铲屎官迟到 3 分钟，已记录。”',
      '“我只是路过，顺便躺在你键盘上。”',
      '“新纸箱不错，已征用。”',
      '“世界很大，我要钻进每一个袋子看看。”',
    ]),
  ];

  static const List<_QuizQuestion> _dogQuestions = [
    _QuizQuestion('你回家时，它通常会怎么迎接你？', [
      '反应比较平静，只是看一眼',
      '会摇尾巴靠近',
      '会跑过来蹭蹭、转圈',
      '会跳起来、叼玩具、哼唧',
      '像失散多年重逢一样激动',
    ]),
    _QuizQuestion('它平时是否喜欢跟着你到处走？', [
      '不太跟，自己玩自己的',
      '偶尔跟着',
      '经常待在我附近',
      '我去哪它去哪',
      '连上厕所都要参与',
    ]),
    _QuizQuestion('它对陌生人的态度通常是？', [
      '害怕、躲避或紧张',
      '会观察，不马上靠近',
      '可以平静接触',
      '很快摇尾巴互动',
      '见谁都像多年好友',
    ]),
    _QuizQuestion('门外有声音、门铃响或有人经过时，它会怎么反应？', [
      '基本没反应',
      '会抬头观察',
      '会走到门口看',
      '会叫几声提醒',
      '会持续吠叫或非常激动',
    ]),
    _QuizQuestion('它每天的运动需求大概如何？', [
      '走一小会儿就满足',
      '正常散步即可',
      '喜欢多走一会儿',
      '不跑不开心',
      '像装了永动机',
    ]),
    _QuizQuestion('它对指令的反应如何，比如“坐下”“过来”“等一下”？', [
      '基本听不懂或不理',
      '看心情执行',
      '熟悉指令能执行',
      '大多数时候能配合',
      '反应很快，还会主动等夸奖',
    ]),
    _QuizQuestion('它是否容易被食物吸引？', [
      '对食物兴趣一般',
      '喜欢吃，但不夸张',
      '看到零食会变专注',
      '为了吃可以表演很多技能',
      '食物面前没有原则',
    ]),
    _QuizQuestion('它在家是否会拆家、咬东西、翻垃圾桶或偷东西？', [
      '几乎不会',
      '偶尔犯错',
      '无聊时会咬东西',
      '经常制造小事故',
      '家里装修风格由它决定',
    ]),
    _QuizQuestion('它和其他狗相处时通常怎样？', [
      '害怕或躲避',
      '会观察后再靠近',
      '可以正常闻闻、共处',
      '喜欢主动邀请玩耍',
      '特别兴奋，容易扑、追、抢玩具',
    ]),
    _QuizQuestion('它遇到新环境时，比如宠物店、医院、公园，会怎样？', [
      '明显害怕、发抖或躲避',
      '有点紧张，但能安抚',
      '观察一会儿就适应',
      '很快开始探索',
      '到哪都像主场',
    ]),
    _QuizQuestion('它是否会主动安慰你或感知你的情绪？', [
      '不太明显',
      '偶尔会靠近',
      '我情绪低落时会待在旁边',
      '会舔手、贴贴、求关注',
      '像专属心理咨询师一样守着我',
    ]),
    _QuizQuestion('如果它有一份家庭工作，最像哪种？', [
      '家庭首席保安，负责门口一切风吹草动',
      '气氛组组长，负责欢迎所有人',
      '健身教练，负责拉主人出门运动',
      '零食审计员，负责监督每一口食物',
      '情绪陪护师，负责贴贴和陪伴',
    ]),
  ];

  static const Map<String, List<_WeightedIndex>> _catDimensionWeights = {
    '黏人指数': [_WeightedIndex(0, 1.3), _WeightedIndex(1, 1.2), _WeightedIndex(8, 1.1)],
    '饭点统治力': [_WeightedIndex(2, 1.5), _WeightedIndex(11, 1.0)],
    '好奇探索欲': [_WeightedIndex(4, 1.2), _WeightedIndex(6, 1.3)],
    '夜间能量值': [_WeightedIndex(5, 1.5), _WeightedIndex(6, 1.0)],
    '领地支配感': [_WeightedIndex(3, 1.1), _WeightedIndex(9, 1.4), _WeightedIndex(10, 1.2)],
    '敏感记仇值': [_WeightedIndex(7, 1.4), _WeightedIndex(8, 1.1), _WeightedIndex(3, 0.9)],
  };

  static const Map<String, List<_WeightedIndex>> _dogDimensionWeights = {
    '社交热情值': [_WeightedIndex(0, 1.3), _WeightedIndex(2, 1.4), _WeightedIndex(8, 1.1)],
    '黏人陪伴值': [_WeightedIndex(1, 1.4), _WeightedIndex(10, 1.2)],
    '运动能量值': [_WeightedIndex(4, 1.5), _WeightedIndex(9, 1.0)],
    '守护警觉值': [_WeightedIndex(3, 1.5), _WeightedIndex(9, 1.0)],
    '训练协作值': [_WeightedIndex(5, 1.5), _WeightedIndex(6, 1.0)],
    '捣蛋创造力': [_WeightedIndex(7, 1.6), _WeightedIndex(6, 1.0), _WeightedIndex(4, 0.8)],
  };

  static const List<List<_WeightedIndex>> _catConfidenceGroups = [
    [_WeightedIndex(0, 1), _WeightedIndex(1, 1), _WeightedIndex(8, 1)],
    [_WeightedIndex(2, 1), _WeightedIndex(11, 1)],
    [_WeightedIndex(4, 1), _WeightedIndex(6, 1)],
    [_WeightedIndex(5, 1), _WeightedIndex(6, 1)],
    [_WeightedIndex(3, 1), _WeightedIndex(9, 1), _WeightedIndex(10, 1)],
    [_WeightedIndex(7, 1), _WeightedIndex(8, 1), _WeightedIndex(3, 1)],
  ];

  static const List<List<_WeightedIndex>> _dogConfidenceGroups = [
    [_WeightedIndex(0, 1), _WeightedIndex(2, 1), _WeightedIndex(8, 1)],
    [_WeightedIndex(1, 1), _WeightedIndex(10, 1)],
    [_WeightedIndex(4, 1), _WeightedIndex(9, 1)],
    [_WeightedIndex(3, 1), _WeightedIndex(9, 1)],
    [_WeightedIndex(5, 1), _WeightedIndex(6, 1)],
    [_WeightedIndex(7, 1), _WeightedIndex(6, 1), _WeightedIndex(4, 1)],
  ];

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    if (!mounted) return;
    setState(() => _isLoadingPets = true);
    try {
      final petsData = await _supabaseService.getAllPets();
      final pets = petsData.map(Pet.fromMap).toList();
      final sortedPets = await _sortPetsByTestStatus(pets);
      final profile = await _supabaseService.getUserProfile();
      final nickname = (profile?['nickname'] as String?)?.trim();
      if (!mounted) return;
      setState(() {
        _pets = sortedPets;
        _userNickname =
            (nickname == null || nickname.isEmpty) ? '用户' : nickname;
        _isLoadingPets = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPets = false);
    }
  }

  Future<List<Pet>> _sortPetsByTestStatus(List<Pet> pets) async {
    final prefs = await SharedPreferences.getInstance();
    _savedResultsByPetId.clear();
    for (final pet in pets) {
      final petId = pet.id ?? '';
      if (petId.isEmpty) continue;
      final raw = prefs.getString('personality_test_result_$petId');
      if (raw == null || raw.isEmpty) continue;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final result = _TestResult.fromJson(map);
        final testedAtMillis = (map['testedAt'] as num?)?.toInt() ?? 0;
        final testedAt = testedAtMillis > 0
            ? DateTime.fromMillisecondsSinceEpoch(testedAtMillis)
            : null;
        _savedResultsByPetId[petId] = _SavedResult(
          result: result,
          testedAt: testedAt,
        );
      } catch (_) {}
    }

    final copied = [...pets];
    copied.sort((a, b) {
      final aSaved = _savedResultsByPetId[a.id ?? ''];
      final bSaved = _savedResultsByPetId[b.id ?? ''];
      if (aSaved != null && bSaved == null) return -1;
      if (aSaved == null && bSaved != null) return 1;
      if (aSaved != null && bSaved != null) {
        final ta = aSaved.testedAt?.millisecondsSinceEpoch ?? 0;
        final tb = bSaved.testedAt?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      }
      return a.name.compareTo(b.name);
    });
    return copied;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PetureColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('宠格测试'),
      ),
      body: (!_started && !_viewingResult)
          ? _buildPetSelectionView()
          : (_viewingResult && _result != null)
              ? _buildResultView()
              : _buildQuizView(),
    );
  }

  Widget _buildPetSelectionView() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const Text(
                '选择要测试的宠物',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: PetureColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '先选择宠物，再开始宠格测试',
                style: TextStyle(fontSize: 13, color: PetureColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (_isLoadingPets)
                const Center(child: CircularProgressIndicator())
              else if (_pets.isEmpty)
                _buildEmptyPetsState()
              else
                ..._pets.map((pet) {
                  final isSelected = _pickedPet?.id == pet.id;
                  final saved = _savedResultsByPetId[pet.id ?? ''];
                  final hasResult = saved != null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => _onPetPicked(pet),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF2ECFF)
                              : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFFE8E2F4),
                            width: isSelected ? 1.6 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFFEDE7FF),
                              child: ClipOval(
                                child: _buildPetAvatar(pet, size: 40),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pet.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: PetureColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${pet.type} · ${pet.breed}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: PetureColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _buildStatusChip(
                                        label: hasResult ? '已测试' : '未测试',
                                        foreground: hasResult
                                            ? const Color(0xFF5B4EC7)
                                            : const Color(0xFF7A728C),
                                        background: hasResult
                                            ? const Color(0xFFEDE7FF)
                                            : const Color(0xFFF1EFF6),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          hasResult
                                              ? '${saved.result.personaName} · ${_formatTestDate(saved.testedAt)}'
                                              : '可开始宠格测试',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: PetureColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.chevron_right_rounded,
                              color: const Color(0xFF7C3AED),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pickedPet != null &&
                  _pickedPet!.id != null &&
                  _savedResultsByPetId[_pickedPet!.id!] != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    onPressed: _startQuizForPickedPet,
                    child: const Text('重新测试'),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _pickedPet == null ? null : _onPrimaryActionPressed,
                  child: Text(_primaryActionLabel),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onPetPicked(Pet pet) {
    final petType = pet.type.trim().toLowerCase();
    final isCat = petType.contains('猫') || petType.contains('cat');
    setState(() {
      _pickedPet = pet;
      _selectedType = isCat ? _PetType.cat : _PetType.dog;
    });
  }

  String get _primaryActionLabel {
    final picked = _pickedPet;
    if (picked == null) return '开始测试';
    final hasResult = _savedResultsByPetId[picked.id ?? ''] != null;
    return hasResult ? '查看结果' : '开始测试';
  }

  void _onPrimaryActionPressed() {
    final picked = _pickedPet;
    if (picked == null) return;
    final saved = _savedResultsByPetId[picked.id ?? ''];
    if (saved != null) {
      setState(() {
        _selectedPet = picked;
        _result = saved.result;
        _viewingResult = true;
        _started = false;
      });
      return;
    }
    _startQuizForPickedPet();
  }

  void _startQuizForPickedPet() {
    final pet = _pickedPet;
    if (pet == null) return;
    setState(() {
      _selectedPet = pet;
      _started = true;
      _viewingResult = false;
      _result = null;
      _currentQuestion = 0;
      _answers = List<int?>.filled(12, null);
    });
  }

  Widget _buildEmptyPetsState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        '还没有宠物档案，请先到“我的-宠物档案”添加宠物。',
        style: TextStyle(fontSize: 13, color: PetureColors.textSecondary),
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required Color foreground,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  String _formatTestDate(DateTime? dt) {
    if (dt == null) return '已测试';
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  _PersonaTheme _resolvePersonaTheme(String personaName) {
    const themes = <String, _PersonaTheme>{
      '玻璃心小黏糕': _PersonaTheme.pink,
      '家庭实际房主': _PersonaTheme.gold,
      '午夜探险家': _PersonaTheme.indigo,
      '冷宫贵妃': _PersonaTheme.slate,
      '阴阳怪气审判官': _PersonaTheme.copper,
      '纸箱征服者': _PersonaTheme.olive,
      '均衡观察型': _PersonaTheme.teal,
      '傲娇观察家': _PersonaTheme.plum,
      '小区外交部长': _PersonaTheme.sky,
      '家庭首席保安': _PersonaTheme.steel,
      '零食驱动型学霸': _PersonaTheme.orange,
      '拆家项目经理': _PersonaTheme.red,
      '情绪陪护师': _PersonaTheme.green,
      '慢热观察员': _PersonaTheme.navy,
      '均衡陪伴型': _PersonaTheme.cyan,
      '元气陪伴官': _PersonaTheme.violet,
    };
    return themes[personaName] ?? _PersonaTheme.violet;
  }

  Widget _buildPetAvatar(Pet pet, {double size = 40}) {
    final avatar = pet.avatar?.trim();
    if (avatar == null || avatar.isEmpty) {
      return _buildAvatarFallback(pet, size);
    }

    final uri = Uri.tryParse(avatar);
    final isHttp = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    if (isHttp) {
      return CachedNetworkImage(
        imageUrl: avatar,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _buildAvatarFallback(pet, size),
      );
    }

    if (File(avatar).existsSync()) {
      return Image.file(
        File(avatar),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }

    return _buildAvatarFallback(pet, size);
  }

  Widget _buildAvatarFallback(Pet pet, double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: const Color(0xFFEDE7FF),
      child: Text(
        pet.name.isNotEmpty ? pet.name.characters.first : '🐾',
        style: const TextStyle(fontSize: 16, color: Color(0xFF5B4EC7)),
      ),
    );
  }

  Widget _buildQuizView() {
    final questions =
        _selectedType == _PetType.cat ? _catQuestions : _dogQuestions;
    final currentQuestion = questions[_currentQuestion];
    final selectedValue = _answers[_currentQuestion];
    final progress = (_currentQuestion + 1) / questions.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedType == _PetType.cat ? '猫咪版' : '狗狗版'} · 第 ${_currentQuestion + 1}/12 题',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PetureColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFEFEAF8),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Q${_currentQuestion + 1}. ${currentQuestion.title}',
              style: const TextStyle(
                fontSize: 17,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: PetureColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...currentQuestion.options.asMap().entries.map((entry) {
            final optionValue = entry.key;
            final selected = selectedValue == optionValue;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  setState(() => _answers[_currentQuestion] = optionValue);
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color:
                        selected ? const Color(0xFFEDE7FF) : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF7C3AED)
                          : Colors.grey.withOpacity(0.18),
                    ),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? const Color(0xFF5B4EC7)
                          : PetureColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  color: const Color(0xFFE9E6F2),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _currentQuestion == 0
                      ? null
                      : () => setState(() => _currentQuestion--),
                  child: const Text(
                    '上一题',
                    style: TextStyle(color: Color(0xFF57496D)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _answers[_currentQuestion] == null
                      ? null
                      : () {
                    if (_currentQuestion < 11) {
                      setState(() => _currentQuestion++);
                      return;
                    }
                    _submitQuiz();
                  },
                  child: Text(_currentQuestion == 11 ? '生成宠格卡' : '下一题'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final result = _result!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        RepaintBoundary(
          key: _shareCardKey,
          child: _buildShareCard(result),
        ),
        const SizedBox(height: 12),
        CupertinoButton(
          color: const Color(0xFFEDE7FF),
          borderRadius: BorderRadius.circular(12),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: result.shareText));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('分享文案已复制')),
            );
          },
          child: const Text(
            '复制分享文案',
            style: TextStyle(color: Color(0xFF5B4EC7)),
          ),
        ),
        const SizedBox(height: 10),
        CupertinoButton.filled(
          borderRadius: BorderRadius.circular(12),
          onPressed: _shareAsImage,
          child: const Text('生成图片分享'),
        ),
        const SizedBox(height: 10),
        CupertinoButton.filled(
          borderRadius: BorderRadius.circular(12),
          onPressed: () {
            setState(() {
              _viewingResult = false;
              _started = true;
              _result = null;
              _currentQuestion = 0;
              _answers = List<int?>.filled(12, null);
            });
          },
          child: const Text('重新测试'),
        ),
      ],
    );
  }

  Widget _buildShareCard(_TestResult result) {
    final entries = result.dimensions.entries.toList();
    final pet = _selectedPet;
    final theme = _resolvePersonaTheme(result.personaName);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.backgroundStart, theme.backgroundEnd],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor,
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Peture 宠格卡 · ${result.personaName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: PetureColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            result.tagline,
            style: const TextStyle(
              fontSize: 14,
              color: PetureColors.textSecondary,
            ),
          ),
          if (pet != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F4FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE7E0F6)),
              ),
                child: Row(
                  children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFEDE7FF),
                    child: ClipOval(
                      child: _buildPetAvatar(pet, size: 36),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '昵称：${pet.name}\n品种：${pet.breed}\n主人：$_userNickname',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: PetureColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              width: 248,
              height: 248,
              child: CustomPaint(
                painter: _RadarChartPainter(
                  entries,
                  accentColor: theme.accentColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildShareSection('主人相处指南', result.guides),
          const SizedBox(height: 6),
          _buildShareSection('宠物口头禅', result.catchphrases),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '智宠合生 Peture',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8A7AA8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '扫码安装获取同款宠格测试',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9D91B6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '结果置信度：${result.confidenceScore}（${result.confidenceLevel}）',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB0A6C4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE7E0F6)),
                ),
                child: QrImageView(
                  data: 'https://testflight.apple.com/join/6ZVsvBuY',
                  version: QrVersions.auto,
                  gapless: true,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF4A3D6B),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF4A3D6B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareSection(String title, List<String> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF).withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E0F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: PetureColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          ...items.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '• $e',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: PetureColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareAsImage() async {
    try {
      final boundary = _shareCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/peture_personality_card_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(pngBytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: _result?.shareText,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('生成分享图片失败，请稍后重试')),
      );
    }
  }

  void _submitQuiz() {
    final unanswered = _answers.indexWhere((e) => e == null);
    if (unanswered != -1) {
      setState(() => _currentQuestion = unanswered);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还有未完成题目，已为你定位到对应题目')),
      );
      return;
    }
    final answers = _answers.map((e) => e ?? 0).toList(growable: false);
    setState(() {
      _result = _selectedType == _PetType.cat
          ? _buildCatResult(answers)
          : _buildDogResult(answers);
      _viewingResult = true;
      _started = false;
    });
    _persistResultForCurrentPet();
  }

  Future<void> _persistResultForCurrentPet() async {
    final petId = _selectedPet?.id;
    if (petId == null || petId.isEmpty || _result == null) return;
    final payload = _result!.toJson()
      ..['testedAt'] = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'personality_test_result_$petId',
      jsonEncode(payload),
    );
    _savedResultsByPetId[petId] = _SavedResult(
      result: _result!,
      testedAt: DateTime.now(),
    );
  }

  _TestResult _buildCatResult(List<int> a) {
    final dimensions = _computeDimensions(a, _catDimensionWeights);
    final top = _topTwoKeys(dimensions);
    final topScore = dimensions[top[0]] ?? 0;
    final combo = '${top[0]}|${top[1]}';
    final confidence = _buildConfidence(a, _catConfidenceGroups);
    final petName = _selectedPet?.name ?? '我家主子';
    final petBreed = _selectedPet?.breed ?? '神秘品种';

    const mapping = <String, (String, String)>{
      '黏人指数|敏感记仇值': ('玻璃心小黏糕', '嘴上不说爱你，但你晚回家一分钟它都记得。'),
      '领地支配感|饭点统治力': ('家庭实际房主', '这不是你家，这是它允许你住的地方。'),
      '好奇探索欲|夜间能量值': ('午夜探险家', '白天充电，晚上开演唱会。'),
      '黏人指数|领地支配感': ('冷宫贵妃', '可以爱它，但不能打扰它。'),
      '饭点统治力|敏感记仇值': ('阴阳怪气审判官', '它不吵，它只是用眼神给你判刑。'),
      '好奇探索欲|领地支配感': ('纸箱征服者', '所有新东西，最终都会成为它的领土。'),
    };
    final data = topScore < 60
        ? ('均衡观察型', '整体性格较均衡，建议结合日常长期观察。')
        : (mapping[combo] ?? ('傲娇观察家', '边界清晰、个性鲜明，气场一直在线。'));
    final guides = <String>[
      '饭点尽量准时，不然它会把你列入“失信名单”。',
      '给它留一个专属角落，它需要体面地独处一下。',
      '每天 10 分钟高质量逗玩，比无效陪伴更加分。',
    ];
    if (a[7] == 4) {
      guides.add('如果它开始“剧情升级”（频繁攻击、乱尿、躲藏），先排查压力和健康。');
    }
    return _TestResult(
      personaName: data.$1,
      tagline: data.$2,
      dimensions: dimensions,
      guides: guides,
      catchphrases: const ['今天的罐罐，审批通过了吗？', '这个位置从现在起归我管。', '你可以摸我三秒，别超时。'],
      shareText: _buildShareText(
        petName: petName,
        petBreed: petBreed,
        personaName: data.$1,
        tagline: data.$2,
        dimensions: dimensions,
        confidence: confidence,
        catchphrase: '今天的罐罐，审批通过了吗？',
      ),
      confidenceScore: confidence.score,
      confidenceLevel: confidence.level,
    );
  }

  _TestResult _buildDogResult(List<int> a) {
    final dimensions = _computeDimensions(a, _dogDimensionWeights);
    final top = _topTwoKeys(dimensions);
    final combo = '${top[0]}|${top[1]}';
    final topScore = dimensions[top[0]] ?? 0;
    final confidence = _buildConfidence(a, _dogConfidenceGroups);
    final petName = _selectedPet?.name ?? '我家毛孩子';
    final petBreed = _selectedPet?.breed ?? '神秘品种';

    const mapping = <String, (String, String)>{
      '社交热情值|运动能量值': ('小区外交部长', '没有陌生人，只有还没认识的朋友。'),
      '守护警觉值|黏人陪伴值': ('家庭首席保安', '门外一片叶子落下，它都要立案调查。'),
      '训练协作值|捣蛋创造力': ('零食驱动型学霸', '只要奖励到位，技能马上学会。'),
      '运动能量值|捣蛋创造力': ('拆家项目经理', '它不是拆家，它是在重新设计空间。'),
      '黏人陪伴值|社交热情值': ('情绪陪护师', '它可能听不懂你的烦恼，但一定会陪着你。'),
      '社交热情值|守护警觉值': ('慢热观察员', '先观察，再决定要不要把你纳入朋友圈。'),
    };
    final data = topScore < 60
        ? ('均衡陪伴型', '整体表现较均衡，建议持续观察多场景行为。')
        : (mapping[combo] ?? ('元气陪伴官', '热情稳定、互动积极，是家里的快乐发动机。'));
    return _TestResult(
      personaName: data.$1,
      tagline: data.$2,
      dimensions: dimensions,
      guides: const ['每天安排稳定放电，不然它会自己开发“新项目”。', '训练时多夸奖+小零食，学习速度会快到离谱。', '进社交场景前先热身，避免它一上来就“全开麦”。'],
      catchphrases: const ['我们现在就出门可以吗？', '这个闻起来像能吃，我申请试一口。', '带我一起，我保证只兴奋一点点。'],
      shareText: _buildShareText(
        petName: petName,
        petBreed: petBreed,
        personaName: data.$1,
        tagline: data.$2,
        dimensions: dimensions,
        confidence: confidence,
        catchphrase: '我们现在就出门可以吗？',
      ),
      confidenceScore: confidence.score,
      confidenceLevel: confidence.level,
    );
  }

  String _buildShareText({
    required String petName,
    required String petBreed,
    required String personaName,
    required String tagline,
    required Map<String, int> dimensions,
    required _Confidence confidence,
    required String catchphrase,
  }) {
    final lines = dimensions.entries
        .map((e) => '${e.key} ${e.value}')
        .join('｜');
    return '我刚给 $petName（$petBreed）做了 Peture 宠格测试！\n'
        '鉴定结果：【$personaName】\n'
        '$tagline\n'
        '六维雷达：$lines\n'
        '宠物口头禅：$catchphrase\n'
        '结果置信度：${confidence.score}（${confidence.level}）\n'
        '扫码安装 Peture，给你家毛孩子也测一张同款宠格卡～\n'
        '下载链接：https://peturezchs.github.io/';
  }

  int _weightedScore(List<int> answers, List<_WeightedIndex> items) {
    double total = 0;
    double max = 0;
    for (final item in items) {
      total += answers[item.index] * item.weight;
      max += 4 * item.weight;
    }
    return ((total / max) * 100).round();
  }

  Map<String, int> _computeDimensions(
    List<int> answers,
    Map<String, List<_WeightedIndex>> config,
  ) {
    return config.map((key, items) => MapEntry(key, _weightedScore(answers, items)));
  }

  _Confidence _buildConfidence(List<int> answers, List<List<_WeightedIndex>> groups) {
    double confidencePoints = 0;
    for (final group in groups) {
      final values = group.map((g) => answers[g.index]).toList();
      final range = values.reduce((a, b) => a > b ? a : b) -
          values.reduce((a, b) => a < b ? a : b);
      if (range <= 1) {
        confidencePoints += 90;
      } else if (range == 2) {
        confidencePoints += 70;
      } else {
        confidencePoints += 50;
      }
    }
    final score = (confidencePoints / groups.length).round();
    final level = score >= 80
        ? '高'
        : score >= 65
            ? '中'
            : '低';
    return _Confidence(score, level);
  }

  List<String> _topTwoKeys(Map<String, int> dimensions) {
    final entries = dimensions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [entries[0].key, entries[1].key];
  }

}

class _TestResult {
  _TestResult({
    required this.personaName,
    required this.tagline,
    required this.dimensions,
    required this.guides,
    required this.catchphrases,
    required this.shareText,
    required this.confidenceScore,
    required this.confidenceLevel,
  });

  final String personaName;
  final String tagline;
  final Map<String, int> dimensions;
  final List<String> guides;
  final List<String> catchphrases;
  final String shareText;
  final int confidenceScore;
  final String confidenceLevel;

  Map<String, dynamic> toJson() => {
        'personaName': personaName,
        'tagline': tagline,
        'dimensions': dimensions,
        'guides': guides,
        'catchphrases': catchphrases,
        'shareText': shareText,
        'confidenceScore': confidenceScore,
        'confidenceLevel': confidenceLevel,
      };
  factory _TestResult.fromJson(Map<String, dynamic> map) {
    return _TestResult(
      personaName: map['personaName']?.toString() ?? '',
      tagline: map['tagline']?.toString() ?? '',
      dimensions: Map<String, int>.from(map['dimensions'] as Map? ?? {}),
      guides: (map['guides'] as List? ?? []).map((e) => e.toString()).toList(),
      catchphrases: (map['catchphrases'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      shareText: map['shareText']?.toString() ?? '',
      confidenceScore: (map['confidenceScore'] as num?)?.toInt() ?? 0,
      confidenceLevel: map['confidenceLevel']?.toString() ?? '低',
    );
  }
}

class _SavedResult {
  const _SavedResult({
    required this.result,
    required this.testedAt,
  });

  final _TestResult result;
  final DateTime? testedAt;
}

class _QuizQuestion {
  const _QuizQuestion(this.title, this.options);

  final String title;
  final List<String> options;
}

class _WeightedIndex {
  const _WeightedIndex(this.index, this.weight);

  final int index;
  final double weight;
}

class _Confidence {
  const _Confidence(this.score, this.level);

  final int score;
  final String level;
}

class _PersonaTheme {
  const _PersonaTheme({
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.borderColor,
    required this.shadowColor,
    required this.accentColor,
  });

  final Color backgroundStart;
  final Color backgroundEnd;
  final Color borderColor;
  final Color shadowColor;
  final Color accentColor;

  static const violet = _PersonaTheme(
    backgroundStart: Color(0xFFFFFFFF),
    backgroundEnd: Color(0xFFF4EEFF),
    borderColor: Color(0xFFDDD0F5),
    shadowColor: Color(0x227C3AED),
    accentColor: Color(0xFF7C3AED),
  );
  static const pink = _PersonaTheme(
    backgroundStart: Color(0xFFFFFCFE),
    backgroundEnd: Color(0xFFFFEEF5),
    borderColor: Color(0xFFF5CFE0),
    shadowColor: Color(0x22E15B94),
    accentColor: Color(0xFFE15B94),
  );
  static const gold = _PersonaTheme(
    backgroundStart: Color(0xFFFFFEF9),
    backgroundEnd: Color(0xFFFFF2D9),
    borderColor: Color(0xFFEFD7A4),
    shadowColor: Color(0x22C4932B),
    accentColor: Color(0xFFC4932B),
  );
  static const indigo = _PersonaTheme(
    backgroundStart: Color(0xFFFCFCFF),
    backgroundEnd: Color(0xFFEDEFFF),
    borderColor: Color(0xFFD0D6F8),
    shadowColor: Color(0x224A5ED1),
    accentColor: Color(0xFF4A5ED1),
  );
  static const slate = _PersonaTheme(
    backgroundStart: Color(0xFFFFFFFF),
    backgroundEnd: Color(0xFFF1F3F7),
    borderColor: Color(0xFFD8DEE8),
    shadowColor: Color(0x223E4E67),
    accentColor: Color(0xFF3E4E67),
  );
  static const copper = _PersonaTheme(
    backgroundStart: Color(0xFFFFFCFA),
    backgroundEnd: Color(0xFFFFEFE7),
    borderColor: Color(0xFFF0D0BF),
    shadowColor: Color(0x22C06A45),
    accentColor: Color(0xFFC06A45),
  );
  static const olive = _PersonaTheme(
    backgroundStart: Color(0xFFFEFFF8),
    backgroundEnd: Color(0xFFF2F8DE),
    borderColor: Color(0xFFDCE9B3),
    shadowColor: Color(0x2283A03A),
    accentColor: Color(0xFF83A03A),
  );
  static const teal = _PersonaTheme(
    backgroundStart: Color(0xFFFAFFFF),
    backgroundEnd: Color(0xFFE6F8F8),
    borderColor: Color(0xFFC5E5E5),
    shadowColor: Color(0x2240A4A4),
    accentColor: Color(0xFF40A4A4),
  );
  static const plum = _PersonaTheme(
    backgroundStart: Color(0xFFFFFCFF),
    backgroundEnd: Color(0xFFF6EBFA),
    borderColor: Color(0xFFE5CDEE),
    shadowColor: Color(0x22904CB2),
    accentColor: Color(0xFF904CB2),
  );
  static const sky = _PersonaTheme(
    backgroundStart: Color(0xFFF9FDFF),
    backgroundEnd: Color(0xFFE8F5FF),
    borderColor: Color(0xFFCBE3F7),
    shadowColor: Color(0x22408CCF),
    accentColor: Color(0xFF408CCF),
  );
  static const steel = _PersonaTheme(
    backgroundStart: Color(0xFFFCFDFF),
    backgroundEnd: Color(0xFFEAEFF5),
    borderColor: Color(0xFFCBD7E4),
    shadowColor: Color(0x224B6B92),
    accentColor: Color(0xFF4B6B92),
  );
  static const orange = _PersonaTheme(
    backgroundStart: Color(0xFFFFFCF7),
    backgroundEnd: Color(0xFFFFF0D9),
    borderColor: Color(0xFFF6D5A8),
    shadowColor: Color(0x22D9872F),
    accentColor: Color(0xFFD9872F),
  );
  static const red = _PersonaTheme(
    backgroundStart: Color(0xFFFFFBFB),
    backgroundEnd: Color(0xFFFFECE9),
    borderColor: Color(0xFFF3C9C2),
    shadowColor: Color(0x22D05A4E),
    accentColor: Color(0xFFD05A4E),
  );
  static const green = _PersonaTheme(
    backgroundStart: Color(0xFFF9FFF9),
    backgroundEnd: Color(0xFFE8F8E8),
    borderColor: Color(0xFFCDE9CD),
    shadowColor: Color(0x22489D61),
    accentColor: Color(0xFF489D61),
  );
  static const navy = _PersonaTheme(
    backgroundStart: Color(0xFFFBFCFF),
    backgroundEnd: Color(0xFFEAEFFC),
    borderColor: Color(0xFFCDD7F0),
    shadowColor: Color(0x223E5FAE),
    accentColor: Color(0xFF3E5FAE),
  );
  static const cyan = _PersonaTheme(
    backgroundStart: Color(0xFFF9FFFF),
    backgroundEnd: Color(0xFFE8FAFF),
    borderColor: Color(0xFFCBEAF3),
    shadowColor: Color(0x22409BB0),
    accentColor: Color(0xFF409BB0),
  );
}

class _RadarChartPainter extends CustomPainter {
  _RadarChartPainter(
    this.entries, {
    required this.accentColor,
  });

  final List<MapEntry<String, int>> entries;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length != 6) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.24;
    const levels = 5;
    final axisPaint = Paint()
      ..color = const Color(0xFFDCD5EC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final dataFill = Paint()
      ..color = accentColor.withOpacity(0.38)
      ..style = PaintingStyle.fill;
    final dataStroke = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    List<Offset> vertices(double r) => List.generate(6, (i) {
          final angle = -math.pi / 2 + (2 * math.pi / 6) * i;
          return Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
        });

    for (var l = 1; l <= levels; l++) {
      final p = Path()..addPolygon(vertices(radius * l / levels), true);
      canvas.drawPath(p, axisPaint);
    }
    final outer = vertices(radius);
    for (final p in outer) {
      canvas.drawLine(center, p, axisPaint);
    }

    final dataPoints = List.generate(6, (i) {
      final valueRatio = (entries[i].value / 100).clamp(0.0, 1.0);
      final angle = -math.pi / 2 + (2 * math.pi / 6) * i;
      final r = radius * valueRatio;
      return Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
    });
    final dataPath = Path()..addPolygon(dataPoints, true);
    canvas.drawPath(dataPath, dataFill);
    canvas.drawPath(dataPath, dataStroke);

    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + (2 * math.pi / 6) * i;
      final anchor = Offset(
        center.dx + (radius + 24) * math.cos(angle),
        center.dy + (radius + 24) * math.sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${entries[i].key}\n${entries[i].value}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5C5570),
            height: 1.25,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: 86);

      var dx = anchor.dx - tp.width / 2;
      var dy = anchor.dy - tp.height / 2;
      const padding = 4.0;
      dx = dx.clamp(padding, size.width - tp.width - padding);
      dy = dy.clamp(padding, size.height - tp.height - padding);
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) =>
      oldDelegate.entries != entries || oldDelegate.accentColor != accentColor;
}
