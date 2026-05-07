import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

/// AI 配图本地缓存服务
/// 
/// 用于缓存日记中的 AI 生成配图，避免重复下载消耗流量。
/// 缓存位置：应用临时目录 / ai_image_cache /
/// 缓存文件名：storage path 的 MD5 hash
class AiImageCacheService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const String _cacheDirName = 'ai_image_cache';
  
  /// 缓存目录路径（延迟初始化）
  Directory? _cacheDir;
  
  /// 获取缓存目录
  Future<Directory> get _cacheDirectory async {
    if (_cacheDir != null) return _cacheDir!;
    
    final tempDir = await getTemporaryDirectory();
    _cacheDir = Directory(p.join(tempDir.path, _cacheDirName));
    
    // 确保缓存目录存在
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    
    return _cacheDir!;
  }
  
  /// 生成缓存文件名（使用 MD5 hash）
  String _generateCacheFileName(String storagePath) {
    final bytes = utf8.encode(storagePath);
    final digest = md5.convert(bytes);
    return '${digest.toString()}.png';
  }
  
  /// 获取图片 bytes
  /// 
  /// 先检查本地缓存，如果不存在则从 Supabase 下载并缓存
  /// 
  /// [storagePath] Supabase Storage 中的文件路径（如：user-id/generated/diary_xxx.png）
  /// [forceRefresh] 是否强制刷新缓存（重新下载）
  Future<Uint8List?> getImageBytes(String storagePath, {bool forceRefresh = false}) async {
    try {
      // 生成缓存文件路径
      final cacheFileName = _generateCacheFileName(storagePath);
      final cacheDir = await _cacheDirectory;
      final cacheFile = File(p.join(cacheDir.path, cacheFileName));
      
      // 检查缓存是否存在且有效（如果不强制刷新）
      if (!forceRefresh && await cacheFile.exists()) {
        final cachedBytes = await cacheFile.readAsBytes();
        debugPrint('📸 AI 图片缓存命中: $storagePath');
        return cachedBytes;
      }
      
      // 缓存未命中，从 Supabase 下载
      debugPrint('☁️ AI 图片缓存未命中，从 Supabase 下载: $storagePath');
      final bytes = await _client.storage
          .from('ai-wallpapers')
          .download(storagePath);
      
      // 保存到缓存（异步，不阻塞返回）
      _saveToCache(cacheFile, bytes);
      
      return bytes;
    } catch (e) {
      debugPrint('❌ 获取 AI 图片失败: $e');
      return null;
    }
  }
  
  /// 保存图片到缓存（内部方法）
  Future<void> _saveToCache(File cacheFile, Uint8List bytes) async {
    try {
      await cacheFile.writeAsBytes(bytes);
      debugPrint('💾 AI 图片已缓存: ${cacheFile.path}');
    } catch (e) {
      debugPrint('⚠️ 缓存 AI 图片失败: $e');
      // 缓存失败不影响主流程
    }
  }
  
  /// 清除所有缓存
  Future<void> clearCache() async {
    try {
      final cacheDir = await _cacheDirectory;
      if (await cacheDir.exists()) {
        final files = await cacheDir.list().toList();
        for (final file in files) {
          if (file is File) {
            await file.delete();
          }
        }
        debugPrint('🗑️ AI 图片缓存已清空');
      }
    } catch (e) {
      debugPrint('❌ 清空 AI 图片缓存失败: $e');
    }
  }
  
  /// 获取缓存大小（字节）
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await _cacheDirectory;
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
      debugPrint('❌ 获取缓存大小失败: $e');
      return 0;
    }
  }
  
  /// 删除指定图片的缓存
  Future<void> removeFromCache(String storagePath) async {
    try {
      final cacheFileName = _generateCacheFileName(storagePath);
      final cacheDir = await _cacheDirectory;
      final cacheFile = File(p.join(cacheDir.path, cacheFileName));
      
      if (await cacheFile.exists()) {
        await cacheFile.delete();
        debugPrint('🗑️ 已删除缓存: $storagePath');
      }
    } catch (e) {
      debugPrint('❌ 删除缓存失败: $e');
    }
  }
}
