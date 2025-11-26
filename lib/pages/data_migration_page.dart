import 'package:flutter/material.dart';
import '../database/medical_record_helper.dart';
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
                      '• 每日提醒\n\n'
                      '⚠️ 请确保网络连接正常，迁移过程中请勿关闭应用。',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 进度条
            LinearProgressIndicator(
              value: _isMigrating ? _progress : null,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
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

      setState(() {
        _status += '\n📊 迁移结果统计:\n';
        _status += '• 宠物: ${pets.length} 个\n';
        _status += '• 医疗记录: ${medicalRecords.length} 个\n';
        _status += '• 体重记录: ${weightRecords.length} 个\n';
        _status += '• 疫苗记录: ${vaccineRecords.length} 个\n';
        _status += '• 每日提醒: ${reminders.length} 个\n\n';

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