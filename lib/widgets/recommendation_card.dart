import 'dart:async';
import 'package:flutter/material.dart';

class RecommendationData {
  final String reason;
  final String productName;
  final String rating;
  final String safetyCheck;
  final List<String> reasoningSteps;
  final String? price; // 新增价格字段

  RecommendationData({
    required this.reason,
    required this.productName,
    required this.rating,
    required this.safetyCheck,
    required this.reasoningSteps,
    this.price,
  });
}

class RecommendationCard extends StatefulWidget {
  final RecommendationData data;
  final VoidCallback onAdopt;

  const RecommendationCard({
    super.key,
    required this.data,
    required this.onAdopt,
  });

  @override
  State<RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<RecommendationCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  
  // 动画相关
  final List<String> _visibleSteps = [];
  Timer? _stepTimer;
  bool _isAnimatingSteps = false;

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded && _visibleSteps.isEmpty && !_isAnimatingSteps) {
      _startStepAnimation();
    }
  }

  void _startStepAnimation() {
    _isAnimatingSteps = true;
    int index = 0;
    _stepTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (index < widget.data.reasoningSteps.length) {
        if (mounted) {
          setState(() {
            _visibleSteps.add(widget.data.reasoningSteps[index]);
          });
        }
        index++;
      } else {
        timer.cancel();
        _isAnimatingSteps = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.08),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFF5D5FEF).withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. 顶部：推荐理由 (高级感渐变)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF8FAFC),
                    Colors.white.withOpacity(0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 12, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              "AI 严选",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "匹配度 98%",
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF059669),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.data.reason,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF1F2937),
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            // 2. 产品展示区 (卡片式)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 产品图
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.shopping_bag_outlined,
                              color: Color(0xFF9CA3AF), size: 32),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0),
                                    Colors.white.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.data.productName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (widget.data.price != null)
                                Flexible(
                                  child: Text(
                                    "¥${widget.data.price}",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111827),
                                      fontFamily: 'DIN',
                                      height: 1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "已售 10w+",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                    height: 1.5,
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
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. 思考过程 (Chain of Thought) - DeepSeek 风格
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC), // 极浅灰
                borderRadius: BorderRadius.circular(20), // 更圆润
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: _toggleExpand,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16), // 增加垂直内边距
                      child: Row(
                        children: [
                          // 思考图标
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.psychology_alt,
                                size: 16, color: Color(0xFF64748B)), // 略微调大图标
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "AI 决策链路",
                            style: TextStyle(
                              fontSize: 14, // 略微调大字体
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _isExpanded ? "收起" : "展开",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(Icons.keyboard_arrow_down,
                                size: 18, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 思考过程内容区 (带动画)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _isExpanded
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Divider(
                                    height: 1,
                                    color: Colors.grey.withOpacity(0.1)),
                                const SizedBox(height: 16),
                                if (_visibleSteps.isEmpty)
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text("正在回溯推理路径...",
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 12)),
                                  ),
                                ..._visibleSteps.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final step = entry.value;
                                  final isLast = index ==
                                      widget.data.reasoningSteps.length - 1;

                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 16.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // 简化的时间轴点
                                        Container(
                                          margin: const EdgeInsets.only(
                                              top: 7, right: 12),
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: isLast
                                                ? const Color(0xFF5D5FEF)
                                                : const Color(0xFFCBD5E1),
                                            shape: BoxShape.circle,
                                            boxShadow: isLast
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(
                                                              0xFF5D5FEF)
                                                          .withOpacity(0.4),
                                                      blurRadius: 6,
                                                      spreadRadius: 1,
                                                    )
                                                  ]
                                                : null,
                                          ),
                                        ),
                                        Expanded(
                                          child: AnimatedOpacity(
                                            opacity: 1.0,
                                            duration: const Duration(
                                                milliseconds: 500),
                                            child: Text(
                                              step,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isLast
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFF94A3B8),
                                                height: 1.6,
                                                fontWeight: isLast
                                                    ? FontWeight.w500
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // 4. 底部操作按钮 (悬浮感)
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onAdopt,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18), // 增加高度
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24), // 更圆润
                    ),
                    elevation: 0,
                    shadowColor: Colors.black.withOpacity(0.2),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "一键采纳 · 自动加购",
                        style: TextStyle(
                          fontSize: 16, // 略微调大字体
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
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
