import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../shared/design_system/peture_design_system.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../../../core/page_tracker_mixin.dart';
import '../../../services/ai_image_cache_service.dart';
import '../../../services/analytics_service.dart';
import '../../../shared/models/pet_diary.dart';

// ========== 水印配置 ==========
const String _watermarkText = '智宠合生 Peture AI 生成';

class _WatermarkMetrics {
  final double horizontalPadding;
  final double verticalPadding;
  final double textPaddingH;
  final double textPaddingV;
  final double fontSize;
  final double letterSpacing;
  final double blurRadius;
  final ui.Offset shadowOffset;
  final double borderRadius;

  const _WatermarkMetrics({
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

_WatermarkMetrics _computeWatermarkMetrics(Size imageSize) {
  final ratio = imageSize.width / math.max(1.0, imageSize.height);
  final isSixteenByNine = (ratio - (16 / 9)).abs() <= 0.03;
  final scale = (imageSize.shortestSide / 1080.0).clamp(0.2, 1.5).toDouble();
  final fontBoost = isSixteenByNine ? 2.0 : 1.0;
  return _WatermarkMetrics(
    horizontalPadding: 24.0 * scale,
    verticalPadding: 16.0 * scale,
    textPaddingH: 14.0 * scale,
    textPaddingV: 8.0 * scale,
    fontSize: 30.0 * scale * fontBoost,
    letterSpacing: 0.4 * scale,
    blurRadius: 6.0 * scale,
    shadowOffset: ui.Offset(0, 1.5 * scale),
    borderRadius: 14.0 * scale,
  );
}

double _computeWatermarkTextFitScale({
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

Widget _buildWatermarkOverlay(BoxConstraints constraints) {
  final imageSize = Size(constraints.maxWidth, constraints.maxHeight);
  final metrics = _computeWatermarkMetrics(imageSize);
  final maxTextWidth = (imageSize.width * 0.75) - (metrics.textPaddingH * 2);
  final textFitScale = _computeWatermarkTextFitScale(
    text: _watermarkText,
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
            _watermarkText,
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

class DiarySharePage extends StatefulWidget {
  final PetDiary diary;
  final String? petType;

  const DiarySharePage({
    super.key,
    required this.diary,
    this.petType,
  });

  @override
  State<DiarySharePage> createState() => _DiarySharePageState();
}

class _DiarySharePageState extends State<DiarySharePage>
    with PageTrackerMixin<DiarySharePage> {
  final GlobalKey _globalKey = GlobalKey();

  // State for customization
  int _selectedStyleIndex = 0;
  String _selectedSticker = '🐶';
  String _selectedWeather = '☀️ 晴朗';
  bool _isGenerating = false;

  // AI Image
  Uint8List? _aiImageBytes;

  // Data options
  final List<String> _stickers = [
    '🐶',
    '🐱',
    '🐾',
    '🦴',
    '🎾',
    '🍦',
    '✨',
    '❤️'
  ];
  final List<String> _weathers = [
    '☀️ 晴朗',
    '☁️ 多云',
    '🌧️ 下雨',
    '❄️ 下雪',
    '🌬️ 大风'
  ];
  final List<String> _styleNames = ['简约白', '温暖手账', '拍立得', '萌宠主题'];

  @override
  void initState() {
    super.initState();
    _loadAiImage();
    // 根据宠物类型设置默认贴纸
    if (widget.petType != null) {
      final type = widget.petType!.toLowerCase();
      if (type == '狗' || type == 'dog') {
        _selectedSticker = '🐶';
      } else if (type == '猫' || type == 'cat') {
        _selectedSticker = '🐱';
      }
    }
  }

  final AiImageCacheService _imageCacheService = AiImageCacheService();

  Future<void> _loadAiImage() async {
    if (widget.diary.aiImg == null || widget.diary.aiImg!.isEmpty) {
      return;
    }

    try {
      // 使用缓存服务获取图片
      final bytes = await _imageCacheService.getImageBytes(widget.diary.aiImg!);

      if (mounted) {
        setState(() {
          _aiImageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load AI image: $e');
    }
  }

  @override
  String get analyticsPageName => 'diary_share';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '生成分享卡片',
          style: GoogleFonts.notoSerif(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isGenerating ? null : () => _captureAndShare(true),
            child: const Text('分享',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Preview Area
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: RepaintBoundary(
                  key: _globalKey,
                  child: _buildCardPreview(),
                ),
              ),
            ),
          ),

          // Controls Area
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  // Tabs
                  DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        const TabBar(
                          labelColor: Colors.black87,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Colors.blue,
                          indicatorSize: TabBarIndicatorSize.label,
                          tabs: [
                            Tab(text: '样式风格'),
                            Tab(text: '形象贴纸'),
                            Tab(text: '天气信息'),
                          ],
                        ),
                        SizedBox(
                          height: 120,
                          child: TabBarView(
                            children: [
                              _buildStyleSelector(),
                              _buildStickerSelector(),
                              _buildWeatherSelector(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isGenerating
                                ? null
                                : () => _captureAndShare(
                                    false), // Save (simulated via share for now or file save)
                            icon: const Icon(Icons.save_alt),
                            label: const Text('保存到相册'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isGenerating
                                ? null
                                : () => _captureAndShare(true),
                            icon: const Icon(Icons.share),
                            label: const Text('直接分享'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPreview() {
    switch (_selectedStyleIndex) {
      case 1:
        return _buildWarmStyle();
      case 2:
        return _buildPolaroidStyle();
      case 3:
        return _buildPetStyle();
      case 0:
      default:
        return _buildSimpleStyle();
    }
  }

  // --- Styles ---

  Widget _buildSimpleStyle() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderRow(),
          const SizedBox(height: 20),
          _buildHashtagText(
            text: widget.diary.content,
            style: GoogleFonts.lato(
                fontSize: 15, height: 1.6, color: Colors.black87),
          ),
          if (_aiImageBytes != null) ...[
            const SizedBox(height: 16),
            _buildAiImageWithWatermark(),
          ],
          const SizedBox(height: 30),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildWarmStyle() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF6E3), // Warm beige
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Icon(Icons.push_pin, color: Colors.red[300], size: 20)),
          const SizedBox(height: 10),
          _buildHeaderRow(),
          const Divider(color: Colors.brown, thickness: 0.5),
          const SizedBox(height: 16),
          _buildHashtagText(
            text: widget.diary.content,
            style: GoogleFonts.notoSerif(
                fontSize: 15, height: 1.8, color: Colors.brown[900]),
          ),
          if (_aiImageBytes != null) ...[
            const SizedBox(height: 16),
            _buildAiImageWithWatermark(),
          ],
          const SizedBox(height: 30),
          _buildFooter(color: Colors.brown[400]),
        ],
      ),
    );
  }

  Widget _buildPolaroidStyle() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C), // Dark background
        borderRadius: BorderRadius.circular(0),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拍立得风格：AI 图片在上方（如果有）
            if (_aiImageBytes != null) ...[
              _buildAiImageWithWatermark(),
              const SizedBox(height: 16),
            ],
            // 完整的文字内容（带蓝色标签）
            Container(
              width: double.infinity,
              color: Colors.grey[100],
              padding: const EdgeInsets.all(12),
              child: RichText(
                text: TextSpan(
                  children: _buildHashtagSpans(
                    widget.diary.content,
                    baseStyle: GoogleFonts.indieFlower(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('yyyy.MM.dd').format(widget.diary.timestamp),
                  style:
                      GoogleFonts.caveat(fontSize: 20, color: Colors.black87),
                ),
                Text(_selectedSticker, style: const TextStyle(fontSize: 24)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '由智宠合生 Peture AI 生成',
              style: GoogleFonts.caveat(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetStyle() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F5), // Lavender blush
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.pink[100]!, width: 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderRow(),
              Icon(Icons.pets, color: Colors.pink[200], size: 24),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _buildHashtagText(
              text: widget.diary.content,
              style: GoogleFonts.lato(
                  fontSize: 15, height: 1.6, color: Colors.black87),
            ),
          ),
          if (_aiImageBytes != null) ...[
            const SizedBox(height: 16),
            _buildAiImageWithWatermark(),
          ],
          const SizedBox(height: 30),
          _buildFooter(color: Colors.pink[300]),
        ],
      ),
    );
  }

  // --- Components ---

  Widget _buildHeaderRow() {
    return Row(
      children: [
        Text(
          _selectedSticker,
          style: const TextStyle(fontSize: 32),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('yyyy年MM月dd日').format(widget.diary.timestamp),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedWeather,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter({Color? color}) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: color ?? Colors.grey[400]),
          const SizedBox(width: 4),
          Text(
            '由智宠合生 Peture AI 生成',
            style: TextStyle(
              fontSize: 10,
              color: color ?? Colors.grey[400],
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// 解析文本中的 #标签，生成带样式的 InlineSpan 列表（小红书风格蓝色标签）
  List<InlineSpan> _buildHashtagSpans(String text,
      {required TextStyle baseStyle}) {
    const hashtagStyle = TextStyle(
      color: Color(0xFF2196F3), // 小红书风格的蓝色
      fontWeight: FontWeight.w500,
    );

    final List<InlineSpan> spans = [];
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
        style: baseStyle.merge(hashtagStyle),
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

    return spans;
  }

  /// 构建带蓝色标签的 RichText（简约白/萌宠主题风格）
  Widget _buildHashtagText({
    required String text,
    required TextStyle style,
    TextAlign textAlign = TextAlign.left,
  }) {
    return RichText(
      text: TextSpan(children: _buildHashtagSpans(text, baseStyle: style)),
      textAlign: textAlign,
    );
  }

  Widget _buildAiImageWithWatermark() {
    if (_aiImageBytes == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Image.memory(
                _aiImageBytes!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Text('图片加载失败'),
                    ),
                  );
                },
              ),
              _buildWatermarkOverlay(constraints),
            ],
          );
        },
      ),
    );
  }

  // --- Selectors ---

  Widget _buildStyleSelector() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _styleNames.length,
      itemBuilder: (context, index) {
        final isSelected = _selectedStyleIndex == index;
        return GestureDetector(
          onTap: () => setState(() => _selectedStyleIndex = index),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: isSelected ? null : Border.all(color: Colors.grey[300]!),
            ),
            alignment: Alignment.center,
            child: Text(
              _styleNames[index],
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStickerSelector() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _stickers.length,
      itemBuilder: (context, index) {
        final sticker = _stickers[index];
        final isSelected = _selectedSticker == sticker;
        return GestureDetector(
          onTap: () => setState(() => _selectedSticker = sticker),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            width: 60,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey[200]!,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(sticker, style: const TextStyle(fontSize: 28)),
          ),
        );
      },
    );
  }

  Widget _buildWeatherSelector() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _weathers.length,
      itemBuilder: (context, index) {
        final weather = _weathers[index];
        final isSelected = _selectedWeather == weather;
        return GestureDetector(
          onTap: () => setState(() => _selectedWeather = weather),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey[200]!,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              weather,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Actions ---

  Future<void> _captureAndShare(bool isShare) async {
    setState(() => _isGenerating = true);
    try {
      // Wait for any potential layout updates
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. Capture Image
      final boundary = _globalKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('无法获取渲染边界');
      }

      // Use a slightly lower pixel ratio to avoid memory issues, but still high quality
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('图片数据为空');
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();

      // 2. Save to temporary file
      final directory = await getTemporaryDirectory();
      final imagePath =
          '${directory.path}/pet_diary_share_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(pngBytes);

      // 3. Share or Save
      if (isShare) {
        if (!mounted) return;
        // Calculate share position origin for iPad
        final box = context.findRenderObject() as RenderBox?;
        final shareOrigin = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : const Rect.fromLTWH(0, 0, 100, 100); // Fallback

        await Share.shareXFiles(
          [XFile(imagePath)],
          text: '我的宠物日记 ✨ #Peture',
          sharePositionOrigin: shareOrigin,
        );
        AnalyticsService.logEvent(
          'share_card_click',
          params: {
            'card_id': _selectedStyleIndex.toString(),
            'card_style': _styleNames[_selectedStyleIndex],
            'diary_id': widget.diary.id ?? 'unknown',
            'diary_style': widget.diary.style,
            'entry_page': 'DiarySharePage',
          },
        );
      } else {
        // Save to Gallery using 'gal' package
        await Gal.putImage(imagePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 已保存到相册'),
              backgroundColor: PetureColors.success,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error generating image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: ${e.toString()}'),
            backgroundColor: PetureColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
