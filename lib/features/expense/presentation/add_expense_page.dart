import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/page_tracker_mixin.dart';
import '../../../shared/utils/loading_guard_mixin.dart';
import '../../../shared/models/expense.dart';
import '../../../services/supabase_service.dart';

/// 添加/编辑账单页面
class AddExpensePage extends StatefulWidget {
  final Expense? expense; // 如果是编辑模式，传入现有账单

  const AddExpensePage({super.key, this.expense});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage>
    with LoadingGuardMixin, PageTrackerMixin<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  int? _selectedPetId;
  String? _selectedPetName;
  List<Map<String, dynamic>> _pets = [];
  bool _isLoading = false;

  @override
  String get analyticsPageName => 'expense_add';

  @override
  void initState() {
    super.initState();
    _loadPets();
    if (widget.expense != null) {
      // 编辑模式，填充现有数据
      _amountController.text = widget.expense!.amount.toString();
      _selectedCategory = widget.expense!.category;
      _selectedDate = DateTime.parse(widget.expense!.date);
      _selectedPetId = widget.expense!.petId;
      _selectedPetName = widget.expense!.petName;
      _noteController.text = widget.expense!.note ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5D5FEF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1A1A1A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// 保存账单
  Future<void> _saveExpense() async {
    await runWithLoadingFlag(
      isLoading: _isLoading,
      assign: (v) => _isLoading = v,
      action: () async {
        if (!_formKey.currentState!.validate()) {
          return;
        }

        if (_selectedCategory == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('请选择消费分类')));
          return;
        }

        try {
          final expense = Expense(
            id: widget.expense?.id,
            amount: double.parse(_amountController.text),
            category: _selectedCategory!,
            date: DateFormat('yyyy-MM-dd').format(_selectedDate),
            petId: _selectedPetId,
            petName: _selectedPetName,
            note: _noteController.text.isEmpty ? null : _noteController.text,
            photoPath: null,
            createdAt:
                widget.expense?.createdAt ?? DateTime.now().toIso8601String(),
          );

          final supabaseService = SupabaseService();
          bool success = false;
          if (widget.expense == null) {
            final result = await supabaseService.insertExpense(expense.toMap());
            if (result != null) {
              success = true;
            }
          } else {
            success = await supabaseService.updateExpense(expense.toMap());
          }

          if (!success) {
            if (mounted) {
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
              SnackBar(content: Text(widget.expense == null ? '账单已添加' : '账单已更新')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(
              content: Text('保存失败，请检查网络连接'),
              backgroundColor: Colors.red,
            ));
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(
          widget.expense == null ? '添加账单' : '编辑账单',
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
        actions: [
          if (widget.expense != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('确认删除'),
                    content: const Text('确定要删除这笔账单吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && widget.expense!.id != null) {
                  final supabaseService = SupabaseService();
                  await supabaseService.deleteExpense(widget.expense!.id!);
                  if (context.mounted) {
                    Navigator.pop(context, true);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('账单已删除')));
                  }
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // 金额输入
            _buildAmountInput(),
            const SizedBox(height: 20),

            // 分类选择
            _buildCategorySelection(),
            const SizedBox(height: 20),

            // 日期选择
            _buildDateSelection(),
            const SizedBox(height: 20),

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
              '分类 *',
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
              children: ExpenseCategory.defaultCategories.map((category) {
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
                            fontSize: 12,
                            color: isSelected ? color : const Color(0xFF8E8E93),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
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
                    const Text(
                      '日期',
                      style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
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
                  final isSelected = _selectedPetId == pet['id'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPetId = pet['id'] as int;
                        _selectedPetName = pet['name'] as String;
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
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
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
                widget.expense == null ? '保存账单' : '更新账单',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
