

class LostPetInfo {
  final String name;
  final String species; // 'cat' or 'dog'
  final String description;
  final String lostTime;
  final String lostLocation;
  final String? rewardAmount;
  final String contactInfo;

  LostPetInfo({
    required this.name,
    required this.species,
    required this.description,
    required this.lostTime,
    required this.lostLocation,
    this.rewardAmount,
    required this.contactInfo,
  });
}

class LostPetMaterials {
  final String urgencyLevel;
  final List<String> searchChecklist; // Changed from searchStrategyTip
  final String wechatMomentsText;
  final String xiaohongshuTitle;
  final String xiaohongshuText;
  final String shortMessageText;
  final String posterHeadline;
  final List<String> posterFeatures;
  final String posterKeyInfo;
  final String posterCtaText;

  LostPetMaterials({
    required this.urgencyLevel,
    required this.searchChecklist,
    required this.wechatMomentsText,
    required this.xiaohongshuTitle,
    required this.xiaohongshuText,
    required this.shortMessageText,
    required this.posterHeadline,
    required this.posterFeatures,
    required this.posterKeyInfo,
    required this.posterCtaText,
  });
}

class LostPetGenerator {
  static LostPetMaterials generate(LostPetInfo info) {
    final isCat = info.species.toLowerCase().contains('cat') || info.species.contains('猫');
    
    // 1. Analysis
    final urgencyLevel = 'High'; // Always high for lost pets
    
    final List<String> searchChecklist = isCat
        ? [
            '检查楼道每一层（包括电表箱、杂物堆）',
            '检查地下室、车库、通风管道口',
            '带着猫粮/罐头在深夜人少时轻声呼唤',
            '在家门口摆放带有它气味的猫砂或垫子',
            '打印海报张贴在小区出入口、电梯内',
            '询问小区保安、保洁阿姨是否见过',
            '调取小区/楼道监控录像',
          ]
        : [
            '立即调取走失地附近的监控录像确定方向',
            '沿途询问路人、保安、环卫工人',
            '前往附近的公园、草地、垃圾站寻找',
            '打印海报张贴在方圆3公里内的显眼处',
            '联系附近的流浪狗救助站/收容所',
            '在本地宠物群/业主群发布寻宠信息',
            '利用“剪刀法”等玄学（宁可信其有）',
          ];

    // 2. Social Media - WeChat Moments
    final rewardText = info.rewardAmount != null && info.rewardAmount!.isNotEmpty
        ? '悬赏${info.rewardAmount}元'
        : '必有重谢';
    
    final wechatMomentsText = '''
🚨紧急寻${isCat ? '猫' : '狗'}！朋友圈的各位帮帮忙！
我家${info.name}于${info.lostTime}在${info.lostLocation}走失。
它对我很重要，现在家里人急疯了！
特征：${info.description}
如有线索请联系：${info.contactInfo}
$rewardText！麻烦大家帮忙转发扩散，好人一生平安！🙏
''';

    // 3. Social Media - XiaoHongShu
    final xiaohongshuTitle = '📍${info.lostLocation}寻${isCat ? '猫' : '狗'}！！救救孩子！';
    final xiaohongshuText = '''
😭😭坐标${info.lostLocation}，我家${info.name}丢了！
时间：${info.lostTime}
地点：${info.lostLocation}附近
品种/特征：${info.description}

它胆子${isCat ? '小' : '大'}，可能${isCat ? '躲在角落' : '在到处乱跑'}。
如果有好心人看到，请一定一定联系我！
📞电话：${info.contactInfo}
💰${rewardText}

#寻${isCat ? '猫' : '狗'} #寻宠 #${info.lostLocation}寻宠 #宠物走失 #扩散 #救救孩子
''';

    // 4. Short Message
    final shortMessageText = '【寻宠】${info.lostLocation}走失一只${info.description}的${isCat ? '猫' : '狗'}，名${info.name}。如有线索请联系${info.contactInfo}，${rewardText}。';

    // 5. Poster Content
    final posterHeadline = '寻${isCat ? '猫' : '狗'}启事 / $rewardText';
    // Split description into features roughly
    final features = info.description.split(RegExp(r'[，,。;；]')).where((s) => s.trim().isNotEmpty).toList();
    if (features.isEmpty) features.add(info.description);
    
    final posterKeyInfo = '时间：${info.lostTime}\n地点：${info.lostLocation}\n名字：${info.name}';
    final posterCtaText = '发现请立即拍照留存并联系，好人一生平安！';

    return LostPetMaterials(
      urgencyLevel: urgencyLevel,
      searchChecklist: searchChecklist,
      wechatMomentsText: wechatMomentsText,
      xiaohongshuTitle: xiaohongshuTitle,
      xiaohongshuText: xiaohongshuText,
      shortMessageText: shortMessageText,
      posterHeadline: posterHeadline,
      posterFeatures: features,
      posterKeyInfo: posterKeyInfo,
      posterCtaText: posterCtaText,
    );
  }
}
