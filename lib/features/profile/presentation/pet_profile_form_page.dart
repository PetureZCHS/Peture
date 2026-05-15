import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/page_tracker_mixin.dart';
import '../../../shared/utils/user_avatar_helper.dart';
import '../../../shared/utils/avatar_image_helper.dart';
import '../../../shared/utils/loading_guard_mixin.dart';
import '../../../services/supabase_service.dart';
import '../../moderation/data/moderation_client.dart';
import '../../moderation/domain/moderation_scene.dart';
import '../../moderation/utils/moderation_guard.dart';

/// 宠物档案表单页面 - 模仿截图设计
class PetProfileFormPage extends StatefulWidget {
  final Map<String, dynamic>? initialData; // 编辑时传入现有数据

  const PetProfileFormPage({super.key, this.initialData});

  @override
  State<PetProfileFormPage> createState() => _PetProfileFormPageState();
}

class _PetProfileFormPageState extends State<PetProfileFormPage>
    with LoadingGuardMixin, PageTrackerMixin<PetProfileFormPage> {
  late final ModerationGuard _moderationGuard;
  String? _petId;
  File? _avatarFile;
  File? _lifePhotoFile;

  @override
  String get analyticsPageName => 'pet_profile_form';

  /// 编辑模式下云端头像 URL（仅展示，未重新选择文件时保留）
  String? _avatarUrl;
  String? _lifePhotoUrl;
  String? _petName;
  String? _petType; // 宠物类型：狗狗/猫咪
  String? _petSpecies; // 品种
  DateTime? _birthDate;
  String? _gender; // 弟弟/妹妹/未知
  String? _neuterStatus; // 已绝育/未绝育
  double? _weight; // kg
// 用户头像路径

  // 主人昵称相关

  String? _ownerNickname; // 该宠物对主人的自定义称呼
  String _defaultOwnerNickname = '主人'; // 用户默认称呼
  bool _isSaving = false;
  String? _lifePhotoPrecheckReason; // 生活照预检查失败原因

  final Map<String, List<String>> _speciesOptions = {
    '猫咪': [
      '布偶猫',
      '暹罗猫',
      '缅因猫',
      '英短猫',
      '狸花猫',
      '美短猫',
      '英短猫',
      '英短金渐层',
      '埃及猫',
      '奥西猫',
      '阿比西尼亚猫',
      '伯曼猫',
      '巴厘猫',
      '布偶猫',
      '彼得秃猫',
      '波斯猫',
      '波米拉猫',
      '东奇尼猫',
      '东方猫',
      '哈瓦那猫',
      '喜马拉雅猫',
      '加州猫',
      '柯尼斯卷毛猫',
      '柯拉特猫',
      '拉邦猫',
      '拉彼姆猫',
      '曼岛猫',
      '孟买猫',
      '孟加拉豹猫',
      '缅甸猫',
      '美短猫',
      '美国卷耳猫',
      '美国硬毛猫',
      '挪威森林猫',
      '欧缅猫',
      '热带草原猫',
      '折耳猫',
      '斯芬克斯猫',
      '塞尔凯克卷毛猫',
      '索马里猫',
      '土耳其安哥拉猫',
      '土耳其梵猫',
      '新加坡猫',
      '异短猫',
      '中国狸花猫',
      '其他猫咪',
    ],
    '狗狗': [
      '博美犬',
      '哈士奇',
      '拉布拉多',
      '柴犬',
      '金毛犬',
      '贵宾犬',
      '边牧犬',
      '柯基犬',
      '爱尔兰猎狼犬',
      '爱尔兰雪达犬',
      '阿富汗犬',
      '阿拉斯加犬',
      '伯恩山犬',
      '北京犬',
      '博美犬',
      '巴仙吉犬',
      '巴吉度犬',
      '巴哥犬',
      '贵宾犬',
      '比利时牧羊犬',
      '大麦町犬',
      '斗牛梗',
      '德牧犬',
      '杜宾犬',
      '法斗犬',
      '芬兰猎犬',
      '刚毛猎狐梗',
      '古代牧羊犬',
      '哥威斯犬',
      '贵宾犬',
      '哈士奇',
      '惠比特犬',
      '荷兰毛狮犬',
      '吉娃娃',
      '京巴犬',
      '金毛犬',
      '卷毛寻回犬',
      '柯基犬',
      '可卡犬',
      '凯恩梗',
      '库瓦兹犬',
      '拉布拉多犬',
      '罗威纳犬',
      '腊肠犬',
      '灵缇犬',
      '猎狐犬',
      '拉萨犬',
      '马尔济斯犬',
      '美可卡犬',
      '雪纳瑞犬',
      '迷你杜宾犬',
      '纽芬兰犬',
      '牛头梗',
      '葡萄牙水犬',
      '平毛寻回犬',
      '秋田犬',
      '拳师犬',
      '日本狆',
      '柴犬',
      '萨摩耶犬',
      '圣伯纳犬',
      '苏格兰梗',
      '松狮犬',
      '苏俄猎狼犬',
      '沙皮犬',
      '丝毛梗',
      '苏牧犬',
      '泰迪犬',
      '腊肠犬',
      '威尔士柯基犬',
      '惠比特犬',
      '万能梗',
      '威玛犬',
      '西高地白梗',
      '西施犬',
      '藏獒犬',
      '喜乐蒂犬',
      '雪纳瑞犬',
      '英可卡犬',
      '英斗犬',
      '英跳猎犬',
      '约克夏梗',
      '伊比赞犬',
      '中国冠毛犬',
      '指示犬',
      '其他狗狗',
    ],
  };

  @override
  void initState() {
    super.initState();
    _moderationGuard = ModerationGuard(ModerationClient());
    _loadUserAvatar();
    _loadDefaultOwnerNickname();
    if (widget.initialData != null) {
      // 从现有数据加载
      _loadInitialData();
    }
  }

  // 加载用户默认的主人昵称
  Future<void> _loadDefaultOwnerNickname() async {
    try {
      final nickname = await SupabaseService().getOwnerNickname();
      if (mounted) {
        setState(() {
          _defaultOwnerNickname = nickname;
        });
      }
    } catch (e) {
      debugPrint('加载默认昵称失败: $e');
    }
  }

  void _loadInitialData() {
    final data = widget.initialData!;
    setState(() {
      _petId = data['id']?.toString();
      _petName = data['name'] as String?;
      _petSpecies = data['species'] as String?;
      _gender = data['gender'] as String?;

      // 加载宠物类型
      if (data['type'] != null) {
        final type = data['type'] as String;
        if (type == '狗') {
          _petType = '狗狗';
        } else if (type == '猫') {
          _petType = '猫咪';
        } else {
          _petType = type;
        }
      }

      // 处理生日日期
      if (data['birthDate'] != null) {
        // 如果有ISO格式的生日日期字符串
        try {
          _birthDate = DateTime.parse(data['birthDate'] as String);
        } catch (e) {
          debugPrint('解析生日日期失败: $e');
        }
      }

      // 如果有头像路径或 URL
      if (data['avatar'] != null) {
        final avatarPath = data['avatar'] as String;
        final isRemote = avatarPath.startsWith('http://') ||
            avatarPath.startsWith('https://');
        if (isRemote) {
          _avatarUrl = avatarPath;
        } else if (File(avatarPath).existsSync()) {
          _avatarFile = File(avatarPath);
        }
      }

      if (data['lifePhoto'] != null || data['life_photo'] != null) {
        final lifePath = (data['lifePhoto'] ?? data['life_photo']) as String;
        final isRemote =
            lifePath.startsWith('http://') || lifePath.startsWith('https://');
        if (isRemote) {
          _lifePhotoUrl = lifePath;
        } else if (File(lifePath).existsSync()) {
          _lifePhotoFile = File(lifePath);
        }
      }

      // 加载其他字段
      if (data['neuterStatus'] != null) {
        _neuterStatus = data['neuterStatus'] as String?;
      }
      if (data['weight'] != null) {
        _weight = data['weight'] as double?;
      }

      // 加载昵称相关字段

      _ownerNickname = data['ownerNickname'] as String?;
    });
  }

  Future<void> _loadUserAvatar() async {
    try {
      final avatarPath = await UserAvatarHelper.getCurrentUserAvatarPath();
      if (mounted && avatarPath != null) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('加载用户头像失败: $e');
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      if (!mounted) return;
      final cropped =
          await AvatarImageHelper.cropAndCompressAvatar(context, file.path);
      if (cropped == null) return;
      final avatarBytes = await cropped.readAsBytes();
      if (!mounted) return;
      final avatarPassed = await _moderationGuard.runImageGuardByBytes(
        context: context,
        scene: ModerationScene.petAvatar,
        bytes: avatarBytes,
        onPassed: () async {},
      );
      if (!avatarPassed || !mounted) return;
      setState(() {
        _avatarFile = cropped;
        _avatarUrl = null;
      });
    } catch (e) {
      debugPrint('选择头像失败: $e');
    }
  }

  Future<void> _pickLifePhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (picked == null) return;

      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(
        tempDir.path,
        '${const Uuid().v4()}_lifephoto.jpg',
      );
      final compressed = await FlutterImageCompress.compressAndGetFile(
        picked.path,
        targetPath,
        quality: 85,
        format: CompressFormat.jpeg,
        minWidth: 1024,
        minHeight: 1024,
      );
      final lifePhotoFile = File(compressed?.path ?? picked.path);
      final lifePhotoBytes = await lifePhotoFile.readAsBytes();
      if (!mounted) return;
      final imagePassed = await _moderationGuard.runImageGuardByBytes(
        context: context,
        scene: ModerationScene.imageInput,
        bytes: lifePhotoBytes,
        onPassed: () async {},
      );
      if (!imagePassed || !mounted) return;

      setState(() {
        _lifePhotoFile = lifePhotoFile;
        _lifePhotoUrl = null;
        _lifePhotoPrecheckReason = null; // 清除之前的预检查结果
      });
    } catch (e) {
      debugPrint('选择生活照失败: $e');
    }
  }

  /// 图片质量预检查 - 调用 img-gen-precheck Edge Function
  Future<({bool pass, String reason})> _precheckLifePhoto({
    required String fileName,
    required String bucket,
    required String path,
  }) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.functions.invoke(
        'img-gen-precheck',
        body: {
          'file_name': fileName,
          'bucket': bucket,
          'path': path,
        },
      );

      dynamic payload = response.data;
      if (payload is String && payload.isNotEmpty) {
        payload = jsonDecode(payload);
      }

      if (payload is! Map) {
        return (pass: false, reason: '图片检测服务返回了无效结果，请稍后重试');
      }

      final bool pass = payload['pass'] == true;
      final String reason = (payload['reason'] as String? ?? '').trim();

      if (pass) {
        return (pass: true, reason: '');
      }

      return (
        pass: false,
        reason: reason.isNotEmpty ? reason : '图片不符合生成要求，请更换后重试'
      );
    } on SocketException {
      return (pass: false, reason: '图片检测失败：网络连接异常，请检查网络后重试');
    } on TimeoutException {
      return (pass: false, reason: '图片检测超时，请稍后再试');
    } on FunctionException catch (e) {
      debugPrint('❌ 生活照预检函数调用失败: $e');
      final message = e.toString().toLowerCase();
      if (message.contains('401') ||
          message.contains('403') ||
          message.contains('unauthorized') ||
          message.contains('forbidden')) {
        return (pass: false, reason: '登录状态已失效，请重新登录后重试');
      }
      if (message.contains('timeout')) {
        return (pass: false, reason: '图片检测超时，请稍后再试');
      }
      if (message.contains('network') || message.contains('fetch')) {
        return (pass: false, reason: '图片检测失败：网络连接异常，请检查网络后重试');
      }
      return (pass: false, reason: '图片检测服务暂时不可用，请稍后重试');
    } catch (e, st) {
      debugPrint('❌ 生活照预检异常: $e\n$st');
      return (pass: false, reason: '图片检测失败，请检查网络后重试');
    }
  }

  void _showSpeciesSelector() {
    String currentCategory = '狗狗'; // 默认狗狗
    final scrollController = ScrollController();
    final pageController = PageController(initialPage: 1); // 0=猫咪, 1=狗狗

    // 热门品种（带图片URL）
    final Map<String, List<Map<String, String>>> popularBreeds = {
      '狗狗': [
        {
          'name': '博美犬',
          'image':
              'https://images.unsplash.com/photo-1544568100-847a948585b9?w=200',
        },
        {
          'name': '哈士奇',
          'image':
              'https://images.unsplash.com/photo-1605568427561-40dd23c2acea?w=200',
        },
        {
          'name': '拉布拉多',
          'image':
              'https://images.unsplash.com/photo-1579684385127-1ef15d508118?w=200',
        },
        {
          'name': '柴犬',
          'image':
              'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=200',
        },
        {
          'name': '金毛犬',
          'image':
              'https://images.unsplash.com/photo-1633722715463-d30f4f325e24?w=200',
        },
        {
          'name': '贵宾犬',
          'image':
              'https://images.unsplash.com/photo-1537151608828-ea2b11777ee8?w=200',
        },
        {
          'name': '边牧犬',
          'image':
              'https://images.unsplash.com/photo-1587300003388-59208cc962cb?w=200',
        },
        {
          'name': '柯基犬',
          'image':
              'https://images.unsplash.com/photo-1546527868-ccb7ee7dfa6a?w=200',
        },
      ],
      '猫咪': [
        {
          'name': '布偶猫',
          'image':
              'https://images.unsplash.com/photo-1513245543132-31f507417b26?w=200',
        },
        {
          'name': '暹罗猫',
          'image':
              'https://images.unsplash.com/photo-1513360371669-4adf3dd7dff8?w=200',
        },
        {
          'name': '缅因猫',
          'image':
              'https://images.unsplash.com/photo-1574158622682-e40e69881006?w=200',
        },
        {
          'name': '英短猫',
          'image':
              'https://images.unsplash.com/photo-1596854407944-bf87f6fdd49e?w=200',
        },
        {
          'name': '狸花猫',
          'image':
              'https://images.unsplash.com/photo-1529778873920-4da4926a72c2?w=200',
        },
        {
          'name': '美短猫',
          'image':
              'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=200',
        },
        {
          'name': '波斯猫',
          'image':
              'https://images.unsplash.com/photo-1495360010541-f48722b34f7d?w=200',
        },
        {
          'name': '金渐层',
          'image':
              'https://images.unsplash.com/photo-1543852786-1cf6624b9987?w=200',
        },
      ],
    };

    // 按字母分组
    Map<String, List<String>> groupByInitial(List<String> breeds) {
      final map = <String, List<String>>{};
      for (var breed in breeds) {
        final initial = _getInitial(breed);
        map.putIfAbsent(initial, () => []).add(breed);
      }
      // 将 # 移到最后
      if (map.containsKey('#')) {
        final hashValue = map.remove('#');
        map['#'] = hashValue!;
      }
      return map;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.85,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题栏
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '选择宠物品种',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    // 分类标签（猫咪/狗狗）- 优化设计
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 60,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: ['猫咪', '狗狗'].asMap().entries.map((entry) {
                          final index = entry.key;
                          final category = entry.value;
                          final isSelected = currentCategory == category;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                                setModalState(() {
                                  currentCategory = category;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.06,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF5A8EFA)
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 内容区域 - 使用PageView实现滑动切换
                    Expanded(
                      child: PageView(
                        controller: pageController,
                        onPageChanged: (index) {
                          setModalState(() {
                            currentCategory = index == 0 ? '猫咪' : '狗狗';
                          });
                        },
                        children: ['猫咪', '狗狗'].map((category) {
                          final allBreeds = _speciesOptions[category] ?? [];
                          final groupedBreeds = groupByInitial(
                            allBreeds.skip(8).toList(),
                          );
                          // 排序字母，把#放到最后
                          final letters = groupedBreeds.keys.toList()
                            ..sort((a, b) {
                              if (a == '#') return 1;
                              if (b == '#') return -1;
                              return a.compareTo(b);
                            });

                          return SingleChildScrollView(
                            controller: scrollController,
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 热门品种网格
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    20,
                                  ),
                                  child: GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                      childAspectRatio: 0.85,
                                    ),
                                    itemCount: popularBreeds[category]!.length,
                                    itemBuilder: (context, index) {
                                      final breed =
                                          popularBreeds[category]![index];
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _petType = currentCategory;
                                            _petSpecies = breed['name'];
                                          });
                                          Navigator.pop(ctx);
                                        },
                                        child: Column(
                                          children: [
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.grey.shade100,
                                                  width: 1,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.06),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: ClipOval(
                                                child: CachedNetworkImage(
                                                  imageUrl: breed['image']!,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      const Center(
                                                    child: SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                  ),
                                                  errorWidget: (
                                                    context,
                                                    url,
                                                    error,
                                                  ) {
                                                    return Container(
                                                      color:
                                                          Colors.grey.shade200,
                                                      child: const Icon(
                                                        Icons.pets,
                                                        size: 24,
                                                        color: Colors.grey,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              breed['name']!,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.black87,
                                                fontWeight: FontWeight.w500,
                                                height: 1.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // 字母索引列表
                                ...letters.map((letter) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8F9FB),
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey.shade100,
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        width: double.infinity,
                                        child: Text(
                                          letter,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      ...groupedBreeds[letter]!.map((breed) {
                                        return Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                _petType = currentCategory;
                                                _petSpecies = breed;
                                              });
                                              Navigator.pop(ctx);
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 16,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: Colors.grey.shade50,
                                                    width: 0.5,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      breed,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        color: Colors.black87,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.arrow_forward_ios,
                                                    size: 14,
                                                    color: Colors.grey.shade400,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  );
                                }),
                                const SizedBox(height: 40),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getInitial(String text) {
    if (text.isEmpty) return '#';
    final char = text[0];
    if (RegExp(r'[A-Z]').hasMatch(char)) return char;
    if (RegExp(r'[a-z]').hasMatch(char)) return char.toUpperCase();
    // 中文拼音首字母简化处理
    const pinyinMap = {
      '阿': 'A',
      '埃': 'A',
      '爱': 'A',
      '安': 'A',
      '巴': 'B',
      '伯': 'B',
      '布': 'B',
      '比': 'B',
      '波': 'B',
      '标': 'B',
      '彼': 'B',
      '边': 'B',
      '博': 'B',
      '北': 'B',
      '东': 'D',
      '德': 'D',
      '大': 'D',
      '杜': 'D',
      '斗': 'D',
      '短': 'D',
      '法': 'F',
      '芬': 'F',
      '佛': 'F',
      '刚': 'G',
      '古': 'G',
      '哥': 'G',
      '贵': 'G',
      '金': 'J',
      '哈': 'H',
      '惠': 'H',
      '荷': 'H',
      '喜': 'H',
      '湖': 'H',
      '吉': 'J',
      '京': 'J',
      '卷': 'J',
      '加': 'J',
      '巨': 'J',
      '柯': 'K',
      '可': 'K',
      '凯': 'K',
      '库': 'K',
      '卡': 'K',
      '康': 'K',
      '拉': 'L',
      '罗': 'L',
      '腊': 'L',
      '灵': 'L',
      '猎': 'L',
      '狸': 'L',
      '蓝': 'L',
      '缅': 'M',
      '马': 'M',
      '美': 'M',
      '迷': 'M',
      '曼': 'M',
      '孟': 'M',
      '猫': 'M',
      '纽': 'N',
      '牛': 'N',
      '挪': 'N',
      '欧': 'O',
      '葡': 'P',
      '平': 'P',
      '苹': 'P',
      '秋': 'Q',
      '拳': 'Q',
      '日': 'R',
      '热': 'R',
      '瑞': 'R',
      '萨': 'S',
      '圣': 'S',
      '苏': 'S',
      '松': 'S',
      '沙': 'S',
      '丝': 'S',
      '斯': 'S',
      '索': 'S',
      '塞': 'S',
      '狮': 'S',
      '山': 'S',
      '暹': 'X',
      '新': 'X',
      '夏': 'X',
      '雪': 'X',
      '泰': 'T',
      '土': 'T',
      '田': 'T',
      '威': 'W',
      '万': 'W',
      '玩': 'W',
      '无': 'W',
      '寻': 'X',
      '西': 'X',
      '英': 'Y',
      '约': 'Y',
      '伊': 'Y',
      '异': 'Y',
      '银': 'Y',
      '玉': 'Y',
      '中': 'Z',
      '指': 'Z',
      '芝': 'Z',
      '折': 'Z',
    };

    for (var entry in pinyinMap.entries) {
      if (text.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return '#';
  }

  void _showDatePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        DateTime tempDate =
            _birthDate ?? DateTime.now().subtract(const Duration(days: 365));

        return StatefulBuilder(
          builder: (context, setModalState) {
            final now = DateTime.now();

            // 生成年份列表 (1990-当前年)
            final years = List.generate(
              now.year - 1990 + 1,
              (i) => 1990 + i,
            );

            // 月份列表
            int maxMonth = 12;
            if (tempDate.year == now.year) {
              maxMonth = now.month;
            }
            final months = List.generate(maxMonth, (i) => i + 1);

            // 天数列表
            int maxDay;
            if (tempDate.year == now.year && tempDate.month == now.month) {
              maxDay = now.day;
            } else {
              maxDay = DateTime(tempDate.year, tempDate.month + 1, 0).day;
            }
            final days = List.generate(maxDay, (i) => i + 1);

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '选择日期',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 24),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  // 日期选择器
                  SizedBox(
                    height: 240,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 年份选择器
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem: years.indexOf(tempDate.year),
                            ),
                            itemExtent: 44,
                            squeeze: 1.1,
                            useMagnifier: true,
                            magnification: 1.15,
                            onSelectedItemChanged: (index) {
                              setModalState(() {
                                final newYear = years[index];

                                // 如果选了当前年份，检查月份是否超过当前月份
                                var newMonth = tempDate.month;
                                if (newYear == now.year &&
                                    newMonth > now.month) {
                                  newMonth = now.month;
                                }

                                // 检查日期是否超过该月最大天数或当前日期
                                var newDay = tempDate.day;
                                int maxDayInNewMonth;
                                if (newYear == now.year &&
                                    newMonth == now.month) {
                                  maxDayInNewMonth = now.day;
                                } else {
                                  maxDayInNewMonth =
                                      DateTime(newYear, newMonth + 1, 0).day;
                                }

                                if (newDay > maxDayInNewMonth) {
                                  newDay = maxDayInNewMonth;
                                }

                                tempDate = DateTime(newYear, newMonth, newDay);
                              });
                            },
                            children: years
                                .map(
                                  (year) => Center(
                                    child: Text(
                                      '$year年',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        // 月份选择器
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem: tempDate.month - 1,
                            ),
                            itemExtent: 44,
                            squeeze: 1.1,
                            useMagnifier: true,
                            magnification: 1.15,
                            onSelectedItemChanged: (index) {
                              setModalState(() {
                                final newMonth = months[index];

                                // 检查日期是否超过该月最大天数或当前日期
                                var newDay = tempDate.day;
                                int maxDayInNewMonth;
                                if (tempDate.year == now.year &&
                                    newMonth == now.month) {
                                  maxDayInNewMonth = now.day;
                                } else {
                                  maxDayInNewMonth =
                                      DateTime(tempDate.year, newMonth + 1, 0)
                                          .day;
                                }

                                if (newDay > maxDayInNewMonth) {
                                  newDay = maxDayInNewMonth;
                                }

                                tempDate =
                                    DateTime(tempDate.year, newMonth, newDay);
                              });
                            },
                            children: months
                                .map(
                                  (month) => Center(
                                    child: Text(
                                      '$month月',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        // 日期选择器
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem: tempDate.day - 1,
                            ),
                            itemExtent: 44,
                            squeeze: 1.1,
                            useMagnifier: true,
                            magnification: 1.15,
                            onSelectedItemChanged: (index) {
                              setModalState(() {
                                tempDate = DateTime(
                                  tempDate.year,
                                  tempDate.month,
                                  days[index],
                                );
                              });
                            },
                            children: days
                                .map(
                                  (day) => Center(
                                    child: Text(
                                      '$day日',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 确定按钮
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5A8EFA),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final now = DateTime.now();
                          // 最终确认：如果选择的日期在未来，使用今天的日期
                          final finalDate =
                              tempDate.isAfter(now) ? now : tempDate;
                          setState(() => _birthDate = finalDate);
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          '确定',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showGenderSelector() {
    final genderOptions = ['弟弟', '妹妹', '未知'];
    String? tempGender = _gender ?? genderOptions[0];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            // 找到初始选中项的索引
            final initialIndex =
                tempGender != null && genderOptions.contains(tempGender)
                    ? genderOptions.indexOf(tempGender!)
                    : 0;

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '宠物性别',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 24),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  // 滚动选择器
                  SizedBox(
                    height: 240,
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: initialIndex,
                      ),
                      itemExtent: 50,
                      onSelectedItemChanged: (index) {
                        setModalState(() {
                          tempGender = genderOptions[index];
                        });
                      },
                      children: genderOptions
                          .map(
                            (option) => Center(
                              child: Text(
                                option,
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  // 确定按钮
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5A8EFA),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          if (tempGender != null) {
                            setState(() => _gender = tempGender);
                          }
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          '确定',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showNeuterSelector() {
    final neuterOptions = ['已绝育', '未绝育'];
    String? tempStatus = _neuterStatus ?? neuterOptions[0];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            // 找到初始选中项的索引
            final initialIndex =
                tempStatus != null && neuterOptions.contains(tempStatus)
                    ? neuterOptions.indexOf(tempStatus!)
                    : 0;

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '是否绝育',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 24),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  // 滚动选择器
                  SizedBox(
                    height: 240,
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: initialIndex,
                      ),
                      itemExtent: 50,
                      onSelectedItemChanged: (index) {
                        setModalState(() {
                          tempStatus = neuterOptions[index];
                        });
                      },
                      children: neuterOptions
                          .map(
                            (option) => Center(
                              child: Text(
                                option,
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  // 确定按钮
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5A8EFA),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          if (tempStatus != null) {
                            setState(() => _neuterStatus = tempStatus);
                          }
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          '确定',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showWeightPicker() {
    double tempWeight = _weight ?? 7.9;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '选择体重',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 24),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 显示当前体重
                    Text(
                      '${tempWeight.toStringAsFixed(1)} KG',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 刻度尺
                    SizedBox(
                      height: 120, // 增加高度以容纳更美观的布局
                      child: Stack(
                        children: [
                          // 刻度尺滚动区域
                          NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollUpdateNotification ||
                                  notification is ScrollEndNotification) {
                                final offset = notification.metrics.pixels;
                                final itemWidth = 8.0; // 每 0.1kg 的宽度
                                final index = (offset / itemWidth).round();
                                final newWeight =
                                    (index / 10.0) + 0.0; // 从 0kg 开始
                                if (newWeight >= 0.0 &&
                                    newWeight <= 60.0 &&
                                    newWeight != tempWeight) {
                                  setModalState(() {
                                    tempWeight = double.parse(
                                      newWeight.toStringAsFixed(1),
                                    );
                                  });
                                }
                              }
                              return false;
                            },
                            child: ListView.builder(
                              controller: ScrollController(
                                initialScrollOffset:
                                    ((tempWeight - 0.0) * 10 * 8.0),
                              ),
                              scrollDirection: Axis.horizontal,
                              itemCount: 601, // 0kg - 60kg
                              padding: EdgeInsets.symmetric(
                                horizontal: MediaQuery.of(ctx).size.width / 2,
                              ),
                              itemBuilder: (context, index) {
                                final value = (index / 10.0) + 0.0;
                                final isInteger = (index % 10) == 0;
                                final isHalf = (index % 5) == 0 && !isInteger;

                                return Container(
                                  width: 8, // 每 0.1kg 的间距
                                  alignment: Alignment.bottomCenter,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // 刻度标签（每整数显示）
                                      if (isInteger)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: Text(
                                            '${value.toInt()}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1A1A1A),
                                            ),
                                          ),
                                        )
                                      else
                                        const SizedBox(height: 28),
                                      // 刻度线
                                      Container(
                                        width: isInteger ? 2 : 1.5,
                                        height:
                                            isInteger ? 40 : (isHalf ? 28 : 16),
                                        decoration: BoxDecoration(
                                          color: isInteger
                                              ? const Color(0xFF1A1A1A)
                                              : (isHalf
                                                  ? const Color(0xFF8E8E93)
                                                  : const Color(0xFFD1D1D6)),
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          // 左侧渐变遮罩
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 80,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // 右侧渐变遮罩
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            width: 80,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerRight,
                                    end: Alignment.centerLeft,
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // 中心指示线
                          Positioned(
                            left: MediaQuery.of(ctx).size.width / 2 - 1.5,
                            top: 45, // 避开数字
                            bottom: 0,
                            child: Container(
                              width: 3,
                              decoration: BoxDecoration(
                                color: const Color(0xFF5A8EFA),
                                borderRadius: BorderRadius.circular(1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF5A8EFA,
                                    ).withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5A8EFA),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(() => _weight = tempWeight);
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            '确定',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showNameInput() {
    final controller = TextEditingController(text: _petName);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (
        BuildContext buildContext,
        Animation animation,
        Animation secondaryAnimation,
      ) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '设置宠物昵称',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(buildContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: controller,
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: '请输入宠物昵称',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              backgroundColor: const Color(0xFFF5F5F5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(buildContext),
                            child: Text(
                              '取消',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5A8EFA),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              setState(() => _petName = controller.text);
                              Navigator.pop(buildContext);
                            },
                            child: const Text(
                              '确认',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  Widget _buildListItem({
    required String label,
    required String placeholder,
    String? value,
    required VoidCallback onTap,
    Widget? trailing,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(20) : Radius.zero,
          bottom: isLast ? const Radius.circular(20) : Radius.zero,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(
                    bottom: BorderSide(color: Colors.grey.shade100, width: 0.5),
                  ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              trailing ??
                  Row(
                    children: [
                      Text(
                        value ?? placeholder,
                        style: TextStyle(
                          fontSize: 15,
                          color: value != null
                              ? Colors.black87
                              : const Color(0xFFCCCCCC),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Color(0xFFCCCCCC),
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLifePhotoTrailing() {
    final hasLifePhoto = _lifePhotoFile != null ||
        (_lifePhotoUrl != null && _lifePhotoUrl!.isNotEmpty);

    Widget thumb;
    if (_lifePhotoFile != null && _lifePhotoFile!.existsSync()) {
      thumb = Image.file(
        _lifePhotoFile!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
      );
    } else if (_lifePhotoUrl != null && _lifePhotoUrl!.isNotEmpty) {
      thumb = CachedNetworkImage(
        imageUrl: _lifePhotoUrl!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => Container(
          width: 44,
          height: 44,
          color: const Color(0xFFF2F3F7),
          child: const Icon(Icons.photo, color: Color(0xFFB8BEC9), size: 20),
        ),
      );
    } else {
      thumb = Container(
        width: 44,
        height: 44,
        color: const Color(0xFFF2F3F7),
        child: const Icon(Icons.photo, color: Color(0xFFB8BEC9), size: 20),
      );
    }

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: thumb,
        ),
        const SizedBox(width: 10),
        if (!hasLifePhoto)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Text(
              '未添加',
              style: TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
            ),
          ),
        const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Color(0xFFCCCCCC),
        ),
      ],
    );
  }

  // 编辑昵称
  void _showNicknameEditor() {
    final controller =
        TextEditingController(text: _ownerNickname ?? _defaultOwnerNickname);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('宠物对你的称呼'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '称呼',
            hintText: '例如：妈妈、姐姐、爸爸',
          ),
          maxLength: 10,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nickname = controller.text.trim();
              if (nickname.isNotEmpty) {
                final passed = await _moderationGuard.runTextGuard(
                  context: context,
                  scene: ModerationScene.ownerNickname,
                  content: nickname,
                  onPassed: () async {},
                );
                if (!passed || !mounted || !context.mounted) return;
                setState(() {
                  _ownerNickname = nickname;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePetProfile() async {
    await runWithLoadingFlag(
      isLoading: _isSaving,
      assign: (v) => _isSaving = v,
      action: () async {
      if (_petName == null || _petName!.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请输入宠物昵称')));
        return;
      }

      final petId = _petId ?? const Uuid().v4();
      _petId = petId;

      final petNamePassed = await _moderationGuard.runTextGuard(
        context: context,
        scene: ModerationScene.petName,
        content: _petName!.trim(),
        onPassed: () async {},
      );
      if (!petNamePassed || !mounted) return;

      if (_ownerNickname != null && _ownerNickname!.trim().isNotEmpty) {
        final ownerNicknamePassed = await _moderationGuard.runTextGuard(
          context: context,
          scene: ModerationScene.ownerNickname,
          content: _ownerNickname!.trim(),
          onPassed: () async {},
        );
        if (!ownerNicknamePassed || !mounted) return;
      }

      if (_avatarFile != null) {
        final avatarBytes = await _avatarFile!.readAsBytes();
        if (!mounted) return;
        final avatarPassed = await _moderationGuard.runImageGuardByBytes(
          context: context,
          scene: ModerationScene.petAvatar,
          bytes: avatarBytes,
          onPassed: () async {},
        );
        if (!avatarPassed || !mounted) return;
      }

      if (_lifePhotoFile != null) {
        final lifePhotoBytes = await _lifePhotoFile!.readAsBytes();
        if (!mounted) return;
        final lifePhotoPassed = await _moderationGuard.runImageGuardByBytes(
          context: context,
          scene: ModerationScene.imageInput,
          bytes: lifePhotoBytes,
          onPassed: () async {},
        );
        if (!lifePhotoPassed || !mounted) return;
      }

      // 保存逻辑，返回数据给上一页
      // 根据品种自动推断宠物类型（如果用户没有明确选择）
      String? petType = _petType;
      if (petType == null && _petSpecies != null) {
        for (final entry in _speciesOptions.entries) {
          if (entry.value.contains(_petSpecies)) {
            petType = entry.key;
            break;
          }
        }
      }

      // 转换类型名称：狗狗 -> 狗，猫咪 -> 猫
      String typeForDb = '其他';
      if (petType == '狗狗') {
        typeForDb = '狗';
      } else if (petType == '猫咪') {
        typeForDb = '猫';
      } else if (petType != null) {
        typeForDb = petType;
      }

      String? avatarValue = widget.initialData?['avatar'] as String?;
      if (_avatarFile != null) {
        final uploaded = await SupabaseService().uploadPetAvatar(
          file: _avatarFile!,
          petId: petId,
        );
        if (uploaded != null && uploaded.isNotEmpty) {
          avatarValue = uploaded;
        }
      }

      String? lifePhotoValue = (widget.initialData?['life_photo'] ??
          widget.initialData?['lifePhoto']) as String?;
      if (_lifePhotoFile != null) {
        final uploadResult = await SupabaseService().uploadPetLifePhotoToStorage(
          file: _lifePhotoFile!,
          petId: petId,
        );
        if (uploadResult == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('生活照上传失败，请重试')),
            );
          }
          return;
        }

        final fileName = uploadResult.path.split('/').last;
        final precheckResult = await _precheckLifePhoto(
          fileName: fileName,
          bucket: 'user-avatars',
          path: uploadResult.path,
        );

        if (!precheckResult.pass) {
          await SupabaseService().removeStorageObject(
            bucket: 'user-avatars',
            path: uploadResult.path,
          );
          if (mounted) {
            setState(() {
              _lifePhotoPrecheckReason = precheckResult.reason;
            });
          }
          return;
        }

        lifePhotoValue = uploadResult.url;
        try {
          await Supabase.instance.client.from('pets').upsert({
            'id': petId,
            'life_photo': lifePhotoValue,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (e) {
          debugPrint('保存 life_photo 到 pets 表失败: $e');
        }
      }

      final result = {
        'id': petId,
        'avatar': avatarValue,
        'life_photo': lifePhotoValue,
        'lifePhoto': lifePhotoValue,
        'name': _petName,
        'type': typeForDb,
        'breed': _petSpecies,
        'birth_date': _birthDate?.toIso8601String(),
        'gender': _gender,
        'neuter_status': _neuterStatus,
        'weight': _weight,
        'useCustomNickname':
            _ownerNickname != null && _ownerNickname!.isNotEmpty,
        'ownerNickname': _ownerNickname,
      };
      if (!mounted) return;
      Navigator.pop(context, result);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F6F9),
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.black87,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            '编辑宠物档案',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 头像区域
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 20, bottom: 28),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickAvatar,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  key: ValueKey<String>(
                                    '${_avatarFile?.path ?? ''}|${_avatarUrl ?? ''}',
                                  ),
                                  radius: 58,
                                  backgroundColor: const Color(0xFFF8F8F8),
                                  backgroundImage: (_avatarFile != null
                                      ? FileImage(_avatarFile!)
                                      : (_avatarUrl != null &&
                                              _avatarUrl!.isNotEmpty
                                          ? NetworkImage(_avatarUrl!)
                                          : null)) as ImageProvider?,
                                  child: _avatarFile == null &&
                                          (_avatarUrl == null ||
                                              _avatarUrl!.isEmpty)
                                      ? const Icon(
                                          Icons.camera_alt,
                                          size: 42,
                                          color: Color(0xFFBBBBBB),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 表单字段列表 - 添加圆角卡片包裹
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildListItem(
                            label: '宠物昵称',
                            placeholder: '请输入爱宠昵称',
                            value: _petName,
                            onTap: _showNameInput,
                            isFirst: true,
                          ),
                          _buildListItem(
                            label: '宠物品种',
                            placeholder: '请选择爱宠品种',
                            value: _petSpecies,
                            onTap: _showSpeciesSelector,
                          ),
                          _buildListItem(
                            label: '出生日期',
                            placeholder: '选择ta的出生日期',
                            value: _birthDate != null
                                ? '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}'
                                : null,
                            onTap: _showDatePicker,
                          ),
                          _buildListItem(
                            label: '宠物性别',
                            placeholder: '选择性别',
                            value: _gender,
                            onTap: _showGenderSelector,
                          ),
                          _buildListItem(
                            label: '是否绝育',
                            placeholder: '是否绝育',
                            value: _neuterStatus,
                            onTap: _showNeuterSelector,
                          ),
                          _buildListItem(
                            label: '宠物体重',
                            placeholder: '请选择爱宠体重 (kg)',
                            value: _weight != null
                                ? '${_weight!.toStringAsFixed(1)} kg'
                                : null,
                            onTap: _showWeightPicker,
                          ),
                          // 昵称设置
                          _FormRow(
                            label: '我的称呼',
                            onTap: _showNicknameEditor,
                            isLast: false,
                            child: Text(
                              _ownerNickname ?? _defaultOwnerNickname,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          _buildListItem(
                            label: '生活照',
                            placeholder: '请选择生活照',
                            trailing: _buildLifePhotoTrailing(),
                            onTap: () {
                              setState(() => _lifePhotoPrecheckReason =
                                  null); // 清除之前的预检查结果
                              _pickLifePhoto();
                            },
                            isLast: true,
                          ),
                          // 生活照预检查失败提示
                          if (_lifePhotoPrecheckReason != null &&
                              _lifePhotoPrecheckReason!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFFB74D),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      color: Color(0xFFF57C00),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _lifePhotoPrecheckReason!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFE65100),
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            // 底部保存按钮
            Container(
              color: const Color(0xFFF5F6F9),
              padding: const EdgeInsets.all(20),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _isSaving
                          ? const LinearGradient(
                              colors: [Color(0xFFD7C9C1), Color(0xFFCDBDB5)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFE3A07B), Color(0xFFD98D72)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isSaving
                            ? const Color(0x00FFFFFF)
                            : const Color(0xFFF1C2AC),
                        width: 1,
                      ),
                      boxShadow: _isSaving
                          ? []
                          : [
                              BoxShadow(
                                color: const Color(0xFFC88768).withOpacity(0.22),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor:
                            _isSaving ? const Color(0xFFF0F4F8) : Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: Colors.transparent,
                      ),
                      onPressed: _isSaving ? null : _savePetProfile,
                      child: _isSaving
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFFF0F4F8)),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  '保存中…',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              '保存档案',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool isLast;

  const _FormRow({
    required this.label,
    required this.child,
    this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          bottom: isLast ? const Radius.circular(20) : Radius.zero,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(
                    bottom: BorderSide(color: Colors.grey.shade100, width: 0.5),
                  ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: child),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Color(0xFFCCCCCC),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
