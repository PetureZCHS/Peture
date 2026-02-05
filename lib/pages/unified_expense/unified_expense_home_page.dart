import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../../models/unified_expense.dart';
import '../../services/supabase_service.dart';
import 'add_unified_expense_page.dart';

// --- Local Style Constants to match Home Screen ---
class ExpenseStyles {
  // Cute Peture Style
  static const LinearGradient bgGradient = LinearGradient(
    colors: [
      Color(0xFFFFFBE6), // Light Cream Yellow
      Color(0xFFFFEEF0), // Light Pink
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient vibrantGradient = LinearGradient(
    colors: [Color(0xFFFFB7C5), Color(0xFFFF69B4)], // Pink gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color textDark = Color(0xFF6D4C41); // Brown text
  static const Color textGrey = Color(0xFFA1887F); // Light Brown text

  static const LinearGradient mainGradient = LinearGradient(
    colors: [Color(0xFFFF9E80), Color(0xFFFF69B4)], // Peach to Pink
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration glassDecoration({double radius = 24}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: const Color(0xFFFFFDE7), // Solid Cream color
      border: Border.all(
        color: const Color(0xFF8D6E63), // Brown border
        width: 3.0,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF8D6E63).withOpacity(0.2),
          blurRadius: 0,
          offset: const Offset(4, 4), // Hard shadow for sticker effect
        ),
      ],
    );
  }
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
    with SingleTickerProviderStateMixin {
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
  List<UnifiedLedger> _ledgers = [];
  late UnifiedLedger _currentLedger;

  @override
  void initState() {
    super.initState();
    // Default Init
    _currentLedger = UnifiedLedger(
        id: 'default',
        name: '默认账本',
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
          name: '默认账本',
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

  Future<void> _saveLedgers() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_ledgers.map((e) => e.toMap()).toList());
    await prefs.setString('unified_ledgers', encoded);
  }

  void _addNewLedger(String name) {
    if (name.isEmpty) return;

    final random = Random();
    final colors = [
      0xFFFF9F0A, // Orange
      0xFF5E5CE6, // Indigo
      0xFF30B0C7, // Teal
      0xFF32D74B, // Green
      0xFFFF375F, // Pink
    ];
    final icons = [
      Icons.pets_rounded,
      Icons.flight_rounded,
      Icons.home_rounded,
      Icons.shopping_bag_rounded,
      Icons.favorite_rounded
    ];

    final newLedger = UnifiedLedger(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      colorValue: colors[random.nextInt(colors.length)],
      iconPoint: icons[random.nextInt(icons.length)].codePoint,
      isSystemDefault: false,
    );

    setState(() {
      _ledgers.add(newLedger);
    });
    _saveLedgers();
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
  void _showLedgerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('切换账本',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                                context: context,
                                builder: (ctx) {
                                  String newName = '';
                                  return AlertDialog(
                                    title: const Text('新建账本'),
                                    content: TextField(
                                      autofocus: true,
                                      decoration: const InputDecoration(
                                          hintText: '输入名称'),
                                      onChanged: (v) => newName = v,
                                    ),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('取消')),
                                      TextButton(
                                          onPressed: () {
                                            if (newName.isNotEmpty) {
                                              _addNewLedger(newName);
                                              setModalState(() {});
                                              Navigator.pop(ctx);
                                            }
                                          },
                                          child: const Text('确定')),
                                    ],
                                  );
                                });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.add_rounded,
                                size: 24, color: Colors.blueAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _ledgers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final ledger = _ledgers[index];
                        final isSelected = ledger.id == _currentLedger.id;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _currentLedger = ledger);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.blueAccent, width: 2)
                                    : Border.all(
                                        color: Colors.transparent, width: 2)),
                            child: Row(
                              children: [
                                Icon(
                                    IconData(ledger.iconPoint,
                                        fontFamily: 'MaterialIcons'),
                                    color: Color(ledger.colorValue),
                                    size: 28),
                                const SizedBox(width: 16),
                                Text(ledger.name,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

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
            color: const Color(0xFFFFFDE7), // Cream
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFF8D6E63), width: 2), // Brown border
            boxShadow: const [
              BoxShadow(color: Color(0xFF8D6E63), offset: Offset(2, 2))
            ]),
        child:
            Icon(icon, color: const Color(0xFF6D4C41), size: 20), // Brown icon
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

          // Right Actions
          Row(
            children: [
              _buildTopButton(
                  _showLedgerPicker, Icons.segment_rounded), // Ledger/Menu
              const SizedBox(width: 12),
              _buildTopButton(
                  _showScopePicker, Icons.search_rounded), // Scope/Search
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBE6), // Cream fallback
      body: Stack(
        children: [
          // 1. Cute Gradient Background
          Positioned.fill(
            child: Container(
              decoration:
                  const BoxDecoration(gradient: ExpenseStyles.bgGradient),
            ),
          ),
          // Decor Orbs (Animated)
          const Positioned(
            top: -100,
            right: -50,
            child: AnimatedBackgroundOrb(
              color: Color(0xFFFFB7C5), // Soft Pink
              size: 300,
            ),
          ),
          const Positioned(
            bottom: 100,
            left: -50,
            child: AnimatedBackgroundOrb(
              color: Color(0xFFFFE4C4), // Bisque/Cream
              size: 250,
              offset: Offset(100, 0),
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
                              color: const Color(0xFFFFFDE7), // Cream
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                  color: const Color(0xFF8D6E63),
                                  width: 2), // Brown border
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(
                                        0xFF8D6E63), // Brownish Hard Shadow
                                    offset: Offset(2, 2))
                              ]),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                                // Gradient Pill Indicator
                                gradient: ExpenseStyles.mainGradient,
                                borderRadius: BorderRadius.circular(24),
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFFFF69B4)
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
        color: const Color(0xFFFFFDE7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8D6E63), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xFF8D6E63), offset: Offset(2, 2))
        ]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Ledger Selector
          GestureDetector(
            onTap: _showLedgerPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: headerDeco,
              child: Row(
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
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: ExpenseStyles.textGrey),
                ],
              ),
            ),
          ),

          // Date Navigator
          Container(
            padding: const EdgeInsets.all(4),
            decoration: headerDeco,
            child: Row(
              children: [
                _navButton(Icons.chevron_left_rounded, _previousRange),
                Container(
                  constraints: const BoxConstraints(minWidth: 80),
                  alignment: Alignment.center,
                  child: Text(dateStr,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ExpenseStyles.textDark)),
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
              child: _buildSummaryCard(),
            ),
          ),
          if (_groupedExpenses.isEmpty)
            const SliverFillRemaining(
              child: CuteEmptyState(
                emoji: '🐱',
                message: '最近没有花钱哦，喵～',
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

  Widget _buildSummaryCard() {
    return _buildGlassCard(
        child: Container(
      padding: const EdgeInsets.all(24),
      // Removed inner white gradient to let the glass decoration handle it
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
    if (isToday)
      displayDate = '今天';
    else if (isYesterday)
      displayDate = '昨天';
    else
      displayDate = DateFormat('M月d日').format(date);

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
            Row(
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
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
      child: this,
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
                            )
                          ),
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
              color: Color(0xFFA1887F),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

