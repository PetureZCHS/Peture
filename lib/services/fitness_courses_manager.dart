// 必需导入
import 'package:flutter/foundation.dart';
import '../shared/data/fitness_courses_data.dart';
import '../shared/models/fitness_course.dart';
import 'supabase_service.dart';
import '../shared/utils/fitness_cache_manager.dart';

/// 健身课程管理器
/// 统一管理本地核心课程和云端扩展课程
class FitnessCoursesManager {
  static final FitnessCoursesManager _instance =
      FitnessCoursesManager._internal();
  factory FitnessCoursesManager() => _instance;
  FitnessCoursesManager._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final FitnessCacheManager _cacheManager = FitnessCacheManager();

  // 核心课程ID列表 - 必须与 FitnessCoursesData.coreCourseIds 保持一致
  static const List<String> coreCourseIds = [
    'dog_high_chase',
    'dog_medium_core',
    'dog_medium_strength',
    'dog_low_yoga',
    'cat_medium_core',
    'cat_low_yoga'
  ];

  // 获取所有课程（核心课程 + 扩展课程，自动去重）
  Future<List<FitnessCourse>> getAllCourses() async {
    final coreCourses = getCoreCourses();
    final extensionCourses = await getExtensionCourses();

    // 重要：去重逻辑 - 如果云端课程与核心课程ID重复，优先使用核心课程
    final coreCourseIds = coreCourses.map((c) => c.id).toSet();
    final filteredExtensions =
        extensionCourses.where((c) => !coreCourseIds.contains(c.id)).toList();

    return [...coreCourses, ...filteredExtensions];
  }

  // 获取核心课程（同步，返回本地核心课程）
  List<FitnessCourse> getCoreCourses() {
    return FitnessCoursesData.getCoreCourses();
  }

  // 获取扩展课程（异步，支持增量更新和缓存降级）
  Future<List<FitnessCourse>> getExtensionCourses(
      {bool forceRefresh = false}) async {
    // 检查缓存是否有效（除非强制刷新）
    if (!forceRefresh && await _cacheManager.isCacheValid()) {
      return await _cacheManager.getCachedCourses();
    }

    // 从云端获取
    try {
      // 尝试增量更新
      final lastUpdateTime = await _cacheManager.getLastCacheTime();
      List<FitnessCourse> courses;

      if (lastUpdateTime != null && !forceRefresh) {
        // 增量更新：只获取更新后的课程
        courses = await _supabaseService
            .getFitnessCoursesUpdatedAfter(lastUpdateTime);
        // 合并增量更新到现有缓存
        final cached = await _cacheManager.getCachedCourses();
        courses = _mergeCourses(cached, courses);
      } else {
        // 全量更新
        courses = await _supabaseService.getFitnessCourses();
      }

      await _cacheManager.saveCourses(courses);
      return courses;
    } catch (e) {
      // 网络失败，尝试返回缓存数据（即使过期）
      final cached = await _cacheManager.getCachedCourses();
      if (cached.isNotEmpty) {
        // 有缓存数据，返回过期缓存（降级策略）
        return cached;
      }
      // 缓存也为空，返回空列表（至少还有核心课程可用）
      debugPrint('获取扩展课程失败，且无缓存数据: $e');
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

  // 刷新缓存（强制从云端获取）
  Future<void> refreshCache() async {
    await getExtensionCourses(forceRefresh: true);
  }

  // 清空缓存
  Future<void> clearCache() async {
    await _cacheManager.clearCache();
  }
}
