import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/unified_expense.dart';
import '../../../shared/database/unified_expense_helper.dart';
import '../../../services/supabase_service.dart';

/// 优化版消费记录页面 - 现代化UI设计
class AddUnifiedExpensePageV2 extends StatefulWidget {
  final UnifiedExpense? expense;

  const AddUnifiedExpensePageV2({super.key, this.expense});

  @override
  State<AddUnifiedExpensePageV2> createState() =>
      _AddUnifiedExpensePageV2State();
}

class _AddUnifiedExpensePageV2State extends State<AddUnifiedExpensePageV2>
    with SingleTickerProviderStateMixin {
  // 基础状态
  ExpenseTypeEnum _selectedExpenseType = ExpenseTypeEnum.oneOff;
  String _amountStr = '';
  UnifiedExpenseCategory? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  // 宠物选择
  String? _selectedPetId;
  String? _selectedPetName;
  List<Map<String, dynamic>> _pets = [];

  // 控制器
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();

  // 自定义分类
  final List<UnifiedExpenseCategory> _customCategories = [];

  // 周期支出额外字段
  final TextEditingController _itemNameController = TextEditingController();
  DateTime? _estimatedEndDate;
  ItemTypeEnum? _selectedItemType;

  bool _isLoading = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _loadPets();
    _initData();
  }

  void _initData() {
    if (widget.expense != null) {
      final amount = widget.expense!.amount;
      _amountStr = amount == amount.toInt()
          ? amount.toInt().toString()
          : amount.toString();

      _selectedExpenseType = widget.expense!.expenseType == 'one-off'
          ? ExpenseTypeEnum.oneOff
          : ExpenseTypeEnum.recurring;

      final categories = _selectedExpenseType == ExpenseTypeEnum.oneOff
          ? UnifiedExpenseCategory.oneOffCategories
          : UnifiedExpenseCategory.recurringCategories;

      try {
        _selectedCategory =
            categories.firstWhere((c) => c.name == widget.expense!.category);
      } catch (_) {
        _selectedCategory = UnifiedExpenseCategory(
          name: widget.expense!.category,
          icon: Icons.category.codePoint,
          color: Colors.grey.value,
          expenseType: _selectedExpenseType,
        );
      }

      _selectedDate = DateTime.parse(widget.expense!.date);
      _selectedPetId = widget.expense!.petId;
      _selectedPetName = widget.expense!.petName;
      _noteController.text = widget.expense!.note ?? '';

      if (widget.expense!.isRecurring) {
        _itemNameController.text = widget.expense!.itemName ?? '';
        if (widget.expense!.estimatedEndDate != null) {
          _estimatedEndDate = DateTime.parse(widget.expense!.estimatedEndDate!);
        }
        _selectedItemType = widget.expense!.itemType == 'consumable'
            ? ItemTypeEnum.consumable
            : ItemTypeEnum.durable;
      }
    } else {
      _selectedCategory = UnifiedExpenseCategory.oneOffCategories.first;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _itemNameController.dispose();
    _noteFocusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadPets() async {
    final supabaseService = SupabaseService();
    final pets = await supabaseService.getAllPets();
    if (mounted) {
      setState(() => _pets = pets);
    }
  }

  // 金额格式化显示
  String get _displayAmount {
    if (_amountStr.isEmpty) return '0';
    return _amountStr;
  }

  void _onKeypadTap(String value) {
    HapticFeedback.lightImpact();

    setState(() {
      if (value == 'DEL') {
        if (_amountStr.isNotEmpty) {
          _amountStr = _amountStr.substring(0, _amountStr.length - 1);
        }
      } else if (value == '.') {
        if (!_amountStr.contains('.') && _amountStr.isNotEmpty) {
          _amountStr += '.';
        } else if (_amountStr.isEmpty) {
          _amountStr = '0.';
        }
      } else {
        // 限制小数点后两位
        if (_amountStr.contains('.')) {
          final parts = _amountStr.split('.');
          if (parts[1].length >= 2) return;
        }
        // 限制整数长度
        if (!_amountStr.contains('.') && _amountStr.length >= 8) return;
        // 避免开头多个0
        if (_amountStr == '0' && value != '.') {
          _amountStr = value;
        } else {
          _amountStr += value;
        }
      }
    });
  }

  Future<void> _selectDate() async {
    HapticFeedback.selectionClick();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF6B6B),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1C1C1E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveExpense() async {
    if (_selectedCategory == null) return;

    double amount = double.tryParse(_amountStr) ?? 0.0;
    if (amount <= 0) {
      _showToast('请输入金额');
      return;
    }

    if (_selectedExpenseType == ExpenseTypeEnum.recurring) {
      if (_itemNameController.text.trim().isEmpty) {
        _itemNameController.text = _selectedCategory!.name;
      }
      _selectedItemType ??= ItemTypeEnum.consumable;
    }

    setState(() => _isLoading = true);

    try {
      final expense = UnifiedExpense(
        id: widget.expense?.id,
        amount: amount,
        category: _selectedCategory!.name,
        expenseType: _selectedExpenseType.value,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        petId: _selectedPetId,
        petName: _selectedPetName,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        itemName: _selectedExpenseType == ExpenseTypeEnum.recurring
            ? (_itemNameController.text.isEmpty
                ? _selectedCategory!.name
                : _itemNameController.text)
            : null,
        estimatedEndDate: _selectedExpenseType == ExpenseTypeEnum.recurring &&
                _estimatedEndDate != null
            ? DateFormat('yyyy-MM-dd').format(_estimatedEndDate!)
            : null,
        itemType: _selectedExpenseType == ExpenseTypeEnum.recurring
            ? _selectedItemType?.value
            : null,
        createdAt:
            widget.expense?.createdAt ?? DateTime.now().toIso8601String(),
        photoPath: null,
      );

      final supabaseService = SupabaseService();
      bool success = false;

      if (widget.expense == null) {
        await UnifiedExpenseHelper.instance.insertExpense(expense);
        final result =
            await supabaseService.insertUnifiedExpense(expense.toMap());
        if (result != null) success = true;
      } else {
        await UnifiedExpenseHelper.instance.updateExpense(expense);
        success = await supabaseService.updateUnifiedExpense(expense.toMap());
      }

      if (!success) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showToast('云端同步失败，已保存到本地', isWarning: true);
        }
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showToast('保存失败: $e', isError: true);
      }
    }
  }

  void _showToast(String message,
      {bool isError = false, bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : (isWarning
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFFF3B30)
            : (isWarning ? Colors.orange : const Color(0xFF34C759)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _selectedExpenseType == ExpenseTypeEnum.oneOff
        ? UnifiedExpenseCategory.oneOffCategories
        : UnifiedExpenseCategory.recurringCategories;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildAmountDisplay(),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildCategorySection(categories),
                    _buildMetaInfo(),
                    const Divider(height: 1, color: Color(0xFFF2F2F7)),
                    _buildNoteField(),
                    const Spacer(),
                    _buildKeypad(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // 关闭按钮
          _buildIconButton(Icons.close_rounded, () => Navigator.pop(context)),
          const Spacer(),
          // 支出类型切换
          _buildTypeSwitch(),
          const Spacer(),
          // 占位
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: const Color(0xFF1C1C1E)),
      ),
    );
  }

  Widget _buildTypeSwitch() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8ED),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTypePill('普通支出', ExpenseTypeEnum.oneOff),
          _buildTypePill('周期支出', ExpenseTypeEnum.recurring),
        ],
      ),
    );
  }

  Widget _buildTypePill(String label, ExpenseTypeEnum type) {
    final isSelected = _selectedExpenseType == type;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedExpenseType = type;
          final newCats = type == ExpenseTypeEnum.oneOff
              ? UnifiedExpenseCategory.oneOffCategories
              : UnifiedExpenseCategory.recurringCategories;
          if (!newCats.any((c) => c.name == _selectedCategory?.name)) {
            _selectedCategory = newCats.first;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1))
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color:
                isSelected ? const Color(0xFF1C1C1E) : const Color(0xFF8E8E93),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountDisplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 宠物选择器
          GestureDetector(
            onTap: _showPetSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5E5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.pets,
                        size: 16, color: Color(0xFFFF6B6B)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedPetName ?? '选择宠物',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _selectedPetName != null
                          ? const Color(0xFF1C1C1E)
                          : const Color(0xFF8E8E93),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: Color(0xFF8E8E93)),
                ],
              ),
            ),
          ),
          const Spacer(),
          // 金额显示
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¥',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF6B6B),
                    ),
                  ),
                  Text(
                    _displayAmount,
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF6B6B),
                      height: 1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPetSelector() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPetSelectorSheet(),
    );
  }

  Widget _buildPetSelectorSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              '选择消费对象',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (_pets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.pets_outlined, size: 48, color: Color(0xFFE0E0E0)),
                  SizedBox(height: 12),
                  Text('暂无宠物', style: TextStyle(color: Color(0xFF8E8E93))),
                ],
              ),
            ),
          ..._pets.map((pet) => _buildPetOption(pet)),
          _buildPetOption({'id': null, 'name': '公共/家庭支出'}, isPublic: true),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildPetOption(Map<String, dynamic> pet, {bool isPublic = false}) {
    final isSelected = isPublic
        ? _selectedPetId == null
        : _selectedPetId == pet['id']?.toString();

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedPetId = isPublic ? null : pet['id']?.toString();
          _selectedPetName = isPublic ? null : pet['name'];
        });
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF0F0) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: const Color(0xFFFF6B6B), width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPublic
                    ? const Color(0xFFF5F5F7)
                    : const Color(0xFFFFE5E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPublic ? Icons.home_rounded : Icons.pets,
                color: isPublic
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFFFF6B6B),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                pet['name'] ?? '公共/家庭支出',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: Color(0xFFFF6B6B), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(List<UnifiedExpenseCategory> categories) {
    final allCategories = [
      ...categories,
      ..._customCategories.where((c) => c.expenseType == _selectedExpenseType)
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: allCategories.length + 1,
        itemBuilder: (context, index) {
          if (index == allCategories.length) {
            return _buildAddCategoryItem();
          }
          return _buildCategoryItem(allCategories[index]);
        },
      ),
    );
  }

  Widget _buildCategoryItem(UnifiedExpenseCategory cat) {
    final isSelected = _selectedCategory?.name == cat.name;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedCategory = cat);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? Color(cat.color)
                    : Color(cat.color).withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: Color(cat.color).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4))
                      ]
                    : null,
              ),
              child: Icon(
                IconData(cat.icon, fontFamily: 'MaterialIcons'),
                color: isSelected ? Colors.white : Color(cat.color),
                size: 26,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              cat.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Color(cat.color) : const Color(0xFF8E8E93),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCategoryItem() {
    return GestureDetector(
      onTap: _showAddCategoryDialog,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFE5E5EA),
                    width: 1.5,
                    strokeAlign: BorderSide.strokeAlignInside),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Color(0xFF8E8E93), size: 26),
            ),
            const SizedBox(height: 8),
            const Text(
              '添加',
              style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    int selectedColor = 0xFFFF6B6B;
    int selectedIcon = Icons.category.codePoint;

    final colors = [
      0xFFFF6B6B,
      0xFFFF8A65,
      0xFFFFB74D,
      0xFFFFD54F,
      0xFF81C784,
      0xFF4FC3F7,
      0xFF9575CD,
      0xFFF06292,
    ];

    final icons = [
      Icons.category,
      Icons.pets,
      Icons.favorite,
      Icons.star,
      Icons.home,
      Icons.shopping_cart,
      Icons.local_cafe,
      Icons.sports_esports,
      Icons.restaurant,
      Icons.medical_services,
      Icons.spa,
      Icons.toys,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('添加分类',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '分类名称',
                        filled: true,
                        fillColor: const Color(0xFFF5F5F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('选择颜色',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: colors.map((color) {
                        final isSelected = selectedColor == color;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedColor = color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(color),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                          color: Color(color).withOpacity(0.5),
                                          blurRadius: 8)
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('选择图标',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: icons.map((icon) {
                        final isSelected = selectedIcon == icon.codePoint;
                        return GestureDetector(
                          onTap: () => setDialogState(
                              () => selectedIcon = icon.codePoint),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Color(selectedColor)
                                  : const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              icon,
                              color: isSelected
                                  ? Colors.white
                                  : Color(selectedColor),
                              size: 24,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F7),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Text('取消',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (nameController.text.trim().isNotEmpty) {
                                final newCategory = UnifiedExpenseCategory(
                                  name: nameController.text.trim(),
                                  icon: selectedIcon,
                                  color: selectedColor,
                                  expenseType: _selectedExpenseType,
                                );
                                setState(() {
                                  _customCategories.add(newCategory);
                                  _selectedCategory = newCategory;
                                });
                                Navigator.pop(ctx);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Color(selectedColor),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Text('确定',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetaInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildMetaChip(
            Icons.calendar_today_rounded,
            _isToday(_selectedDate)
                ? '今天'
                : DateFormat('MM/dd').format(_selectedDate),
            onTap: _selectDate,
          ),
          const SizedBox(width: 10),
          _buildMetaChip(
            Icons.folder_outlined,
            '我的账本',
            onTap: () {},
          ),
          if (_selectedPetName != null) ...[
            const SizedBox(width: 10),
            _buildMetaChip(
              Icons.pets,
              _selectedPetName!,
              color: const Color(0xFFFF6B6B),
            ),
          ],
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildMetaChip(IconData icon, String text,
      {VoidCallback? onTap, Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color?.withOpacity(0.1) ?? const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color ?? const Color(0xFF8E8E93)),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color ?? const Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _noteController,
        focusNode: _noteFocusNode,
        decoration: InputDecoration(
          hintText: '添加备注...',
          hintStyle: const TextStyle(color: Color(0xFFC7C7CC)),
          border: InputBorder.none,
          isDense: true,
          prefixIcon: const Icon(Icons.edit_note_rounded,
              color: Color(0xFFC7C7CC), size: 22),
          prefixIconConstraints: const BoxConstraints(minWidth: 36),
        ),
        style: const TextStyle(fontSize: 15),
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      color: const Color(0xFFFAFAFA),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          // 数字键盘
          Expanded(
            flex: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [_buildKey('7'), _buildKey('8'), _buildKey('9')]),
                Row(children: [_buildKey('4'), _buildKey('5'), _buildKey('6')]),
                Row(children: [_buildKey('1'), _buildKey('2'), _buildKey('3')]),
                Row(children: [
                  _buildKey('.'),
                  _buildKey('0'),
                  _buildKey('DEL', icon: Icons.backspace_outlined)
                ]),
              ],
            ),
          ),
          // 右侧按钮
          Expanded(
            flex: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildKey('DATE', icon: Icons.calendar_month_rounded),
                _buildSaveButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String value, {IconData? icon}) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (value == 'DATE') {
            _selectDate();
          } else {
            _onKeypadTap(value);
          }
        },
        child: Container(
          height: 52,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, color: const Color(0xFF1C1C1E), size: 22)
                : Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Expanded(
      flex: 3,
      child: GestureDetector(
        onTap: _isLoading ? null : _saveExpense,
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    '保存',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
