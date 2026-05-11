import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/expense.dart';
import '../../../services/supabase_service.dart';
import 'add_expense_page.dart';
import 'expense_statistics_page.dart';

/// 宠物记账主页
class ExpenseHomePage extends StatefulWidget {
  const ExpenseHomePage({super.key});

  @override
  State<ExpenseHomePage> createState() => _ExpenseHomePageState();
}

class _ExpenseHomePageState extends State<ExpenseHomePage> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Expense> _expenses = [];
  Map<String, List<Expense>> _groupedExpenses = {};
  double _monthlyTotal = 0.0;
  bool _isLoading = true;

  // 模拟的时间选择和账本选择
  final String _currentDateRange = '本月';
  final String _currentLedger = '我的账本';

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  /// 加载账单数据
  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 优先从 Supabase 加载 (Develop 分支的逻辑)
      final expensesData = await _supabaseService.getAllExpenses();
      final expenses = expensesData.map((e) => Expense.fromMap(e)).toList();

      final now = DateTime.now();
      double monthlyTotal = 0.0;

      // 手动计算月度总支出 (替代 ExpenseHelper 的本地计算)
      for (final expense in expenses) {
        final expenseDate = DateTime.parse(expense.date);
        if (expenseDate.year == now.year && expenseDate.month == now.month) {
          monthlyTotal += expense.amount;
        }
      }

      // 按日期分组 (Feature 分支的 UI 需要)
      final Map<String, List<Expense>> grouped = {};
      for (var expense in expenses) {
        if (!grouped.containsKey(expense.date)) {
          grouped[expense.date] = [];
        }
        grouped[expense.date]!.add(expense);
      }

      if (mounted) {
        setState(() {
          _expenses = expenses;
          _groupedExpenses = grouped;
          _monthlyTotal = monthlyTotal;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  /// 删除账单
  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除这笔 ¥${expense.amount.toStringAsFixed(2)} 的账单吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && expense.id != null) {
      // 使用 SupabaseService 删除 (Develop 分支的逻辑)
      await _supabaseService.deleteExpense(expense.id!);
      _loadExpenses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('账单已删除')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 使用 Feature 分支的 UI 结构
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA), // 浅灰色背景
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA), // 与背景色一致
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '收支',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFF1A1A1A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF1A1A1A)),
            onPressed: () {
              // 搜索功能预留
            },
          ),
          IconButton(
            icon: const Icon(Icons.pie_chart_outline, color: Color(0xFF1A1A1A)),
            tooltip: '统计分析',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExpenseStatisticsPage(),
                ),
              ).then((_) => _loadExpenses());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadExpenses,
              child: CustomScrollView(
                slivers: [
                  // 顶部摘要区域
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 10.0),
                      child: Column(
                        children: [
                          _buildFilterRow(),
                          const SizedBox(height: 20),
                          _buildSummaryCard(),
                          const SizedBox(height: 24),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '近期账单',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  // 账单列表
                  _expenses.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.pets,
                                  size: 60,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '还没有宠物消费记录',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final sortedDates = _groupedExpenses.keys
                                    .toList()
                                  ..sort((a, b) => b.compareTo(a));
                                final date = sortedDates[index];
                                final expensesForDate = _groupedExpenses[date]!;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 20.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 日期头
                                      _buildDateHeader(date, expensesForDate),
                                      const SizedBox(height: 12),
                                      // 交易列表
                                      ...expensesForDate
                                          .map((expense) => Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 12.0),
                                                child:
                                                    _buildExpenseCard(expense),
                                              )),
                                    ],
                                  ),
                                );
                              },
                              childCount: _groupedExpenses.length,
                            ),
                          ),
                        ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5D5FEF).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddExpensePage()),
            );
            if (result == true) {
              _loadExpenses();
            }
          },
          backgroundColor: const Color(0xFF5D5FEF),
          elevation: 0,
          child: const Icon(Icons.add, size: 30),
        ),
      ),
    );
  }

  // 顶部筛选行：我的账本 | 1月4日-1月10日
  Widget _buildFilterRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Text(
                _currentLedger,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down,
                  size: 16, color: Color(0xFF1A1A1A)),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Color(0xFF8E8E93)),
              onPressed: () {},
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                _currentDateRange,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Color(0xFF8E8E93)),
              onPressed: () {},
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建顶部汇总卡片 (Feature 分支样式)
  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '当月支出', // 或 '本周支出'
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                Icon(Icons.remove_red_eye_outlined,
                    color: Colors.grey[400], size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '¥${_monthlyTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildSummaryItem(
                  icon: Icons.south_west,
                  iconColor:
                      const Color(0xFF4cd964), // Green for income (placeholder)
                  label: '预算剩余',
                  amount: '¥0.00', // 示例数据
                ),
                const SizedBox(width: 16),
                _buildSummaryItem(
                  icon: Icons.north_east,
                  iconColor: const Color(0xFFFF3B30),
                  label: '日均支出',
                  amount:
                      '¥${(_monthlyTotal / DateTime.now().day).toStringAsFixed(2)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String amount,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 12, color: iconColor),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(String dateStr, List<Expense> expenses) {
    if (expenses.isEmpty) return const SizedBox.shrink();

    final date = DateTime.parse(dateStr);
    final now = DateTime.now();

    String weekday = '';
    switch (date.weekday) {
      case 1:
        weekday = '周一';
        break;
      case 2:
        weekday = '周二';
        break;
      case 3:
        weekday = '周三';
        break;
      case 4:
        weekday = '周四';
        break;
      case 5:
        weekday = '周五';
        break;
      case 6:
        weekday = '周六';
        break;
      case 7:
        weekday = '周日';
        break;
    }

    String formattedDate;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      formattedDate = '今天';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      formattedDate = '昨天';
    } else {
      formattedDate = DateFormat('M月d日').format(date);
    }

    double total = expenses.fold(0, (sum, item) => sum + item.amount);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              formattedDate,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              weekday,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
        Text(
          '支: ¥${total.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF8E8E93),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 构建单个账单卡片 (Feature 分支样式)
  Widget _buildExpenseCard(Expense expense) {
    final category = ExpenseCategory.getCategoryByName(expense.category);
    // 使用 Material Icons
    final iconData = category != null
        ? IconData(category.icon, fontFamily: 'MaterialIcons')
        : Icons.more_horiz;

    // 如果找不到分类（可能是旧数据），使用默认颜色
    final color = category != null ? Color(category.color) : Colors.grey;

    return Dismissible(
      key: Key(expense.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B30),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        await _deleteExpense(expense);
        return false;
      },
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddExpensePage(expense: expense),
            ),
          );
          if (result == true) {
            _loadExpenses();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            // 不使用阴影，更扁平化，符合现代风格
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 分类图标
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA), // 浅灰色背景
                    borderRadius: BorderRadius.circular(16), // 圆角方形
                  ),
                  child: Center(
                    // 确保图标居中
                    child: Icon(iconData, color: color, size: 26),
                  ),
                ),
                const SizedBox(width: 16),

                // 详情
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        expense.category.isEmpty ? '其他' : expense.category,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (expense.note != null && expense.note!.isNotEmpty)
                        Text(
                          expense.note!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8E8E93),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else if (expense.petName != null)
                        Text(
                          expense.petName!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8E8E93),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),

                // 金额和时间
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '-¥${expense.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF3B30), // 红色表示支出
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm').format(DateTime.parse(expense.date)),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFC7C7CC),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
