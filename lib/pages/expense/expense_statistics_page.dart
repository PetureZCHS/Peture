import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/expense.dart';
import '../../services/supabase_service.dart';

/// 统计分析页面
class ExpenseStatisticsPage extends StatefulWidget {
  const ExpenseStatisticsPage({super.key});

  @override
  State<ExpenseStatisticsPage> createState() => _ExpenseStatisticsPageState();
}

class _ExpenseStatisticsPageState extends State<ExpenseStatisticsPage> {
  final SupabaseService _supabaseService = SupabaseService();
  String _selectedPeriod = 'month'; // 'month' 或 'year'
  Map<String, double> _statistics = {};
  double _totalAmount = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  /// 加载统计数据
  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 优先从 Supabase 加载
      final expensesData = await _supabaseService.getAllExpenses();
      final expenses = expensesData.map((e) => Expense.fromMap(e)).toList();

      final now = DateTime.now();
      DateTime startDate, endDate;

      if (_selectedPeriod == 'month') {
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0);
      } else {
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31);
      }

      // 前端计算分类统计
      Map<String, double> statistics = {};
      double total = 0.0;

      for (final expense in expenses) {
        final expenseDate = DateTime.parse(expense.date);
        if (expenseDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
            expenseDate.isBefore(endDate.add(const Duration(days: 1)))) {
          statistics[expense.category] =
              (statistics[expense.category] ?? 0.0) + expense.amount;
          total += expense.amount;
        }
      }

      if (mounted) {
        setState(() {
          _statistics = statistics;
          _totalAmount = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text(
          '统计分析',
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20.0),
              children: [
                // 时间筛选
                _buildPeriodSelector(),
                const SizedBox(height: 24),

                // 总支出卡片
                _buildTotalCard(),
                const SizedBox(height: 24),

                // 饼状图
                if (_statistics.isNotEmpty) ...[
                  _buildPieChart(),
                  const SizedBox(height: 24),

                  // 分类排行榜
                  _buildCategoryRanking(),
                ],

                if (_statistics.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.pie_chart_outline,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '当前时间段暂无数据',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  /// 时间筛选器
  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 2),
            blurRadius: 4.0,
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPeriod = 'month';
                  });
                  _loadStatistics();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedPeriod == 'month'
                        ? const Color(0xFF5D5FEF)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '本月',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _selectedPeriod == 'month'
                          ? Colors.white
                          : const Color(0xFF8E8E93),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPeriod = 'year';
                  });
                  _loadStatistics();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedPeriod == 'year'
                        ? const Color(0xFF5D5FEF)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '本年',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _selectedPeriod == 'year'
                          ? Colors.white
                          : const Color(0xFF8E8E93),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 总支出卡片
  Widget _buildTotalCard() {
    final now = DateTime.now();
    final title =
        _selectedPeriod == 'month' ? '${now.month}月总支出' : '${now.year}年总支出';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 12.0,
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '¥${_totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 饼状图
  Widget _buildPieChart() {
    final sortedEntries = _statistics.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 2),
            blurRadius: 4.0,
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '支出分布',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 60,
                  sections: _buildPieSections(sortedEntries),
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 图例
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: sortedEntries.map((entry) {
                final category = ExpenseCategory.getCategoryByName(entry.key);
                final color =
                    category != null ? Color(category.color) : Colors.grey;
                final percentage = (_totalAmount > 0)
                    ? (entry.value / _totalAmount * 100)
                    : 0.0;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.key} ${percentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建饼图分区
  List<PieChartSectionData> _buildPieSections(
    List<MapEntry<String, double>> sortedEntries,
  ) {
    return sortedEntries.map((categoryEntry) {
      final category = ExpenseCategory.getCategoryByName(categoryEntry.key);
      final color = category != null ? Color(category.color) : Colors.grey;

      return PieChartSectionData(
        color: color,
        value: categoryEntry.value,
        title: '',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  /// 分类排行榜
  Widget _buildCategoryRanking() {
    final sortedEntries = _statistics.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 2),
            blurRadius: 4.0,
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '消费排行',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            ...sortedEntries.asMap().entries.map((entry) {
              final index = entry.key;
              final categoryEntry = entry.value;
              final category = ExpenseCategory.getCategoryByName(
                categoryEntry.key,
              );
              final iconData = category != null
                  ? IconData(category.icon, fontFamily: 'MaterialIcons')
                  : Icons.more_horiz;
              final color =
                  category != null ? Color(category.color) : Colors.grey;
              final percentage = (_totalAmount > 0)
                  ? (categoryEntry.value / _totalAmount * 100)
                  : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // 排名
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: index < 3
                                ? const Color(0xFF5D5FEF).withOpacity(0.15)
                                : const Color(0xFFF5F5F7),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: index < 3
                                    ? const Color(0xFF5D5FEF)
                                    : const Color(0xFF8E8E93),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 分类图标
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(iconData, color: color, size: 22),
                        ),
                        const SizedBox(width: 12),

                        // 分类名称
                        Expanded(
                          child: Text(
                            categoryEntry.key,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),

                        // 金额和百分比
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '¥${categoryEntry.value.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 进度条
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: const Color(0xFFF5F5F7),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
