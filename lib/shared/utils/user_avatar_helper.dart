// 用户头像管理工具类

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserAvatarHelper {
  static const String _keyPrefix = 'user_avatar_';
  static const String _sourceUrlKeyPrefix = 'user_avatar_source_url_';

  /// 获取当前用户的头像路径
  static Future<String?> getCurrentUserAvatarPath() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;

      final prefs = await SharedPreferences.getInstance();
      final avatarPath = prefs.getString('$_keyPrefix${user.id}');

      // 检查文件是否存在
      if (avatarPath != null && File(avatarPath).existsSync()) {
        return avatarPath;
      }

      return null;
    } catch (e) {
      debugPrint('获取用户头像路径失败: $e');
      return null;
    }
  }

  /// 构建用户头像Widget
  static Widget buildUserAvatar({
    String? avatarPath,
    String? fallbackText,
    double radius = 24,
    Color? backgroundColor,
    TextStyle? textStyle,
  }) {
    final hasAvatar = avatarPath != null && File(avatarPath).existsSync();

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.blue.withOpacity(0.1),
      backgroundImage: hasAvatar ? FileImage(File(avatarPath)) : null,
      child: !hasAvatar
          ? Text(
              fallbackText ?? '?',
              style: textStyle ??
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.6,
                  ),
            )
          : null,
    );
  }

  /// 获取头像的文字占位符
  static String getAvatarText({String? userName, String? userEmail}) {
    if (userName?.isNotEmpty == true) {
      return userName![0].toUpperCase();
    } else if (userEmail?.isNotEmpty == true) {
      return userEmail![0].toUpperCase();
    } else {
      return '?';
    }
  }

  /// 获取显示名称
  static String getDisplayName({String? userName, String? userEmail}) {
    if (userName?.isNotEmpty == true) {
      return userName!;
    } else if (userEmail?.isNotEmpty == true) {
      return userEmail!.split('@')[0];
    } else {
      return '点击登录';
    }
  }

  /// 保存用户头像路径
  static Future<bool> saveUserAvatarPath(String avatarPath) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString('$_keyPrefix${user.id}', avatarPath);
    } catch (e) {
      debugPrint('保存用户头像路径失败: $e');
      return false;
    }
  }

  /// 记录当前本地缓存对应的云端头像 URL（不含 query，用于判断是否需要重新 download）
  static Future<void> setAvatarSourceUrlBasename(String? urlWithoutQuery) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      final k = '$_sourceUrlKeyPrefix${user.id}';
      if (urlWithoutQuery == null || urlWithoutQuery.isEmpty) {
        await prefs.remove(k);
      } else {
        await prefs.setString(k, urlWithoutQuery);
      }
    } catch (e) {
      debugPrint('setAvatarSourceUrlBasename 失败: $e');
    }
  }

  static Future<String?> getAvatarSourceUrlBasename() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_sourceUrlKeyPrefix${user.id}');
    } catch (e) {
      return null;
    }
  }

  /// 若 URL 与本地缓存一致则复用；否则 [downloadFn] 下载后写入 prefs。
  static Future<String?> ensureCachedAvatarFile(
    String? avatarPublicUrl,
    Future<String?> Function(String? url) downloadFn,
  ) async {
    final base = (avatarPublicUrl ?? '').split('?').first;
    if (base.isEmpty) {
      await clearLocalAvatarCacheForCurrentUser();
      return null;
    }
    final remembered = await getAvatarSourceUrlBasename();
    final existingPath = await getCurrentUserAvatarPath();
    if (remembered == base &&
        existingPath != null &&
        File(existingPath).existsSync()) {
      return existingPath;
    }
    await clearLocalAvatarCacheForCurrentUser();
    final local = await downloadFn(avatarPublicUrl);
    if (local != null) {
      await saveUserAvatarPath(local);
      await setAvatarSourceUrlBasename(base);
    }
    return local;
  }

  /// 删除磁盘上的缓存文件并清除 prefs（更换头像前调用，避免旧文件盖住新图）
  static Future<void> clearLocalAvatarCacheForCurrentUser() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix${user.id}';
      final path = prefs.getString(key);
      if (path != null) {
        try {
          final f = File(path);
          if (f.existsSync()) await f.delete();
        } catch (e) {
          debugPrint('删除本地头像文件失败: $e');
        }
      }
      await prefs.remove(key);
      await prefs.remove('$_sourceUrlKeyPrefix${user.id}');
    } catch (e) {
      debugPrint('clearLocalAvatarCacheForCurrentUser 失败: $e');
    }
  }

  /// 删除用户头像路径
  static Future<bool> removeUserAvatarPath() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove('$_keyPrefix${user.id}');
    } catch (e) {
      debugPrint('删除用户头像路径失败: $e');
      return false;
    }
  }

  /// 清理无效的头像文件
  static Future<void> cleanupInvalidAvatars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_keyPrefix));

      for (final key in keys) {
        final path = prefs.getString(key);
        if (path != null && !File(path).existsSync()) {
          await prefs.remove(key);
          debugPrint('清理无效头像路径: $path');
        }
      }
    } catch (e) {
      debugPrint('清理头像失败: $e');
    }
  }
}
