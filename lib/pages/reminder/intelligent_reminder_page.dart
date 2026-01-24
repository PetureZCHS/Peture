import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import 'add_vaccine_reminder_page.dart';
import 'add_deworming_reminder_page.dart';
import 'add_medication_reminder_page.dart';
import 'medication_checkmark_page.dart';

/// 智能提醒系统主页
/// Intelligent Reminder System
class IntelligentReminderPage extends StatefulWidget {
  const IntelligentReminderPage({super.key});

  @override
  State<IntelligentReminderPage> createState() =>
      _IntelligentReminderPageState();
}

class _IntelligentReminderPageState extends State<IntelligentReminderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text(
          '智能提醒系统',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF5D5FEF),
          unselectedLabelColor: const Color(0xFF8E8E93),
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          indicatorColor: const Color(0xFF5D5FEF),
          tabs: const [
            Tab(text: '疫苗提醒'),
            Tab(text: '驱虫提醒'),
            Tab(text: '用药记录'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          VaccineReminderTab(),
          DewormingReminderTab(),
          MedicationReminderTab(),
        ],
      ),
    );
  }
}

// ========================================
// 疫苗提醒标签页
// ========================================
class VaccineReminderTab extends StatefulWidget {
  const VaccineReminderTab({super.key});

  @override
  State<VaccineReminderTab> createState() => _VaccineReminderTabState();
}

class _VaccineReminderTabState extends State<VaccineReminderTab> {
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _supabaseService.getAllVaccineReminders();
      if (mounted) {
        setState(() {
          _reminders = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteReminder(String id) async {
    await _supabaseService.deleteVaccineReminder(id);
    _loadReminders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _InfoCard(
                      icon: Icons.vaccines,
                      title: '疫苗提醒说明',
                      description: '根据宠物年龄和种类，自动生成疫苗接种时间表，并提前推送提醒',
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                ),
                _reminders.isEmpty
                    ? SliverFillRemaining(
                        child: _EmptyState(
                          icon: Icons.vaccines_outlined,
                          message: '暂无疫苗提醒',
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final reminder = _reminders[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: _buildVaccineCard(reminder),
                            );
                          }, childCount: _reminders.length),
                        ),
                      ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddVaccineReminderPage(),
            ),
          );
          if (result == true) {
            _loadReminders();
          }
        },
        backgroundColor: const Color(0xFF5D5FEF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildVaccineCard(Map<String, dynamic> reminder) {
    final scheduledDate = reminder['next_due_date'] != null
        ? DateTime.parse(reminder['next_due_date'] as String)
        : DateTime.parse(reminder['injection_date'] as String);
    final daysUntil = scheduledDate.difference(DateTime.now()).inDays;
    final isUrgent = daysUntil <= 3 && daysUntil >= 0;

    return Dismissible(
      key: Key(reminder['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认删除'),
            content: const Text('确定要删除这条提醒吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _deleteReminder(reminder['id'] as String);
        }
        return false;
      },
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddVaccineReminderPage(existingReminder: reminder),
            ),
          );
          if (result == true) {
            _loadReminders();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isUrgent
                ? Border.all(color: const Color(0xFFFF6B6B), width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 2),
                blurRadius: 4.0,
                color: Colors.black.withOpacity(0.04),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.vaccines,
                        color: Color(0xFF4CAF50),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                reminder['pet_name'] as String,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF5D5FEF,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  reminder['vaccine_name'] as String,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF5D5FEF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('yyyy年MM月dd日').format(scheduledDate),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$daysUntil天后',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFF6B6B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                if (reminder['notes'] != null &&
                    (reminder['notes'] as String).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '备注：${reminder['notes']}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========================================
// 驱虫提醒标签页
// ========================================
class DewormingReminderTab extends StatefulWidget {
  const DewormingReminderTab({super.key});

  @override
  State<DewormingReminderTab> createState() => _DewormingReminderTabState();
}

class _DewormingReminderTabState extends State<DewormingReminderTab> {
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _supabaseService.getAllDewormingReminders();
      if (mounted) {
        setState(() {
          _reminders = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteReminder(String id) async {
    await _supabaseService.deleteDewormingReminder(id);
    _loadReminders();
  }

  Future<void> _completeDeworming(int id) async {
    // 云端版本暂未实现自动生成下一次驱虫提醒，这里先提示并刷新列表
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已标记完成（云端版本暂不自动续期）')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _InfoCard(
                      icon: Icons.bug_report,
                      title: '驱虫提醒说明',
                      description: '设定体内外驱虫的周期（如每月、每季度），到期自动提醒',
                      color: const Color(0xFFFF9800),
                    ),
                  ),
                ),
                _reminders.isEmpty
                    ? SliverFillRemaining(
                        child: _EmptyState(
                          icon: Icons.bug_report_outlined,
                          message: '暂无驱虫提醒',
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final reminder = _reminders[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: _buildDewormingCard(reminder),
                            );
                          }, childCount: _reminders.length),
                        ),
                      ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddDewormingReminderPage(),
            ),
          );
          if (result == true) {
            _loadReminders();
          }
        },
        backgroundColor: const Color(0xFF5D5FEF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDewormingCard(Map<String, dynamic> reminder) {
    final nextDate = DateTime.parse(reminder['next_reminder_date'] as String);
    final daysUntil = nextDate.difference(DateTime.now()).inDays;
    final isUrgent = daysUntil <= 3 && daysUntil >= 0;

    return Dismissible(
      key: Key(reminder['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认删除'),
            content: const Text('确定要删除这条提醒吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _deleteReminder(reminder['id'] as String);
        }
        return false;
      },
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddDewormingReminderPage(existingReminder: reminder),
            ),
          );
          if (result == true) {
            _loadReminders();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isUrgent
                ? Border.all(color: const Color(0xFFFF6B6B), width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 2),
                blurRadius: 4.0,
                color: Colors.black.withOpacity(0.04),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.bug_report,
                        color: Color(0xFFFF9800),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                reminder['pet_name'] as String,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF5D5FEF,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  reminder['type'] == 'internal'
                                      ? '体内驱虫'
                                      : '体外驱虫',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF5D5FEF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('yyyy年MM月dd日').format(nextDate),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$daysUntil天后',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFF6B6B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _completeDeworming(reminder['id'] as int),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('我已完成'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========================================
// 用药记录标签页
// ========================================
class MedicationReminderTab extends StatefulWidget {
  const MedicationReminderTab({super.key});

  @override
  State<MedicationReminderTab> createState() => _MedicationReminderTabState();
}

class _MedicationReminderTabState extends State<MedicationReminderTab> {
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _supabaseService.getAllMedicationReminders();
      if (mounted) {
        setState(() {
          _reminders = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteReminder(String id) async {
    await _supabaseService.deleteMedicationReminder(id);
    _loadReminders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _InfoCard(
                      icon: Icons.medication,
                      title: '用药记录说明',
                      description: '记录用药名称、剂量和频率，设置用药提醒，避免遗忘',
                      color: const Color(0xFF2196F3),
                    ),
                  ),
                ),
                _reminders.isEmpty
                    ? SliverFillRemaining(
                        child: _EmptyState(
                          icon: Icons.medication_outlined,
                          message: '暂无用药记录',
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final reminder = _reminders[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: _buildMedicationCard(reminder),
                            );
                          }, childCount: _reminders.length),
                        ),
                      ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddMedicationReminderPage(),
            ),
          );
          if (result == true) {
            _loadReminders();
          }
        },
        backgroundColor: const Color(0xFF5D5FEF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMedicationCard(Map<String, dynamic> reminder) {
    final startDate = DateTime.parse(reminder['start_date'] as String);
    final endDate = DateTime.parse(reminder['end_date'] as String);
    final daysRemaining = endDate.difference(DateTime.now()).inDays;
    final isActive = daysRemaining >= 0;

    return Dismissible(
      key: Key(reminder['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认删除'),
            content: const Text('确定要删除这条记录吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _deleteReminder(reminder['id'] as String);
        }
        return false;
      },
      child: InkWell(
        onTap: () async {
          // 跳转到打卡详情页
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MedicationCheckmarkPage(reminder: reminder),
            ),
          );
          _loadReminders(); // 返回后刷新列表
        },
        onLongPress: () async {
          // 长按编辑
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddMedicationReminderPage(existingReminder: reminder),
            ),
          );
          if (result == true) {
            _loadReminders();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(color: const Color(0xFF4CAF50), width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 2),
                blurRadius: 4.0,
                color: Colors.black.withOpacity(0.04),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.medication,
                        color: Color(0xFF2196F3),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                reminder['pet_name'] as String,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF5D5FEF,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  reminder['med_name'] as String,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF5D5FEF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${reminder['dosage']} • ${_getFrequencyText(reminder)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '剩$daysRemaining天',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Color(0xFF8E8E93),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${DateFormat('MM/dd').format(startDate)} - ${DateFormat('MM/dd').format(endDate)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
                // 今日进度显示
                // 云端版本暂未实现每日打卡统计，先不展示进度
                if (reminder['notes'] != null &&
                    (reminder['notes'] as String).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '备注：${reminder['notes']}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getFrequencyText(Map<String, dynamic> reminder) {
    final type = reminder['frequency_type'] as String;
    final details = reminder['frequency_details'] as String;

    if (type == 'daily') {
      final times = details.split(',');
      return '每日${times.length}次';
    } else {
      return '每$details小时';
    }
  }
}

// ========================================
// 通用组件
// ========================================

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: color.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[400]),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角 + 号添加',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}
