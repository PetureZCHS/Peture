import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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
    TextStyle textStyle;
    switch (style) {
      case ShareCardStyle.paper: // 手账
        textStyle = GoogleFonts.zhiMangXing(
          color: const Color(0xFF2D3436),
          fontSize: 20,
          height: 1.6,
        );
        break;
      case ShareCardStyle.minimal:
        textStyle = const TextStyle( // 使用系统字体确保中文可读性
          color: Color(0xFF2D3436),
          fontSize: 15,
          height: 1.9,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.3,
        );
    }

    return Text(
      content,
      style: textStyle,
      textAlign: style == ShareCardStyle.paper ? TextAlign.left : TextAlign.justify,
    );
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
