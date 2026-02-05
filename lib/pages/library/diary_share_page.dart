import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../../models/pet_diary.dart';

class DiarySharePage extends StatefulWidget {
  final PetDiary diary;

  const DiarySharePage({super.key, required this.diary});

  @override
  State<DiarySharePage> createState() => _DiarySharePageState();
}

class _DiarySharePageState extends State<DiarySharePage> {
  final GlobalKey _globalKey = GlobalKey();

  // State for customization
  int _selectedStyleIndex = 0;
  String _selectedSticker = '🐶';
  String _selectedWeather = '☀️ 晴朗';
  bool _isGenerating = false;

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
          Text(
            widget.diary.content,
            style: GoogleFonts.lato(
                fontSize: 15, height: 1.6, color: Colors.black87),
          ),
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
          Text(
            widget.diary.content,
            style: GoogleFonts.notoSerif(
                fontSize: 15, height: 1.8, color: Colors.brown[900]),
          ),
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
            Container(
              width: double.infinity,
              height: 200,
              color: Colors.grey[100],
              child: Center(
                child: Text(
                  widget.diary.content,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.indieFlower(fontSize: 16, height: 1.4),
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
              '由智宠合生Peture AI生成',
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
            child: Text(
              widget.diary.content,
              style: GoogleFonts.lato(
                  fontSize: 15, height: 1.6, color: Colors.black87),
            ),
          ),
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
            '由智宠合生Peture AI生成',
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
      } else {
        // Save to Gallery using 'gal' package
        await Gal.putImage(imagePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 已保存到相册'),
              backgroundColor: Colors.green,
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
            backgroundColor: Colors.red,
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
