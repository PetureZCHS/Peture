import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/medical_record_helper.dart';
import '../../database/reminder_helper.dart';

/// 添加/编辑驱虫提醒
class AddDewormingReminderPage extends StatefulWidget {
  final Map<String, dynamic>? existingReminder;

  const AddDewormingReminderPage({super.key, this.existingReminder});

  @override
  State<AddDewormingReminderPage> createState() =>
      _AddDewormingReminderPageState();
}

class _AddDewormingReminderPageState extends State<AddDewormingReminderPage> {
  final _formKey = GlobalKey<FormState>();

  // 表单字段
  int? _selectedPetId;
  String? _selectedPetName;
  String _dewormingType = 'external'; // internal/external
  final TextEditingController _brandController = TextEditingController();
  DateTime _lastDewormingDate = DateTime.now();
  String _frequency = 'monthly'; // monthly/quarterly/half_yearly/custom
  int _customDays = 30;

  List<Map<String, dynamic>> _pets = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPets();
    _loadExistingData();
  }

  Future<void> _loadPets() async {
    final pets = await MedicalRecordHelper.instance.getAllPets();
    setState(() {
      _pets = pets;
    });
  }

  void _loadExistingData() {
    if (widget.existingReminder != null) {
      final data = widget.existingReminder!;
      _selectedPetId = data['pet_id'] as int;
      _selectedPetName = data['pet_name'] as String;
      _dewormingType = data['type'] as String;
      _brandController.text = data['brand'] as String? ?? '';
      _lastDewormingDate = DateTime.parse(data['last_date'] as String);
      _frequency = data['frequency'] as String;
      _customDays = data['custom_days'] as int? ?? 30;
    }
  }

  DateTime _calculateNextReminderDate() {
    switch (_frequency) {
      case 'monthly':
        return DateTime(
          _lastDewormingDate.year,
          _lastDewormingDate.month + 1,
          _lastDewormingDate.day,
        );
      case 'quarterly':
        return DateTime(
          _lastDewormingDate.year,
          _lastDewormingDate.month + 3,
          _lastDewormingDate.day,
        );
      case 'half_yearly':
        return DateTime(
          _lastDewormingDate.year,
          _lastDewormingDate.month + 6,
          _lastDewormingDate.day,
        );
      case 'custom':
        return _lastDewormingDate.add(Duration(days: _customDays));
      default:
        return _lastDewormingDate.add(const Duration(days: 30));
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
      final nextReminderDate = _calculateNextReminderDate();
      final data = {
        'pet_id': _selectedPetId!,
        'pet_name': _selectedPetName!,
        'type': _dewormingType,
        'brand': _brandController.text.isEmpty ? null : _brandController.text,
        'last_date': _lastDewormingDate.toIso8601String(),
        'next_reminder_date': nextReminderDate.toIso8601String(),
        'frequency': _frequency,
        'custom_days': _customDays,
        'status': 'upcoming',
      };

      if (widget.existingReminder != null) {
        // 更新
        data['id'] = widget.existingReminder!['id'];
        await ReminderHelper.instance.updateDewormingReminder(data);
      } else {
        // 创建
        await ReminderHelper.instance.createDewormingReminder(data);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(
          widget.existingReminder != null ? '编辑驱虫提醒' : '添加驱虫提醒',
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
                    _buildSection(
                      title: '基本信息',
                      children: [
                        _buildPetSelector(),
                        const SizedBox(height: 16),
                        _buildDewormingTypeSelector(),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _brandController,
                          label: '药品品牌（选填）',
                          hint: '例如：福来恩、大宠爱',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      title: '驱虫记录',
                      children: [
                        _buildDateSelector(
                          label: '上次驱虫日期',
                          date: _lastDewormingDate,
                          onChanged: (date) {
                            setState(() {
                              _lastDewormingDate = date;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildFrequencySelector(),
                        if (_frequency == 'custom') ...[
                          const SizedBox(height: 16),
                          _buildCustomDaysInput(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildNextReminderPreview(),
                    const SizedBox(height: 32),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildPetSelector() {
    return DropdownButtonFormField<int>(
      value: _selectedPetId,
      decoration: const InputDecoration(
        labelText: '选择宠物 *',
        border: OutlineInputBorder(),
      ),
      items: _pets.map((pet) {
        return DropdownMenuItem<int>(
          value: pet['id'] as int,
          child: Text(pet['name'] as String),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedPetId = value;
          _selectedPetName =
              _pets.firstWhere((pet) => pet['id'] == value)['name'] as String;
        });
      },
      validator: (value) => value == null ? '请选择宠物' : null,
    );
  }

  Widget _buildDewormingTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '驱虫类型 *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('体外驱虫'),
                value: 'external',
                groupValue: _dewormingType,
                onChanged: (value) {
                  setState(() {
                    _dewormingType = value!;
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('体内驱虫'),
                value: 'internal',
                groupValue: _dewormingType,
                onChanged: (value) {
                  setState(() {
                    _dewormingType = value!;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime date,
    required Function(DateTime) onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('yyyy年MM月dd日').format(date),
              style: const TextStyle(fontSize: 16),
            ),
            const Icon(Icons.calendar_today, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencySelector() {
    return DropdownButtonFormField<String>(
      value: _frequency,
      decoration: const InputDecoration(
        labelText: '驱虫周期 *',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'monthly', child: Text('每月一次')),
        DropdownMenuItem(value: 'quarterly', child: Text('每季度一次')),
        DropdownMenuItem(value: 'half_yearly', child: Text('每半年一次')),
        DropdownMenuItem(value: 'custom', child: Text('自定义周期')),
      ],
      onChanged: (value) {
        setState(() {
          _frequency = value!;
        });
      },
    );
  }

  Widget _buildCustomDaysInput() {
    return TextFormField(
      initialValue: _customDays.toString(),
      decoration: const InputDecoration(
        labelText: '自定义天数',
        hintText: '输入间隔天数',
        border: OutlineInputBorder(),
        suffixText: '天',
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) {
        setState(() {
          _customDays = int.tryParse(value) ?? 30;
        });
      },
    );
  }

  Widget _buildNextReminderPreview() {
    final nextDate = _calculateNextReminderDate();
    final daysUntil = nextDate.difference(DateTime.now()).inDays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFFFC107)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '下次提醒日期',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('yyyy年MM月dd日').format(nextDate),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '距今 $daysUntil 天',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
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
        widget.existingReminder != null ? '保存修改' : '创建提醒',
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
    _brandController.dispose();
    super.dispose();
  }
}
