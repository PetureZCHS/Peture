import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

/// 头像类型枚举
/// 
/// 注意：用户头像和宠物头像都存储在 user-avatars bucket 下
/// - 用户头像路径格式：userId/avatar_timestamp.jpg
/// - 宠物头像路径格式：userId/petId/avatar_timestamp.jpg
enum AvatarType {
  user,   // 用户头像
  pet,    // 宠物头像
}

/// 头像缓存服务
/// 
/// 用于缓存用户头像和宠物头像，避免重复下载消耗流量。
/// 支持在更新头像后自动清除旧缓存。
/// 
/// 缓存位置：应用临时目录 / avatar_cache / {type} /
/// 缓存文件名：storage path 的 MD5 hash
class AvatarCacheService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const String _cacheDirName = 'avatar_cache';
  
  // 单例模式
  static final AvatarCacheService _instance = AvatarCacheService._internal();
  factory AvatarCacheService() => _instance;
  AvatarCacheService._internal();
  
  /// 缓存目录缓存
  final Map<AvatarType, Directory?> _cacheDirs = {};
  
  /// 获取 bucket 名称
  String _getBucketName(AvatarType type) {
    switch (type) {
      case AvatarType.user:
        return 'user-avatars';
      case AvatarType.pet:
        return 'pet-avatars';
    }
  }
  
  /// 获取缓存目录
  Future<Directory> _getCacheDirectory(AvatarType type) async {
    if (_cacheDirs[type] != null) return _cacheDirs[type]!;
    
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(tempDir.path, _cacheDirName, type.name));
    
    // 确保缓存目录存在
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    _cacheDirs[type] = cacheDir;
    return cacheDir;
  }
  
  /// 生成缓存文件名（使用 MD5 hash）
  String _generateCacheFileName(String storagePath) {
    final bytes = utf8.encode(storagePath);
    final digest = md5.convert(bytes);
    return '${digest.toString()}.jpg';
  }
  
  /// 从完整 URL 提取 storage path
  /// 
  /// 例如：https://xxx.supabase.co/storage/v1/object/public/user-avatars/userId/avatar.jpg
  /// 提取：userId/avatar.jpg
  String? _extractStoragePathFromUrl(String url, AvatarType type) {
    final bucket = _getBucketName(type);
    final marker = '/object/public/$bucket/';
    final index = url.indexOf(marker);
    if (index == -1) return null;
    
    var path = url.substring(index + marker.length);
    // 去除 query 参数
    path = path.split('?').first;
    if (path.isEmpty) return null;
    
    return Uri.decodeComponent(path);
  }
  
  /// 获取头像图片 bytes
  /// 
  /// 支持两种输入格式：
  /// 1. 完整的 Storage URL（自动提取 path）
  /// 2. 纯 storage path（如：userId/avatar.jpg）
  /// 
  /// 先检查本地缓存，如果不存在则从 Supabase 下载并缓存
  /// 
  /// [avatarUrlOrPath] 头像 URL 或 Storage path
  /// [type] 头像类型（用户/宠物）
  /// [forceRefresh] 是否强制刷新缓存（重新下载）
  Future<Uint8List?> getAvatarBytes(
    String avatarUrlOrPath, {
    required AvatarType type,
    bool forceRefresh = false,
  }) async {
    if (avatarUrlOrPath.isEmpty) return null;
    
    try {
      // 判断是完整 URL 还是纯 path
      String storagePath;
      if (avatarUrlOrPath.startsWith('http')) {
        final extracted = _extractStoragePathFromUrl(avatarUrlOrPath, type);
        if (extracted == null) {
          debugPrint('⚠️ 无法从 URL 提取 storage path: $avatarUrlOrPath');
          return null;
        }
        storagePath = extracted;
      } else {
        storagePath = avatarUrlOrPath;
      }
      
      // 生成缓存文件路径
      final cacheFileName = _generateCacheFileName(storagePath);
      final cacheDir = await _getCacheDirectory(type);
      final cacheFile = File(p.join(cacheDir.path, cacheFileName));
      
      // 检查缓存是否存在且有效（如果不强制刷新）
      if (!forceRefresh && await cacheFile.exists()) {
        final cachedBytes = await cacheFile.readAsBytes();
        debugPrint('📸 头像缓存命中 [$type]: $storagePath');
        return cachedBytes;
      }
      
      // 缓存未命中，从 Supabase 下载
      debugPrint('☁️ 头像缓存未命中，从 Supabase 下载 [$type]: $storagePath');
      final bucket = _getBucketName(type);
      final bytes = await _client.storage.from(bucket).download(storagePath);
      
      // 保存到缓存（异步，不阻塞返回）
      _saveToCache(cacheFile, bytes);
      
      return bytes;
    } catch (e) {
      debugPrint('❌ 获取头像失败 [$type]: $e');
      return null;
    }
  }
  
  /// 保存图片到缓存（内部方法）
  Future<void> _saveToCache(File cacheFile, Uint8List bytes) async {
    try {
      await cacheFile.writeAsBytes(bytes);
      debugPrint('💾 头像已缓存: ${cacheFile.path}');
    } catch (e) {
      debugPrint('⚠️ 缓存头像失败: $e');
      // 缓存失败不影响主流程
    }
  }
  
  /// 清除指定头像的缓存（更新头像时调用）
  /// 
  /// [avatarUrlOrPath] 头像 URL 或 Storage path
  /// [type] 头像类型
  Future<void> removeFromCache(String avatarUrlOrPath, {required AvatarType type}) async {
    if (avatarUrlOrPath.isEmpty) return;
    
    try {
      // 判断是完整 URL 还是纯 path
      String storagePath;
      if (avatarUrlOrPath.startsWith('http')) {
        final extracted = _extractStoragePathFromUrl(avatarUrlOrPath, type);
        if (extracted == null) return;
        storagePath = extracted;
      } else {
        storagePath = avatarUrlOrPath;
      }
      
      final cacheFileName = _generateCacheFileName(storagePath);
      final cacheDir = await _getCacheDirectory(type);
      final cacheFile = File(p.join(cacheDir.path, cacheFileName));
      
      if (await cacheFile.exists()) {
        await cacheFile.delete();
        debugPrint('🗑️ 已删除头像缓存 [$type]: $storagePath');
      }
    } catch (e) {
      debugPrint('❌ 删除头像缓存失败: $e');
    }
  }
  
  /// 清除指定类型的所有缓存
  Future<void> clearCacheByType(AvatarType type) async {
    try {
      final cacheDir = await _getCacheDirectory(type);
      if (await cacheDir.exists()) {
        final files = await cacheDir.list().toList();
        for (final file in files) {
          if (file is File) {
            await file.delete();
          }
        }
        debugPrint('🗑️ [$type] 头像缓存已清空');
      }
    } catch (e) {
      debugPrint('❌ 清空 [$type] 头像缓存失败: $e');
    }
  }
  
  /// 清除所有头像缓存
  Future<void> clearAllCache() async {
    await Future.wait([
      clearCacheByType(AvatarType.user),
      clearCacheByType(AvatarType.pet),
    ]);
    debugPrint('🗑️ 所有头像缓存已清空');
  }
  
  /// 获取指定类型的缓存大小（字节）
  Future<int> getCacheSizeByType(AvatarType type) async {
    try {
      final cacheDir = await _getCacheDirectory(type);
      if (!await cacheDir.exists()) return 0;
      
      int totalSize = 0;
      final files = await cacheDir.list().toList();
      for (final file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('❌ 获取 [$type] 缓存大小失败: $e');
      return 0;
    }
  }
  
  /// 获取所有缓存大小（字节）
  Future<Map<AvatarType, int>> getAllCacheSize() async {
    return {
      AvatarType.user: await getCacheSizeByType(AvatarType.user),
      AvatarType.pet: await getCacheSizeByType(AvatarType.pet),
    };
  }
}
