import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../widgets/avatar_crop_page.dart';

/// 头像：全屏圆形裁剪（Flutter）+ JPEG 压缩（用户/宠物共用）
class AvatarImageHelper {
  AvatarImageHelper._();

  static const int _maxEdge = 512;
  static const int _quality = 85;

  /// [context] 用于打开裁剪页；用户取消裁剪时返回 null
  static Future<File?> cropAndCompressAvatar(
    BuildContext context,
    String sourcePath,
  ) async {
    if (!context.mounted) return null;
    final cropped = await AvatarCropPage.open(context, sourcePath);
    if (cropped == null) return null;

    final dir = await getTemporaryDirectory();
    final targetPath = p.join(dir.path, '${const Uuid().v4()}_avatar.jpg');
    final out = await FlutterImageCompress.compressAndGetFile(
      cropped.path,
      targetPath,
      quality: _quality,
      format: CompressFormat.jpeg,
      minWidth: _maxEdge,
      minHeight: _maxEdge,
    );
    if (out != null) {
      try {
        if (cropped.existsSync()) await cropped.delete();
      } catch (_) {}
      return File(out.path);
    }
    debugPrint('头像压缩失败，使用裁剪原图');
    return cropped;
  }
}
