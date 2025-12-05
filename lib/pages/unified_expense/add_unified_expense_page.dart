import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/unified_expense.dart';
import '../../services/supabase_service.dart';

/// 统一的添加/编辑消费页面
class AddUnifiedExpensePage extends StatefulWidget {
  final UnifiedExpense? expense; // 如果是编辑模式，传入现有记录

  const AddUnifiedExpensePage({super.key, this.expense});

  @override
  State<AddUnifiedExpensePage> createState() => _AddUnifiedExpensePageState();
}

class _AddUnifiedExpensePageState extends State<AddUnifiedExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _itemNameController = TextEditingController();

  // 支出类型
  ExpenseTypeEnum _selectedExpenseType = ExpenseTypeEnum.oneOff;

  // 物品类型（仅周期性成本）
  ItemTypeEnum? _selectedItemType;

  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  DateTime? _estimatedEndDate;
  String? _selectedPetId; // 改为 String? 以支持 UUID
  String? _selectedPetName;
  List<Map<String, dynamic>> _pets = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPets();

    if (widget.expense != null) {
      // 编辑模式，填充现有数据
      _amountController.text = widget.expense!.amount.toString();
      _selectedCategory = widget.expense!.category;
      _selectedExpenseType = widget.expense!.expenseType == 'one-off'
          ? ExpenseTypeEnum.oneOff
          : ExpenseTypeEnum.recurring;
      _selectedDate = DateTime.parse(widget.expense!.date);
      _selectedPetId = widget.expense!.petId;
      _selectedPetName = widget.expense!.petName;
      _noteController.text = widget.expense!.note ?? '';

      if (widget.expense!.isRecurring) {
        _itemNameController.text = widget.expense!.itemName ?? '';
        if (widget.expense!.estimatedEndDate != null) {
          _estimatedEndDate = DateTime.parse(widget.expense!.estimatedEndDate!);
        }
        if (widget.expense!.itemType != null) {
          _selectedItemType = widget.expense!.itemType == 'consumable'
              ? ItemTypeEnum.consumable
              : ItemTypeEnum.durable;
        }
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _itemNameController.dispose();
    super.dispose();
  }

  /// 加载宠物列表
  Future<void> _loadPets() async {
    final supabaseService = SupabaseService();
    final pets = await supabaseService.getAllPets();
    if (mounted) {
      setState(() {
        _pets = pets;
      });
    }
  }

  /// 选择日期
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// 选择预计用完日期
  Future<void> _selectEstimatedEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _estimatedEndDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: _selectedDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 未来10年
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null) {
      setState(() {
        _estimatedEndDate = picked;
      });
    }
  }

  /// 保存消费记录
  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择消费分类')));
      return;
    }

    // 周期性成本的额外验证
    if (_selectedExpenseType == ExpenseTypeEnum.recurring) {
      if (_itemNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请输入物品名称')));
        return;
      }

      if (_selectedItemType == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请选择物品类型')));
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final expense = UnifiedExpense(
        id: widget.expense?.id,
        amount: double.parse(_amountController.text),
        category: _selectedCategory!,
        expenseType: _selectedExpenseType.value,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        petId: _selectedPetId,
        petName: _selectedPetName,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        photoPath: null,
        itemName: _selectedExpenseType == ExpenseTypeEnum.recurring
            ? _itemNameController.text.trim()
            : null,
        estimatedEndDate:
            _selectedExpenseType == ExpenseTypeEnum.recurring &&
                _estimatedEndDate != null
            ? DateFormat('yyyy-MM-dd').format(_estimatedEndDate!)
            : null,
        itemType: _selectedExpenseType == ExpenseTypeEnum.recurring
            ? _selectedItemType?.value
            : null,
        createdAt:
            widget.expense?.createdAt ?? DateTime.now().toIso8601String(),
      );

      final supabaseService = SupabaseService();
      bool success = false;
      if (widget.expense == null) {
        // 新增
        final result = await supabaseService.insertUnifiedExpense(expense.toMap());
        if (result != null) {
          success = true;
        }
      } else {
        // 更新
        success = await supabaseService.updateUnifiedExpense(expense.toMap());
      }

      if (!success) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(
            content: Text('保存失败，请检查网络连接'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.expense == null ? '添加成功' : '更新成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(
          content: Text('保存失败，请检查网络连接'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(
          widget.expense == null ? '添加消费' : '编辑消费',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // 支出类型选择
            _buildExpenseTypeSelection(),
            const SizedBox(height: 20),

            // 金额输入
            _buildAmountInput(),
            const SizedBox(height: 20),

            // 分类选择
            _buildCategorySelection(),
            const SizedBox(height: 20),

            // 购买日期选择
            _buildDateSelection(),
            const SizedBox(height: 20),

            // 周期性成本的额外字段
            if (_selectedExpenseType == ExpenseTypeEnum.recurring) ...[
              _buildItemNameInput(),
              const SizedBox(height: 20),
              _buildItemTypeSelection(),
              const SizedBox(height: 20),
              _buildEstimatedEndDateSelection(),
              const SizedBox(height: 20),
            ],

            // 宠物选择
            if (_pets.isNotEmpty) ...[
              _buildPetSelection(),
              const SizedBox(height: 20),
            ],

            // 备注输入
            _buildNoteInput(),
            const SizedBox(height: 32),

            // 保存按钮
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  /// 支出类型选择
  Widget _buildExpenseTypeSelection() {
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '支出类型 *',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildExpenseTypeButton(
                    ExpenseTypeEnum.oneOff,
                    Icons.payments,
                    '一次性支出',
                    '医疗、美容、零食等',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildExpenseTypeButton(
                    ExpenseTypeEnum.recurring,
                    Icons.shopping_cart,
                    '周期性支出',
                    '主粮、用品、装备等',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseTypeButton(
    ExpenseTypeEnum type,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isSelected = _selectedExpenseType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedExpenseType = type;
          _selectedCategory = null; // 重置分类
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF5D5FEF).withOpacity(0.1)
              : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF5D5FEF) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF5D5FEF)
                  : const Color(0xFF8E8E93),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF5D5FEF)
                    : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 金额输入框
  Widget _buildAmountInput() {
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '金额 *',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                prefixText: '¥ ',
                prefixStyle: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D5FEF),
                ),
                border: InputBorder.none,
                hintText: '0.00',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入金额';
                }
                if (double.tryParse(value) == null) {
                  return '请输入有效的金额';
                }
                if (double.parse(value) <= 0) {
                  return '金额必须大于0';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 分类选择
  Widget _buildCategorySelection() {
    final categories = _selectedExpenseType == ExpenseTypeEnum.oneOff
        ? UnifiedExpenseCategory.oneOffCategories
        : UnifiedExpenseCategory.recurringCategories;

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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedExpenseType == ExpenseTypeEnum.oneOff
                  ? '一次性支出分类 *'
                  : '周期性支出分类 *',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: categories.map((category) {
                final isSelected = _selectedCategory == category.name;
                final iconData = IconData(
                  category.icon,
                  fontFamily: 'MaterialIcons',
                );
                final color = Color(category.color);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category.name;
                    });
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.15)
                          : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          iconData,
                          color: isSelected ? color : const Color(0xFF8E8E93),
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? color : const Color(0xFF8E8E93),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 日期选择
  Widget _buildDateSelection() {
    return InkWell(
      onTap: _selectDate,
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
            children: [
              const Icon(
                Icons.calendar_today,
                color: Color(0xFF5D5FEF),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedExpenseType == ExpenseTypeEnum.oneOff
                          ? '消费日期'
                          : '购买日期',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('yyyy年MM月dd日', 'zh_CN').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFF8E8E93),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 物品名称输入（仅周期性成本）
  Widget _buildItemNameInput() {
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '物品名称 *',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _itemNameController,
              decoration: const InputDecoration(
                hintText: '例如：皇家猫粮 K36 4kg',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF5D5FEF), width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 物品类型选择（仅周期性成本）
  Widget _buildItemTypeSelection() {
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '物品类型 *',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildItemTypeButton(
                    ItemTypeEnum.consumable,
                    Icons.inventory,
                    '消耗品',
                    '猫粮、猫砂等',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildItemTypeButton(
                    ItemTypeEnum.durable,
                    Icons.shopping_basket,
                    '耐用品',
                    '猫爬架、饮水机等',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTypeButton(
    ItemTypeEnum type,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isSelected = _selectedItemType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedItemType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF5D5FEF).withOpacity(0.1)
              : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF5D5FEF) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF5D5FEF)
                  : const Color(0xFF8E8E93),
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF5D5FEF)
                    : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 预计用完日期选择（仅周期性成本）
  Widget _buildEstimatedEndDateSelection() {
    return InkWell(
      onTap: _selectEstimatedEndDate,
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
            children: [
              const Icon(
                Icons.event_available,
                color: Color(0xFF5D5FEF),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '用完日期 (选填)',
                      style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _estimatedEndDate == null
                          ? '选填，不填则动态计算日均成本'
                          : DateFormat(
                              'yyyy年MM月dd日',
                              'zh_CN',
                            ).format(_estimatedEndDate!),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _estimatedEndDate == null
                            ? const Color(0xFF8E8E93)
                            : const Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFF8E8E93),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 宠物选择
  Widget _buildPetSelection() {
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '宠物（选填）',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // 不选择宠物
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPetId = null;
                      _selectedPetName = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedPetId == null
                          ? const Color(0xFF5D5FEF).withOpacity(0.15)
                          : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedPetId == null
                            ? const Color(0xFF5D5FEF)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '不指定',
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedPetId == null
                            ? const Color(0xFF5D5FEF)
                            : const Color(0xFF8E8E93),
                        fontWeight: _selectedPetId == null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                ..._pets.map((pet) {
                  final petId = pet['id']?.toString();
                  final isSelected = _selectedPetId == petId;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPetId = petId;
                        _selectedPetName = pet['name'] as String?;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF5D5FEF).withOpacity(0.15)
                            : const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF5D5FEF)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        pet['name'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected
                              ? const Color(0xFF5D5FEF)
                              : const Color(0xFF8E8E93),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 备注输入
  Widget _buildNoteInput() {
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '备注（选填）',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '记录更多细节...',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF5D5FEF), width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 保存按钮
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveExpense,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5D5FEF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : Text(
                widget.expense == null ? '保存' : '更新',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
