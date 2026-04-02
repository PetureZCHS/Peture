import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 头像：正方形裁剪 + JPEG 压缩（用户/宠物共用）
class AvatarImageHelper {
  AvatarImageHelper._();

  static const int _maxEdge = 512;
  static const int _quality = 85;

  /// 用户取消裁剪时返回 null
  static Future<File?> cropAndCompressAvatar(String sourcePath) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '裁剪头像',
          toolbarColor: const Color(0xFF4E7EFF),
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: '裁剪头像',
          aspectRatioLockEnabled: true,
        ),
      ],
    );
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
        final f = File(cropped.path);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
      return File(out.path);
    }
    debugPrint('头像压缩失败，使用裁剪原图');
    return File(cropped.path);
  }
}
