import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/unified_expense.dart';
import '../../database/unified_expense_helper.dart';
import '../../database/medical_record_helper.dart';

class AddUnifiedExpensePage extends StatefulWidget {
  final UnifiedExpense? expense;

  const AddUnifiedExpensePage({super.key, this.expense});

  @override
  State<AddUnifiedExpensePage> createState() => _AddUnifiedExpensePageState();
}

class _AddUnifiedExpensePageState extends State<AddUnifiedExpensePage> {
  // State
  ExpenseTypeEnum _selectedExpenseType = ExpenseTypeEnum.oneOff;
  String _amountStr = '0.00';
  bool _isTyping = false; // To handle initial clear on first tap
  
  UnifiedExpenseCategory? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  
  // Pet Selection
  int? _selectedPetId;
  String? _selectedPetName;
  List<Map<String, dynamic>> _pets = [];
  
  // Note
  final TextEditingController _noteController = TextEditingController();
  
  // Recurring Extra Fields
  final TextEditingController _itemNameController = TextEditingController();
  DateTime? _estimatedEndDate;
  ItemTypeEnum? _selectedItemType; // Default consumable for recurring

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPets();
    _initData();
  }

  void _initData() {
    if (widget.expense != null) {
      _amountStr = widget.expense!.amount.toStringAsFixed(2);
      // Remove trailing .00 if needed for better display editing but usually keep formatted
       if (_amountStr.endsWith('.00')) {
         _amountStr = widget.expense!.amount.toStringAsFixed(0);
       } else {
          _amountStr = widget.expense!.amount.toString();
       }
       _isTyping = true; // Don't clear on click

      _selectedExpenseType = widget.expense!.expenseType == 'one-off'
          ? ExpenseTypeEnum.oneOff
          : ExpenseTypeEnum.recurring;
      
      // Find category object
      final categories = _selectedExpenseType == ExpenseTypeEnum.oneOff 
          ? UnifiedExpenseCategory.oneOffCategories 
          : UnifiedExpenseCategory.recurringCategories;
      
      try {
        _selectedCategory = categories.firstWhere((c) => c.name == widget.expense!.category);
      } catch (_) {
        // Fallback or use by name if custom
        _selectedCategory = UnifiedExpenseCategory(
          name: widget.expense!.category, 
          icon: Icons.category.codePoint, 
          color: Colors.grey.value, 
          expenseType: _selectedExpenseType
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
      // Defaults
      _selectedCategory = UnifiedExpenseCategory.oneOffCategories.first;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _itemNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPets() async {
    final pets = await MedicalRecordHelper.instance.getAllPets();
    if (mounted) {
      setState(() {
        _pets = pets;
      });
    }
  }

  void _onKeypadTap(String value) {
    setState(() {
      if (value == 'DEL') {
        if (_amountStr.isNotEmpty) {
           if (_amountStr.length == 1) {
             _amountStr = '0.00';
             _isTyping = false;
           } else {
             _amountStr = _amountStr.substring(0, _amountStr.length - 1);
           }
        }
      } else if (value == 'DATE') {
        _selectDate();
      } else if (value == 'OK') {
        _saveExpense();
      } else {
        // Number or Dot
        if (!_isTyping) {
          if (value == '.') {
            _amountStr = '0.';
          } else {
            _amountStr = value;
          }
          _isTyping = true;
        } else {
          if (value == '.' && _amountStr.contains('.')) return;
          // Prevent too many decimals
          if (_amountStr.contains('.')) {
             final parts = _amountStr.split('.');
             if (parts.length > 1 && parts[1].length >= 2) return;
          }
          _amountStr += value;
        }
      }
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)), // Allow future for Recurring?
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  Future<void> _saveExpense() async {
    if (_selectedCategory == null) return;
    
    double amount = double.tryParse(_amountStr) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入金额')));
      return;
    }

    // Recurring Checks
    if (_selectedExpenseType == ExpenseTypeEnum.recurring) {
      if (_itemNameController.text.trim().isEmpty) {
        // If empty, auto-use category name or note, but better ask user
        // For simplicity, auto-use category name if note is also empty
        _itemNameController.text = _selectedCategory!.name;
      }
      if (_selectedItemType == null) {
        _selectedItemType = ItemTypeEnum.consumable;
      }
    }

    setState(() { _isLoading = true; });

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
        itemName: _selectedExpenseType == ExpenseTypeEnum.recurring ? (_itemNameController.text.isEmpty ? _selectedCategory!.name : _itemNameController.text) : null,
        estimatedEndDate: _estimatedEndDate != null ? DateFormat('yyyy-MM-dd').format(_estimatedEndDate!) : null,
        itemType: _selectedExpenseType == ExpenseTypeEnum.recurring ? _selectedItemType?.value : null,
        createdAt: widget.expense?.createdAt ?? DateTime.now().toIso8601String(),
        photoPath: null, 
      );

      if (widget.expense == null) {
        await UnifiedExpenseHelper.instance.insertExpense(expense);
      } else {
        await UnifiedExpenseHelper.instance.updateExpense(expense);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Current visible categories
    final categories = _selectedExpenseType == ExpenseTypeEnum.oneOff 
         ? UnifiedExpenseCategory.oneOffCategories 
         : UnifiedExpenseCategory.recurringCategories;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Custom Top Bar + Type Switcher
            _buildTopBar(),

            // 2. Account Selector & Amount Display
            _buildAccountAndAmount(),
            
            // 3. Category Grid (Expanded)
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
                  ]
                ),
                child: Column(
                  children: [
                    Expanded(child: _buildCategoryGrid(categories)),
                    _buildInputArea(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 28, color: Color(0xFF1C1C1E)),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _buildTypeTab('普通支出', ExpenseTypeEnum.oneOff),
                _buildTypeTab('周期支出', ExpenseTypeEnum.recurring),
              ],
            ),
          ),
          const SizedBox(width: 48), // Balance for back button
        ],
      ),
    );
  }

  Widget _buildTypeTab(String label, ExpenseTypeEnum type) {
    final isSelected = _selectedExpenseType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedExpenseType = type;
          // Reset category if not found in new type
          final newCats = type == ExpenseTypeEnum.oneOff 
              ? UnifiedExpenseCategory.oneOffCategories 
              : UnifiedExpenseCategory.recurringCategories;
          if (!newCats.any((c) => c.name == _selectedCategory?.name)) {
            _selectedCategory = newCats.first;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? const Color(0xFF1C1C1E) : const Color(0xFF8E8E93),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountAndAmount() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Account Selector
          GestureDetector(
             onTap: _showPetSelector,
             child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(_selectedPetName ?? '选择宠物', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down_rounded, size: 20, color: Color(0xFF1C1C1E)),
                  ],
                ),
             ),
          ),
          
          // Amount
          Text(
            '¥$_amountStr',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF3B30),
              fontFamily: 'Roboto', // Or system
            ),
          ),
        ],
      ),
    );
  }

  void _showPetSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('选择消费对象', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (_pets.isEmpty)
               const Padding(
                 padding: EdgeInsets.all(20),
                 child: Text('暂无宠物，请先去添加宠物档案'),
               ),
            ..._pets.map((pet) => ListTile(
              leading: const CircleAvatar(child: Icon(Icons.pets)), // Should use photo
              title: Text(pet['name']),
              onTap: () {
                setState(() {
                  _selectedPetId = pet['id'];
                  _selectedPetName = pet['name'];
                });
                Navigator.pop(context);
              },
            )),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('公共/家庭支出'),
              onTap: () {
                setState(() {
                  _selectedPetId = null;
                  _selectedPetName = null; // null means generic
                });
                 Navigator.pop(context);
              },
            )
          ],
        );
      }
    );
  }

  Widget _buildCategoryGrid(List<UnifiedExpenseCategory> categories) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = _selectedCategory?.name == cat.name;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected ? Color(cat.color) : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  IconData(cat.icon, fontFamily: 'MaterialIcons'),
                  color: isSelected ? Colors.white : Color(cat.color),
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                cat.name,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Color(cat.color) : const Color(0xFF8E8E93),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Options Row
          Container(
            height: 44,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF2F2F7))),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildSmallChip(
                  icon: Icons.calendar_today_rounded, 
                  text: DateFormat('MM/dd').format(_selectedDate),
                  onTap: _selectDate
                ),
                const SizedBox(width: 8),
                _buildSmallChip(
                  icon: Icons.book_rounded, 
                  text: '默认账本', // Placeholder
                  onTap: () {}
                ),
                // Only show item name input for recurring
                if (_selectedExpenseType == ExpenseTypeEnum.recurring) ...[
                   const SizedBox(width: 8),
                   GestureDetector(
                     onTap: () {
                         showDialog(context: context, builder: (c) => AlertDialog(
                           title: const Text('物品名称'),
                           content: TextField(
                             controller: _itemNameController,
                             decoration: const InputDecoration(hintText: '例如: 皇家猫粮10kg'),
                           ),
                           actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('确定'))],
                         ));
                     },
                     child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration( color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(14)),
                      child: Text(_itemNameController.text.isEmpty ? '输入物品名' : _itemNameController.text, style: const TextStyle(fontSize: 13, color: Color(0xFF1C1C1E))),
                     ),
                   )
                ]
              ],
            ),
          ),
          
          // Remarks
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             alignment: Alignment.centerLeft,
             child: TextField(
               controller: _noteController,
               decoration: const InputDecoration(
                 hintText: '添加备注...',
                 border: InputBorder.none,
                 isDense: true,
                 icon: Icon(Icons.edit_note_rounded, color: Color(0xFFC7C7CC)),
               ),
               style: const TextStyle(fontSize: 15),
             ),
          ),
          
          const Divider(height: 1, color: Color(0xFFF2F2F7)),
          
          // Keypad
          _buildKeypad(),
        ],
      ),
    );
  }

  Widget _buildSmallChip({required IconData icon, required String text, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF636366)),
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF1C1C1E))),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      height: 260,
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          // Numbers Area (3/4 width)
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(child: Row(children: [_kBtn('7'), _kBtn('8'), _kBtn('9')])),
                Expanded(child: Row(children: [_kBtn('4'), _kBtn('5'), _kBtn('6')])),
                Expanded(child: Row(children: [_kBtn('1'), _kBtn('2'), _kBtn('3')])),
                Expanded(child: Row(children: [_kBtn('.'), _kBtn('0'), _kBtn('DEL', icon: Icons.backspace_outlined)])),
              ],
            ),
          ),
          // Action Area (1/4 width)
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _kBtn('DATE', icon: Icons.calendar_month)), // Or other functional key
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _saveExpense,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('保存', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kBtn(String value, {IconData? icon}) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _onKeypadTap(value),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            // boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2)]
          ),
          child: Center(
             child: icon != null 
               ? Icon(icon, color: const Color(0xFF1C1C1E))
               : Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Color(0xFF1C1C1E))),
          ),
        ),
      ),
    );
  }
}
