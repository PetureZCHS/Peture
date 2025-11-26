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

      final response = await _client
          .from('pets')
          .insert(petData)
          .select()
          .single();
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

      return List<Map<String, dynamic>>.from(response);
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

      await _client
          .from('pets')
          .update(updateData)
          .eq('id', petId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('更新宠物失败: $e');
      return false;
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
      final response = await _client
          .from('daily_reminders')
          .select()
          .eq('user_id', userId);

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
      var query = _client
          .from('daily_reminders')
          .select()
          .eq('user_id', userId);

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
  // 对话相关方法
  // ============================================================

  /// 插入对话
  Future<String?> insertConversation(Conversation conversation) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      // 确保用户资料存在
      await _ensureUserProfileExists(userId);

      final conversationData = {
        'user_id': userId,
        'question': conversation.question,
        'answer': conversation.answer,
        'is_pinned': conversation.isPinned,
        'created_at': conversation.timestamp.toIso8601String(),
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

  /// 更新对话
  Future<bool> updateConversation(Conversation conversation) async {
    final userId = await currentUserId;
    if (userId == null || conversation.id == null) return false;

    try {
      await _client
          .from('conversations')
          .update({
            'question': conversation.question,
            'answer': conversation.answer,
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

  /// 删除对话
  Future<bool> deleteConversation(String id) async {
    final userId = await currentUserId;
    if (userId == null) return false;

    try {
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
  }) async {
    final userId = await currentUserId;
    if (userId == null) return null;

    try {
      final messageData = {
        'conversation_id': conversationId,
        'user_id': userId,
        'text': text,
        'is_user': isUser,
        'created_at': DateTime.now().toIso8601String(),
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

      final response = await _client
          .from('pet_diaries')
          .insert(diaryData)
          .select()
          .single();
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
