// 必需导入
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/fitness_courses_data.dart';
import '../models/fitness_course.dart';
import '../services/supabase_service.dart';

/// 健身课程管理器
/// 统一管理本地核心课程和云端扩展课程
class FitnessCoursesManager {
  static final FitnessCoursesManager _instance = FitnessCoursesManager._internal();
  factory FitnessCoursesManager() => _instance;
  FitnessCoursesManager._internal();

  final SupabaseService _supabaseService = SupabaseService();

  // 核心课程ID列表 - 必须与 FitnessCoursesData.coreCourseIds 保持一致
  static const List<String> coreCourseIds = [
    'dog_high_chase', 'dog_medium_core', 'dog_medium_strength',
    'dog_low_yoga', 'cat_medium_core', 'cat_low_yoga'
  ];

  // 缓存相关
  static const String _cacheKey = 'fitness_extension_courses';
  static const String _cacheTimestampKey = 'fitness_courses_timestamp';
  static const Duration _cacheDuration = Duration(hours: 24);
  static const int _maxCacheSize = 50; // 最多缓存50个扩展课程

  // 获取所有课程（核心课程 + 扩展课程，自动去重）
  Future<List<FitnessCourse>> getAllCourses() async {
    final coreCourses = getCoreCourses();
    final extensionCourses = await getExtensionCourses();
    
    // 重要：去重逻辑 - 如果云端课程与核心课程ID重复，优先使用核心课程
    final coreCourseIds = coreCourses.map((c) => c.id).toSet();
    final filteredExtensions = extensionCourses
        .where((c) => !coreCourseIds.contains(c.id))
        .toList();
    
    return [...coreCourses, ...filteredExtensions];
  }

  // 获取核心课程（同步，返回本地核心课程）
  List<FitnessCourse> getCoreCourses() {
    return FitnessCoursesData.getCoreCourses();
  }

  // 获取扩展课程（异步，支持增量更新和缓存降级）
  Future<List<FitnessCourse>> getExtensionCourses({bool forceRefresh = false}) async {
    // 检查缓存是否有效（除非强制刷新）
    if (!forceRefresh && await _isCacheValid()) {
      return await _getCachedCourses();
    }

    // 从云端获取
    try {
      // 尝试增量更新
      final lastUpdateTime = await _getLastCacheTime();
      List<FitnessCourse> courses;
      
      if (lastUpdateTime != null && !forceRefresh) {
        // 增量更新：只获取更新后的课程
        courses = await _supabaseService.getFitnessCoursesUpdatedAfter(lastUpdateTime);
        // 合并增量更新到现有缓存
        final cached = await _getCachedCourses();
        courses = _mergeCourses(cached, courses);
      } else {
        // 全量更新
        courses = await _supabaseService.getFitnessCourses();
      }
      
      // 限制缓存大小
      if (courses.length > _maxCacheSize) {
        courses = courses.take(_maxCacheSize).toList();
      }
      
      await _saveToCache(courses);
      return courses;
    } catch (e) {
      // 网络失败，尝试返回缓存数据（即使过期）
      final cached = await _getCachedCourses();
      if (cached.isNotEmpty) {
        // 有缓存数据，返回过期缓存（降级策略）
        return cached;
      }
      // 缓存也为空，返回空列表（至少还有核心课程可用）
      print('获取扩展课程失败，且无缓存数据: $e');
      return [];
    }
  }

  // 合并课程列表（处理更新和新增）
  List<FitnessCourse> _mergeCourses(
    List<FitnessCourse> cached,
    List<FitnessCourse> updated,
  ) {
    final cachedMap = {for (var c in cached) c.id: c};
    // 更新或新增课程
    for (var course in updated) {
      cachedMap[course.id] = course;
    }
    return cachedMap.values.toList();
  }

  // 获取最后缓存时间
  Future<DateTime?> _getLastCacheTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_cacheTimestampKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  // 检查缓存是否有效
  Future<bool> _isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_cacheTimestampKey);
    if (timestamp == null) return false;

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(cacheTime) < _cacheDuration;
  }

  // 从缓存获取课程
  Future<List<FitnessCourse>> _getCachedCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final coursesJson = prefs.getString(_cacheKey);
    if (coursesJson == null || coursesJson.isEmpty) return [];

    try {
      final coursesList = jsonDecode(coursesJson) as List;
      return coursesList
          .map((json) => FitnessCourse.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('解析缓存课程失败: $e');
      return [];
    }
  }

  // 保存课程到缓存
  Future<void> _saveToCache(List<FitnessCourse> courses) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final coursesJson = courses.map((c) => c.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(coursesJson));
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('保存缓存失败: $e');
    }
  }

  // 刷新缓存（强制从云端获取）
  Future<void> refreshCache() async {
    await getExtensionCourses(forceRefresh: true);
  }

  // 清空缓存
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimestampKey);
  }
}

