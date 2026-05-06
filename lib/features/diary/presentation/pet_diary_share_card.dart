import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ========== 水印配置 ==========
const String _shareWatermarkText = '智宠合生 Peture AI 生成';

class _ShareWatermarkMetrics {
  final double horizontalPadding;
  final double verticalPadding;
  final double textPaddingH;
  final double textPaddingV;
  final double fontSize;
  final double letterSpacing;
  final double blurRadius;
  final Offset shadowOffset;
  final double borderRadius;

  const _ShareWatermarkMetrics({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.textPaddingH,
    required this.textPaddingV,
    required this.fontSize,
    required this.letterSpacing,
    required this.blurRadius,
    required this.shadowOffset,
    required this.borderRadius,
  });
}

_ShareWatermarkMetrics _computeShareWatermarkMetrics(Size imageSize) {
  final ratio = imageSize.width / math.max(1.0, imageSize.height);
  final isSixteenByNine = (ratio - (16 / 9)).abs() <= 0.03;
  final scale = (imageSize.shortestSide / 1080.0).clamp(0.2, 1.5).toDouble();
  final fontBoost = isSixteenByNine ? 2.0 : 1.0;
  return _ShareWatermarkMetrics(
    horizontalPadding: 24.0 * scale,
    verticalPadding: 16.0 * scale,
    textPaddingH: 14.0 * scale,
    textPaddingV: 8.0 * scale,
    fontSize: 30.0 * scale * fontBoost,
    letterSpacing: 0.4 * scale,
    blurRadius: 6.0 * scale,
    shadowOffset: Offset(0, 1.5 * scale),
    borderRadius: 14.0 * scale,
  );
}

double _computeShareWatermarkTextFitScale({
  required String text,
  required double maxTextWidth,
  required double fontSize,
  required double letterSpacing,
}) {
  final safeMaxWidth = math.max(1.0, maxTextWidth);
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: letterSpacing,
      ),
    ),
    textDirection: ui.TextDirection.ltr,
    maxLines: 1,
  )..layout();

  if (painter.width <= safeMaxWidth) {
    return 1.0;
  }

  return (safeMaxWidth / painter.width).clamp(0.45, 1.0);
}

enum ShareCardStyle {
  minimal, // 极简艺术 (Art Gallery)
  paper,   // 手账笔记 (Journal)
}

class PetDiaryShareCard extends StatelessWidget {
  final String content;
  final String petName;
  final String? avatarUrl; // 宠物头像URL或路径
  final String? breed;
  final String? gender;
  final DateTime date;
  final ShareCardStyle style;
  final double width;
  final File? diaryImageFile; // AI生成的日记配图（本地文件）
  final String? diaryImageUrl; // AI生成的日记配图（网络URL）

  const PetDiaryShareCard({
    super.key,
    required this.content,
    required this.petName,
    this.avatarUrl,
    this.breed,
    this.gender,
    required this.date,
    this.style = ShareCardStyle.minimal,
    this.width = 300,
    this.diaryImageFile,
    this.diaryImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    // 基础容器
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. 背景层 (纹理/渐变/装饰)
          _buildBackgroundLayer(),

          // 2. 内容层
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildContent(),
                if (_hasDiaryImage()) ...[
                  const SizedBox(height: 20),
                  _buildDiaryImage(),
                ],
                const SizedBox(height: 32),
                _buildFooter(),
              ],
            ),
          ),
          
          // 3. 装饰层 (浮动元素/水印)
          _buildDecorationLayer(),
        ],
      ),
    );
  }

  // --- 样式辅助方法 ---

  Color _getBackgroundColor() {
    switch (style) {
      case ShareCardStyle.minimal:
        return Colors.white;
      case ShareCardStyle.paper:
        return const Color(0xFFF9F5EB); // 暖色纸张
    }
  }

  // --- 组件构建方法 ---

  Widget _buildBackgroundLayer() {
    switch (style) {
      case ShareCardStyle.minimal:
        return Positioned(
          top: -50,
          right: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.05),
                  Colors.purple.withOpacity(0.05)
                ],
              ),
            ),
          ),
        );
      case ShareCardStyle.paper: // 手账风
        return Positioned.fill(
          child: CustomPaint(
            painter: _NotebookPainter(),
          ),
        );
    }
  }

  Widget _buildDecorationLayer() {
    switch (style) {
      case ShareCardStyle.minimal:
        return const SizedBox();
      case ShareCardStyle.paper:
        return const Positioned(
          top: 0,
          right: 30,
          child: Icon(Icons.bookmark, color: Color(0xFFFF6B6B), size: 40),
        );
    }
  }

  Widget _buildHeader() {
    // 其他风格头部
    return Row(
      children: [
        _buildAvatar(48),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              petName,
              style: GoogleFonts.notoSans(
                color: _getTextColor(),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getAccentColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                DateFormat('yyyy.MM.dd | EEEE', 'zh_CN').format(date),
                style: TextStyle(
                  color: _getAccentColor(),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        // 极简风右上角加个Logo或引号
        if (style == ShareCardStyle.minimal)
          Icon(Icons.format_quote_rounded, color: Colors.grey.shade200, size: 40),
      ],
    );
  }

  Widget _buildContent() {
    final baseTextStyle = _getBaseTextStyle();
    final hashtagStyle = baseTextStyle.copyWith(
      color: const Color(0xFF2196F3), // 小红书风格的蓝色标签
      fontWeight: FontWeight.w500,
    );

    return RichText(
      text: _buildHashtagTextSpan(content, baseTextStyle, hashtagStyle),
      textAlign: style == ShareCardStyle.paper ? TextAlign.left : TextAlign.justify,
    );
  }

  TextStyle _getBaseTextStyle() {
    switch (style) {
      case ShareCardStyle.paper: // 手账
        return GoogleFonts.zhiMangXing(
          color: const Color(0xFF2D3436),
          fontSize: 20,
          height: 1.6,
        );
      case ShareCardStyle.minimal:
        return const TextStyle( // 使用系统字体确保中文可读性
          color: Color(0xFF2D3436),
          fontSize: 15,
          height: 1.9,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.3,
        );
    }
  }

  /// 解析文本中的 #标签，生成带样式的 TextSpan
  TextSpan _buildHashtagTextSpan(
    String text,
    TextStyle baseStyle,
    TextStyle hashtagStyle,
  ) {
    final List<TextSpan> spans = [];
    final RegExp hashtagRegExp = RegExp(r'#[\w\u4e00-\u9fa5]+');
    int currentIndex = 0;

    for (final match in hashtagRegExp.allMatches(text)) {
      // 添加标签前的普通文本
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: baseStyle,
        ));
      }
      // 添加蓝色标签
      spans.add(TextSpan(
        text: match.group(0),
        style: hashtagStyle,
      ));
      currentIndex = match.end;
    }

    // 添加剩余的普通文本
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans);
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Divider(
          color: _getTextColor().withOpacity(0.1),
          height: 1,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // 二维码占位符
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getTextColor().withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(Icons.qr_code_2, color: _getTextColor().withOpacity(0.5)),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Peture',
                      style: GoogleFonts.dancingScript(
                        color: _getTextColor(),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Scan to join',
                      style: TextStyle(
                        color: _getTextColor().withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // 心情指数或互动
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _getTextColor().withOpacity(0.1)),
              ),
              child: Icon(Icons.thumb_up_alt_outlined, size: 16, color: _getTextColor().withOpacity(0.5)),
            ),
          ],
        ),
      ],
    );
  }

  // --- 日记配图构建 ---

  bool _hasDiaryImage() {
    return diaryImageFile != null ||
        (diaryImageUrl != null && diaryImageUrl!.isNotEmpty);
  }

  Widget _buildDiaryImage() {
    ImageProvider? imageProvider;
    if (diaryImageFile != null) {
      imageProvider = FileImage(diaryImageFile!);
    } else if (diaryImageUrl != null && diaryImageUrl!.isNotEmpty) {
      final uri = Uri.tryParse(diaryImageUrl!);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        imageProvider = NetworkImage(diaryImageUrl!);
      } else {
        imageProvider = FileImage(File(diaryImageUrl!));
      }
    }

    if (imageProvider == null) return const SizedBox();

    // Promote to non-null for use inside the LayoutBuilder closure
    final ImageProvider nonNullImageProvider = imageProvider;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Image(
                image: nonNullImageProvider,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
              // 水印 overlay — 模仿 diary_detail_page.dart 中 _ContainedImageWithWatermark 的定位逻辑
              _buildShareWatermarkOverlay(constraints),
            ],
          );
        },
      ),
    );
  }

  /// 构建分享卡片中的水印覆盖层
  Widget _buildShareWatermarkOverlay(BoxConstraints constraints) {
    final imageSize = Size(constraints.maxWidth, constraints.maxHeight);
    final metrics = _computeShareWatermarkMetrics(imageSize);
    final maxTextWidth = (imageSize.width * 0.75) - (metrics.textPaddingH * 2);
    final textFitScale = _computeShareWatermarkTextFitScale(
      text: _shareWatermarkText,
      maxTextWidth: maxTextWidth,
      fontSize: metrics.fontSize,
      letterSpacing: metrics.letterSpacing,
    );

    return Positioned(
      right: metrics.horizontalPadding,
      bottom: metrics.verticalPadding,
      child: IgnorePointer(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.textPaddingH,
            vertical: metrics.textPaddingV,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.22),
            borderRadius: BorderRadius.circular(metrics.borderRadius),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: math.max(1, maxTextWidth),
            ),
            child: Text(
              _shareWatermarkText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: metrics.fontSize * textFitScale,
                fontWeight: FontWeight.w600,
                letterSpacing: metrics.letterSpacing * textFitScale,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: metrics.blurRadius * textFitScale,
                    offset: metrics.shadowOffset * textFitScale,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 头像构建 ---

  Widget _buildAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade100, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        image: _getAvatarImage(),
      ),
      child: _getAvatarImage() == null
          ? Center(
              child: Text(
                petName.isNotEmpty ? petName.substring(0, 1) : '',
                style: TextStyle(
                  color: _getAccentColor(),
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  DecorationImage? _getAvatarImage() {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;
    
    ImageProvider? imageProvider;
    final uri = Uri.tryParse(avatarUrl!);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
       imageProvider = NetworkImage(avatarUrl!);
    } else {
       imageProvider = FileImage(File(avatarUrl!));
    }

    return DecorationImage(
      image: imageProvider,
      fit: BoxFit.cover,
    );
  }

  // --- 颜色配置 ---

  Color _getTextColor() {
    return const Color(0xFF2D3436);
  }

  Color _getAccentColor() {
    switch (style) {
      case ShareCardStyle.minimal:
        return const Color(0xFF2D3436); // 深灰
      case ShareCardStyle.paper:
        return const Color(0xFFFF6B6B); // 珊瑚红
    }
  }
}

class _NotebookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 纸张底色
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF9F5EB),
    );

    // 横线
    final linePaint = Paint()
      ..color = Colors.blue.withOpacity(0.05)
      ..strokeWidth = 1.0;

    const double lineHeight = 30.0;
    for (double y = lineHeight; y < size.height; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // 竖线 (页边距)
    final marginPaint = Paint()
      ..color = Colors.red.withOpacity(0.05)
      ..strokeWidth = 1.0;
    
    canvas.drawLine(
      const Offset(40, 0),
      Offset(40, size.height),
      marginPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
