import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 用药打卡详情页
/// 显示某个用药记录的每日打卡清单
class MedicationCheckmarkPage extends StatefulWidget {
  final Map<String, dynamic> reminder;

  const MedicationCheckmarkPage({super.key, required this.reminder});

  @override
  State<MedicationCheckmarkPage> createState() =>
      _MedicationCheckmarkPageState();
}

class _MedicationCheckmarkPageState extends State<MedicationCheckmarkPage> {
  List<Map<String, dynamic>> _checkmarks = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  // 预留后续云端打卡实现，目前未使用

  @override
  void initState() {
    super.initState();
    _loadCheckmarks();
  }

  Future<void> _loadCheckmarks() async {
    // 云端暂未存储打卡明细，这里仅展示提醒概览
    setState(() {
      _isLoading = false;
      _checkmarks = [];
    });
  }

  /// 切换打卡状态
  Future<void> _toggleCheckmark(Map<String, dynamic> checkmark) async {
    // 云端未实现打卡明细，暂不操作
  }

  /// 切换日期
  Future<void> _selectDate() async {
    final startDate = DateTime.parse(widget.reminder['start_date'] as String);
    final endDate = DateTime.parse(widget.reminder['end_date'] as String);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: startDate,
      lastDate: endDate,
      locale: const Locale('zh', 'CN'),
      helpText: '选择日期',
      confirmText: '确定',
      cancelText: '取消',
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadCheckmarks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedCount =
        _checkmarks.where((c) => c['is_completed'] == 1).length;
    final totalCount = _checkmarks.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text('${widget.reminder['pet_name']} - 用药打卡'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 头部信息卡片
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.medication,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.reminder['med_name'] as String,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.reminder['dosage'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 日期选择器
                  InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedDate.day == DateTime.now().day &&
                                        _selectedDate.month ==
                                            DateTime.now().month
                                    ? '今天 ${DateFormat('MM月dd日').format(_selectedDate)}'
                                    : DateFormat(
                                        'yyyy年MM月dd日',
                                      ).format(_selectedDate),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 进度显示
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$completedCount/$totalCount',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '已完成',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${((completedCount / (totalCount > 0 ? totalCount : 1)) * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '完成率',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 打卡清单
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _checkmarks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '该日期无用药任务',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _checkmarks.length,
                        itemBuilder: (context, index) {
                          final checkmark = _checkmarks[index];
                          return _buildCheckmarkItem(checkmark, index);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckmarkItem(Map<String, dynamic> checkmark, int index) {
    final isCompleted = checkmark['is_completed'] == 1;
    final checkTime = checkmark['check_time'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () => _toggleCheckmark(checkmark),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCompleted
                  ? const Color(0xFF4CAF50)
                  : Colors.grey.withOpacity(0.2),
              width: isCompleted ? 2 : 1,
            ),
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
            child: Row(
              children: [
                // 复选框
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF4CAF50)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF4CAF50)
                          : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(width: 16),

                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '第 ${index + 1} 次',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isCompleted
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF1A1A1A),
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              checkTime,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2196F3),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isCompleted) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '已完成',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // 状态指示器
                Icon(
                  isCompleted ? Icons.check_circle : Icons.circle_outlined,
                  color:
                      isCompleted ? const Color(0xFF4CAF50) : Colors.grey[400],
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
