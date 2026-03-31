import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/models/conversation.dart';
import '../shared/models/pet_diary.dart';
import '../shared/models/fitness_course.dart';

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
      debugPrint('获取 LeanCloud 用户 ID 失败: $e');
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
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('获取用户资料失败: $e');
      return null;
    }
  }

  /// 当前用户会员类型：'free' | 'lifetime'
  Future<String> getMembershipType() async {
    final profile = await getUserProfile();
    final type = profile?['membership_type'] as String?;
    return type == 'lifetime' ? 'lifetime' : 'free';
  }

  /// 是否为终身会员
  Future<bool> isLifetimeMember() async {
    return await getMembershipType() == 'lifetime';
  }

  /// 获取或创建当前用户的 8 位邀请码（仅对白名单邮箱开放，否则 error 为「该功能暂未对小主们开放」）
  Future<({String? code, String? error})> getOrCreateMyInvitationCode() async {
    final userId = await currentUserId;
    if (userId == null) return (code: null, error: '请先登录');
    try {
      final res =
          await _client.functions.invoke('get-or-create-invitation-code');
      final data = res.data as Map<String, dynamic>?;
      final err = data?['error'] as String?;
      final codeVal = data?['code'];
      if (res.status == 200 && codeVal is String && codeVal.isNotEmpty) {
        return (code: codeVal, error: null);
      }
      if (data?['code'] == 'NOT_ALLOWED' || (res.status == 403)) {
        return (code: null, error: err ?? '该功能暂未对小主们开放');
      }
      return (code: null, error: err ?? '获取失败');
    } catch (e) {
      debugPrint('获取邀请码异常: $e');
      return (code: null, error: '网络异常，请重试');
    }
  }

  /// 兑换邀请码，成功则当前用户获得终身会员
  Future<({bool success, String? error})> redeemInvitationCode(
      String code) async {
    final userId = await currentUserId;
    if (userId == null) return (success: false, error: '请先登录');
    final trimmed = code.trim();
    if (trimmed.length < 4) return (success: false, error: '请输入有效邀请码');
    try {
      final res = await _client.functions
          .invoke('redeem-invitation', body: {'code': trimmed});
      final data = res.data as Map<String, dynamic>?;
      final err = data?['error'] as String?;
      if (res.status == 200 && data != null && data['success'] == true) {
        return (success: true, error: null);
      }
      return (success: false, error: err ?? '兑换失败');
    } catch (e) {
      debugPrint('兑换邀请码异常: $e');
      return (success: false, error: '网络异常，请重试');
    }
  }

  /// 创建或更新用户资料
  Future<bool> upsertUserProfile({
    String? nickname,
    String? avatarUrl,
    String? ownerNickname,
    String? gender,
    String? birthDate,
    String? province,
    String? city,
  }) async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
      final data = {
        'id': userId,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (nickname != null) data['nickname'] = nickname;
      if (avatarUrl != null) data['avatar_url'] = avatarUrl;
      if (ownerNickname != null) data['owner_nickname'] = ownerNickname;
      if (gender != null) data['gender'] = gender;
      if (birthDate != null) {
        data['birth_date'] =
            birthDate.contains('T') ? birthDate.split('T')[0] : birthDate;
      }
      if (province != null) data['province'] = province;
      if (city != null) data['city'] = city;

      await _client.from('users_profiles').upsert(data);

      return true;
    } catch (e) {
      debugPrint('更新用户资料失败: $e');
      return false;
    }
  }

  /// 获取用户默认的主人昵称（宠物对主人的称呼）
  Future<String> getOwnerNickname() async {
    final profile = await getUserProfile();
    return profile?['owner_nickname'] as String? ?? '主人';
  }

  /// 更新用户默认的主人昵称
  Future<bool> updateOwnerNickname(String nickname) async {
    return await upsertUserProfile(ownerNickname: nickname);
  }

  // ============================================================
  // 宠物相关方法
  // ============================================================

  /// 插入宠物
  Future<String?> insertPet(Map<String, dynamic> pet) async {
    final userId = await currentUserId;
    if (userId == null) {
      debugPrint('插入宠物失败: 用户未登录');
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
            debugPrint('警告: 未知的 neuter_status 值: $neuterStatusStr');
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

      final response =
          await _client.from('pets').insert(petData).select().single().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('请求超时，请检查网络连接');
        },
      );
      return response['id'] as String?;
    } catch (e) {
      debugPrint('插入宠物失败: $e');
      debugPrint('用户ID: $userId');
      debugPrint('宠物数据: $pet');
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
          'membership_type': 'free',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('自动创建用户资料: $userId');
      }
    } catch (e) {
      debugPrint('确保用户资料存在失败: $e');
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
      debugPrint('获取宠物列表失败: $e');
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
            debugPrint('警告: 未知的 neuter_status 值: $neuterStatusStr');
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
      debugPrint('更新宠物失败: $e');
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
      debugPrint('删除宠物失败: $e');
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
      debugPrint('插入医疗记录失败: $e');
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
      debugPrint('获取医疗记录失败: $e');
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
      debugPrint('获取宠物医疗记录失败: $e');
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
      debugPrint('更新医疗记录失败: $e');
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
      debugPrint('删除医疗记录失败: $e');
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
      debugPrint('插入体重记录失败: $e');
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
      debugPrint('获取体重记录失败: $e');
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
      debugPrint('获取宠物体重记录失败: $e');
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
      debugPrint('更新体重记录失败: $e');
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
      debugPrint('删除体重记录失败: $e');
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
      debugPrint('插入疫苗记录失败: $e');
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
      debugPrint('获取疫苗记录失败: $e');
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
      debugPrint('获取宠物疫苗记录失败: $e');
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
      debugPrint('更新疫苗记录失败: $e');
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
      debugPrint('删除疫苗记录失败: $e');
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
      debugPrint('插入每日提醒失败: $e');
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
      debugPrint('获取每日提醒失败: $e');
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
      debugPrint('获取宠物每日提醒失败: $e');
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
      debugPrint('更新每日提醒失败: $e');
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
      debugPrint('删除每日提醒失败: $e');
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
      debugPrint('获取用药提醒失败: $e');
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
      debugPrint('获取宠物用药提醒失败: $e');
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
      debugPrint('插入用药提醒失败: $e');
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
      debugPrint('更新用药提醒失败: $e');
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
      debugPrint('删除用药提醒失败: $e');
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
      debugPrint('获取疫苗提醒失败: $e');
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
      debugPrint('获取宠物疫苗提醒失败: $e');
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
      debugPrint('插入疫苗提醒失败: $e');
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
      debugPrint('更新疫苗提醒失败: $e');
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
      debugPrint('删除疫苗提醒失败: $e');
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
      debugPrint('获取驱虫提醒失败: $e');
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
      debugPrint('获取宠物驱虫提醒失败: $e');
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
      debugPrint('插入驱虫提醒失败: $e');
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
      debugPrint('更新驱虫提醒失败: $e');
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
      debugPrint('删除驱虫提醒失败: $e');
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
      debugPrint('插入对话失败: $e');
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
      debugPrint('获取对话列表失败: $e');
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
      debugPrint('获取对话失败: $e');
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
      debugPrint('更新对话失败: $e');
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
      debugPrint('更新 Dify conversation_id 失败: $e');
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
      debugPrint('删除对话失败: $e');
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
      debugPrint('删除所有对话失败: $e');
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
      debugPrint('插入聊天消息失败: $e');
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
      debugPrint('获取聊天消息失败: $e');
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
      debugPrint('删除聊天消息失败: $e');
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
      // 尝试确保用户资料存在，但不阻塞日记保存
      // 如果用户资料检查失败（网络问题），仍然尝试保存日记
      try {
        await _ensureUserProfileExists(userId);
      } catch (e) {
        debugPrint('检查用户资料时出错（将继续保存日记）: $e');
      }

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
      debugPrint('插入宠物日记失败: $e');
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
      debugPrint('获取宠物日记失败: $e');
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
      debugPrint('删除宠物日记失败: $e');
      return false;
    }
  }

  // ============================================================
  // 统一消费记录相关方法
  // ============================================================

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

      final response =
          await _client.from('daily_cost_items').insert(data).select().single();
      return response['id'] as String?;
    } catch (e) {
      debugPrint('插入日常消费品记录失败: $e');
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
      debugPrint('获取日常消费品记录失败: $e');
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
      debugPrint('更新日常消费品记录失败: $e');
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
      debugPrint('删除日常消费品记录失败: $e');
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

      final response =
          await _client.from('fitness_records').insert(data).select().single();
      return response['id'] as String?;
    } catch (e) {
      debugPrint('插入健身记录失败: $e');
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
      debugPrint('获取健身记录失败: $e');
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
      debugPrint('删除健身记录失败: $e');
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

      final response =
          await _client.from('health_plans').insert(data).select().single();
      return response['id'] as String?;
    } catch (e) {
      debugPrint('插入健康计划失败: $e');
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
      debugPrint('获取健康计划失败: $e');
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
      data['mbti_description'] =
          data['mbtiDescription'] ?? data['mbti_description'];
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
        final List<dynamic> achievementList =
            achievements is List ? achievements : [];
        if (achievementList.isNotEmpty) {
          final rows = achievementList.map((a) {
            final m = Map<String, dynamic>.from(a as Map);
            m['passport_id'] = resultId;
            m['achievement_id'] = m['id'] ?? m['achievement_id'];
            m.remove('id');
            m['achievement_name'] = m['name'] ?? m['achievement_name'];
            m.remove('name');
            m['achievement_description'] =
                m['description'] ?? m['achievement_description'];
            m.remove('description');
            m['icon_name'] = m['iconName'] ?? m['icon_name'];
            m.remove('iconName');
            m['unlocked_at'] = m['unlockedAt'] ?? m['unlocked_at'];
            m.remove('unlockedAt');
            return m;
          }).toList();

          await _client.from('pet_passport_achievements').insert(rows);
        }
      }

      return resultId;
    } catch (e) {
      debugPrint('同步宠物护照失败: $e');
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

      final achievements =
          List<Map<String, dynamic>>.from(achievementsResponse).map((a) {
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
      debugPrint('获取宠物护照失败: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllPassports() async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response =
          await _client.from('pet_passports').select().eq('user_id', userId);

      final List<Map<String, dynamic>> passports = [];

      for (final row in response) {
        final map = Map<String, dynamic>.from(row);

        // 加载成就
        final achievementsResponse = await _client
            .from('pet_passport_achievements')
            .select()
            .eq('passport_id', map['id']);

        final achievements =
            List<Map<String, dynamic>>.from(achievementsResponse).map((a) {
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
      debugPrint('获取所有宠物护照失败: $e');
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
      debugPrint('删除所有宠物日记失败: $e');
      return false;
    }
  }

  // ============================================================
  // 统一消费记录相关方法
  // ============================================================

  /// 插入统一消费记录
  Future<String?> insertUnifiedExpense(Map<String, dynamic> expense) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      // 确保用户资料存在（因为 unified_expenses 表有外键约束）
      await _ensureUserProfileExists(userId);

      // 准备插入数据，转换字段名
      final expenseData = Map<String, dynamic>.from(expense);
      expenseData.remove('id'); // 移除 id，让数据库自动生成 UUID
      expenseData['user_id'] = userId;

      // 字段名映射：驼峰命名 -> 下划线命名
      expenseData['expense_type'] = expenseData['expenseType'];
      expenseData.remove('expenseType');

      if (expenseData.containsKey('petId')) {
        // petId 可能是 int（本地）或 String（UUID），需要转换
        final petId = expenseData['petId'];
        if (petId != null) {
          if (petId is int) {
            // 如果是整数（本地数据库的 ID），设为 null
            // 因为云端数据库使用 UUID，无法直接映射
            expenseData['pet_id'] = null;
          } else {
            // 如果是字符串（UUID），直接使用
            expenseData['pet_id'] = petId;
          }
        } else {
          expenseData['pet_id'] = null;
        }
        expenseData.remove('petId');
      }

      if (expenseData.containsKey('petName')) {
        expenseData['pet_name'] = expenseData['petName'];
        expenseData.remove('petName');
      }

      if (expenseData.containsKey('photoPath')) {
        expenseData['photo_path'] = expenseData['photoPath'];
        expenseData.remove('photoPath');
      }

      if (expenseData.containsKey('itemName')) {
        expenseData['item_name'] = expenseData['itemName'];
        expenseData.remove('itemName');
      }

      if (expenseData.containsKey('estimatedEndDate')) {
        expenseData['estimated_end_date'] = expenseData['estimatedEndDate'];
        expenseData.remove('estimatedEndDate');
      }

      if (expenseData.containsKey('itemType')) {
        expenseData['item_type'] = expenseData['itemType'];
        expenseData.remove('itemType');
      }

      if (expenseData.containsKey('createdAt')) {
        expenseData['created_at'] = expenseData['createdAt'];
        expenseData.remove('createdAt');
      }

      final response = await _client
          .from('unified_expenses')
          .insert(expenseData)
          .select()
          .single();

      return response['id'] as String?;
    } catch (e) {
      debugPrint('插入统一消费记录失败: $e');
      return null;
    }
  }

  /// 获取所有统一消费记录
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

      // 转换字段名以匹配应用层
      return _convertUnifiedExpenseList(response);
    } catch (e) {
      debugPrint('获取统一消费记录失败: $e');
      return [];
    }
  }

  /// 获取所有一次性支出
  Future<List<Map<String, dynamic>>> getOneOffUnifiedExpenses() async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('unified_expenses')
          .select()
          .eq('user_id', userId)
          .eq('expense_type', 'one-off')
          .order('date', ascending: false)
          .order('created_at', ascending: false);

      return _convertUnifiedExpenseList(response);
    } catch (e) {
      debugPrint('获取一次性支出失败: $e');
      return [];
    }
  }

  /// 获取所有周期性成本
  Future<List<Map<String, dynamic>>> getRecurringUnifiedExpenses() async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('unified_expenses')
          .select()
          .eq('user_id', userId)
          .eq('expense_type', 'recurring')
          .order('date', ascending: false)
          .order('created_at', ascending: false);

      return _convertUnifiedExpenseList(response);
    } catch (e) {
      debugPrint('获取周期性成本失败: $e');
      return [];
    }
  }

  /// 根据宠物ID获取消费记录
  Future<List<Map<String, dynamic>>> getUnifiedExpensesByPetId(
    String petId,
  ) async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('unified_expenses')
          .select()
          .eq('pet_id', petId)
          .eq('user_id', userId)
          .order('date', ascending: false)
          .order('created_at', ascending: false);

      return _convertUnifiedExpenseList(response);
    } catch (e) {
      debugPrint('获取宠物消费记录失败: $e');
      return [];
    }
  }

  /// 根据日期范围获取消费记录
  Future<List<Map<String, dynamic>>> getUnifiedExpensesByDateRange(
    String startDate,
    String endDate,
  ) async {
    final userId = await currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('unified_expenses')
          .select()
          .eq('user_id', userId)
          .gte('date', startDate)
          .lte('date', endDate)
          .order('date', ascending: false)
          .order('created_at', ascending: false);

      return _convertUnifiedExpenseList(response);
    } catch (e) {
      debugPrint('获取日期范围消费记录失败: $e');
      return [];
    }
  }

  /// 更新统一消费记录
  Future<bool> updateUnifiedExpense(Map<String, dynamic> expense) async {
    final userId = await currentUserId;
    if (userId == null || expense['id'] == null) return false;

    try {
      final expenseId = expense['id'] as String;
      final updateData = Map<String, dynamic>.from(expense);
      updateData.remove('id');
      updateData.remove('user_id');
      updateData['updated_at'] = DateTime.now().toIso8601String();

      // 字段名映射
      if (updateData.containsKey('expenseType')) {
        updateData['expense_type'] = updateData['expenseType'];
        updateData.remove('expenseType');
      }

      if (updateData.containsKey('petId')) {
        final petId = updateData['petId'];
        if (petId != null && petId is int) {
          // 如果是整数，设为 null（无法映射到 UUID）
          updateData['pet_id'] = null;
        } else {
          updateData['pet_id'] = petId;
        }
        updateData.remove('petId');
      }

      if (updateData.containsKey('petName')) {
        updateData['pet_name'] = updateData['petName'];
        updateData.remove('petName');
      }

      if (updateData.containsKey('photoPath')) {
        updateData['photo_path'] = updateData['photoPath'];
        updateData.remove('photoPath');
      }

      if (updateData.containsKey('itemName')) {
        updateData['item_name'] = updateData['itemName'];
        updateData.remove('itemName');
      }

      if (updateData.containsKey('estimatedEndDate')) {
        updateData['estimated_end_date'] = updateData['estimatedEndDate'];
        updateData.remove('estimatedEndDate');
      }

      if (updateData.containsKey('itemType')) {
        updateData['item_type'] = updateData['itemType'];
        updateData.remove('itemType');
      }

      if (updateData.containsKey('createdAt')) {
        updateData['created_at'] = updateData['createdAt'];
        updateData.remove('createdAt');
      }

      await _client
          .from('unified_expenses')
          .update(updateData)
          .eq('id', expenseId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('更新统一消费记录失败: $e');
      return false;
    }
  }

  /// 删除统一消费记录
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
      debugPrint('删除统一消费记录失败: $e');
      return false;
    }
  }

  /// 获取指定月份的总支出
  Future<double> getUnifiedExpensesMonthlyTotal(int year, int month) async {
    final userId = await currentUserId;
    if (userId == null) return 0.0;

    try {
      final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
      final endDate = '$year-${month.toString().padLeft(2, '0')}-31';

      final response = await _client
          .from('unified_expenses')
          .select('amount')
          .eq('user_id', userId)
          .gte('date', startDate)
          .lte('date', endDate);

      double total = 0.0;
      for (var row in response) {
        total += (row['amount'] as num).toDouble();
      }

      return total;
    } catch (e) {
      debugPrint('获取月度总支出失败: $e');
      return 0.0;
    }
  }

  /// 获取指定年份的总支出
  Future<double> getUnifiedExpensesYearlyTotal(int year) async {
    final userId = await currentUserId;
    if (userId == null) return 0.0;

    try {
      final startDate = '$year-01-01';
      final endDate = '$year-12-31';

      final response = await _client
          .from('unified_expenses')
          .select('amount')
          .eq('user_id', userId)
          .gte('date', startDate)
          .lte('date', endDate);

      double total = 0.0;
      for (var row in response) {
        total += (row['amount'] as num).toDouble();
      }

      return total;
    } catch (e) {
      debugPrint('获取年度总支出失败: $e');
      return 0.0;
    }
  }

  /// 获取分类统计（指定日期范围）
  Future<Map<String, double>> getUnifiedExpensesCategoryStatistics(
    String startDate,
    String endDate,
  ) async {
    final userId = await currentUserId;
    if (userId == null) return {};

    try {
      final response = await _client
          .from('unified_expenses')
          .select('category, amount')
          .eq('user_id', userId)
          .gte('date', startDate)
          .lte('date', endDate);

      Map<String, double> statistics = {};
      for (var row in response) {
        final category = row['category'] as String;
        final amount = (row['amount'] as num).toDouble();
        statistics[category] = (statistics[category] ?? 0.0) + amount;
      }

      // 按金额排序
      final sortedEntries = statistics.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return Map.fromEntries(sortedEntries);
    } catch (e) {
      debugPrint('获取分类统计失败: $e');
      return {};
    }
  }

  /// 获取所有支出总额
  Future<double> getUnifiedExpensesTotal() async {
    final userId = await currentUserId;
    if (userId == null) return 0.0;

    try {
      final response = await _client
          .from('unified_expenses')
          .select('amount')
          .eq('user_id', userId);

      double total = 0.0;
      for (var row in response) {
        total += (row['amount'] as num).toDouble();
      }

      return total;
    } catch (e) {
      debugPrint('获取总支出失败: $e');
      return 0.0;
    }
  }

  /// 转换统一消费记录列表（字段名映射：下划线 -> 驼峰）
  List<Map<String, dynamic>> _convertUnifiedExpenseList(
    List<dynamic> response,
  ) {
    return response.map((row) {
      final map = Map<String, dynamic>.from(row);

      // 字段名映射：下划线命名 -> 驼峰命名
      map['expenseType'] = map['expense_type'];
      map.remove('expense_type');

      map['petId'] = map['pet_id'];
      map.remove('pet_id');

      map['petName'] = map['pet_name'];
      map.remove('pet_name');

      map['photoPath'] = map['photo_path'];
      map.remove('photo_path');

      map['itemName'] = map['item_name'];
      map.remove('item_name');

      map['estimatedEndDate'] = map['estimated_end_date'];
      map.remove('estimated_end_date');

      map['itemType'] = map['item_type'];
      map.remove('item_type');

      map['createdAt'] = map['created_at'];
      map.remove('created_at');

      // id 从 UUID 转换为 String（保持一致性）
      if (map['id'] != null) {
        map['id'] = map['id'].toString();
      }

      return map;
    }).toList();
  }

  // ============================================================
  // 健身课程相关方法
  // ============================================================

  /// 获取所有激活的健身课程
  Future<List<FitnessCourse>> getFitnessCourses() async {
    try {
      final response = await _client
          .from('fitness_courses')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response)
          .map((json) => FitnessCourse.fromSupabaseJson(json))
          .toList();
    } catch (e) {
      // 区分不同类型的错误
      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        debugPrint('获取健身课程失败: 网络错误 - $e');
      } else if (e.toString().contains('permission') ||
          e.toString().contains('policy')) {
        debugPrint('获取健身课程失败: 权限错误 - $e');
      } else {
        debugPrint('获取健身课程失败: $e');
      }
      return [];
    }
  }

  /// 根据宠物类型获取课程
  Future<List<FitnessCourse>> getFitnessCoursesByPetType(String petType) async {
    try {
      // 验证petType值
      if (!['dog', 'cat'].contains(petType)) {
        debugPrint(
            '获取宠物类型健身课程失败: Invalid petType: $petType. Must be either dog or cat');
        return [];
      }

      final response = await _client
          .from('fitness_courses')
          .select()
          .eq('pet_type', petType)
          .eq('is_active', true)
          .order('sort_order', ascending: false);

      return List<Map<String, dynamic>>.from(response)
          .map((json) => FitnessCourse.fromSupabaseJson(json))
          .toList();
    } catch (e) {
      // 区分不同类型的错误
      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        debugPrint('获取宠物类型健身课程失败: 网络错误 - $e');
      } else if (e.toString().contains('permission') ||
          e.toString().contains('policy')) {
        debugPrint('获取宠物类型健身课程失败: 权限错误 - $e');
      } else {
        debugPrint('获取宠物类型健身课程失败: $e');
      }
      return [];
    }
  }

  /// 获取自指定时间后的更新课程（增量更新）
  /// 注意：此方法用于优化网络请求，只获取更新的课程
  Future<List<FitnessCourse>> getFitnessCoursesUpdatedAfter(
      DateTime since) async {
    try {
      final response = await _client
          .from('fitness_courses')
          .select()
          .eq('is_active', true)
          .gte('updated_at', since.toIso8601String())
          .order('updated_at', ascending: false);

      return List<Map<String, dynamic>>.from(response)
          .map((json) => FitnessCourse.fromSupabaseJson(json))
          .toList();
    } catch (e) {
      // 区分不同类型的错误
      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        debugPrint('获取增量健身课程失败: 网络错误 - $e');
      } else if (e.toString().contains('permission') ||
          e.toString().contains('policy')) {
        debugPrint('获取增量健身课程失败: 权限错误 - $e');
      } else {
        debugPrint('获取增量健身课程失败: $e');
      }
      // 增量更新失败时，返回空列表（上层会降级到全量更新）
      return [];
    }
  }

  /// 处理健身课程数据的字段映射和类型转换
  void _processFitnessCourseData(Map<String, dynamic> data) {
    // 字段名映射
    final fieldMapping = {
      'courseId': 'course_id',
      'durationMinutes': 'duration_minutes',
      'caloriesEstimate': 'calories_estimate',
      'petCaloriesEstimate': 'pet_calories_estimate',
      'iconEmoji': 'icon_emoji',
      'petType': 'pet_type',
      'isActive': 'is_active',
      'sortOrder': 'sort_order',
    };

    for (var entry in fieldMapping.entries) {
      if (data.containsKey(entry.key)) {
        data[entry.value] = data[entry.key];
        data.remove(entry.key);
      }
    }

    // 处理actions字段（JSONB类型）
    if (data.containsKey('actions')) {
      final actions = data['actions'];
      if (actions is List) {
        // 如果actions是List<FitnessAction>，转换为List<Map>
        data['actions'] = actions.map((action) {
          if (action is FitnessAction) {
            return action.toSupabaseJson();
          }
          // 如果已经是Map格式，直接使用
          return action as Map<String, dynamic>;
        }).toList();
      }
    }

    // 处理tags字段（TEXT[]类型）
    if (data.containsKey('tags')) {
      // 确保tags是List<String>
      if (data['tags'] is List) {
        data['tags'] = List<String>.from(data['tags']);
      }
    }
  }

  /// 插入健身课程（管理后台使用）
  Future<String?> insertFitnessCourse(Map<String, dynamic> course) async {
    try {
      final data = Map<String, dynamic>.from(course);
      data.remove('id'); // 让数据库生成UUID

      // 使用辅助方法处理字段映射和复杂类型转换
      _processFitnessCourseData(data);

      // 数据验证
      // 验证必需字段
      if (data['course_id'] == null || (data['course_id'] as String).isEmpty) {
        debugPrint('插入健身课程失败: course_id is required');
        return null;
      }

      // 验证intensity值
      if (data.containsKey('intensity')) {
        final intensity = data['intensity'] as String?;
        if (intensity != null &&
            !['low', 'medium', 'high'].contains(intensity)) {
          debugPrint('插入健身课程失败: intensity must be low, medium, or high');
          return null;
        }
      }

      // 验证petType值
      if (data.containsKey('pet_type')) {
        final petType = data['pet_type'] as String?;
        if (petType != null && !['dog', 'cat'].contains(petType)) {
          debugPrint('插入健身课程失败: pet_type must be dog or cat');
          return null;
        }
      }

      final response =
          await _client.from('fitness_courses').insert(data).select().single();

      return response['id'] as String?;
    } catch (e) {
      // 区分不同类型的错误
      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        debugPrint('插入健身课程失败: 网络错误 - $e');
      } else if (e.toString().contains('permission') ||
          e.toString().contains('policy')) {
        debugPrint('插入健身课程失败: 权限错误 - $e');
      } else if (e.toString().contains('duplicate') ||
          e.toString().contains('unique')) {
        debugPrint('插入健身课程失败: 数据重复错误 - $e');
      } else if (e.toString().contains('validation') ||
          e.toString().contains('constraint')) {
        debugPrint('插入健身课程失败: 数据验证错误 - $e');
      } else {
        debugPrint('插入健身课程失败: $e');
      }
      return null;
    }
  }

  /// 更新健身课程
  Future<bool> updateFitnessCourse(Map<String, dynamic> course) async {
    try {
      final courseId = course['id'];
      if (courseId == null) {
        debugPrint('更新健身课程失败: course id is required');
        return false;
      }

      final data = Map<String, dynamic>.from(course);
      data.remove('id');

      // 使用辅助方法处理字段映射和复杂类型转换
      _processFitnessCourseData(data);

      // 数据验证
      // 验证intensity值（如果提供）
      if (data.containsKey('intensity')) {
        final intensity = data['intensity'] as String?;
        if (intensity != null &&
            !['low', 'medium', 'high'].contains(intensity)) {
          debugPrint('更新健身课程失败: intensity must be low, medium, or high');
          return false;
        }
      }

      // 验证petType值（如果提供）
      if (data.containsKey('pet_type')) {
        final petType = data['pet_type'] as String?;
        if (petType != null && !['dog', 'cat'].contains(petType)) {
          debugPrint('更新健身课程失败: pet_type must be dog or cat');
          return false;
        }
      }

      await _client.from('fitness_courses').update(data).eq('id', courseId);

      return true;
    } catch (e) {
      // 区分不同类型的错误
      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        debugPrint('更新健身课程失败: 网络错误 - $e');
      } else if (e.toString().contains('permission') ||
          e.toString().contains('policy')) {
        debugPrint('更新健身课程失败: 权限错误 - $e');
      } else if (e.toString().contains('validation') ||
          e.toString().contains('constraint')) {
        debugPrint('更新健身课程失败: 数据验证错误 - $e');
      } else {
        debugPrint('更新健身课程失败: $e');
      }
      return false;
    }
  }

  /// 根据course_id获取单个课程
  Future<FitnessCourse?> getFitnessCourseById(String courseId) async {
    try {
      final response = await _client
          .from('fitness_courses')
          .select()
          .eq('course_id', courseId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;

      return FitnessCourse.fromSupabaseJson(response);
    } catch (e) {
      // 区分不同类型的错误
      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        debugPrint('获取健身课程失败: 网络错误 - $e');
      } else if (e.toString().contains('permission') ||
          e.toString().contains('policy')) {
        debugPrint('获取健身课程失败: 权限错误 - $e');
      } else {
        debugPrint('获取健身课程失败: $e');
      }
      return null;
    }
  }

  /// 删除健身课程（软删除，设置is_active=false）
  /// 注意：使用数据库的id字段（UUID），不是course_id
  Future<bool> deleteFitnessCourse(String courseId) async {
    try {
      await _client
          .from('fitness_courses')
          .update({'is_active': false}).eq('id', courseId);

      return true;
    } catch (e) {
      // 区分不同类型的错误
      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        debugPrint('删除健身课程失败: 网络错误 - $e');
      } else if (e.toString().contains('permission') ||
          e.toString().contains('policy')) {
        debugPrint('删除健身课程失败: 权限错误 - $e');
      } else {
        debugPrint('删除健身课程失败: $e');
      }
      return false;
    }
  }

  // ============================================================
  // 社区帖子（Phase 1：发帖 + 信息流）
  // ============================================================

  static const String _communityBucket = 'post-images';
  static const String _userAvatarBucket = 'user-avatars';
  static const String _petAvatarBucket = 'pet-avatars';

  /// 上传帖子图片到 Storage，返回公开 URL
  /// path 建议格式: {userId}/{postId}_{index}.jpg
  Future<String?> uploadPostImage(File file, String path) async {
    try {
      await _client.storage.from(_communityBucket).upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = _client.storage.from(_communityBucket).getPublicUrl(path);
      return url;
    } catch (e) {
      debugPrint('上传帖子图片失败: $e');
      return null;
    }
  }

  /// 上传帖子图片（Uint8List，用于海报等内存图）
  Future<String?> uploadPostImageBytes(Uint8List bytes, String path) async {
    try {
      await _client.storage.from(_communityBucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return _client.storage.from(_communityBucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('上传帖子图片失败: $e');
      return null;
    }
  }

  /// 上传用户头像到 Storage，返回公开 URL
  Future<String?> uploadUserAvatar(File file) async {
    final userId = await currentUserId;
    if (userId == null) return null;
    final path = '$userId/avatar.jpg';
    try {
      await _client.storage.from(_userAvatarBucket).upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      return _client.storage.from(_userAvatarBucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('上传用户头像失败: $e');
      return null;
    }
  }

  /// 上传宠物头像到 Storage，返回公开 URL
  Future<String?> uploadPetAvatar({
    required File file,
    String? petId,
  }) async {
    final userId = await currentUserId;
    if (userId == null) return null;
    final identifier = petId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final path = '$userId/$identifier/avatar.jpg';
    try {
      await _client.storage.from(_petAvatarBucket).upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      return _client.storage.from(_petAvatarBucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('上传宠物头像失败: $e');
      return null;
    }
  }

  /// 创建帖子
  Future<Map<String, dynamic>?> createCommunityPost({
    required String content,
    required List<String> imageUrls,
    List<String> topicIds = const [],
    String sourceType = 'normal',
  }) async {
    final userId = await currentUserId;
    if (userId == null) return null;
    try {
      final res = await _client
          .from('community_posts')
          .insert({
            'author_id': userId,
            'content': content,
            'image_urls': imageUrls,
            'topic_ids': topicIds,
            'source_type': sourceType,
          })
          .select()
          .single();
      return res as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('创建社区帖子失败: $e');
      return null;
    }
  }

  /// 分页拉取帖子列表（含作者昵称、头像）
  Future<List<Map<String, dynamic>>> listCommunityPosts({
    int limit = 20,
    int offset = 0,
    String? sourceType,
  }) async {
    try {
      var query = _client.from('community_posts').select(
          'id, content, image_urls, topic_ids, source_type, like_count, comment_count, created_at, author_id');
      if (sourceType != null && sourceType.isNotEmpty) {
        query = query.eq('source_type', sourceType);
      }
      final list = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      if (list.isEmpty) return [];
      final posts = List<Map<String, dynamic>>.from(list as List);
      final authorIds = posts
          .where((p) => p['author_id'] != null)
          .map<String>((p) => p['author_id'].toString())
          .toSet()
          .toList();
      final profiles = await _getProfilesByIds(authorIds);
      for (final p in posts) {
        final profile = profiles[p['author_id'] as String];
        p['author_nickname'] = profile?['nickname'] ?? '用户';
        p['author_avatar_url'] = profile?['avatar_url'];
      }
      return posts;
    } catch (e) {
      debugPrint('拉取社区帖子列表失败: $e');
      return [];
    }
  }

  /// 按 id 列表批量拉取 users_profiles
  Future<Map<String, Map<String, dynamic>>> _getProfilesByIds(
      List<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      final list = await _client
          .from('users_profiles')
          .select('id, nickname, avatar_url')
          .inFilter('id', ids);
      final map = <String, Map<String, dynamic>>{};
      for (final row in list as List) {
        final r = Map<String, dynamic>.from(row as Map);
        final id = r['id']?.toString();
        if (id != null) map[id] = r;
      }
      return map;
    } catch (e) {
      debugPrint('批量拉取用户资料失败: $e');
      return {};
    }
  }

  /// 单条帖子详情（含作者信息）
  Future<Map<String, dynamic>?> getCommunityPost(String postId) async {
    try {
      final res = await _client
          .from('community_posts')
          .select(
              'id, content, image_urls, topic_ids, source_type, like_count, comment_count, created_at, author_id')
          .eq('id', postId)
          .single();
      final data = res as Map<String, dynamic>?;
      if (data == null || data['author_id'] == null) return null;
      final authorId = data['author_id'].toString();
      final profiles = await _getProfilesByIds([authorId]);
      final profile = profiles[authorId];
      data['author_nickname'] = profile?['nickname'] ?? '用户';
      data['author_avatar_url'] = profile?['avatar_url'];
      return data;
    } catch (e) {
      debugPrint('获取社区帖子失败: $e');
      return null;
    }
  }

  // ============================================================
  // 社区互动（Phase 2：评论、点赞、收藏、关注）
  // ============================================================

  /// 发表评论
  Future<Map<String, dynamic>?> createComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    final userId = await currentUserId;
    if (userId == null) return null;
    try {
      final res = await _client
          .from('community_post_comments')
          .insert({
            'post_id': postId,
            'user_id': userId,
            'parent_id': parentId,
            'content': content,
          })
          .select()
          .single();
      return res as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('发表评论失败: $e');
      return null;
    }
  }

  /// 获取帖子的评论列表（含作者信息）
  Future<List<Map<String, dynamic>>> getPostComments(String postId) async {
    try {
      final list = await _client
          .from('community_post_comments')
          .select('id, post_id, user_id, parent_id, content, created_at')
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      if (list.isEmpty) return [];
      final comments = List<Map<String, dynamic>>.from(list as List);
      final userIds = comments
          .map<String>((c) => c['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (userIds.isEmpty) return comments;
      final profiles = await _getProfilesByIds(userIds);
      for (final c in comments) {
        final uid = c['user_id']?.toString();
        if (uid != null) {
          final profile = profiles[uid];
          c['author_nickname'] = profile?['nickname'] ?? '用户';
          c['author_avatar_url'] = profile?['avatar_url'];
        }
      }
      return comments;
    } catch (e) {
      debugPrint('获取评论列表失败: $e');
      return [];
    }
  }

  /// 点赞/取消点赞
  Future<bool> toggleLike(String postId) async {
    final userId = await currentUserId;
    if (userId == null) return false;
    try {
      final existing = await _client
          .from('community_post_likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();
      if (existing != null) {
        await _client
            .from('community_post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
        return false;
      } else {
        await _client.from('community_post_likes').insert({
          'post_id': postId,
          'user_id': userId,
        });
        return true;
      }
    } catch (e) {
      debugPrint('点赞操作失败: $e');
      return false;
    }
  }

  /// 检查当前用户是否已点赞
  Future<bool> isLiked(String postId) async {
    final userId = await currentUserId;
    if (userId == null) return false;
    try {
      final res = await _client
          .from('community_post_likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();
      return res != null;
    } catch (e) {
      return false;
    }
  }

  /// 收藏/取消收藏
  Future<bool> toggleCollection(String postId) async {
    final userId = await currentUserId;
    if (userId == null) return false;
    try {
      final existing = await _client
          .from('community_post_collections')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();
      if (existing != null) {
        await _client
            .from('community_post_collections')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
        return false;
      } else {
        await _client.from('community_post_collections').insert({
          'post_id': postId,
          'user_id': userId,
        });
        return true;
      }
    } catch (e) {
      debugPrint('收藏操作失败: $e');
      return false;
    }
  }

  /// 检查当前用户是否已收藏
  Future<bool> isCollected(String postId) async {
    final userId = await currentUserId;
    if (userId == null) return false;
    try {
      final res = await _client
          .from('community_post_collections')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();
      return res != null;
    } catch (e) {
      return false;
    }
  }

  /// 关注/取消关注
  /// 返回 true 表示已关注，false 表示已取消关注
  Future<bool> toggleFollow(String followingId) async {
    final userId = await currentUserId;
    if (userId == null || userId == followingId) {
      debugPrint('关注操作失败: userId=$userId, followingId=$followingId');
      return false;
    }
    try {
      final existing = await _client
          .from('community_user_follows')
          .select('id')
          .eq('follower_id', userId)
          .eq('following_id', followingId)
          .maybeSingle();
      if (existing != null) {
        // 已关注，执行取消关注
        await _client
            .from('community_user_follows')
            .delete()
            .eq('follower_id', userId)
            .eq('following_id', followingId);
        debugPrint('取消关注成功: $followingId');
        return false; // false = 已取消关注
      } else {
        // 未关注，执行关注
        await _client.from('community_user_follows').insert({
          'follower_id': userId,
          'following_id': followingId,
        });
        debugPrint('关注成功: $followingId');
        return true; // true = 已关注
      }
    } catch (e) {
      debugPrint('关注操作失败: $e');
      return false;
    }
  }

  /// 检查当前用户是否已关注
  Future<bool> isFollowing(String userId) async {
    final currentId = await currentUserId;
    if (currentId == null || currentId == userId) return false;
    try {
      final res = await _client
          .from('community_user_follows')
          .select('id')
          .eq('follower_id', currentId)
          .eq('following_id', userId)
          .maybeSingle();
      return res != null;
    } catch (e) {
      return false;
    }
  }

  /// 批量检查点赞状态（用于列表）
  Future<Map<String, bool>> batchCheckLiked(List<String> postIds) async {
    final userId = await currentUserId;
    if (userId == null || postIds.isEmpty) return {};
    try {
      final list = await _client
          .from('community_post_likes')
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds);
      final map = <String, bool>{};
      for (final row in list as List) {
        final pid = row['post_id']?.toString();
        if (pid != null) map[pid] = true;
      }
      return map;
    } catch (e) {
      return {};
    }
  }

  /// 获取关注流（关注的人的帖子）
  Future<List<Map<String, dynamic>>> getFollowingFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    final userId = await currentUserId;
    if (userId == null) return [];
    try {
      // 1. 获取当前用户关注的人列表
      final follows = await _client
          .from('community_user_follows')
          .select('following_id')
          .eq('follower_id', userId);
      if (follows.isEmpty) return [];
      final followingIds = (follows as List)
          .map<String>((f) => f['following_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      if (followingIds.isEmpty) return [];
      // 2. 查询这些人的帖子
      final list = await _client
          .from('community_posts')
          .select(
              'id, content, image_urls, topic_ids, source_type, like_count, comment_count, created_at, author_id')
          .inFilter('author_id', followingIds)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      if (list.isEmpty) return [];
      final posts = List<Map<String, dynamic>>.from(list as List);
      // 3. 获取作者信息
      final authorIds = posts
          .where((p) => p['author_id'] != null)
          .map<String>((p) => p['author_id'].toString())
          .toSet()
          .toList();
      if (authorIds.isEmpty) return posts;
      final profiles = await _getProfilesByIds(authorIds);
      for (final p in posts) {
        final uid = p['author_id']?.toString();
        if (uid != null) {
          final profile = profiles[uid];
          p['author_nickname'] = profile?['nickname'] ?? '用户';
          p['author_avatar_url'] = profile?['avatar_url'];
        }
      }
      return posts;
    } catch (e) {
      debugPrint('获取关注流失败: $e');
      return [];
    }
  }
}
