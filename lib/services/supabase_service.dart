import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversation.dart';
import '../models/pet_diary.dart';

/// Supabase 数据库服务类
/// 用于替换 SQLite Helper，提供统一的数据访问接口
class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// 获取当前用户ID
  /// 优先从 Supabase Auth 获取，如果不存在则从 SharedPreferences 获取 LeanCloud 用户 ID
  Future<String?> get currentUserId async {
    // 优先使用 Supabase Auth 的用户 ID
    final supabaseUserId = _client.auth.currentUser?.id;
    if (supabaseUserId != null) {
      return supabaseUserId;
    }

    // 如果 Supabase Auth 中没有用户，尝试从 SharedPreferences 获取 LeanCloud 用户 ID
    try {
      final prefs = await SharedPreferences.getInstance();
      final leanCloudUserId = prefs.getString('userId');
      if (leanCloudUserId != null && leanCloudUserId.isNotEmpty) {
        return leanCloudUserId;
      }
    } catch (e) {
      print('获取 LeanCloud 用户 ID 失败: $e');
    }

    return null;
  }

  /// 检查用户是否已登录
  Future<bool> get isLoggedIn async {
    final userId = await currentUserId;
    return userId != null;
  }

  // ============================================================
  // 用户资料相关方法
  // ============================================================

  /// 获取用户资料
  Future<Map<String, dynamic>?> getUserProfile() async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('users_profiles')
          .select()
          .eq('id', userId)
          .single();

      return response;
    } catch (e) {
      print('获取用户资料失败: $e');
      return null;
    }
  }

  /// 创建或更新用户资料
  Future<bool> upsertUserProfile({String? nickname, String? avatarUrl}) async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
      await _client.from('users_profiles').upsert({
        'id': userId,
        'nickname': nickname,
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('更新用户资料失败: $e');
      return false;
    }
  }

  // ============================================================
  // 宠物相关方法
  // ============================================================

  /// 插入宠物
  Future<String?> insertPet(Map<String, dynamic> pet) async {
    final userId = await currentUserId;
    if (userId == null) {
      print('插入宠物失败: 用户未登录');
      return null;
    }

    try {
      // 确保用户资料存在（因为 pets 表有外键约束）
      await _ensureUserProfileExists(userId);

      // 创建插入数据，移除 id 字段让数据库自动生成
      final petData = Map<String, dynamic>.from(pet);
      petData.remove('id'); // 移除 id，让数据库使用默认值生成 UUID
      petData['user_id'] = userId;

      // 处理 neuter_status：将字符串转换为布尔值
      if (petData.containsKey('neuter_status')) {
        final neuterStatusStr = petData['neuter_status'];
        if (neuterStatusStr is String) {
          if (neuterStatusStr == '已绝育') {
            petData['neuter_status'] = true;
          } else if (neuterStatusStr == '未绝育') {
            petData['neuter_status'] = false;
          } else {
            print('警告: 未知的 neuter_status 值: $neuterStatusStr');
            petData['neuter_status'] = null;
          }
        }
      }

      // 处理 birth_date：确保格式正确（只保留日期部分）
      if (petData.containsKey('birth_date') && petData['birth_date'] != null) {
        final birthDate = petData['birth_date'].toString();
        // 如果包含时间部分，只保留日期
        if (birthDate.contains('T')) {
          petData['birth_date'] = birthDate.split('T')[0];
        }
      }

      final response = await _client
          .from('pets')
          .insert(petData)
          .select()
          .single()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('请求超时，请检查网络连接');
            },
          );
      return response['id'] as String?;
    } catch (e) {
      print('插入宠物失败: $e');
      print('用户ID: $userId');
      print('宠物数据: $pet');
      rethrow; // 重新抛出异常以便上层捕获
    }
  }

  /// 确保用户资料存在（如果不存在则创建）
  Future<void> _ensureUserProfileExists(String userId) async {
    try {
      // 尝试获取用户资料
      final profile = await _client
          .from('users_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      // 如果用户资料不存在，创建一个
      if (profile == null) {
        await _client.from('users_profiles').insert({
          'id': userId,
          'nickname': null,
          'avatar_url': null,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        print('自动创建用户资料: $userId');
      }
    } catch (e) {
      print('确保用户资料存在失败: $e');
      // 不抛出异常，让上层处理
    }
  }

  /// 获取所有宠物
  Future<List<Map<String, dynamic>>> getAllPets() async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('pets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // 转换字段类型以匹配应用层
      return List<Map<String, dynamic>>.from(response).map((pet) {
        final mapped = Map<String, dynamic>.from(pet);
        // neuter_status: 布尔值 -> 字符串
        if (mapped.containsKey('neuter_status')) {
          mapped['neuter_status'] =
              mapped['neuter_status'] == true ? '已绝育' : '未绝育';
        }
        return mapped;
      }).toList();
    } catch (e) {
      print('获取宠物列表失败: $e');
      return [];
    }
  }

  /// 更新宠物
  Future<bool> updatePet(Map<String, dynamic> pet) async {
    final userId = await currentUserId;
    if (userId == null || pet['id'] == null) return false;

    try {
      final petId = pet['id'] as String;
      final updateData = Map<String, dynamic>.from(pet);
      updateData.remove('id');
      updateData.remove('user_id'); // 不允许更新user_id
      updateData['updated_at'] = DateTime.now().toIso8601String();

      // 处理 neuter_status：将字符串转换为布尔值
      if (updateData.containsKey('neuter_status')) {
        final neuterStatusStr = updateData['neuter_status'];
        if (neuterStatusStr is String) {
          if (neuterStatusStr == '已绝育') {
            updateData['neuter_status'] = true;
          } else if (neuterStatusStr == '未绝育') {
            updateData['neuter_status'] = false;
          } else {
            print('警告: 未知的 neuter_status 值: $neuterStatusStr');
            updateData['neuter_status'] = null;
          }
        }
      }

      // 处理 birth_date：确保格式正确（只保留日期部分）
      if (updateData.containsKey('birth_date') &&
          updateData['birth_date'] != null) {
        final birthDate = updateData['birth_date'].toString();
        if (birthDate.contains('T')) {
          updateData['birth_date'] = birthDate.split('T')[0];
        }
      }

      await _client
          .from('pets')
          .update(updateData)
          .eq('id', petId)
          .eq('user_id', userId)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('请求超时，请检查网络连接');
            },
          );

      return true;
    } catch (e) {
      print('更新宠物失败: $e');
      rethrow; // 重新抛出异常以便上层捕获
    }
  }

  /// 删除宠物
  Future<bool> deletePet(String petId) async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
      await _client.from('pets').delete().eq('id', petId).eq('user_id', userId);

      return true;
    } catch (e) {
      print('删除宠物失败: $e');
      return false;
    }
  }

  // ============================================================
  // 医疗记录相关方法
  // ============================================================

  /// 插入医疗记录
  Future<String?> insertMedicalRecord(Map<String, dynamic> record) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      // 确保用户资料存在
      await _ensureUserProfileExists(userId);

      // 移除 id 字段让数据库自动生成
      final recordData = Map<String, dynamic>.from(record);
      recordData.remove('id');
      recordData['user_id'] = userId;

      final response = await _client
          .from('medical_records')
          .insert(recordData)
          .select()
          .single();
      return response['id'] as String?;
    } catch (e) {
      print('插入医疗记录失败: $e');
      return null;
    }
  }

  /// 获取所有医疗记录
  Future<List<Map<String, dynamic>>> getAllMedicalRecords() async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('medical_records')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('获取医疗记录失败: $e');
      return [];
    }
  }

  /// 根据宠物ID获取医疗记录
  Future<List<Map<String, dynamic>>> getMedicalRecordsForPet(
    String petId,
  ) async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('medical_records')
          .select()
          .eq('pet_id', petId)
          .eq('user_id', userId)
          .order('date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('获取宠物医疗记录失败: $e');
      return [];
    }
  }

  /// 更新医疗记录
  Future<bool> updateMedicalRecord(Map<String, dynamic> record) async {
    final userId = await currentUserId;
    if (userId == null || record['id'] == null) return false;

    try {
      final recordId = record['id'] as String;
      final updateData = Map<String, dynamic>.from(record);
      updateData.remove('id');
      updateData.remove('user_id');
      updateData['updated_at'] = DateTime.now().toIso8601String();

      await _client
          .from('medical_records')
          .update(updateData)
          .eq('id', recordId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('更新医疗记录失败: $e');
      return false;
    }
  }

  /// 删除医疗记录
  Future<bool> deleteMedicalRecord(String recordId) async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
      await _client
          .from('medical_records')
          .delete()
          .eq('id', recordId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('删除医疗记录失败: $e');
      return false;
    }
  }

  // ============================================================
  // 体重记录相关方法
  // ============================================================

  /// 插入体重记录
  Future<String?> insertWeightRecord(Map<String, dynamic> record) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      // 确保用户资料存在
      await _ensureUserProfileExists(userId);

      // 移除 id 字段让数据库自动生成
      final recordData = Map<String, dynamic>.from(record);
      recordData.remove('id');
      recordData['user_id'] = userId;

      final response = await _client
          .from('weight_records')
          .insert(recordData)
          .select()
          .single();
      return response['id'] as String?;
    } catch (e) {
      print('插入体重记录失败: $e');
      return null;
    }
  }

  /// 获取所有体重记录
  Future<List<Map<String, dynamic>>> getAllWeightRecords() async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('weight_records')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('获取体重记录失败: $e');
      return [];
    }
  }

  /// 根据宠物ID获取体重记录
  Future<List<Map<String, dynamic>>> getWeightRecordsForPet(
    String petId,
  ) async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('weight_records')
          .select()
          .eq('pet_id', petId)
          .eq('user_id', userId)
          .order('date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('获取宠物体重记录失败: $e');
      return [];
    }
  }

  /// 更新体重记录
  Future<bool> updateWeightRecord(Map<String, dynamic> record) async {
    final userId = await currentUserId;
    if (userId == null || record['id'] == null) return false;

    try {
      final recordId = record['id'] as String;
      final updateData = Map<String, dynamic>.from(record);
      updateData.remove('id');
      updateData.remove('user_id');
      updateData['updated_at'] = DateTime.now().toIso8601String();

      await _client
          .from('weight_records')
          .update(updateData)
          .eq('id', recordId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('更新体重记录失败: $e');
      return false;
    }
  }

  /// 删除体重记录
  Future<bool> deleteWeightRecord(String recordId) async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
      await _client
          .from('weight_records')
          .delete()
          .eq('id', recordId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('删除体重记录失败: $e');
      return false;
    }
  }

  // ============================================================
  // 疫苗记录相关方法
  // ============================================================

  /// 插入疫苗记录
  Future<String?> insertVaccineRecord(Map<String, dynamic> record) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      // 确保用户资料存在
      await _ensureUserProfileExists(userId);

      // 移除 id 字段让数据库自动生成，并转换字段名
      final recordData = Map<String, dynamic>.from(record);
      recordData.remove('id');
      recordData['user_id'] = userId;
      recordData['next_due_date'] = recordData['nextDueDate'];
      recordData.remove('nextDueDate');

      final response = await _client
          .from('vaccine_records')
          .insert(recordData)
          .select()
          .single();
      return response['id'] as String?;
    } catch (e) {
      print('插入疫苗记录失败: $e');
      return null;
    }
  }

  /// 获取所有疫苗记录
  Future<List<Map<String, dynamic>>> getAllVaccineRecords() async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('vaccine_records')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('获取疫苗记录失败: $e');
      return [];
    }
  }

  /// 根据宠物ID获取疫苗记录
  Future<List<Map<String, dynamic>>> getVaccineRecordsForPet(
    String petId,
  ) async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('vaccine_records')
          .select()
          .eq('pet_id', petId)
          .eq('user_id', userId)
          .order('date', ascending: false);

      // 转换字段名以匹配模型
      return response.map((record) {
        final map = Map<String, dynamic>.from(record);
        map['nextDueDate'] = map['next_due_date'];
        map.remove('next_due_date');
        return map;
      }).toList();
    } catch (e) {
      print('获取宠物疫苗记录失败: $e');
      return [];
    }
  }

  /// 更新疫苗记录
  Future<bool> updateVaccineRecord(Map<String, dynamic> record) async {
    final userId = await currentUserId;
    if (userId == null || record['id'] == null) return false;

    try {
      final recordId = record['id'] as String;
      final updateData = Map<String, dynamic>.from(record);
      updateData.remove('id');
      updateData.remove('user_id');
      if (updateData.containsKey('nextDueDate')) {
        updateData['next_due_date'] = updateData['nextDueDate'];
        updateData.remove('nextDueDate');
      }
      updateData['updated_at'] = DateTime.now().toIso8601String();

      await _client
          .from('vaccine_records')
          .update(updateData)
          .eq('id', recordId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('更新疫苗记录失败: $e');
      return false;
    }
  }

  /// 删除疫苗记录
  Future<bool> deleteVaccineRecord(String recordId) async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
      await _client
          .from('vaccine_records')
          .delete()
          .eq('id', recordId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('删除疫苗记录失败: $e');
      return false;
    }
  }

  // ============================================================
  // 每日提醒相关方法
  // ============================================================

  /// 插入每日提醒
  Future<String?> insertDailyReminder(Map<String, dynamic> reminder) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      // 确保用户资料存在
      await _ensureUserProfileExists(userId);

      // 移除 id 字段让数据库自动生成
      final reminderData = Map<String, dynamic>.from(reminder);
      reminderData.remove('id');
      reminderData['user_id'] = userId;

      final response = await _client
          .from('daily_reminders')
          .insert(reminderData)
          .select()
          .single();
      return response['id'] as String?;
    } catch (e) {
      print('插入每日提醒失败: $e');
      return null;
    }
  }

  /// 获取所有每日提醒
  Future<List<Map<String, dynamic>>> getAllDailyReminders() async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response =
          await _client.from('daily_reminders').select().eq('user_id', userId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('获取每日提醒失败: $e');
      return [];
    }
  }

  /// 根据宠物ID获取每日提醒
  Future<List<Map<String, dynamic>>> getDailyRemindersForPet(
    String? petId,
  ) async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      var query =
          _client.from('daily_reminders').select().eq('user_id', userId);

      if (petId != null) {
        query = query.eq('pet_id', petId);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('获取宠物每日提醒失败: $e');
      return [];
    }
  }

  /// 更新每日提醒
  Future<bool> updateDailyReminder(Map<String, dynamic> reminder) async {
    final userId = await currentUserId;
    if (userId == null || reminder['id'] == null) return false;

    try {
      final reminderId = reminder['id'] as String;
      final updateData = Map<String, dynamic>.from(reminder);
      updateData.remove('id');
      updateData.remove('user_id');
      updateData['updated_at'] = DateTime.now().toIso8601String();

      await _client
          .from('daily_reminders')
          .update(updateData)
          .eq('id', reminderId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('更新每日提醒失败: $e');
      return false;
    }
  }

  /// 删除每日提醒
  Future<bool> deleteDailyReminder(String reminderId) async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
      await _client
          .from('daily_reminders')
          .delete()
          .eq('id', reminderId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('删除每日提醒失败: $e');
      return false;
    }
  }

  // ============================================================
  // 用药/疫苗/驱虫提醒（云端）
  // ============================================================

  // -------------------- 用药提醒 --------------------
  Future<List<Map<String, dynamic>>> getAllMedicationReminders() async {
    final userId = await currentUserId;
    if (userId == null) return [];
    try {
      final resp = await _client
          .from('medication_reminders')
          .select()
          .eq('user_id', userId)
          .order('start_date', ascending: false);
      return List<Map<String, dynamic>>.from(resp);
    } catch (e) {
      print('获取用药提醒失败: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMedicationRemindersForPet(
      String petId) async {
    final userId = await currentUserId;
    if (userId == null) return [];
    try {
      final resp = await _client
          .from('medication_reminders')
          .select()
          .eq('user_id', userId)
          .eq('pet_id', petId)
          .order('start_date', ascending: false);
      return List<Map<String, dynamic>>.from(resp);
    } catch (e) {
      print('获取宠物用药提醒失败: $e');
      return [];
    }
  }

  Future<String?> insertMedicationReminder(Map<String, dynamic> data) async {
    final userId = await currentUserId;
    if (userId == null) return null;
    try {
      final payload = Map<String, dynamic>.from(data);
      payload.remove('id');
      payload['user_id'] = userId;
      final resp = await _client
          .from('medication_reminders')
          .insert(payload)
          .select()
          .single();
      return resp['id'] as String?;
    } catch (e) {
      print('插入用药提醒失败: $e');
      return null;
    }
  }

  Future<bool> updateMedicationReminder(Map<String, dynamic> data) async {
    final userId = await currentUserId;
    if (userId == null || data['id'] == null) return false;
    try {
      final id = data['id'] as String;
      final payload = Map<String, dynamic>.from(data)
        ..remove('id')
        ..remove('user_id')
        ..['updated_at'] = DateTime.now().toIso8601String();
      await _client
          .from('medication_reminders')
          .update(payload)
          .eq('id', id)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      print('更新用药提醒失败: $e');
      return false;
    }
  }

  Future<bool> deleteMedicationReminder(String id) async {
    final userId = await currentUserId;
    if (userId == null) return false;
    try {
      await _client
          .from('medication_reminders')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      print('删除用药提醒失败: $e');
      return false;
    }
  }

  // -------------------- 疫苗提醒 --------------------
  Future<List<Map<String, dynamic>>> getAllVaccineReminders() async {
    final userId = await currentUserId;
    if (userId == null) return [];
    try {
      final resp = await _client
          .from('vaccine_reminders')
          .select()
          .eq('user_id', userId)
          .order('injection_date', ascending: false);
      return List<Map<String, dynamic>>.from(resp);
    } catch (e) {
      print('获取疫苗提醒失败: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getVaccineRemindersForPet(
      String petId) async {
    final userId = await currentUserId;
    if (userId == null) return [];
    try {
      final resp = await _client
          .from('vaccine_reminders')
          .select()
          .eq('user_id', userId)
          .eq('pet_id', petId)
          .order('injection_date', ascending: false);
      return List<Map<String, dynamic>>.from(resp);
    } catch (e) {
      print('获取宠物疫苗提醒失败: $e');
      return [];
    }
  }

  Future<String?> insertVaccineReminder(Map<String, dynamic> data) async {
    final userId = await currentUserId;
    if (userId == null) return null;
    try {
      final payload = Map<String, dynamic>.from(data);
      payload.remove('id');
      payload['user_id'] = userId;
      final resp = await _client
          .from('vaccine_reminders')
          .insert(payload)
          .select()
          .single();
      return resp['id'] as String?;
    } catch (e) {
      print('插入疫苗提醒失败: $e');
      return null;
    }
  }

  Future<bool> updateVaccineReminder(Map<String, dynamic> data) async {
    final userId = await currentUserId;
    if (userId == null || data['id'] == null) return false;
    try {
      final id = data['id'] as String;
      final payload = Map<String, dynamic>.from(data)
        ..remove('id')
        ..remove('user_id')
        ..['updated_at'] = DateTime.now().toIso8601String();
      await _client
          .from('vaccine_reminders')
          .update(payload)
          .eq('id', id)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      print('更新疫苗提醒失败: $e');
      return false;
    }
  }

  Future<bool> deleteVaccineReminder(String id) async {
    final userId = await currentUserId;
    if (userId == null) return false;
    try {
      await _client
          .from('vaccine_reminders')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      print('删除疫苗提醒失败: $e');
      return false;
    }
  }

  // -------------------- 驱虫提醒 --------------------
  Future<List<Map<String, dynamic>>> getAllDewormingReminders() async {
    final userId = await currentUserId;
    if (userId == null) return [];
    try {
      final resp = await _client
          .from('deworming_reminders')
          .select()
          .eq('user_id', userId)
          .order('last_date', ascending: false);
      return List<Map<String, dynamic>>.from(resp);
    } catch (e) {
      print('获取驱虫提醒失败: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDewormingRemindersForPet(
      String petId) async {
    final userId = await currentUserId;
    if (userId == null) return [];
    try {
      final resp = await _client
          .from('deworming_reminders')
          .select()
          .eq('user_id', userId)
          .eq('pet_id', petId)
          .order('last_date', ascending: false);
      return List<Map<String, dynamic>>.from(resp);
    } catch (e) {
      print('获取宠物驱虫提醒失败: $e');
      return [];
    }
  }

  Future<String?> insertDewormingReminder(Map<String, dynamic> data) async {
    final userId = await currentUserId;
    if (userId == null) return null;
    try {
      final payload = Map<String, dynamic>.from(data);
      payload.remove('id');
      payload['user_id'] = userId;
      final resp = await _client
          .from('deworming_reminders')
          .insert(payload)
          .select()
          .single();
      return resp['id'] as String?;
    } catch (e) {
      print('插入驱虫提醒失败: $e');
      return null;
    }
  }

  Future<bool> updateDewormingReminder(Map<String, dynamic> data) async {
    final userId = await currentUserId;
    if (userId == null || data['id'] == null) return false;
    try {
      final id = data['id'] as String;
      final payload = Map<String, dynamic>.from(data)
        ..remove('id')
        ..remove('user_id')
        ..['updated_at'] = DateTime.now().toIso8601String();
      await _client
          .from('deworming_reminders')
          .update(payload)
          .eq('id', id)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      print('更新驱虫提醒失败: $e');
      return false;
    }
  }

  Future<bool> deleteDewormingReminder(String id) async {
    final userId = await currentUserId;
    if (userId == null) return false;
    try {
      await _client
          .from('deworming_reminders')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      print('删除驱虫提醒失败: $e');
      return false;
    }
  }

  // ============================================================
  // 对话相关方法
  // ============================================================

  /// 插入对话（只保存标题）
  Future<String?> insertConversation(Conversation conversation) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      // 确保用户资料存在
      await _ensureUserProfileExists(userId);

      final conversationData = {
        'user_id': userId,
        'title': conversation.title,
        'is_pinned': conversation.isPinned,
        'timestamp': conversation.timestamp.toIso8601String(),
        'created_at': conversation.timestamp.toIso8601String(),
        if (conversation.difyConversationId != null)
          'dify_conversation_id': conversation.difyConversationId,
      };

      final response = await _client
          .from('conversations')
          .insert(conversationData)
          .select()
          .single();
      return response['id'] as String?;
    } catch (e) {
      print('插入对话失败: $e');
      return null;
    }
  }

  /// 获取所有对话
  Future<List<Conversation>> getAllConversations() async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('conversations')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((map) => Conversation.fromMap(map))
          .toList();
    } catch (e) {
      print('获取对话列表失败: $e');
      return [];
    }
  }

  /// 根据ID获取对话
  Future<Conversation?> getConversation(String id) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('conversations')
          .select()
          .eq('id', id)
          .eq('user_id', userId)
          .single();

      return Conversation.fromMap(response);
    } catch (e) {
      print('获取对话失败: $e');
      return null;
    }
  }

  /// 更新对话（只更新标题和置顶状态，不更新 dify_conversation_id）
  /// 注意：title 通常不应该被更新，此方法主要用于重命名和置顶操作
  Future<bool> updateConversation(Conversation conversation) async {
    final userId = await currentUserId;
    if (userId == null || conversation.id == null) return false;

    try {
      await _client
          .from('conversations')
          .update({
            'title': conversation.title,
            'is_pinned': conversation.isPinned,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conversation.id!)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('更新对话失败: $e');
      return false;
    }
  }

  /// 只更新 Dify conversation_id（不更新 title）
  Future<bool> updateConversationDifyId({
    required String conversationId,
    required String? difyConversationId,
  }) async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
      await _client
          .from('conversations')
          .update({
            'dify_conversation_id': difyConversationId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conversationId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('更新 Dify conversation_id 失败: $e');
      return false;
    }
  }

  /// 删除对话（同时删除相关的消息）
  Future<bool> deleteConversation(String id) async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
      // 先删除该 conversation 的所有消息
      await deleteMessagesByConversationId(id);
      
      // 再删除 conversation
      await _client
          .from('conversations')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('删除对话失败: $e');
      return false;
    }
  }

  /// 删除所有对话
  Future<bool> deleteAllConversations() async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
      await _client.from('conversations').delete().eq('user_id', userId);
      return true;
    } catch (e) {
      print('删除所有对话失败: $e');
      return false;
    }
  }

  // ============================================================
  // 聊天消息相关方法
  // ============================================================

  /// 插入聊天消息
  Future<String?> insertChatMessage({
    required String conversationId,
    required String text,
    required bool isUser,
    DateTime? createdAt,
  }) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      final messageData = {
        'conversation_id': conversationId,
        'user_id': userId,
        'text': text,
        'is_user': isUser,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      };

      final response = await _client
          .from('chat_messages')
          .insert(messageData)
          .select()
          .single();
      return response['id'] as String?;
    } catch (e) {
      print('插入聊天消息失败: $e');
      return null;
    }
  }

  /// 根据对话ID获取所有消息
  Future<List<Map<String, dynamic>>> getMessagesByConversationId(
    String conversationId,
  ) async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('获取聊天消息失败: $e');
      return [];
    }
  }

  /// 删除对话的所有消息
  Future<bool> deleteMessagesByConversationId(String conversationId) async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
      await _client
          .from('chat_messages')
          .delete()
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('删除聊天消息失败: $e');
      return false;
    }
  }

  // ============================================================
  // 宠物日记相关方法
  // ============================================================

  /// 插入宠物日记
  Future<String?> insertDiary(PetDiary diary) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      // 确保用户资料存在
      await _ensureUserProfileExists(userId);

      final diaryData = {
        'user_id': userId,
        'original_text': diary.originalText,
        'content': diary.content,
        'style': diary.style,
        'created_at': diary.timestamp.toIso8601String(),
      };

      final response =
          await _client.from('pet_diaries').insert(diaryData).select().single();
      return response['id'] as String?;
    } catch (e) {
      print('插入宠物日记失败: $e');
      return null;
    }
  }

  /// 获取所有宠物日记
  Future<List<PetDiary>> getAllDiaries() async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('pet_diaries')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((map) => PetDiary.fromMap(map)).toList();
    } catch (e) {
      print('获取宠物日记失败: $e');
      return [];
    }
  }

  /// 删除宠物日记
  Future<bool> deleteDiary(String id) async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
      await _client
          .from('pet_diaries')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('删除宠物日记失败: $e');
      return false;
    }
  }

  // ============================================================
  // 统一消费记录相关方法
  // ============================================================

  Future<String?> insertUnifiedExpense(Map<String, dynamic> expense) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      final data = Map<String, dynamic>.from(expense);
      data.remove('id');
      data['user_id'] = userId;

      // 字段名映射
      data['expense_type'] = data['expenseType'];
      data.remove('expenseType');
      data['photo_path'] = data['photoPath'];
      data.remove('photoPath');
      data['item_name'] = data['itemName'];
      data.remove('itemName');
      data['estimated_end_date'] = data['estimatedEndDate'];
      data.remove('estimatedEndDate');
      data['item_type'] = data['itemType'];
      data.remove('itemType');
      // 移除 imagePath，unified_expenses 表没有这个字段
      data.remove('imagePath');
      // 移除 createdAt，数据库会自动设置 created_at
      data.remove('createdAt');
      // 处理 petId 到 pet_id 的映射
      if (data.containsKey('petId')) {
        data['pet_id'] = data['petId'];
        data.remove('petId');
      }
      // 处理 petName 到 pet_name 的映射
      if (data.containsKey('petName')) {
        data['pet_name'] = data['petName'];
        data.remove('petName');
      }

      final response = await _client
          .from('unified_expenses')
          .insert(data)
          .select()
          .single();
      return response['id'] as String?;
    } catch (e) {
      print('插入统一消费记录失败: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllUnifiedExpenses() async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('unified_expenses')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response).map((row) {
        final map = Map<String, dynamic>.from(row);
        map['expenseType'] = map['expense_type'];
        map.remove('expense_type');
        map['photoPath'] = map['photo_path'];
        map.remove('photo_path');
        map['itemName'] = map['item_name'];
        map.remove('item_name');
        map['estimatedEndDate'] = map['estimated_end_date'];
        map.remove('estimated_end_date');
        map['itemType'] = map['item_type'];
        map.remove('item_type');
        // unified_expenses 表没有 image_path 字段，设置为 null
        map['imagePath'] = null;
        map['petId'] = map['pet_id'];
        map.remove('pet_id');
        map['petName'] = map['pet_name'];
        map.remove('pet_name');
        map['petName'] = map['pet_name'];
        map.remove('pet_name');
        map['createdAt'] = map['created_at'] ?? map['createdAt'];
        return map;
      }).toList();
    } catch (e) {
      print('获取统一消费记录失败: $e');
      return [];
    }
  }

  Future<bool> updateUnifiedExpense(Map<String, dynamic> expense) async {
    final userId = await currentUserId;
    if (userId == null || expense['id'] == null) return false;

    try {
      final expenseId = expense['id'] as String;
      final updateData = Map<String, dynamic>.from(expense);
      updateData.remove('id');
      updateData.remove('user_id');
      updateData['expense_type'] = updateData['expenseType'];
      updateData.remove('expenseType');
      updateData['photo_path'] = updateData['photoPath'];
      updateData.remove('photoPath');
      updateData['item_name'] = updateData['itemName'];
      updateData.remove('itemName');
      updateData['estimated_end_date'] = updateData['estimatedEndDate'];
      updateData.remove('estimatedEndDate');
      updateData['item_type'] = updateData['itemType'];
      updateData.remove('itemType');
      // 移除 imagePath，unified_expenses 表没有这个字段
      updateData.remove('imagePath');
      // 移除 createdAt，数据库会自动管理时间戳
      updateData.remove('createdAt');
      // 处理 petId 到 pet_id 的映射
      if (updateData.containsKey('petId')) {
        updateData['pet_id'] = updateData['petId'];
        updateData.remove('petId');
      }
      // 处理 petName 到 pet_name 的映射
      if (updateData.containsKey('petName')) {
        updateData['pet_name'] = updateData['petName'];
        updateData.remove('petName');
      }
      updateData['updated_at'] = DateTime.now().toIso8601String();

      await _client
          .from('unified_expenses')
          .update(updateData)
          .eq('id', expenseId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('更新统一消费记录失败: $e');
      return false;
    }
  }

  Future<bool> deleteUnifiedExpense(String expenseId) async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
      await _client
          .from('unified_expenses')
          .delete()
          .eq('id', expenseId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('删除统一消费记录失败: $e');
      return false;
    }
  }

  // ============================================================
  // Expense 相关方法（映射到 unified_expenses，作为一次性支出）
  // ============================================================

  Future<String?> insertExpense(Map<String, dynamic> expense) async {
    // Expense 映射为 UnifiedExpense 的一次性支出
    final unifiedExpense = Map<String, dynamic>.from(expense);
    unifiedExpense['expenseType'] = 'one-off';
    unifiedExpense['category'] = expense['category'] ?? '其他';
    return await insertUnifiedExpense(unifiedExpense);
  }

  Future<List<Map<String, dynamic>>> getAllExpenses() async {
    // 只返回一次性支出
    final all = await getAllUnifiedExpenses();
    return all.where((e) => e['expenseType'] == 'one-off').toList();
  }

  Future<bool> updateExpense(Map<String, dynamic> expense) async {
    // Expense 映射为 UnifiedExpense 的一次性支出
    final unifiedExpense = Map<String, dynamic>.from(expense);
    unifiedExpense['expenseType'] = 'one-off';
    unifiedExpense['category'] = expense['category'] ?? '其他';
    return await updateUnifiedExpense(unifiedExpense);
  }

  Future<bool> deleteExpense(String expenseId) async {
    return await deleteUnifiedExpense(expenseId);
  }

  // ============================================================
  // 日常消费品记录相关方法
  // ============================================================

  Future<String?> insertDailyCostItem(Map<String, dynamic> item) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      final data = Map<String, dynamic>.from(item);
      data.remove('id');
      data['user_id'] = userId;

      data['item_name'] = data['itemName'];
      data.remove('itemName');
      data['total_price'] = data['totalPrice'];
      data.remove('totalPrice');
      data['purchase_date'] = data['purchaseDate'];
      data.remove('purchaseDate');
      data['finish_date'] = data['finishDate'];
      data.remove('finishDate');
      data['image_path'] = data['imagePath'];
      data.remove('imagePath');
      // 移除 createdAt，数据库会自动设置 created_at
      data.remove('createdAt');

      final response = await _client
          .from('daily_cost_items')
          .insert(data)
          .select()
          .single();
      return response['id'] as String?;
    } catch (e) {
      print('插入日常消费品记录失败: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllDailyCostItems() async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('daily_cost_items')
          .select()
          .eq('user_id', userId)
          .order('purchase_date', ascending: false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response).map((row) {
        final map = Map<String, dynamic>.from(row);
        map['itemName'] = map['item_name'];
        map.remove('item_name');
        map['totalPrice'] = map['total_price'];
        map.remove('total_price');
        map['purchaseDate'] = map['purchase_date'];
        map.remove('purchase_date');
        map['finishDate'] = map['finish_date'];
        map.remove('finish_date');
        map['imagePath'] = map['image_path'];
        map.remove('image_path');
        map['createdAt'] = map['created_at'] ?? map['createdAt'];
        return map;
      }).toList();
    } catch (e) {
      print('获取日常消费品记录失败: $e');
      return [];
    }
  }

  Future<bool> updateDailyCostItem(Map<String, dynamic> item) async {
    final userId = await currentUserId;
    if (userId == null || item['id'] == null) return false;

    try {
      final itemId = item['id'] as String;
      final updateData = Map<String, dynamic>.from(item);
      updateData.remove('id');
      updateData.remove('user_id');
      updateData['item_name'] = updateData['itemName'];
      updateData.remove('itemName');
      updateData['total_price'] = updateData['totalPrice'];
      updateData.remove('totalPrice');
      updateData['purchase_date'] = updateData['purchaseDate'];
      updateData.remove('purchaseDate');
      updateData['finish_date'] = updateData['finishDate'];
      updateData.remove('finishDate');
      updateData['image_path'] = updateData['imagePath'];
      updateData.remove('imagePath');
      // 移除 createdAt，数据库会自动管理时间戳
      updateData.remove('createdAt');
      updateData['updated_at'] = DateTime.now().toIso8601String();

      await _client
          .from('daily_cost_items')
          .update(updateData)
          .eq('id', itemId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('更新日常消费品记录失败: $e');
      return false;
    }
  }

  Future<bool> deleteDailyCostItem(String itemId) async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
      await _client
          .from('daily_cost_items')
          .delete()
          .eq('id', itemId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('删除日常消费品记录失败: $e');
      return false;
    }
  }

  // ============================================================
  // 健身记录相关方法
  // ============================================================

  Future<String?> insertFitnessRecord(Map<String, dynamic> record) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      final data = Map<String, dynamic>.from(record);
      data.remove('id');
      data['user_id'] = userId;
      data['course_id'] = data['courseId'];
      data.remove('courseId');
      data['course_name'] = data['courseName'];
      data.remove('courseName');
      data['completed_at'] = data['completedAt'];
      data.remove('completedAt');
      data['duration_minutes'] = data['durationMinutes'];
      data.remove('durationMinutes');
      data['calories_burned'] = data['caloriesBurned'];
      data.remove('caloriesBurned');
      data['pet_calories_burned'] = data['petCaloriesBurned'];
      data.remove('petCaloriesBurned');

      final response = await _client
          .from('fitness_records')
          .insert(data)
          .select()
          .single();
      return response['id'] as String?;
    } catch (e) {
      print('插入健身记录失败: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllFitnessRecords() async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('fitness_records')
          .select()
          .eq('user_id', userId)
          .order('completed_at', ascending: false);

      return List<Map<String, dynamic>>.from(response).map((row) {
        final map = Map<String, dynamic>.from(row);
        map['courseId'] = map['course_id'];
        map.remove('course_id');
        map['courseName'] = map['course_name'];
        map.remove('course_name');
        map['completedAt'] = map['completed_at'];
        map.remove('completed_at');
        map['durationMinutes'] = map['duration_minutes'];
        map.remove('duration_minutes');
        map['caloriesBurned'] = map['calories_burned'];
        map.remove('calories_burned');
        map['petCaloriesBurned'] = map['pet_calories_burned'];
        map.remove('pet_calories_burned');
        return map;
      }).toList();
    } catch (e) {
      print('获取健身记录失败: $e');
      return [];
    }
  }

  Future<bool> deleteFitnessRecord(String recordId) async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
      await _client
          .from('fitness_records')
          .delete()
          .eq('id', recordId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('删除健身记录失败: $e');
      return false;
    }
  }

  // ============================================================
  // 健康计划相关方法
  // ============================================================

  Future<String?> insertHealthPlan(Map<String, dynamic> plan) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      final data = Map<String, dynamic>.from(plan);
      data.remove('id');
      data['user_id'] = userId;
      data['start_date'] = data['startDate'];
      data.remove('startDate');
      data['end_date'] = data['endDate'];
      data.remove('endDate');

      final response = await _client
          .from('health_plans')
          .insert(data)
          .select()
          .single();
      return response['id'] as String?;
    } catch (e) {
      print('插入健康计划失败: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllHealthPlans() async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('health_plans')
          .select()
          .eq('user_id', userId)
          .order('start_date', ascending: false);

      return List<Map<String, dynamic>>.from(response).map((row) {
        final map = Map<String, dynamic>.from(row);
        map['startDate'] = map['start_date'];
        map.remove('start_date');
        map['endDate'] = map['end_date'];
        map.remove('end_date');
        return map;
      }).toList();
    } catch (e) {
      print('获取健康计划失败: $e');
      return [];
    }
  }

  // ============================================================
  // 宠物护照相关方法
  // ============================================================

  Future<String?> upsertPetPassport(Map<String, dynamic> passport) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      final data = Map<String, dynamic>.from(passport);
      final passportId = data['id'] as String?;
      data.remove('id');
      data['user_id'] = userId;
      
      // 字段名映射
      data['pet_id'] = data['petId'] ?? data['pet_id'];
      data.remove('petId');
      data['photo_path'] = data['photoPath'] ?? data['photo_path'];
      data.remove('photoPath');
      data['owner_name'] = data['ownerName'] ?? data['owner_name'];
      data.remove('ownerName');
      data['adoption_date'] = data['adoptionDate'] ?? data['adoption_date'];
      data.remove('adoptionDate');
      data['mbti_type'] = data['mbtiType'] ?? data['mbti_type'];
      data.remove('mbtiType');
      data['mbti_description'] = data['mbtiDescription'] ?? data['mbti_description'];
      data.remove('mbtiDescription');
      data['interest_tags'] = data['interestTags'] ?? data['interest_tags'];
      data.remove('interestTags');
      data['friend_count'] = data['friendCount'] ?? data['friend_count'];
      data.remove('friendCount');

      final achievements = data['achievements'];
      data.remove('achievements');

      final response = await _client
          .from('pet_passports')
          .upsert(data, onConflict: 'user_id,pet_id')
          .select()
          .single();
      final resultId = response['id'] as String?;

      // 处理成就
      if (achievements != null && resultId != null) {
        // 先删除旧的成就
        await _client
            .from('pet_passport_achievements')
            .delete()
            .eq('passport_id', resultId);
        
        // 插入新成就
        final List<dynamic> achievementList = achievements is List ? achievements : [];
        if (achievementList.isNotEmpty) {
          final rows = achievementList.map((a) {
            final m = Map<String, dynamic>.from(a as Map);
            m['passport_id'] = resultId;
            m['achievement_id'] = m['id'] ?? m['achievement_id'];
            m.remove('id');
            m['achievement_name'] = m['name'] ?? m['achievement_name'];
            m.remove('name');
            m['achievement_description'] = m['description'] ?? m['achievement_description'];
            m.remove('description');
            m['icon_name'] = m['iconName'] ?? m['icon_name'];
            m.remove('iconName');
            m['unlocked_at'] = m['unlockedAt'] ?? m['unlocked_at'];
            m.remove('unlockedAt');
            return m;
          }).toList();

          await _client
              .from('pet_passport_achievements')
              .insert(rows);
        }
      }

      return resultId;
    } catch (e) {
      print('同步宠物护照失败: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getPassportByPetId(String petId) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('pet_passports')
          .select()
          .eq('user_id', userId)
          .eq('pet_id', petId)
          .maybeSingle();

      if (response == null) return null;

      final map = Map<String, dynamic>.from(response);
      
      // 加载成就
      final achievementsResponse = await _client
          .from('pet_passport_achievements')
          .select()
          .eq('passport_id', map['id']);

      final achievements = List<Map<String, dynamic>>.from(achievementsResponse)
          .map((a) {
            final m = Map<String, dynamic>.from(a);
            m['id'] = m['achievement_id'];
            m['name'] = m['achievement_name'];
            m['description'] = m['achievement_description'];
            m['iconName'] = m['icon_name'];
            m['unlockedAt'] = m['unlocked_at'];
            return m;
          }).toList();

      map['achievements'] = achievements;
      
      // 字段名映射
      map['petId'] = map['pet_id'];
      map['photoPath'] = map['photo_path'];
      map['ownerName'] = map['owner_name'];
      map['adoptionDate'] = map['adoption_date'];
      map['mbtiType'] = map['mbti_type'];
      map['mbtiDescription'] = map['mbti_description'];
      map['interestTags'] = map['interest_tags'];
      map['friendCount'] = map['friend_count'];
      map['createdAt'] = map['created_at'];
      map['updatedAt'] = map['updated_at'];

      return map;
    } catch (e) {
      print('获取宠物护照失败: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllPassports() async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('pet_passports')
          .select()
          .eq('user_id', userId);

      final List<Map<String, dynamic>> passports = [];
      
      for (final row in response) {
        final map = Map<String, dynamic>.from(row);
        
        // 加载成就
        final achievementsResponse = await _client
            .from('pet_passport_achievements')
            .select()
            .eq('passport_id', map['id']);

        final achievements = List<Map<String, dynamic>>.from(achievementsResponse)
            .map((a) {
              final m = Map<String, dynamic>.from(a);
              m['id'] = m['achievement_id'];
              m['name'] = m['achievement_name'];
              m['description'] = m['achievement_description'];
              m['iconName'] = m['icon_name'];
              m['unlockedAt'] = m['unlocked_at'];
              return m;
            }).toList();

        map['achievements'] = achievements;
        
        // 字段名映射
        map['petId'] = map['pet_id'];
        map['photoPath'] = map['photo_path'];
        map['ownerName'] = map['owner_name'];
        map['adoptionDate'] = map['adoption_date'];
        map['mbtiType'] = map['mbti_type'];
        map['mbtiDescription'] = map['mbti_description'];
        map['interestTags'] = map['interest_tags'];
        map['friendCount'] = map['friend_count'];
        map['createdAt'] = map['created_at'];
        map['updatedAt'] = map['updated_at'];

        passports.add(map);
      }

      return passports;
    } catch (e) {
      print('获取所有宠物护照失败: $e');
      return [];
    }
  }

  /// 删除所有宠物日记
  Future<bool> deleteAllDiaries() async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
      await _client.from('pet_diaries').delete().eq('user_id', userId);
      return true;
    } catch (e) {
      print('删除所有宠物日记失败: $e');
      return false;
    }
  }
}
