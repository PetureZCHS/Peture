import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/unified_expense.dart';
import '../../database/unified_expense_helper.dart';
import 'add_unified_expense_page.dart';

/// 统一的宠物消费主页（带标签页）
class UnifiedExpenseHomePage extends StatefulWidget {
  const UnifiedExpenseHomePage({super.key});

  @override
  State<UnifiedExpenseHomePage> createState() => _UnifiedExpenseHomePageState();
}

class _UnifiedExpenseHomePageState extends State<UnifiedExpenseHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<UnifiedExpense> _recurringExpenses = [];
  List<UnifiedExpense> _allExpenses = [];
  double _totalDailyCost = 0.0;
  double _monthlyTotal = 0.0;
  double _yearlyTotal = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 加载数据
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final recurring = await UnifiedExpenseHelper.instance
          .getRecurringExpenses();
      final all = await UnifiedExpenseHelper.instance.getAllExpenses();
      final dailyCost = await UnifiedExpenseHelper.instance.getTotalDailyCost();

      final now = DateTime.now();
      final monthlyTotal = await UnifiedExpenseHelper.instance.getMonthlyTotal(
        now.year,
        now.month,
      );
      final yearlyTotal = await UnifiedExpenseHelper.instance.getYearlyTotal(
        now.year,
      );

      if (mounted) {
        setState(() {
          _recurringExpenses = recurring;
          _allExpenses = all;
          _totalDailyCost = dailyCost;
          _monthlyTotal = monthlyTotal;
          _yearlyTotal = yearlyTotal;
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

  /// 删除消费记录
  Future<void> _deleteExpense(UnifiedExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除这笔 ¥${expense.amount.toStringAsFixed(2)} 的记录吗？'),
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
      await UnifiedExpenseHelper.instance.deleteExpense(expense.id!);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已删除')));
      }
    }
  }

  /// 标记商品为已用完
  Future<void> _markAsFinished(UnifiedExpense expense) async {
    final startDate = DateTime.parse(expense.date);
    final today = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: startDate, // 不能早于开始使用日期
      lastDate: today.add(const Duration(days: 365)), // 允许选择未来一年内的日期
      locale: const Locale('zh', 'CN'),
      helpText: '选择用完日期',
      confirmText: '确定',
      cancelText: '取消',
    );

    if (picked != null && expense.id != null) {
      final updatedExpense = expense.copyWith(
        estimatedEndDate: DateFormat('yyyy-MM-dd').format(picked),
      );

      await UnifiedExpenseHelper.instance.updateExpense(updatedExpense);
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已标记为用完，最终日均成本：¥${updatedExpense.dailyCost.toStringAsFixed(2)}',
            ),
          ),
        );
      }
    }
  }

  /// 取消用完标记（恢复到使用中状态）
  /// 撤销"已用完"状态，改回"使用中"
  Future<void> _undoFinished(UnifiedExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤销标记'),
        content: const Text('确定要将此物品改回"使用中"状态吗？日均成本将继续动态计算。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF5D5FEF),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true && expense.id != null) {
      // 使用 copyWith 清除 estimatedEndDate
      final updatedExpense = expense.copyWith(
        clearEstimatedEndDate: true, // 标记需要清除此字段
      );

      await UnifiedExpenseHelper.instance.updateExpense(updatedExpense);
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已改回使用中，日均成本将动态更新')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text(
          '宠物消费',
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
          indicatorColor: const Color(0xFF5D5FEF),
          labelColor: const Color(0xFF5D5FEF),
          unselectedLabelColor: const Color(0xFF8E8E93),
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: '支出流水'),
            Tab(text: '成本追踪'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildExpenseFlowTab(), _buildRecurringCostTab()],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddUnifiedExpensePage(),
            ),
          );
          if (result == true) {
            _loadData();
          }
        },
        backgroundColor: const Color(0xFF5D5FEF),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  /// 成本追踪标签页
  Widget _buildRecurringCostTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          // 顶部总日均成本卡片
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildTotalDailyCostCard(),
            ),
          ),

          // 周期性支出列表标题
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '周期性支出',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    '共 ${_recurringExpenses.length} 项',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // 周期性成本列表
          _recurringExpenses.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.trending_up_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '还没有周期性支出记录',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击 + 号添加主粮、用品等周期性支出',
                          style: TextStyle(
                            fontSize: 14,
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
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final expense = _recurringExpenses[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildRecurringCostCard(expense),
                      );
                    }, childCount: _recurringExpenses.length),
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  /// 支出流水标签页
  Widget _buildExpenseFlowTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          // 顶部汇总卡片
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildExpenseSummaryCard(),
            ),
          ),

          // 支出流水列表标题
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '支出流水',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    '共 ${_allExpenses.length} 笔',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // 支出流水列表
          _allExpenses.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '还没有支出记录',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击 + 号添加第一笔支出',
                          style: TextStyle(
                            fontSize: 14,
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
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final expense = _allExpenses[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildExpenseFlowCard(expense),
                      );
                    }, childCount: _allExpenses.length),
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  /// 总日均成本卡片
  Widget _buildTotalDailyCostCard() {
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '总日均成本',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '¥${_totalDailyCost.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '每天平均花费 • 共 ${_recurringExpenses.length} 项周期性支出',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  /// 支出汇总卡片
  Widget _buildExpenseSummaryCard() {
    final now = DateTime.now();
    final monthName = DateFormat('M月', 'zh_CN').format(now);
    final year = now.year;

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
            const Text(
              '支出概览',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$monthName支出',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '¥${_monthlyTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.white24),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$year年支出',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '¥${_yearlyTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 周期性成本卡片
  Widget _buildRecurringCostCard(UnifiedExpense expense) {
    final purchaseDate = DateTime.parse(expense.date);
    final purchaseDateStr = DateFormat('yyyy/MM/dd').format(purchaseDate);

    String endDateStr = '使用中';
    bool isInUse = expense.isInUse;

    if (expense.estimatedEndDate != null) {
      final endDate = DateTime.parse(expense.estimatedEndDate!);
      endDateStr = DateFormat('yyyy/MM/dd').format(endDate);
    }

    final category = UnifiedExpenseCategory.getCategoryByName(expense.category);
    final iconData = category != null
        ? IconData(category.icon, fontFamily: 'MaterialIcons')
        : Icons.more_horiz;
    final color = category != null ? Color(category.color) : Colors.grey;

    return Dismissible(
      key: Key(expense.id.toString()),
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
        await _deleteExpense(expense);
        return false;
      },
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddUnifiedExpensePage(expense: expense),
            ),
          );
          if (result == true) {
            _loadData();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 第一行：物品名称和状态标签
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(iconData, color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  expense.itemName ?? expense.category,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 状态标签
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isInUse
                                      ? const Color(
                                          0xFF4CAF50,
                                        ).withOpacity(0.15)
                                      : const Color(
                                          0xFF9E9E9E,
                                        ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isInUse ? '使用中' : '已用完',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isInUse
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFF9E9E9E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            expense.category,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (expense.petName != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5D5FEF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.pets,
                              size: 14,
                              color: Color(0xFF5D5FEF),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              expense.petName!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF5D5FEF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // 第二行：价格和日期信息
                Row(
                  children: [
                    // 总价格
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '总价格',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '¥${expense.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 使用天数
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '使用天数',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${expense.usageDays} 天',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 日均成本（突出显示）
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            '日均成本',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFFF6B6B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '¥${expense.dailyCost.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF6B6B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 第三行：日期信息
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Color(0xFF8E8E93),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        purchaseDateStr,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: Color(0xFF8E8E93),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        endDateStr,
                        style: TextStyle(
                          fontSize: 13,
                          color: isInUse
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF8E8E93),
                          fontWeight: isInUse
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),

                // 第四行：操作按钮
                // 使用中：显示"标记用完"按钮
                // 已用完：显示"撤销"按钮
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => isInUse
                      ? _markAsFinished(expense)
                      : _undoFinished(expense),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isInUse
                          ? const Color(0xFF5D5FEF).withOpacity(0.1)
                          : const Color(0xFFFF9800).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isInUse
                            ? const Color(0xFF5D5FEF)
                            : const Color(0xFFFF9800),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isInUse ? Icons.check_circle_outline : Icons.replay,
                          size: 18,
                          color: isInUse
                              ? const Color(0xFF5D5FEF)
                              : const Color(0xFFFF9800),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isInUse ? '标记用完' : '撤销标记',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isInUse
                                ? const Color(0xFF5D5FEF)
                                : const Color(0xFFFF9800),
                          ),
                        ),
                      ],
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

  /// 支出流水卡片
  Widget _buildExpenseFlowCard(UnifiedExpense expense) {
    final category = UnifiedExpenseCategory.getCategoryByName(expense.category);
    final iconData = category != null
        ? IconData(category.icon, fontFamily: 'MaterialIcons')
        : Icons.more_horiz;
    final color = category != null ? Color(category.color) : Colors.grey;

    final date = DateTime.parse(expense.date);
    final dateStr = DateFormat('MM月dd日', 'zh_CN').format(date);

    return Dismissible(
      key: Key('flow_${expense.id}'),
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
        await _deleteExpense(expense);
        return false;
      },
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddUnifiedExpensePage(expense: expense),
            ),
          );
          if (result == true) {
            _loadData();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 分类图标
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, color: color, size: 26),
                ),
                const SizedBox(width: 16),

                // 分类名称和详情（双行布局）
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 第一行：分类名称（完整显示）
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              expense.category,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 金额（右对齐）
                          Text(
                            '¥${expense.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 第二行：标签 + 日期 + 备注
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // 周期性/一次性标签
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: expense.isRecurring
                                  ? const Color(0xFFFF6B6B).withOpacity(0.1)
                                  : const Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              expense.isRecurring ? '周期性' : '一次性',
                              style: TextStyle(
                                fontSize: 11,
                                color: expense.isRecurring
                                    ? const Color(0xFFFF6B6B)
                                    : const Color(0xFF4CAF50),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          // 宠物名标签
                          if (expense.petName != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF5D5FEF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                expense.petName!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF5D5FEF),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                          // 日期
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E8E93),
                            ),
                          ),

                          // 备注（如果有）
                          if (expense.isRecurring && expense.itemName != null)
                            Flexible(
                              child: Text(
                                '· ${expense.itemName!}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8E8E93),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          else if (expense.note != null &&
                              expense.note!.isNotEmpty)
                            Flexible(
                              child: Text(
                                '· ${expense.note!}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8E8E93),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
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
