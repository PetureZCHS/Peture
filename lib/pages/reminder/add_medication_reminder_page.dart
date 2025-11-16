import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/medical_record_helper.dart';
import '../../database/reminder_helper.dart';

/// 添加/编辑用药记录
class AddMedicationReminderPage extends StatefulWidget {
  final Map<String, dynamic>? existingReminder;

  const AddMedicationReminderPage({super.key, this.existingReminder});

  @override
  State<AddMedicationReminderPage> createState() =>
      _AddMedicationReminderPageState();
}

class _AddMedicationReminderPageState extends State<AddMedicationReminderPage> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedPetId;
  String? _selectedPetName;
  final TextEditingController _medNameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  String _frequencyType = 'daily'; // daily / every_x_hours
  final List<TimeOfDay> _dailyTimes = [const TimeOfDay(hour: 9, minute: 0)];
  int _everyXHours = 8;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  final TextEditingController _notesController = TextEditingController();

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
      _medNameController.text = data['med_name'] as String;
      _dosageController.text = data['dosage'] as String;
      _frequencyType = data['frequency_type'] as String;
      _startDate = DateTime.parse(data['start_date'] as String);
      _endDate = DateTime.parse(data['end_date'] as String);
      _notesController.text = data['notes'] as String? ?? '';

      final frequencyDetails = data['frequency_details'] as String;
      if (_frequencyType == 'daily') {
        _dailyTimes.clear();
        for (final timeStr in frequencyDetails.split(',')) {
          final parts = timeStr.split(':');
          _dailyTimes.add(
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
          );
        }
      } else {
        _everyXHours = int.parse(frequencyDetails);
      }
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
      String frequencyDetails;
      if (_frequencyType == 'daily') {
        frequencyDetails = _dailyTimes
            .map((time) {
              return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
            })
            .join(',');
      } else {
        frequencyDetails = _everyXHours.toString();
      }

      final data = {
        'pet_id': _selectedPetId!,
        'pet_name': _selectedPetName!,
        'med_name': _medNameController.text,
        'dosage': _dosageController.text,
        'frequency_type': _frequencyType,
        'frequency_details': frequencyDetails,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
        'status': 'active',
      };

      int medicationId;
      if (widget.existingReminder != null) {
        data['id'] = widget.existingReminder!['id'];
        await ReminderHelper.instance.updateMedicationReminder(data);
        medicationId = widget.existingReminder!['id'] as int;
      } else {
        medicationId = await ReminderHelper.instance.createMedicationReminder(
          data,
        );
      }

      // 生成今日打卡清单
      await ReminderHelper.instance.generateTodayCheckmarks(medicationId);

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
          widget.existingReminder != null ? '编辑用药记录' : '添加用药记录',
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
                    _buildTextField(
                      controller: _medNameController,
                      label: '药品名称 *',
                      hint: '例如：消炎药',
                      validator: (value) =>
                          value?.isEmpty ?? true ? '请输入药品名称' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _dosageController,
                      label: '用药剂量 *',
                      hint: '例如：1片 或 5ml',
                      validator: (value) =>
                          value?.isEmpty ?? true ? '请输入用药剂量' : null,
                    ),
                    const SizedBox(height: 24),
                    _buildFrequencyTypeSelector(),
                    const SizedBox(height: 16),
                    if (_frequencyType == 'daily')
                      _buildDailyTimesSelector()
                    else
                      _buildEveryXHoursSelector(),
                    const SizedBox(height: 24),
                    _buildDateRangeSelector(),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _notesController,
                      label: '备注（选填）',
                      hint: '例如：饭后服用',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPetSelector() {
    return DropdownButtonFormField<int>(
      value: _selectedPetId,
      decoration: const InputDecoration(
        labelText: '选择宠物 *',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildFrequencyTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '用药频率 *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('每日固定时间'),
                value: 'daily',
                groupValue: _frequencyType,
                onChanged: (value) {
                  setState(() {
                    _frequencyType = value!;
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('每隔X小时'),
                value: 'every_x_hours',
                groupValue: _frequencyType,
                onChanged: (value) {
                  setState(() {
                    _frequencyType = value!;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDailyTimesSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '每日用药时间',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          ..._dailyTimes.asMap().entries.map((entry) {
            final index = entry.key;
            final time = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(index),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '第${index + 1}次: ${time.format(context)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Icon(Icons.access_time, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_dailyTimes.length > 1)
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        setState(() {
                          _dailyTimes.removeAt(index);
                        });
                      },
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _dailyTimes.add(const TimeOfDay(hour: 20, minute: 0));
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('添加时间'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyTimes[index],
    );
    if (picked != null) {
      setState(() {
        _dailyTimes[index] = picked;
      });
    }
  }

  Widget _buildEveryXHoursSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const Text('每隔', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: _everyXHours.toString(),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _everyXHours = int.tryParse(value) ?? 8;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          const Text('小时服用一次', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    final days = _endDate.difference(_startDate).inDays + 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '用药周期',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDateButton(
                  label: '开始日期',
                  date: _startDate,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _startDate = picked;
                        if (_endDate.isBefore(_startDate)) {
                          _endDate = _startDate.add(const Duration(days: 7));
                        }
                      });
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.arrow_forward, size: 20),
              ),
              Expanded(
                child: _buildDateButton(
                  label: '结束日期',
                  date: _endDate,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate,
                      firstDate: _startDate,
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _endDate = picked;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '总计 $days 天',
            style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MM/dd').format(date),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
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
        widget.existingReminder != null ? '保存修改' : '创建用药记录',
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
    _medNameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
