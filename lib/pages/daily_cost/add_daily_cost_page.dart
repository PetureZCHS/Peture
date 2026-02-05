import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/daily_cost_item.dart';
import '../../models/pet.dart';
import '../../services/supabase_service.dart';

/// 添加/编辑日均成本项目页面
class AddDailyCostPage extends StatefulWidget {
  final DailyCostItem? item; // 如果传入，则为编辑模式

  const AddDailyCostPage({super.key, this.item});

  @override
  State<AddDailyCostPage> createState() => _AddDailyCostPageState();
}

class _AddDailyCostPageState extends State<AddDailyCostPage> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _totalPriceController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime? _purchaseDate;
  DateTime? _finishDate;
  Pet? _selectedPet;
  String? _imagePath;

  List<Pet> _availablePets = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPets();

    // 如果是编辑模式，填充现有数据
    if (widget.item != null) {
      _itemNameController.text = widget.item!.itemName;
      _totalPriceController.text = widget.item!.totalPrice.toString();
      _noteController.text = widget.item!.note ?? '';
      _purchaseDate = DateTime.parse(widget.item!.purchaseDate);
      if (widget.item!.finishDate != null) {
        _finishDate = DateTime.parse(widget.item!.finishDate!);
      }
      _imagePath = widget.item!.imagePath;
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _totalPriceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 加载宠物列表
  Future<void> _loadPets() async {
    try {
      final supabaseService = SupabaseService();
      final petsData = await supabaseService.getAllPets();
      final pets = petsData.map((petMap) => Pet.fromMap(petMap)).toList();

      setState(() {
        _availablePets = pets;

        // 如果是编辑模式，设置已选择的宠物
        if (widget.item != null && widget.item!.petId != null) {
          _selectedPet = pets.firstWhere(
            (pet) => pet.id == widget.item!.petId,
            orElse: () => pets.first,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载宠物列表失败: $e')));
      }
    }
  }

  /// 选择购买日期
  Future<void> _selectPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null) {
      setState(() {
        _purchaseDate = picked;
      });
    }
  }

  /// 选择用完日期
  Future<void> _selectFinishDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _finishDate ?? DateTime.now(),
      firstDate: _purchaseDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 未来10年
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null) {
      setState(() {
        _finishDate = picked;
      });
    }
  }

  /// 选择图片
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  /// 保存记录
  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_purchaseDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择购买日期')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final item = DailyCostItem(
        id: widget.item?.id,
        itemName: _itemNameController.text.trim(),
        totalPrice: double.parse(_totalPriceController.text),
        purchaseDate: DateFormat('yyyy-MM-dd').format(_purchaseDate!),
        finishDate: _finishDate != null
            ? DateFormat('yyyy-MM-dd').format(_finishDate!)
            : null,
        petId: _selectedPet?.id,
        petName: _selectedPet?.name,
        imagePath: _imagePath,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        createdAt: widget.item?.createdAt ?? DateTime.now().toIso8601String(),
      );

      final supabaseService = SupabaseService();
      bool success = false;
      if (widget.item == null) {
        // 新增
        final result = await supabaseService.insertDailyCostItem(item.toMap());
        if (result != null) {
          success = true;
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('添加成功')));
          }
        }
      } else {
        // 编辑
        success = await supabaseService.updateDailyCostItem(item.toMap());
        if (success && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('更新成功')));
        }
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(
          widget.item == null ? '添加消费品' : '编辑消费品',
          style: const TextStyle(
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
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveItem,
              child: const Text(
                '保存',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D5FEF),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 物品名称
              _buildSectionTitle('物品名称 *'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _itemNameController,
                hintText: '例如：皇家猫粮 K36 4kg',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入物品名称';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // 总价格
              _buildSectionTitle('总价格 (¥) *'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _totalPriceController,
                hintText: '0.00',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入总价格';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return '请输入有效的价格';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // 购买日期
              _buildSectionTitle('购买日期 *'),
              const SizedBox(height: 8),
              _buildDateSelector(
                label: _purchaseDate == null
                    ? '选择购买日期'
                    : DateFormat('yyyy年MM月dd日').format(_purchaseDate!),
                onTap: _selectPurchaseDate,
                icon: Icons.calendar_today,
              ),

              const SizedBox(height: 24),

              // 用完日期
              _buildSectionTitle('用完日期（可选）'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDateSelector(
                      label: _finishDate == null
                          ? '选择用完日期'
                          : DateFormat('yyyy年MM月dd日').format(_finishDate!),
                      onTap: _selectFinishDate,
                      icon: Icons.event_available,
                    ),
                  ),
                  if (_finishDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _finishDate = null;
                        });
                      },
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),

              // 关联宠物
              _buildSectionTitle('关联宠物'),
              const SizedBox(height: 8),
              _buildPetSelector(),

              const SizedBox(height: 24),

              // 物品图片
              _buildSectionTitle('物品图片（可选）'),
              const SizedBox(height: 8),
              _buildImagePicker(),

              const SizedBox(height: 24),

              // 备注
              _buildSectionTitle('备注（可选）'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _noteController,
                hintText: '填写额外信息...',
                maxLines: 3,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
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
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF5D5FEF), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
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
    );
  }

  Widget _buildPetSelector() {
    if (_availablePets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('还没有添加宠物档案，请先添加宠物', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      );
    }

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
      child: DropdownButtonFormField<Pet>(
        value: _selectedPet,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.pets, color: Color(0xFF5D5FEF)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        hint: const Text('选择关联的宠物'),
        items: _availablePets.map((Pet pet) {
          return DropdownMenuItem<Pet>(
            value: pet,
            child: Text(
              '${pet.name} (${pet.type})',
              style: const TextStyle(fontSize: 15),
            ),
          );
        }).toList(),
        onChanged: (Pet? newValue) {
          setState(() {
            _selectedPet = newValue;
          });
        },
      ),
    );
  }

  Widget _buildImagePicker() {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 120,
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
        child: _imagePath == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 40,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '点击上传图片',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_imagePath!),
                      width: double.infinity,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      radius: 16,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _imagePath = null;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
