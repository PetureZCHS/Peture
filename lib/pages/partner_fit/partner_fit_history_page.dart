import 'package:flutter/material.dart';
import '../../models/fitness_course.dart';
import '../../database/fitness_helper.dart';

/// 训练历史记录页面
class PartnerFitHistoryPage extends StatefulWidget {
  const PartnerFitHistoryPage({super.key});

  @override
  State<PartnerFitHistoryPage> createState() => _PartnerFitHistoryPageState();
}

class _PartnerFitHistoryPageState extends State<PartnerFitHistoryPage> {
  List<FitnessRecord> records = [];
  Map<String, int> stats = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    final loadedRecords = await FitnessHelper.instance.getAllRecords();
    final loadedStats = await FitnessHelper.instance.getTotalStats();

    setState(() {
      records = loadedRecords;
      stats = loadedStats;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8F8),
        foregroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : records.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                // 统计卡片
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '总体成就',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatColumn(
                            icon: Icons.fitness_center,
                            value: '${stats['totalWorkouts'] ?? 0}',
                            label: '次训练',
                          ),
                          _buildStatColumn(
                            icon: Icons.local_fire_department,
                            value: '${stats['totalCalories'] ?? 0}',
                            label: '总卡路里',
                          ),
                          _buildStatColumn(
                            icon: Icons.timer,
                            value: '${stats['totalMinutes'] ?? 0}',
                            label: '总分钟',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 记录列表标题
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '历史记录',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${records.length} 次',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                // 记录列表
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      return _buildRecordCard(records[index]);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '还没有训练记录',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '开始你的第一次人宠健身吧！',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildRecordCard(FitnessRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.check_circle, color: Colors.white, size: 28),
        ),
        title: Text(
          record.courseName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              _formatDateTime(record.completedAt),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 14,
                  color: Colors.orange[700],
                ),
                const SizedBox(width: 4),
                Text(
                  '${record.caloriesBurned} 大卡',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.timer, size: 14, color: Color(0xFF5A8EFA)),
                const SizedBox(width: 4),
                Text(
                  '${record.durationMinutes} 分钟',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _deleteRecord(record),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '今天 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '昨天 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _deleteRecord(FitnessRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条训练记录吗？'),
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

    if (confirmed == true && record.id != null) {
      await FitnessHelper.instance.deleteRecord(record.id!);
      _loadData(); // 重新加载数据
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已删除训练记录')));
      }
    }
  }
}
