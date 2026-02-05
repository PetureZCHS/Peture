import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../utils/ui_helpers.dart';

// --- Models ---
enum GrowthEventType {
  aiDiagnosis,
  medication,
  vaccine,
  dailyLog,
}

class GrowthEvent {
  final DateTime date;
  final String title;
  final String description;
  final GrowthEventType type;
  final List<String> images;

  GrowthEvent({
    required this.date,
    required this.title,
    required this.description,
    required this.type,
    this.images = const [],
  });
}

class GrowthLogPage extends StatefulWidget {
  final bool isEmbedded;
  const GrowthLogPage({super.key, this.isEmbedded = false});

  @override
  State<GrowthLogPage> createState() => _GrowthLogPageState();
}

class _GrowthLogPageState extends State<GrowthLogPage> {
  final ScrollController _scrollController = ScrollController();

  // Mock Data
  final List<GrowthEvent> _events = [
    GrowthEvent(
      date: DateTime.now().subtract(const Duration(hours: 2)),
      title: 'AI 问诊记录',
      description: '针对“最近食欲不振”的咨询建议：建议观察排泄情况，尝试加热食物，必要时就医。',
      type: GrowthEventType.aiDiagnosis,
    ),
    GrowthEvent(
      date: DateTime.now().subtract(const Duration(days: 1)),
      title: '疫苗接种: 狂犬疫苗',
      description: '已接种狂犬疫苗（第2针），下次接种时间：2026-02-14。',
      type: GrowthEventType.vaccine,
    ),
    GrowthEvent(
      date: DateTime.now().subtract(const Duration(days: 2)),
      title: '驱虫记录',
      description: '使用了大宠爱体内外驱虫滴剂。',
      type: GrowthEventType.medication,
    ),
    GrowthEvent(
      date: DateTime.now().subtract(const Duration(days: 3)),
      title: '日常记录',
      description: '今天去公园玩得很开心，认识了新朋友。',
      type: GrowthEventType.dailyLog,
      images: ['https://picsum.photos/200'],
    ),
    GrowthEvent(
      date: DateTime.now().subtract(const Duration(days: 5)),
      title: 'AI 问诊记录',
      description: '针对“皮肤瘙痒”的咨询：可能是换季过敏，建议补充卵磷脂。',
      type: GrowthEventType.aiDiagnosis,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF5F7FA), // Soft background
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isEmbedded,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.white.withOpacity(0.7)),
          ),
        ),
        leading: widget.isEmbedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textDark),
                onPressed: () => Navigator.of(context).pop(),
              ),
        centerTitle: true,
        title: const Text(
          '成长日志',
          style:
              TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              // TODO: Add new log event
            },
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: AppColors.primary, size: 22),
            ),
            tooltip: "记录日常",
          ),
          // If embedded, hide the filter button
          if (!widget.isEmbedded)
            IconButton(
              icon: const Icon(Icons.filter_list_rounded,
                  color: AppColors.textDark),
              onPressed: () {},
            ),
          if (widget.isEmbedded)
            const SizedBox(width: 60), // Space for Home toggle button
        ],
      ),
      body: AnimationLimiter(
        child: ListView.builder(
          controller: _scrollController,
          // 增加底部 Padding，避免被 Home 底部导航栏遮挡 (Home 底部通常有 80-100 的高度)
          padding: const EdgeInsets.fromLTRB(20, 120, 20, 120),
          itemCount: _events.length,
          itemBuilder: (context, index) {
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: _GrowthTimelineItem(
                      event: _events[index],
                      isLast: index == _events.length - 1),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GrowthTimelineItem extends StatelessWidget {
  final GrowthEvent event;
  final bool isLast;

  const _GrowthTimelineItem({
    required this.event,
    required this.isLast,
  });

  Color _getColorForType(GrowthEventType type) {
    switch (type) {
      case GrowthEventType.aiDiagnosis:
        return const Color(0xFF8B5CF6); // Violet
      case GrowthEventType.medication:
        return const Color(0xFFEF4444); // Red
      case GrowthEventType.vaccine:
        return const Color(0xFF10B981); // Green
      case GrowthEventType.dailyLog:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  IconData _getIconForType(GrowthEventType type) {
    switch (type) {
      case GrowthEventType.aiDiagnosis:
        return Icons.medical_services_rounded;
      case GrowthEventType.medication:
        return Icons.medication_rounded;
      case GrowthEventType.vaccine:
        return Icons.verified_user_rounded;
      case GrowthEventType.dailyLog:
        return Icons.edit_note_rounded;
    }
  }

  String _getTypeLabel(GrowthEventType type) {
    switch (type) {
      case GrowthEventType.aiDiagnosis:
        return 'AI 问诊';
      case GrowthEventType.medication:
        return '用药记录';
      case GrowthEventType.vaccine:
        return '疫苗接种';
      case GrowthEventType.dailyLog:
        return '日常记录';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _getColorForType(event.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 左侧：时间展示
          SizedBox(
            width: 50,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('HH:mm').format(event.date),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MM/dd').format(event.date),
                    style: TextStyle(
                      color: AppColors.textGrey.withOpacity(0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 2. 中间：时间线轴 + 节点
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 18), // Align with time text
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: themeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          themeColor.withOpacity(0.5),
                          Colors.grey.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 16),

          // 3. 右侧：内容卡片
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF636585).withOpacity(0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 0,
                      offset: const Offset(0, 0),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      // TODO: Navigate to detail
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Icon + Title
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: themeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getIconForType(event.type),
                                  size: 18,
                                  color: themeColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.textDark,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Body: Description
                          Text(
                            event.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textDark.withOpacity(0.7),
                              height: 1.6,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Footer: Images (if any)
                          if (event.images.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 70,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: event.images.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, imgIndex) {
                                  return Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.grey[100],
                                      image: const DecorationImage(
                                        image: NetworkImage(
                                            'https://picsum.photos/200'), // Use placeholder for now
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
