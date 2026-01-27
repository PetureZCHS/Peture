import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/unified_expense.dart';
import '../../database/unified_expense_helper.dart';
import '../../services/supabase_service.dart';

class AddUnifiedExpensePage extends StatefulWidget {
  final UnifiedExpense? expense;

  const AddUnifiedExpensePage({super.key, this.expense});

  @override
  State<AddUnifiedExpensePage> createState() => _AddUnifiedExpensePageState();
}

class _AddUnifiedExpensePageState extends State<AddUnifiedExpensePage> {
  // State - Using Feature UI approach
  ExpenseTypeEnum _selectedExpenseType = ExpenseTypeEnum.oneOff;
  String _amountStr = '0.00';
  bool _isTyping = false;
  
  UnifiedExpenseCategory? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  
  // Pet Selection - String for Supabase UUID support
  String? _selectedPetId;
  String? _selectedPetName;
  List<Map<String, dynamic>> _pets = [];
  
  // Note
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();
  bool _isNoteFocused = false;
  
  // Custom Categories
  List<UnifiedExpenseCategory> _customCategories = [];
  
  // Recurring Extra Fields
  final TextEditingController _itemNameController = TextEditingController();
  DateTime? _estimatedEndDate;
  ItemTypeEnum? _selectedItemType;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _noteFocusNode.addListener(_onNoteFocusChange);
    _loadPets();
    _initData();
  }

  void _onNoteFocusChange() {
    setState(() {
      _isNoteFocused = _noteFocusNode.hasFocus;
    });
  }

  void _initData() {
    if (widget.expense != null) {
      _amountStr = widget.expense!.amount.toStringAsFixed(2);
      if (_amountStr.endsWith('.00')) {
         _amountStr = widget.expense!.amount.toStringAsFixed(0);
       } else {
          _amountStr = widget.expense!.amount.toString();
       }
       _isTyping = true;

      _selectedExpenseType = widget.expense!.expenseType == 'one-off'
          ? ExpenseTypeEnum.oneOff
          : ExpenseTypeEnum.recurring;
      
      final categories = _selectedExpenseType == ExpenseTypeEnum.oneOff 
          ? UnifiedExpenseCategory.oneOffCategories 
          : UnifiedExpenseCategory.recurringCategories;
      
      try {
        _selectedCategory = categories.firstWhere((c) => c.name == widget.expense!.category);
      } catch (_) {
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
      _selectedCategory = UnifiedExpenseCategory.oneOffCategories.first;
    }
  }

  @override
  void dispose() {
    _noteFocusNode.removeListener(_onNoteFocusChange);
    _noteFocusNode.dispose();
    _noteController.dispose();
    _itemNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPets() async {
    // Load from Supabase for UUID support
    final supabaseService = SupabaseService();
    final pets = await supabaseService.getAllPets();
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
      lastDate: DateTime.now().add(const Duration(days: 365)), 
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null && picked != _selectedDate) {
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

    if (_selectedExpenseType == ExpenseTypeEnum.recurring) {
      if (_itemNameController.text.trim().isEmpty) {
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
        itemName: _selectedExpenseType == ExpenseTypeEnum.recurring 
            ? (_itemNameController.text.isEmpty ? _selectedCategory!.name : _itemNameController.text) 
            : null,
        estimatedEndDate: _selectedExpenseType == ExpenseTypeEnum.recurring && _estimatedEndDate != null
            ? DateFormat('yyyy-MM-dd').format(_estimatedEndDate!)
            : null,
        itemType: _selectedExpenseType == ExpenseTypeEnum.recurring 
            ? _selectedItemType?.value 
            : null,
        createdAt: widget.expense?.createdAt ?? DateTime.now().toIso8601String(),
        photoPath: null,
      );

      // Dual storage: Local database + Supabase sync
      final supabaseService = SupabaseService();
      bool success = false;
      
      if (widget.expense == null) {
        // 新增 - Save to both local and cloud
        await UnifiedExpenseHelper.instance.insertExpense(expense);
        final result = await supabaseService.insertUnifiedExpense(expense.toMap());
        if (result != null) success = true;
      } else {
        // 更新 - Update both local and cloud
        await UnifiedExpenseHelper.instance.updateExpense(expense);
        success = await supabaseService.updateUnifiedExpense(expense.toMap());
      }

      if (!success) {
        if (mounted) {
           setState(() { _isLoading = false; });
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('云端保存失败，请检查网络连接'), backgroundColor: Colors.orange)
           );
        }
        return;
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _selectedExpenseType == ExpenseTypeEnum.oneOff 
         ? UnifiedExpenseCategory.oneOffCategories 
         : UnifiedExpenseCategory.recurringCategories;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildAccountAndAmount(),
            
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
          
          Text(
            '¥$_amountStr',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF3B30),
              fontFamily: 'Roboto',
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
              leading: const CircleAvatar(child: Icon(Icons.pets)),
              title: Text(pet['name']),
              onTap: () {
                setState(() {
                  _selectedPetId = pet['id']?.toString();
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
                  _selectedPetName = null;
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
    // 合并默认分类和自定义分类
    final allCategories = [...categories, ..._customCategories.where((c) => c.expenseType == _selectedExpenseType)];
    
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: allCategories.length + 1, // +1 for add button
      itemBuilder: (context, index) {
        // 最后一个是添加按钮
        if (index == allCategories.length) {
          return _buildAddCategoryButton();
        }
        
        final cat = allCategories[index];
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
              const SizedBox(height: 6),
              Text(
                cat.name,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Color(cat.color) : const Color(0xFF8E8E93),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddCategoryButton() {
    return GestureDetector(
      onTap: _showAddCategoryDialog,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
            ),
            child: const Icon(
              Icons.add,
              color: Color(0xFF8E8E93),
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '添加',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF8E8E93),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    int selectedColor = 0xFF4FC3F7;
    int selectedIcon = Icons.category.codePoint;
    
    final colors = [
      0xFFFF8A65, 0xFF4FC3F7, 0xFFF06292, 0xFFBA68C8,
      0xFFFFD54F, 0xFF81C784, 0xFF9575CD, 0xFFA1887F,
    ];
    
    final icons = [
      Icons.category, Icons.pets, Icons.favorite, Icons.star,
      Icons.home, Icons.shopping_cart, Icons.local_cafe, Icons.sports_esports,
    ];
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('添加分类'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '分类名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('选择颜色', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: colors.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(color),
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('选择图标', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: icons.map((icon) {
                      final isSelected = selectedIcon == icon.codePoint;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIcon = icon.codePoint),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected ? Color(selectedColor) : const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: isSelected ? Colors.white : Color(selectedColor), size: 20),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
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
                  child: const Text('确定'),
                ),
              ],
            );
          },
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
                  text: '默认账本',
                  onTap: () {}
                ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             alignment: Alignment.centerLeft,
             child: TextField(
               controller: _noteController,
               focusNode: _noteFocusNode,
               textInputAction: TextInputAction.done,
               onSubmitted: (_) {
                 _noteFocusNode.unfocus();
               },
               onTapOutside: (event) {
                 _noteFocusNode.unfocus();
               },
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
          
          if (!_isNoteFocused) _buildKeypad(),
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
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _kBtn('DATE', icon: Icons.calendar_month)),
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
