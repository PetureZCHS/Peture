import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/page_tracker_mixin.dart';
import '../../../shared/models/unified_expense.dart';
import '../../../services/supabase_service.dart';
import 'add_unified_expense_page.dart';

// --- Local Style Constants to match Home Screen ---
class ExpenseStyles {
  // Modern Clean Style
  static const LinearGradient bgGradient = LinearGradient(
    colors: [
      Color(0xFFF5F7FA), // Light Blue Grey
      Color(0xFFFFFFFF), // White
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient vibrantGradient = LinearGradient(
    colors: [Color(0xFF4facfe), Color(0xFF00f2fe)], // Blue gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color textDark = Color(0xFF2C3E50); // Dark Slate
  static const Color textGrey = Color(0xFF7F8C8D); // Grey

  static const LinearGradient mainGradient = LinearGradient(
    colors: [Color(0xFF667EEA), Color(0xFF764BA2)], // Blue to Purple
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration glassDecoration({double radius = 20}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: Colors.white,
      border: Border.all(
        color: Colors.grey.withOpacity(0.1),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 16,
          offset: const Offset(0, 4), // Soft shadow
        ),
      ],
    );
  }
}

/// 支出构成图例单项（类别名、占比、图标、颜色）
class _LegendEntry {
  final String label;
  final double percent;
  final int iconCodePoint;
  final Color color;
  _LegendEntry({
    required this.label,
    required this.percent,
    required this.iconCodePoint,
    required this.color,
  });
}

/// Ledger Model
class UnifiedLedger {
  final String id;
  final String name;
  final int colorValue;
  final int iconPoint;
  final bool isSystemDefault;

  UnifiedLedger({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconPoint,
    this.isSystemDefault = false,
  });

  UnifiedLedger copyWith({bool? isSystemDefault}) {
    return UnifiedLedger(
      id: id,
      name: name,
      colorValue: colorValue,
      iconPoint: iconPoint,
      isSystemDefault: isSystemDefault ?? this.isSystemDefault,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'iconPoint': iconPoint,
        'isSystemDefault': isSystemDefault
      };

  factory UnifiedLedger.fromMap(Map<String, dynamic> map) => UnifiedLedger(
        id: map['id'],
        name: map['name'],
        colorValue: map['colorValue'] ?? 0xFF5D5FEF,
        iconPoint: map['iconPoint'] ?? Icons.book.codePoint,
        isSystemDefault: map['isSystemDefault'] ?? false,
      );
}

class UnifiedExpenseHomePage extends StatefulWidget {
  const UnifiedExpenseHomePage({super.key});

  @override
  State<UnifiedExpenseHomePage> createState() => _UnifiedExpenseHomePageState();
}

enum ViewScope { week, month, year }

class _UnifiedExpenseHomePageState extends State<UnifiedExpenseHomePage>
    with
        SingleTickerProviderStateMixin,
        PageTrackerMixin<UnifiedExpenseHomePage> {
  late TabController _tabController;
  final SupabaseService _supabaseService = SupabaseService();

  // Data
  List<UnifiedExpense> _recurringExpenses = [];
  List<UnifiedExpense> _allExpenses = [];
  Map<String, List<UnifiedExpense>> _groupedExpenses = {};

  // Stats
  double _totalDailyCost = 0.0;
  double _periodTotal = 0.0;
  double _periodRecurringTotal = 0.0;
  double _periodOneOffTotal = 0.0;

  bool _isLoading = true;

  // Date Filter State
  late DateTime _startDate;
  late DateTime _endDate;
  ViewScope _currentScope = ViewScope.week;

  // Ledger State
  bool _isBalanceVisible = true;
  bool _isAnalysisVisible = true; // Control Pie Chart Visibility
  int _touchedIndex = -1; // Track touched section for interaction
  List<UnifiedLedger> _ledgers = [];
  late UnifiedLedger _currentLedger;

  @override
  String get analyticsPageName => 'expense_unified_home';

  @override
  void initState() {
    super.initState();
    // Default Init
    _currentLedger = UnifiedLedger(
        id: 'default',
        name: '我的账本',
        colorValue: ExpenseStyles.mainGradient.colors.first.value,
        iconPoint: Icons.book.codePoint);
    _tabController = TabController(length: 2, vsync: this);
    _initLedgers();
    _updateDateRangeToCurrent();
    _loadData();
  }

  void _toggleVisibility() {
    setState(() {
      _isBalanceVisible = !_isBalanceVisible;
    });
    HapticFeedback.selectionClick();
  }

  // Initialize Ledgers
  Future<void> _initLedgers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? ledgersJson = prefs.getString('unified_ledgers');

    if (ledgersJson != null) {
      final List<dynamic> decoded = jsonDecode(ledgersJson);
      _ledgers = decoded.map((e) => UnifiedLedger.fromMap(e)).toList();
    } else {
      _ledgers = [
        UnifiedLedger(
          id: 'default',
          name: '我的账本',
          colorValue: ExpenseStyles.mainGradient.colors.first.value,
          iconPoint: Icons.book.codePoint,
          isSystemDefault: true,
        ),
      ];
    }

    try {
      _currentLedger = _ledgers.firstWhere((l) => l.isSystemDefault,
          orElse: () => _ledgers.first);
    } catch (e) {
      _currentLedger = _ledgers.first;
    }

    if (mounted) setState(() {});
  }

  // --- Date Logic ---
  void _updateDateRangeToCurrent() {
    final now = DateTime.now();
    if (_currentScope == ViewScope.week) {
      _startDate = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      _endDate = _startDate
          .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    } else if (_currentScope == ViewScope.month) {
      _startDate = DateTime(now.year, now.month, 1);
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      _endDate = nextMonth.subtract(const Duration(seconds: 1));
    } else {
      _startDate = DateTime(now.year, 1, 1);
      _endDate = DateTime(now.year, 12, 31, 23, 59, 59);
    }
    _filterData();
  }

  void _previousRange() {
    setState(() {
      if (_currentScope == ViewScope.week) {
        _startDate = _startDate.subtract(const Duration(days: 7));
        _endDate = _endDate.subtract(const Duration(days: 7));
      } else if (_currentScope == ViewScope.month) {
        final prevMonth = DateTime(_startDate.year, _startDate.month - 1, 1);
        _startDate = prevMonth;
        final nextMonth = DateTime(prevMonth.year, prevMonth.month + 1, 1);
        _endDate = nextMonth.subtract(const Duration(seconds: 1));
      } else {
        _startDate = DateTime(_startDate.year - 1, 1, 1);
        _endDate = DateTime(_startDate.year, 12, 31, 23, 59, 59);
      }
    });
    _filterData();
  }

  void _nextRange() {
    setState(() {
      if (_currentScope == ViewScope.week) {
        _startDate = _startDate.add(const Duration(days: 7));
        _endDate = _endDate.add(const Duration(days: 7));
      } else if (_currentScope == ViewScope.month) {
        final nextMonthStart =
            DateTime(_startDate.year, _startDate.month + 1, 1);
        _startDate = nextMonthStart;
        final nextMonthEnd =
            DateTime(nextMonthStart.year, nextMonthStart.month + 1, 1)
                .subtract(const Duration(seconds: 1));
        _endDate = nextMonthEnd;
      } else {
        _startDate = DateTime(_startDate.year + 1, 1, 1);
        _endDate = DateTime(_startDate.year + 1, 12, 31, 23, 59, 59);
      }
    });
    _filterData();
  }

  // --- Data Loading ---
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use SupabaseService as in Develop branch
      final allData = await _supabaseService.getAllUnifiedExpenses();
      final all = allData.map((e) => UnifiedExpense.fromMap(e)).toList();

      final recurring = all.where((e) => e.isRecurring).toList();

      double dailyCost = 0.0;
      for (final expense in recurring) {
        dailyCost += expense.dailyCost;
      }

      if (mounted) {
        setState(() {
          _recurringExpenses = recurring;
          _allExpenses = all;
          _totalDailyCost = dailyCost;
        });
        _filterData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        debugPrint('Error loading expenses: $e');
      }
    }
  }

  void _filterData() {
    double periodTotal = 0.0;
    double recurringTotal = 0.0;
    double oneOffTotal = 0.0;
    final Map<String, List<UnifiedExpense>> grouped = {};

    for (var expense in _allExpenses) {
      final date = DateTime.parse(expense.date);
      if (date.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
          date.isBefore(_endDate.add(const Duration(seconds: 1)))) {
        if (!grouped.containsKey(expense.date)) {
          grouped[expense.date] = [];
        }
        grouped[expense.date]!.add(expense);

        periodTotal += expense.amount;
        if (expense.expenseType == 'recurring') {
          recurringTotal += expense.amount;
        } else {
          oneOffTotal += expense.amount;
        }
      }
    }

    setState(() {
      _touchedIndex = -1;
      _groupedExpenses = grouped;
      _periodTotal = periodTotal;
      _periodRecurringTotal = recurringTotal;
      _periodOneOffTotal = oneOffTotal;
      _isLoading = false;
    });
  }

  // 删除消费记录
  Future<void> _deleteExpense(UnifiedExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('删除后无法恢复，金额 ¥${expense.amount.toStringAsFixed(2)} 将被移除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('保留')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && expense.id != null) {
      // Use SupabaseService for deletion
      await _supabaseService.deleteUnifiedExpense(expense.id!);
      _loadData();
    }
  }

  // --- Dialogs ---
  void _showScopePicker() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const Text('选择时间维度',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildScopeOption('周视图', ViewScope.week),
                const Divider(),
                _buildScopeOption('月视图', ViewScope.month),
                const Divider(),
                _buildScopeOption('年视图', ViewScope.year),
                const SizedBox(height: 16),
              ],
            ),
          );
        });
  }

  Widget _buildScopeOption(String label, ViewScope scope) {
    final isSelected = _currentScope == scope;
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        if (_currentScope != scope) {
          setState(() {
            _currentScope = scope;
            _updateDateRangeToCurrent();
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 16,
                    color: isSelected ? Colors.blueAccent : Colors.black,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal)),
            if (isSelected)
              const Icon(Icons.check, color: Colors.blueAccent, size: 20)
          ],
        ),
      ),
    );
  }

  Future<void> _markAsFinished(UnifiedExpense expense) async {
    final startDate = DateTime.parse(expense.date);
    final today = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: startDate, // 不能早于开始使用日期
      lastDate: today.add(const Duration(days: 365)), // 允许选择未来一年内的日期
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null && expense.id != null) {
      final updatedExpense = expense.copyWith(
        estimatedEndDate: DateFormat('yyyy-MM-dd').format(picked),
      );
      // Use SupabaseService
      await _supabaseService.updateUnifiedExpense(updatedExpense.toMap());
      _loadData();
    }
  }

  Future<void> _undoFinished(UnifiedExpense expense) async {
    if (expense.id != null) {
      final updatedExpense = expense.copyWith(clearEstimatedEndDate: true);
      // Use SupabaseService
      await _supabaseService.updateUnifiedExpense(updatedExpense.toMap());
      _loadData();
    }
  }

  // =========================================================
  // UI BUILD
  // =========================================================

  Widget _buildTopButton(VoidCallback onTap, IconData icon) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Icon(icon, color: ExpenseStyles.textDark, size: 20),
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button - Styled identically to other top buttons
          _buildTopButton(
              () => Navigator.pop(context), Icons.arrow_back_ios_new_rounded),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          // 1. Clean Gradient Background
          Positioned.fill(
            child: Container(
              decoration:
                  const BoxDecoration(gradient: ExpenseStyles.bgGradient),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildCustomAppBar(context),
                _buildHeaderControls(),
                const SizedBox(height: 16),

                // Content
                Expanded(
                  child: Column(
                    children: [
                      // 2. TabBar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                                color: Colors.grey.withOpacity(0.1), width: 1),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                                // Gradient Pill Indicator
                                gradient: ExpenseStyles.mainGradient,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                      color: ExpenseStyles
                                          .mainGradient.colors.first
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2))
                                ]),
                            labelColor: Colors.white,
                            unselectedLabelColor:
                                ExpenseStyles.textDark.withOpacity(0.6),
                            labelStyle: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                            tabs: const [
                              Tab(
                                  child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                    Icon(Icons.list_rounded),
                                    SizedBox(width: 8),
                                    Text('支出明细')
                                  ])),
                              Tab(
                                  child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                    Icon(Icons.cached_rounded),
                                    SizedBox(width: 8),
                                    Text('成本追踪')
                                  ])),
                            ],
                            indicatorSize: TabBarIndicatorSize.tab,
                            splashBorderRadius: BorderRadius.circular(24),
                            dividerColor: Colors.transparent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildExpenseList(),
                                  _buildRecurringList(),
                                ],
                              ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AddUnifiedExpensePage()));
          if (result == true) {
            _loadData();
          }
        },
        // Using Container to apply Gradient
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
              gradient: ExpenseStyles.mainGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: ExpenseStyles.mainGradient.colors.first
                        .withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ]),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
        margin: padding ?? EdgeInsets.zero,
        decoration: ExpenseStyles.glassDecoration(),
        child: child); // Removed blur for solid cuter look
  }

  Widget _buildHeaderControls() {
    String dateStr;
    if (_currentScope == ViewScope.year) {
      dateStr = '${_startDate.year}年';
    } else if (_currentScope == ViewScope.month) {
      dateStr = DateFormat('yyyy年M月', 'zh_CN').format(_startDate);
    } else {
      dateStr =
          '${DateFormat('M.d', 'zh_CN').format(_startDate)} - ${DateFormat('M.d', 'zh_CN').format(_endDate)}';
    }

    // Common decoration for header pills
    final headerDeco = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        )
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 账本展示（当前仅支持单一账本「我的账本」，切换账本功能暂未开放）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: headerDeco,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    IconData(_currentLedger.iconPoint,
                        fontFamily: 'MaterialIcons'),
                    color: Color(_currentLedger.colorValue),
                    size: 16),
                const SizedBox(width: 8),
                Text(_currentLedger.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: ExpenseStyles.textDark)),
              ],
            ),
          ),

          // Date Navigator
          Container(
            padding: const EdgeInsets.all(4),
            decoration: headerDeco,
            child: Row(
              children: [
                _navButton(Icons.chevron_left_rounded, _previousRange),
                GestureDetector(
                  onTap: _showScopePicker,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 80),
                    alignment: Alignment.center,
                    child: Text(dateStr,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ExpenseStyles.textDark)),
                  ),
                ),
                _navButton(Icons.chevron_right_rounded, _nextRange),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: ExpenseStyles.textDark),
      ),
    );
  }

  Widget _buildExpenseList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  _buildSummaryCard(),
                  if (_groupedExpenses.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildAnalysisCard(),
                  ]
                ],
              ),
            ),
          ),
          if (_groupedExpenses.isEmpty)
            const SliverFillRemaining(
              child: CuteEmptyState(
                emoji: '🐱',
                message: '本月还没有给主子花钱哦，喵～',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final sortedDates = _groupedExpenses.keys.toList()
                    ..sort((a, b) => b.compareTo(a));
                  final date = sortedDates[index];
                  final expenses = _groupedExpenses[date]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        child: _buildDateHeader(date, expenses),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildGlassCard(
                            child: Column(
                          children: expenses
                              .map((e) => _buildExpenseItem(e))
                              .toList(),
                        )),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }, childCount: _groupedExpenses.length),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildRecurringList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildDailyCostCard(),
            ),
          ),
          if (_recurringExpenses.isEmpty)
            const SliverFillRemaining(
              child: CuteEmptyState(
                emoji: '🐕',
                message: '并没有什么订阅... 汪',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final expense = _recurringExpenses[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildRecurringCard(expense),
                  );
                }, childCount: _recurringExpenses.length),
              ),
            )
        ],
      ),
    );
  }

  // --- Cards ---

  Widget _buildAnalysisCard() {
    final Map<String, double> categoryTotals = {};
    final visibleExpenses =
        _groupedExpenses.values.expand((element) => element).toList();

    if (visibleExpenses.isEmpty) return const SizedBox.shrink();

    for (var expense in visibleExpenses) {
      if (expense.amount > 0) {
        final key = expense.category.isEmpty ? '其他' : expense.category;
        categoryTotals[key] = (categoryTotals[key] ?? 0) + expense.amount;
      }
    }

    if (categoryTotals.isEmpty) return const SizedBox.shrink();

    final total = categoryTotals.values.fold(0.0, (sum, val) => sum + val);
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 1. 阈值逻辑优化：合并占比 <= 2% 的长尾项为“其他”
    final List<MapEntry<String, double>> processedEntries = [];
    double otherTotal = 0.0;

    for (var entry in sortedEntries) {
      final percent = (entry.value / total) * 100;
      if (percent > 2) {
        processedEntries.add(entry);
      } else {
        otherTotal += entry.value;
      }
    }

    if (otherTotal > 0) {
      // 检查是否已经有“其他”项，如果有则累加
      int otherIdx = processedEntries.indexWhere((e) => e.key == '其他');
      if (otherIdx != -1) {
        processedEntries[otherIdx] =
            MapEntry('其他', processedEntries[otherIdx].value + otherTotal);
      } else {
        processedEntries.add(MapEntry('其他', otherTotal));
      }
      // 重新按金额排序，确保“其他”项在合适位置（通常是最后，但也可能很大）
      processedEntries.sort((a, b) => b.value.compareTo(a.value));
    }

    final safeTouchedIndex =
        (_touchedIndex >= 0 && _touchedIndex < processedEntries.length)
            ? _touchedIndex
            : -1;

    final List<PieChartSectionData> sections = [];
    Color? touchedColor;
    // Fallback palette
    final List<Color> palette = [
      const Color(0xFF6E85B2),
      const Color(0xFFB4C5E4),
      const Color(0xFF9A8C98),
      const Color(0xFFC9ADA7),
      const Color(0xFFF2E9E4),
      const Color(0xFF4A4E69),
    ];

    for (int i = 0; i < processedEntries.length; i++) {
      final entry = processedEntries[i];
      final categoryName = entry.key;
      final amount = entry.value;
      final category = UnifiedExpenseCategory.getCategoryByName(categoryName);
      final color = category != null
          ? Color(category.color)
          : palette[i % palette.length];
      final percent = (amount / total) * 100;
      final isTouched = i == safeTouchedIndex;
      final anyTouched = safeTouchedIndex != -1;

      if (isTouched) touchedColor = color;

      // 动态计算半径：选中项放大，非选中项在有选中时缩小
      double radius;
      if (isTouched) {
        radius = 86; // 进一步放大
      } else if (anyTouched) {
        radius = 64; // 其他项缩小
      } else {
        radius = 72; // 默认状态
      }

      sections.add(PieChartSectionData(
        color: isTouched ? color : color.withOpacity(anyTouched ? 0.6 : 1.0),
        value: amount,
        title: isTouched
            ? '${percent.toStringAsFixed(1)}%'
            : (anyTouched ? '' : '${percent.toStringAsFixed(0)}%'),
        radius: radius,
        titleStyle: TextStyle(
            fontSize: isTouched ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.white),
        // 玻璃风格边缘：通过多层 borderSide 模拟发光/模糊感
        borderSide: isTouched
            ? BorderSide(
                color: color.withOpacity(0.8), // 提高透明度使边缘更明显
                width: 6, // 增加宽度
              )
            : const BorderSide(color: Colors.transparent, width: 0),
        badgeWidget: _buildBadge(category?.icon ?? Icons.more_horiz.codePoint,
            isTouched ? color : color.withOpacity(anyTouched ? 0.5 : 1.0),
            size: isTouched ? 24 : 18),
        badgePositionPercentageOffset: .98,
      ));
    }

    return _buildGlassCard(
        child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Header Row with Toggle
          InkWell(
            onTap: () {
              setState(() {
                _isAnalysisVisible = !_isAnalysisVisible;
              });
            },
            child: Row(
              children: [
                const Icon(Icons.pie_chart_rounded,
                    size: 16, color: ExpenseStyles.textGrey),
                const SizedBox(width: 6),
                const Text('支出构成',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: ExpenseStyles.textDark)),
                const Spacer(),
                if (_isAnalysisVisible)
                  Text('¥${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: ExpenseStyles.textDark)),
                const SizedBox(width: 8),
                Icon(
                  _isAnalysisVisible
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: ExpenseStyles.textGrey,
                  size: 20,
                ),
              ],
            ),
          ),

          // Collapsible Content
          AnimatedCrossFade(
            firstChild: Container(),
            secondChild: Column(
              children: [
                const SizedBox(height: 24),
                SizedBox(
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        key: ValueKey(
                            'pie_${_currentScope.name}_${_startDate.millisecondsSinceEpoch}_${_endDate.millisecondsSinceEpoch}_${processedEntries.length}'),
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback:
                                (FlTouchEvent event, pieTouchResponse) {
                              final touchedSection =
                                  pieTouchResponse?.touchedSection;

                              // 命中扇形
                              if (touchedSection != null) {
                                final newIndex =
                                    touchedSection.touchedSectionIndex;

                                // 只有在按下瞬间（TapDown）处理切换逻辑，避免滑动过程中频繁切换
                                if (event is FlTapDownEvent) {
                                  setState(() {
                                    if (_touchedIndex == newIndex) {
                                      // 再次点击当前已放大的扇形 -> 取消选中
                                      _touchedIndex = -1;
                                    } else {
                                      // 点击新的扇形 -> 切换到新扇形
                                      _touchedIndex = newIndex;
                                    }
                                  });
                                } else if (event is FlPanUpdateEvent ||
                                    event is FlPanStartEvent) {
                                  // 滑动过程中，如果进入了新的扇形，则更新选中（增强钻取感）
                                  if (newIndex != _touchedIndex) {
                                    setState(() {
                                      _touchedIndex = newIndex;
                                    });
                                  }
                                }
                                return;
                              }

                              // 仅在“按下空白区域”时恢复默认
                              if (event is FlTapDownEvent) {
                                if (_touchedIndex != -1) {
                                  setState(() {
                                    _touchedIndex = -1;
                                  });
                                }
                              }
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 2,
                          centerSpaceRadius: 64,
                          sections: sections,
                        ),
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOutBack,
                      ),
                      // 2. 环形图中心区域增强
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(
                                milliseconds: 50), // 极短时间，实现近乎即时的变色
                            curve: Curves.linear,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: touchedColor ?? ExpenseStyles.textDark,
                            ),
                            child: Text(
                              safeTouchedIndex != -1
                                  ? '¥${processedEntries[safeTouchedIndex].value.toStringAsFixed(2)}'
                                  : '¥${total.toStringAsFixed(2)}',
                            ),
                          ),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 50),
                            curve: Curves.linear,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: safeTouchedIndex != -1
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: touchedColor?.withOpacity(0.8) ??
                                  ExpenseStyles.textGrey,
                            ),
                            child: Text(
                              safeTouchedIndex != -1
                                  ? processedEntries[safeTouchedIndex].key
                                  : '总支出',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildExpenseLegendTwoColumn(
                  sortedEntries: processedEntries,
                  total: total,
                  palette: palette,
                ),
              ],
            ),
            crossFadeState: _isAnalysisVisible
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    ));
  }

  Widget _buildBadge(int iconCodePoint, Color bg, {double size = 14}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
        ],
      ),
      child: Icon(IconData(iconCodePoint, fontFamily: 'MaterialIcons'),
          size: size, color: bg),
    );
  }

  /// 支出构成图例：双列规整布局，展示所有处理后的类别
  Widget _buildExpenseLegendTwoColumn({
    required List<MapEntry<String, double>> sortedEntries,
    required double total,
    required List<Color> palette,
  }) {
    final legendEntries = <_LegendEntry>[];
    for (var i = 0; i < sortedEntries.length; i++) {
      final e = sortedEntries[i];
      final percent = (e.value / total) * 100;
      // 不再过滤，因为 sortedEntries 已经是处理过的（合并了其他项）
      final category = UnifiedExpenseCategory.getCategoryByName(e.key);
      final color = category != null
          ? Color(category.color)
          : palette[i % palette.length];
      final iconCodePoint = category?.icon ?? Icons.more_horiz.codePoint;
      legendEntries.add(_LegendEntry(
        label: e.key,
        percent: percent,
        iconCodePoint: iconCodePoint,
        color: color,
      ));
    }
    if (legendEntries.isEmpty) return const SizedBox.shrink();

    final half = (legendEntries.length / 2).ceil();
    final leftColumn = legendEntries.take(half).toList();
    final rightColumn = legendEntries.skip(half).toList();

    const itemHeight = 28.0;
    const iconSize = 20.0;

    Widget buildLegendItem(_LegendEntry entry) {
      return SizedBox(
        height: itemHeight,
        child: Row(
          children: [
            Icon(
              IconData(entry.iconCodePoint, fontFamily: 'MaterialIcons'),
              size: iconSize,
              color: entry.color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: ExpenseStyles.textDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${entry.percent.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ExpenseStyles.textDark,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: leftColumn.map((e) => buildLegendItem(e)).toList(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: rightColumn.map((e) => buildLegendItem(e)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return _buildGlassCard(
        child: Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('本期支出',
                  style:
                      TextStyle(fontSize: 14, color: ExpenseStyles.textGrey)),
              GestureDetector(
                onTap: _toggleVisibility,
                child: Icon(
                  _isBalanceVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey,
                  size: 20,
                ),
              )
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _isBalanceVisible
                  ? '¥${_periodTotal.toStringAsFixed(2)}'
                  : '****',
              style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: ExpenseStyles.textDark,
                  letterSpacing: -1),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('固定支出',
                        style: TextStyle(
                            fontSize: 12, color: ExpenseStyles.textGrey)),
                    const SizedBox(height: 4),
                    Text(
                      _isBalanceVisible
                          ? '¥${_periodRecurringTotal.toStringAsFixed(2)}'
                          : '****',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: ExpenseStyles.textDark),
                    )
                  ],
                ),
              ),
              Container(
                  width: 1,
                  height: 30,
                  color: Colors.black.withOpacity(0.05)), // Softer divider
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('临时支出',
                        style: TextStyle(
                            fontSize: 12, color: ExpenseStyles.textGrey)),
                    const SizedBox(height: 4),
                    Text(
                      _isBalanceVisible
                          ? '¥${_periodOneOffTotal.toStringAsFixed(2)}'
                          : '****',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: ExpenseStyles.textDark),
                    )
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ));
  }

  Widget _buildDailyCostCard() {
    return _buildGlassCard(
        child: Stack(children: [
      Positioned(
        right: -30,
        top: -30,
        child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                    color: ExpenseStyles.mainGradient.colors.first
                        .withOpacity(0.1),
                    shape: BoxShape.circle))
            .blurred(sigmaX: 30, sigmaY: 30),
      ),
      Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: ExpenseStyles.mainGradient.colors.first
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: ExpenseStyles.mainGradient.colors.first
                              .withOpacity(0.1))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart_rounded,
                          size: 14,
                          color: ExpenseStyles.mainGradient.colors.first),
                      const SizedBox(width: 4),
                      Text("日均成本",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: ExpenseStyles.mainGradient.colors.first)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '¥${_totalDailyCost.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: ExpenseStyles.textDark,
                  letterSpacing: -1.5),
            ),
            const SizedBox(height: 8),
            const Text('基于所有有效周期性支出计算',
                style: TextStyle(fontSize: 13, color: ExpenseStyles.textGrey)),
          ],
        ),
      ),
    ]));
  }

  // List Item for Expense Flow
  Widget _buildExpenseItem(UnifiedExpense expense) {
    final category = UnifiedExpenseCategory.getCategoryByName(expense.category);
    final iconData = category != null
        ? IconData(category.icon, fontFamily: 'MaterialIcons')
        : Icons.more_horiz;
    final color = category != null ? Color(category.color) : Colors.grey;

    return Dismissible(
      key: Key(expense.id?.toString() ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: Colors.red.withOpacity(0.8),
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _deleteExpense(expense);
        return false;
      },
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      AddUnifiedExpensePage(expense: expense)));
          if (result == true) {
            _loadData();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.category.isEmpty ? '其他' : expense.category,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ExpenseStyles.textDark)),
                    if (expense.note != null && expense.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(expense.note!,
                            style: const TextStyle(
                                fontSize: 12, color: ExpenseStyles.textGrey),
                            maxLines: 1),
                      )
                  ],
                ),
              ),
              Text('-${expense.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ExpenseStyles.textDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateHeader(String dateStr, List<UnifiedExpense> expenses) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final isToday =
        now.year == date.year && now.month == date.month && now.day == date.day;
    final isYesterday = now.difference(date).inDays == 1;
    String displayDate;
    if (isToday) {
      displayDate = '今天';
    } else if (isYesterday) {
      displayDate = '昨天';
    } else {
      displayDate = DateFormat('M月d日').format(date);
    }

    final total = expenses.fold(0.0, (sum, e) => sum + e.amount);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(displayDate,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: ExpenseStyles.textGrey)),
        Text('支 ¥${total.toStringAsFixed(2)}',
            style:
                const TextStyle(fontSize: 12, color: ExpenseStyles.textGrey)),
      ],
    );
  }

  Widget _buildRecurringCard(UnifiedExpense expense) {
    final category = UnifiedExpenseCategory.getCategoryByName(expense.category);
    final iconData = category != null
        ? IconData(category.icon, fontFamily: 'MaterialIcons')
        : Icons.more_horiz;
    final color = category != null ? Color(category.color) : Colors.grey;
    final isInUse = expense.estimatedEndDate == null;

    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            InkWell(
              onTap: () async {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            AddUnifiedExpensePage(expense: expense)));
                if (result == true) {
                  _loadData();
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(iconData, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(expense.itemName ?? expense.category,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: ExpenseStyles.textDark)),
                        const SizedBox(height: 4),
                        Text('日均: ¥${expense.dailyCost.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 12, color: ExpenseStyles.textGrey)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('¥${expense.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: ExpenseStyles.textDark)),
                      if (!isInUse)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('已用完',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold)),
                        )
                    ],
                  )
                ],
              ),
            ),
            if (isInUse) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              InkWell(
                onTap: () => _markAsFinished(expense),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 12),
                  alignment: Alignment.center,
                  child: const Text('标记用完',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6A85B6))),
                ),
              )
            ] else ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              InkWell(
                onTap: () => _undoFinished(expense),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 12),
                  alignment: Alignment.center,
                  child: const Text('恢复使用',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange)),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

// Extension to help with blur
extension _WidgetExt on Widget {
  Widget blurred({double sigmaX = 10, double sigmaY = 10}) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: this,
      ),
    );
  }
}

// --- Animation Components ---

class AnimatedBackgroundOrb extends StatefulWidget {
  final Color color;
  final double size;
  final Offset offset;

  const AnimatedBackgroundOrb({
    super.key,
    required this.color,
    required this.size,
    this.offset = Offset.zero,
  });

  @override
  State<AnimatedBackgroundOrb> createState() => _AnimatedBackgroundOrbState();
}

class _AnimatedBackgroundOrbState extends State<AnimatedBackgroundOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(reverse: true);

    if (widget.offset.dx > 0) {
      _controller.forward(from: 0.5);
    }

    _scaleAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _slideAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(10, -10),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnim.value,
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(0.3),
              ),
            ).blurred(sigmaX: 80, sigmaY: 80),
          ),
        );
      },
    );
  }
}

class CuteEmptyState extends StatefulWidget {
  final String message;
  final String emoji;
  final bool isSleeping;

  const CuteEmptyState({
    super.key,
    required this.message,
    this.emoji = '🐱',
    this.isSleeping = true,
  });

  @override
  State<CuteEmptyState> createState() => _CuteEmptyStateState();
}

class _CuteEmptyStateState extends State<CuteEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 100,
                height: 30,
                margin: const EdgeInsets.only(top: 60),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: const Color(0xFF8D6E63).withOpacity(0.1),
                ),
              ),
              Transform.scale(
                scale: 1.0,
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 80),
                ),
              ),
              if (widget.isSleeping)
                Positioned(
                  right: -15,
                  top: -10,
                  child: AnimatedBuilder(
                    animation: _floatAnim,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(5, _floatAnim.value),
                        child: const Opacity(
                          opacity: 0.8,
                          child: Text('Zzz...',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8D6E63),
                              )),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            widget.message,
            style: const TextStyle(
              fontSize: 16,
              color: ExpenseStyles.textGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
