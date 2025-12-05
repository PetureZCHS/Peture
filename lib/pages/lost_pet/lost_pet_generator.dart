

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
  final String searchStrategyTip;
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
    required this.searchStrategyTip,
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
    final searchStrategyTip = isCat
        ? '家养猫走失主要在楼道、地下室和通风管道，通常不会跑远，建议带着猫粮和它熟悉的物品在深夜轻声呼唤。'
        : '狗狗走失通常会沿气味跑远，建议立即查看监控确定方向，并沿途询问路人，黄金72小时内扩散范围越广越好。';

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
      searchStrategyTip: searchStrategyTip,
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
