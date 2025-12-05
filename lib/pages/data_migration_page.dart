import 'package:flutter/material.dart';
import '../database/medical_record_helper.dart';
import '../database/database_helper.dart';
import '../database/chat_history_helper.dart';
import '../database/unified_expense_helper.dart';
import '../database/daily_cost_helper.dart';
import '../database/fitness_helper.dart';
import '../database/pet_passport_helper.dart';
import '../models/conversation.dart';
import '../models/pet_diary.dart';
import '../models/chat_history.dart' as chat_models;
import '../services/supabase_service.dart';

/// 数据迁移页面
/// 用于将 SQLite 数据迁移到 Supabase
class DataMigrationPage extends StatefulWidget {
  const DataMigrationPage({super.key});

  @override
  State<DataMigrationPage> createState() => _DataMigrationPageState();
}

class _DataMigrationPageState extends State<DataMigrationPage> {
  String _status = '准备开始数据迁移...';
  bool _isMigrating = false;
  double _progress = 0.0;
  int _totalItems = 0;
  int _migratedItems = 0;

  final SupabaseService _supabaseService = SupabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据迁移到 Supabase'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 说明卡片
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          '数据迁移说明',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '此工具将把您本地 SQLite 数据库中的数据迁移到 Supabase 云数据库。\n\n'
                      '迁移内容包括：\n'
                      '• 宠物信息\n'
                      '• 医疗记录\n'
                      '• 体重记录\n'
                      '• 疫苗记录\n'
                      '• 每日提醒\n'
                      '• 对话记录 + 聊天消息\n'
      '• 宠物日记\n'
      '• 统一消费 / 日常消费\n'
      '• 健身记录 / 健康计划\n'
      '• 宠物护照\n\n'
                      '⚠️ 请确保网络连接正常，迁移过程中请勿关闭应用。',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 进度条：仅迁移中显示动画，非迁移时保持静止(0%)
            LinearProgressIndicator(
              value: _isMigrating ? _progress : 0.0,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _isMigrating ? Colors.blue : Colors.grey,
              ),
            ),

            const SizedBox(height: 16),

            // 状态文本
            Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _status,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 操作按钮
            ElevatedButton.icon(
              onPressed: _isMigrating ? null : _startMigration,
              icon: _isMigrating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_isMigrating ? '迁移中...' : '开始迁移'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
              ),
            ),

            const SizedBox(height: 12),

            // 验证按钮
            OutlinedButton.icon(
              onPressed: _isMigrating ? null : _verifyMigration,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('验证迁移结果'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                side: const BorderSide(color: Colors.green),
                foregroundColor: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startMigration() async {
    setState(() {
      _isMigrating = true;
      _progress = 0.0;
      _status = '开始数据迁移...\n';
      _totalItems = 0;
      _migratedItems = 0;
    });

    try {
      // 检查用户是否已登录
      final isLoggedIn = await _supabaseService.isLoggedIn;
      if (!isLoggedIn) {
        setState(() {
          _status += '❌ 错误：用户未登录 Supabase，请先登录\n';
          _isMigrating = false;
        });
        return;
      }

      _status += '✅ 用户已登录，开始迁移数据...\n\n';

      // 1. 迁移宠物数据
      await _migratePets();

      // 2. 迁移医疗记录
      await _migrateMedicalRecords();

      // 3. 迁移体重记录
      await _migrateWeightRecords();

      // 4. 迁移疫苗记录
      await _migrateVaccineRecords();

      // 5. 迁移每日提醒
      await _migrateDailyReminders();

      // 6. 迁移统一消费记录
      await _migrateUnifiedExpenses();

      // 7. 迁移日常消费品记录
      await _migrateDailyCostItems();

      // 8. 迁移健身记录
      await _migrateFitnessRecords();

      // 9. 迁移对话记录 & 聊天历史
      await _migrateConversationsAndMessages();

      // 10. 迁移宠物日记
      await _migratePetDiaries();

      // 11. 迁移宠物护照
      await _migratePetPassports();

      setState(() {
        _progress = 1.0;
        _status += '\n🎉 数据迁移完成！\n';
        _status += '总共迁移了 $_migratedItems 个数据项\n';
        _isMigrating = false;
      });

    } catch (e) {
      setState(() {
        _status += '\n❌ 迁移失败: $e\n';
        _isMigrating = false;
      });
    }
  }

  Future<void> _migratePets() async {
    setState(() {
      _status += '📊 迁移宠物数据...\n';
    });

    try {
      final pets = await MedicalRecordHelper.instance.getAllPets();
      _totalItems += pets.length;

      for (final petMap in pets) {
        try {
          final result = await _supabaseService.insertPet(petMap);

          if (result != null) {
            _migratedItems++;
            setState(() {
              _progress = _migratedItems / _totalItems;
              _status += '✅ 宠物 "${petMap['name']}" 迁移成功\n';
            });
          } else {
            setState(() {
              _status += '⚠️ 宠物 "${petMap['name']}" 迁移失败\n';
            });
          }
        } catch (e) {
          setState(() {
            _status += '❌ 宠物迁移错误: $e\n';
          });
        }
      }
    } catch (e) {
      setState(() {
        _status += '❌ 获取宠物数据失败: $e\n';
      });
    }
  }

  Future<void> _migrateMedicalRecords() async {
    setState(() {
      _status += '\n🏥 迁移医疗记录...\n';
    });

    try {
      final records = await MedicalRecordHelper.instance.getAllMedicalRecords();
      _totalItems += records.length;

      for (final recordMap in records) {
        try {
          final result = await _supabaseService.insertMedicalRecord(recordMap);

          if (result != null) {
            _migratedItems++;
            setState(() {
              _progress = _migratedItems / _totalItems;
              _status += '✅ 医疗记录迁移成功\n';
            });
          } else {
            setState(() {
              _status += '⚠️ 医疗记录迁移失败\n';
            });
          }
        } catch (e) {
          setState(() {
            _status += '❌ 医疗记录迁移错误: $e\n';
          });
        }
      }
    } catch (e) {
      setState(() {
        _status += '❌ 获取医疗记录失败: $e\n';
      });
    }
  }

  Future<void> _migrateWeightRecords() async {
    setState(() {
      _status += '\n⚖️ 迁移体重记录...\n';
    });

    try {
      final records = await MedicalRecordHelper.instance.getAllWeightRecords();
      _totalItems += records.length;

      for (final recordMap in records) {
        try {
          final result = await _supabaseService.insertWeightRecord(recordMap);

          if (result != null) {
            _migratedItems++;
            setState(() {
              _progress = _migratedItems / _totalItems;
              _status += '✅ 体重记录迁移成功\n';
            });
          } else {
            setState(() {
              _status += '⚠️ 体重记录迁移失败\n';
            });
          }
        } catch (e) {
          setState(() {
            _status += '❌ 体重记录迁移错误: $e\n';
          });
        }
      }
    } catch (e) {
      setState(() {
        _status += '❌ 获取体重记录失败: $e\n';
      });
    }
  }

  Future<void> _migrateVaccineRecords() async {
    setState(() {
      _status += '\n💉 迁移疫苗记录...\n';
    });

    try {
      final records = await MedicalRecordHelper.instance.getAllVaccineRecords();
      _totalItems += records.length;

      for (final recordMap in records) {
        try {
          final result = await _supabaseService.insertVaccineRecord(recordMap);

          if (result != null) {
            _migratedItems++;
            setState(() {
              _progress = _migratedItems / _totalItems;
              _status += '✅ 疫苗记录迁移成功\n';
            });
          } else {
            setState(() {
              _status += '⚠️ 疫苗记录迁移失败\n';
            });
          }
        } catch (e) {
          setState(() {
            _status += '❌ 疫苗记录迁移错误: $e\n';
          });
        }
      }
    } catch (e) {
      setState(() {
        _status += '❌ 获取疫苗记录失败: $e\n';
      });
    }
  }

  Future<void> _migrateDailyReminders() async {
    setState(() {
      _status += '\n⏰ 迁移每日提醒...\n';
    });

    try {
      final reminders = await MedicalRecordHelper.instance.getAllDailyReminders();
      _totalItems += reminders.length;

      for (final reminderMap in reminders) {
        try {
          final result = await _supabaseService.insertDailyReminder(reminderMap);

          if (result != null) {
            _migratedItems++;
            setState(() {
              _progress = _migratedItems / _totalItems;
              _status += '✅ 每日提醒迁移成功\n';
            });
          } else {
            setState(() {
              _status += '⚠️ 每日提醒迁移失败\n';
            });
          }
        } catch (e) {
          setState(() {
            _status += '❌ 每日提醒迁移错误: $e\n';
          });
        }
      }
    } catch (e) {
      setState(() {
        _status += '❌ 获取每日提醒失败: $e\n';
      });
    }
  }

  Future<void> _migrateUnifiedExpenses() async {
    setState(() {
      _status += '\n💰 迁移统一消费记录...\n';
    });

    try {
      final localExpenses =
          await UnifiedExpenseHelper.instance.getAllExpenses();
      _totalItems += localExpenses.length;

      for (final expense in localExpenses) {
        try {
          final result =
              await _supabaseService.insertUnifiedExpense(expense.toMap());
          if (result != null) {
            _migratedItems++;
            setState(() {
              _progress = _migratedItems / _totalItems;
              _status += '✅ 统一消费记录迁移成功（${expense.category} ¥${expense.amount}）\n';
            });
          } else {
            setState(() {
              _status += '⚠️ 统一消费记录迁移失败\n';
            });
          }
        } catch (e) {
          setState(() {
            _status += '❌ 统一消费记录迁移错误: $e\n';
          });
        }
      }
    } catch (e) {
      setState(() {
        _status += '❌ 获取统一消费记录失败: $e\n';
      });
    }
  }

  Future<void> _migrateDailyCostItems() async {
    setState(() {
      _status += '\n🛒 迁移日常消费品记录...\n';
    });

    try {
      final localItems = await DailyCostHelper.instance.getAllItems();
      _totalItems += localItems.length;

      for (final item in localItems) {
        try {
          final result =
              await _supabaseService.insertDailyCostItem(item.toMap());
          if (result != null) {
            _migratedItems++;
            setState(() {
              _progress = _migratedItems / _totalItems;
              _status += '✅ 日常消费品迁移成功（${item.itemName} ¥${item.totalPrice}）\n';
            });
          } else {
            setState(() {
              _status += '⚠️ 日常消费品迁移失败\n';
            });
          }
        } catch (e) {
          setState(() {
            _status += '❌ 日常消费品迁移错误: $e\n';
          });
        }
      }
    } catch (e) {
      setState(() {
        _status += '❌ 获取日常消费品数据失败: $e\n';
      });
    }
  }

  Future<void> _migrateFitnessRecords() async {
    setState(() {
      _status += '\n🏃 迁移健身记录...\n';
    });

    try {
      final records = await FitnessHelper.instance.getAllRecords();
      _totalItems += records.length;

      for (final record in records) {
        try {
          final result =
              await _supabaseService.insertFitnessRecord(record.toMap());
          if (result != null) {
            _migratedItems++;
            setState(() {
              _progress = _migratedItems / _totalItems;
              _status +=
                  '✅ 健身记录迁移成功（${record.courseName} ${record.durationMinutes} 分钟）\n';
            });
          } else {
            setState(() {
              _status += '⚠️ 健身记录迁移失败\n';
            });
          }
        } catch (e) {
          setState(() {
            _status += '❌ 健身记录迁移错误: $e\n';
          });
        }
      }
    } catch (e) {
      setState(() {
        _status += '❌ 获取健身记录失败: $e\n';
      });
    }
  }

  Future<void> _migrateConversationsAndMessages() async {
    setState(() {
      _status += '\n💬 迁移对话记录与聊天历史...\n';
    });

    try {
      final dbHelper = DatabaseHelper.instance;
      final chatHelper = ChatHistoryHelper.instance;
      final List<Conversation> conversations =
          await dbHelper.getAllConversations();
      _totalItems += conversations.length;

      for (final conversation in conversations) {
        try {
          final newConversationId =
              await _supabaseService.insertConversation(conversation);

          if (newConversationId != null) {
            _migratedItems++;
            setState(() {
              _progress = _migratedItems / _totalItems;
              _status += '✅ 对话 "${conversation.question.length > 20 ? conversation.question.substring(0, 20) + '...' : conversation.question}" 迁移成功\n';
            });

            final localConversationId = int.tryParse(conversation.id ?? '');
            if (localConversationId != null) {
              final messages = await chatHelper
                  .getMessagesByConversationId(localConversationId);
              if (messages.isNotEmpty) {
                setState(() {
                  _status += '   ↳ 正在同步 ${messages.length} 条聊天消息...\n';
                });
              }

              for (final chat_models.ChatMessage message in messages) {
                await _supabaseService.insertChatMessage(
                  conversationId: newConversationId,
                  text: message.text,
                  isUser: message.isUser,
                  createdAt: message.timestamp,
                );
              }
            } else {
              setState(() {
                _status += '   ⚠️ 无法识别本地聊天消息（ID: ${conversation.id ?? '未知'}）\n';
              });
            }
          } else {
            setState(() {
              _status += '⚠️ 对话 "${conversation.question}" 迁移失败\n';
            });
          }
        } catch (e) {
          setState(() {
            _status += '❌ 对话迁移错误: $e\n';
          });
        }
      }
    } catch (e) {
      setState(() {
        _status += '❌ 获取对话数据失败: $e\n';
      });
    }
  }

  Future<void> _migratePetDiaries() async {
    setState(() {
      _status += '\n📔 迁移宠物日记...\n';
    });

    try {
      final dbHelper = DatabaseHelper.instance;
      final diaries = await dbHelper.getAllDiaries();
      _totalItems += diaries.length;

      for (final PetDiary diary in diaries) {
        try {
          final result = await _supabaseService.insertDiary(diary);

          if (result != null) {
            _migratedItems++;
            setState(() {
              _progress = _migratedItems / _totalItems;
              _status += '✅ 日记（${diary.style}）迁移成功\n';
            });
          } else {
            setState(() {
              _status += '⚠️ 日记迁移失败\n';
            });
          }
        } catch (e) {
          setState(() {
            _status += '❌ 日记迁移错误: $e\n';
          });
        }
      }
    } catch (e) {
      setState(() {
        _status += '❌ 获取宠物日记失败: $e\n';
      });
    }
  }

  Future<void> _migratePetPassports() async {
    setState(() {
      _status += '\n🪪 迁移宠物护照...\n';
    });

    try {
      final passports = await PetPassportHelper.instance.getAllPassports();
      _totalItems += passports.length;

      for (final passport in passports) {
        try {
          final map = passport.toMap();
          final result = await _supabaseService.upsertPetPassport(map);
          if (result != null) {
            _migratedItems++;
            setState(() {
              _progress = _migratedItems / _totalItems;
              _status += '✅ 宠物护照迁移成功（pet_id=${passport.petId}）\n';
            });
          } else {
            setState(() {
              _status += '⚠️ 宠物护照迁移失败（pet_id=${passport.petId}）\n';
            });
          }
        } catch (e) {
          setState(() {
            _status += '❌ 宠物护照迁移错误（pet_id=${passport.petId}）: $e\n';
          });
        }
      }
    } catch (e) {
      setState(() {
        _status += '❌ 获取宠物护照失败: $e\n';
      });
    }
  }

  Future<void> _verifyMigration() async {
    setState(() {
      _status = '🔍 验证迁移结果...\n';
    });

    try {
      // 检查各种数据是否成功迁移
      final pets = await _supabaseService.getAllPets();
      final medicalRecords = await _supabaseService.getAllMedicalRecords();
      final weightRecords = await _supabaseService.getAllWeightRecords();
      final vaccineRecords = await _supabaseService.getAllVaccineRecords();
      final reminders = await _supabaseService.getAllDailyReminders();
      final unifiedExpenses = await _supabaseService.getAllUnifiedExpenses();
      final dailyCostItems = await _supabaseService.getAllDailyCostItems();
      final fitnessRecords = await _supabaseService.getAllFitnessRecords();
      final healthPlans = await _supabaseService.getAllHealthPlans();
      final conversations = await _supabaseService.getAllConversations();
      final diaries = await _supabaseService.getAllDiaries();

      setState(() {
        _status += '\n📊 迁移结果统计:\n';
        _status += '• 宠物: ${pets.length} 个\n';
        _status += '• 医疗记录: ${medicalRecords.length} 个\n';
        _status += '• 体重记录: ${weightRecords.length} 个\n';
        _status += '• 疫苗记录: ${vaccineRecords.length} 个\n';
        _status += '• 每日提醒: ${reminders.length} 个\n';
        _status += '• 统一消费记录: ${unifiedExpenses.length} 条\n';
        _status += '• 日常消费品记录: ${dailyCostItems.length} 条\n';
        _status += '• 健身记录: ${fitnessRecords.length} 条\n';
        _status += '• 健康计划: ${healthPlans.length} 条\n';
        _status += '• 对话记录: ${conversations.length} 条\n';
        _status += '• 宠物日记: ${diaries.length} 篇\n\n';

        if (pets.isNotEmpty || medicalRecords.isNotEmpty ||
            weightRecords.isNotEmpty || vaccineRecords.isNotEmpty ||
            reminders.isNotEmpty) {
          _status += '✅ 数据迁移验证成功！\n';
          _status += '您现在可以使用 Supabase 云数据库了。\n';
        } else {
          _status += '⚠️ 未找到迁移的数据，请检查迁移过程。\n';
        }
      });
    } catch (e) {
      setState(() {
        _status += '❌ 验证失败: $e\n';
      });
    }
  }
}