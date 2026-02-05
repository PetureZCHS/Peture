import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';

/// 添加/编辑疫苗提醒
class AddVaccineReminderPage extends StatefulWidget {
  final Map<String, dynamic>? existingReminder;

  const AddVaccineReminderPage({super.key, this.existingReminder});

  @override
  State<AddVaccineReminderPage> createState() => _AddVaccineReminderPageState();
}

class _AddVaccineReminderPageState extends State<AddVaccineReminderPage> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedPetId;
  String? _selectedPetName;
  String _vaccineName = '';
  DateTime _injectionDate = DateTime.now();
  String _doseType = 'first';
  DateTime? _nextDueDate;
  final TextEditingController _notesController = TextEditingController();

  List<Map<String, dynamic>> _pets = [];
  bool _isLoading = false;
  bool _useTemplate = false;
  final SupabaseService _supabaseService = SupabaseService();

  final List<String> _commonVaccines = ['猫三联', '狂犬疫苗', '犬八联', '犬六联', '自定义'];

  @override
  void initState() {
    super.initState();
    _loadPets();
    _loadExistingData();
  }

  Future<void> _loadPets() async {
    final pets = await _supabaseService.getAllPets();
    if (!mounted) return;
    setState(() {
      _pets = pets;
    });
  }

  void _loadExistingData() {
    if (widget.existingReminder != null) {
      final data = widget.existingReminder!;
      _selectedPetId = data['pet_id'] as String?;
      _selectedPetName = data['pet_name'] as String?;
      _vaccineName = data['vaccine_name'] as String;
      _injectionDate = DateTime.parse(data['injection_date'] as String);
      _doseType = data['dose_type'] as String;
      if (data['next_due_date'] != null) {
        _nextDueDate = DateTime.parse(data['next_due_date'] as String);
      }
      _notesController.text = data['notes'] as String? ?? '';
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPetId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择宠物')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_useTemplate) {
        // 使用智能模板创建疫苗计划
        final templateSuccess = await _createVaccineTemplate();
        if (!templateSuccess) {
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
      } else {
        // 创建单个疫苗记录
        final data = {
          'pet_id': _selectedPetId!,
          'pet_name': _selectedPetName!,
          'vaccine_name': _vaccineName,
          'injection_date': _injectionDate.toIso8601String(),
          'dose_type': _doseType,
          'next_due_date': _nextDueDate?.toIso8601String(),
          'notes': _notesController.text.isEmpty ? null : _notesController.text,
          'status': 'upcoming',
        };

        bool success = false;
        if (widget.existingReminder != null) {
          data['id'] = widget.existingReminder!['id'];
          success = await _supabaseService.updateVaccineReminder(data);
        } else {
          final result = await _supabaseService.insertVaccineReminder(data);
          success = result != null;
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _createVaccineTemplate() async {
    // 这里可按宠物类型决定模板，目前仅演示单条插入

    // 简单判断是否幼宠（目前未使用，可按需拓展逻辑）

    final result = await _supabaseService.insertVaccineReminder({
      'pet_id': _selectedPetId,
      'pet_name': _selectedPetName,
      'vaccine_name': _vaccineName,
      'injection_date': _injectionDate.toIso8601String(),
      'dose_type': _doseType,
      'next_due_date':
          _injectionDate.add(const Duration(days: 21)).toIso8601String(),
      'notes': _notesController.text.isEmpty ? null : _notesController.text,
      'status': 'upcoming',
    });
    return result != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(
          widget.existingReminder != null ? '编辑疫苗提醒' : '添加疫苗提醒',
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPetSelector(),
                    const SizedBox(height: 16),
                    _buildVaccineNameSelector(),
                    const SizedBox(height: 16),
                    _buildDateSelector(
                      label: '接种日期 *',
                      date: _injectionDate,
                      onChanged: (date) {
                        setState(() {
                          _injectionDate = date;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDoseTypeSelector(),
                    const SizedBox(height: 16),
                    if (_nextDueDate != null)
                      Column(
                        children: [
                          _buildDateSelector(
                            label: '下次接种日期',
                            date: _nextDueDate!,
                            onChanged: (date) {
                              setState(() {
                                _nextDueDate = date;
                              });
                            },
                            allowClear: true,
                          ),
                          const SizedBox(height: 16),
                        ],
                      )
                    else
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _nextDueDate = _injectionDate.add(
                              const Duration(days: 21),
                            );
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('设置下次接种日期'),
                      ),
                    const SizedBox(height: 16),
                    _buildNotesField(),
                    const SizedBox(height: 24),
                    if (widget.existingReminder == null) _buildTemplateSwitch(),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPetSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedPetId,
      decoration: const InputDecoration(
        labelText: '选择宠物 *',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _pets
          .map((pet) => DropdownMenuItem<String>(
                value: pet['id']?.toString(),
                child: Text(pet['name'] as String),
              ))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedPetId = value;
          _selectedPetName =
              _pets.firstWhere((pet) => pet['id']?.toString() == value)['name']
                  as String;
        });
      },
      validator: (value) => value == null ? '请选择宠物' : null,
    );
  }

  Widget _buildVaccineNameSelector() {
    return DropdownButtonFormField<String>(
      value: _commonVaccines.contains(_vaccineName) ? _vaccineName : '自定义',
      decoration: const InputDecoration(
        labelText: '疫苗名称 *',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _commonVaccines.map((vaccine) {
        return DropdownMenuItem<String>(value: vaccine, child: Text(vaccine));
      }).toList(),
      onChanged: (value) {
        setState(() {
          if (value == '自定义') {
            _showCustomVaccineDialog();
          } else {
            _vaccineName = value!;
          }
        });
      },
      validator: (value) => _vaccineName.isEmpty ? '请选择疫苗名称' : null,
    );
  }

  Future<void> _showCustomVaccineDialog() async {
    final controller = TextEditingController(text: _vaccineName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义疫苗名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '疫苗名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _vaccineName = result;
      });
    }
  }

  Widget _buildDoseTypeSelector() {
    return DropdownButtonFormField<String>(
      value: _doseType,
      decoration: const InputDecoration(
        labelText: '针次类型 *',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      items: const [
        DropdownMenuItem(value: 'first', child: Text('首次接种')),
        DropdownMenuItem(value: 'second', child: Text('第二针')),
        DropdownMenuItem(value: 'third', child: Text('第三针')),
        DropdownMenuItem(value: 'booster', child: Text('加强针')),
        DropdownMenuItem(value: 'annual', child: Text('年度加强')),
      ],
      onChanged: (value) {
        setState(() {
          _doseType = value!;
        });
      },
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime date,
    required Function(DateTime) onChanged,
    bool allowClear = false,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('yyyy年MM月dd日').format(date),
              style: const TextStyle(fontSize: 16),
            ),
            Row(
              children: [
                if (allowClear)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      setState(() {
                        _nextDueDate = null;
                      });
                    },
                  ),
                const Icon(Icons.calendar_today, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: const InputDecoration(
        labelText: '备注（选填）',
        hintText: '例如：在XX医院接种，医生XXX',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      maxLines: 3,
    );
  }

  Widget _buildTemplateSwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF4CAF50)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '使用智能模板',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '自动生成3针疫苗计划',
                  style: TextStyle(fontSize: 13, color: Color(0xFF4CAF50)),
                ),
              ],
            ),
          ),
          Switch(
            value: _useTemplate,
            onChanged: (value) {
              setState(() {
                _useTemplate = value;
              });
            },
            activeColor: const Color(0xFF4CAF50),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _saveReminder,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF5D5FEF),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        _useTemplate
            ? '创建疫苗计划'
            : (widget.existingReminder != null ? '保存修改' : '创建提醒'),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
