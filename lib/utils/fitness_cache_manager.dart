// 必需导入
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fitness_course.dart';

/// 健身课程缓存管理器
/// 提供独立的缓存操作接口
class FitnessCacheManager {
  static const String _coursesKey = 'fitness_extension_courses';
  static const String _timestampKey = 'fitness_courses_timestamp';
  static const Duration _cacheDuration = Duration(hours: 24);
  static const int _maxCacheSize = 50; // 最多缓存50个扩展课程

  // 保存课程到缓存（自动限制大小）
  Future<void> saveCourses(List<FitnessCourse> courses) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 限制缓存大小
    final limitedCourses = courses.length > _maxCacheSize
        ? courses.take(_maxCacheSize).toList()
        : courses;
    
    try {
      final coursesJson = limitedCourses.map((c) => c.toJson()).toList();
      await prefs.setString(_coursesKey, jsonEncode(coursesJson));
      await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('保存课程缓存失败: $e');
      rethrow;
    }
  }

  // 从缓存获取课程
  Future<List<FitnessCourse>> getCachedCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final coursesJson = prefs.getString(_coursesKey);
    if (coursesJson == null || coursesJson.isEmpty) return [];

    try {
      final coursesList = jsonDecode(coursesJson) as List;
      return coursesList
          .map((json) => FitnessCourse.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('解析缓存课程失败: $e');
      // 缓存数据损坏，清空缓存
      await clearCache();
      return [];
    }
  }

  // 检查缓存是否有效
  Future<bool> isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_timestampKey);
    if (timestamp == null) return false;

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(cacheTime) < _cacheDuration;
  }

  // 清空缓存
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_coursesKey);
    await prefs.remove(_timestampKey);
  }
}


