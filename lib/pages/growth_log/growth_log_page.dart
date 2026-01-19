import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../utils/ui_helpers.dart';

// --- Placeholder for Models ---
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
  const GrowthLogPage({super.key});

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
      images: ['https://picsum.photos/200'], // Placeholder
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.white.withOpacity(0.7)),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '成长日志',
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: AppColors.textDark),
            onPressed: () {
               // Filter dialog
            },
          ),
        ],
      ),
      body: _buildTimelineList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Add log
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("记录日常", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTimelineList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 110, 20, 100),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        final isLast = index == _events.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Time & Layout
              SizedBox(
                width: 60,
                child: Column(
                  children: [
                    Text(
                      DateFormat('HH:mm').format(event.date),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textGrey,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      DateFormat('MM/dd').format(event.date),
                      style: TextStyle(
                        color: AppColors.textGrey.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Middle: Line & Dot
              Column(
                children: [
                   Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _getColorForType(event.type),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _getColorForType(event.type).withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
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
                          color: Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 16),

              // Right: Content Card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: _buildEventCard(event),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventCard(GrowthEvent event) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getIconForType(event.type), size: 18, color: _getColorForType(event.type)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            event.description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.secondaryText,
              height: 1.5,
            ),
          ),
          if (event.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: event.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, imgIndex) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                        width: 80, height: 80,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, color: Colors.grey) // Placeholder
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getColorForType(GrowthEventType type) {
    switch (type) {
      case GrowthEventType.aiDiagnosis:
        return const Color(0xFF7C3AED); // Violet
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
}
