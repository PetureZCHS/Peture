import 'dart:io';

import 'package:custom_image_crop/custom_image_crop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 全屏头像裁剪：圆形遮罩辅助对齐，但实际导出为方形区域。
class AvatarCropPage extends StatefulWidget {
  const AvatarCropPage({super.key, required this.imagePath});

  final String imagePath;

  static Future<File?> open(BuildContext context, String imagePath) {
    return Navigator.of(context).push<File?>(
      PageRouteBuilder<File?>(
        fullscreenDialog: true,
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (ctx, _, __) => AvatarCropPage(imagePath: imagePath),
        transitionsBuilder: (ctx, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  late final CustomImageCropController _controller;
  bool _busy = false;

  static const Color _primaryBlue = Color(0xFF0095FF);

  @override
  void initState() {
    super.initState();
    _controller = CustomImageCropController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDone() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final mem = await _controller.onCropImage();
      if (!mounted) return;
      if (mem == null) {
        setState(() => _busy = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未能生成裁剪图，请重试')),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final outPath = p.join(dir.path, '${const Uuid().v4()}_avatar_crop.png');
      await File(outPath).writeAsBytes(mem.bytes);
      if (mounted) Navigator.of(context).pop(File(outPath));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _resetRotation() {
    final current = _controller.cropImageData;
    if (current == null) return;
    _controller.setData(
      CropImageData(
        x: current.x,
        y: current.y,
        scale: current.scale,
        angle: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.imagePath);
    if (!file.existsSync()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('图片不存在', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: Colors.white,
                    tooltip: '返回',
                  ),
                  const Expanded(
                    child: Text(
                      '移动和缩放',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: CustomImageCrop(
                  cropController: _controller,
                  image: FileImage(file),
                  shape: CustomCropShape.Circle,
                  maskShape: CustomCropShape.Circle,
                  backgroundColor: Colors.black,
                  overlayColor: const Color(0x8A000000),
                  outlineColor: Colors.white,
                  outlineStrokeWidth: 2.5,
                  drawPath: SolidCropPathPainter.drawPath,
                  imageFit: CustomImageFit.fitCropSpace,
                  cropPercentage: 0.82,
                  canRotate: true,
                  canScale: true,
                  canMove: true,
                  forceInsideCropArea: true,
                  // 保留方形完整区域，避免圆形透明区在 JPEG 中变黑。
                  clipShapeOnCrop: false,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _resetRotation,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        '回正',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _busy ? null : _onDone,
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              _primaryBlue.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                '完成',
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
            ),
            ],
          ),
        ),
      ),
    );
  }
}
