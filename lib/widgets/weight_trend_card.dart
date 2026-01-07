import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../utils/ui_helpers.dart';

class WeightTrendCard extends StatefulWidget {
  const WeightTrendCard({super.key});

  @override
  State<WeightTrendCard> createState() => _WeightTrendCardState();
}

class _WeightTrendCardState extends State<WeightTrendCard> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isExpanded = false; // 控制折叠状态
  int _selectedTimeRangeIndex = 2; // Default to "Month" (index 2)
  final List<String> _timeRanges = ['日', '周', '月', '6个月', '年'];
  
  String _currentPetId = '';
  String _currentPetName = '';
  List<Map<String, dynamic>> _allPets = [];
  List<Map<String, dynamic>> _allWeightRecords = [];
  
  // Chart Data
  List<FlSpot> _chartSpots = [];
  double _averageWeight = 0.0;
  String _dateRangeText = '';
  double _minY = 0;
  double _maxY = 100;
  DateTime _currentStartDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    try {
      // 1. Get Pets
      final pets = await _supabaseService.getAllPets();
      if (pets.isNotEmpty) {
        // Store all pets and default to first pet
        _allPets = pets;
        _currentPetId = pets.first['id'] as String;
        _currentPetName = pets.first['name'] as String;
        
        // 2. Get Weight Records
        await _refreshWeightRecords();
      } else {
        // No pets
        if (mounted) {
          setState(() {
          });
        }
      }
    } catch (e) {
      print('Error loading weight data: $e');
      if (mounted) setState(() {});
    }
  }

  Future<void> _refreshWeightRecords() async {
    if (_currentPetId.isEmpty) return;
    
    final records = await _supabaseService.getWeightRecordsForPet(_currentPetId);
    // Sort by date ascending
    records.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
    
    if (mounted) {
      setState(() {
        _allWeightRecords = records;
        _processData();
      });
    }
  }

  void _processData() {
    if (_allWeightRecords.isEmpty) {
      _resetChartData();
      return;
    }

    final now = DateTime.now();
    DateTime startDate;
    
    // Determine start date based on range
    switch (_selectedTimeRangeIndex) {
      case 0: // Day (Today)
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 1: // Week (Last 7 days)
        startDate = now.subtract(const Duration(days: 6));
        break;
      case 2: // Month (Last 30 days)
        startDate = now.subtract(const Duration(days: 29));
        break;
      case 3: // 6 Months
        startDate = DateTime(now.year, now.month - 5, now.day);
        break;
      case 4: // Year
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = now.subtract(const Duration(days: 29));
    }
    _currentStartDate = startDate;

    // Filter records
    final filteredRecords = _allWeightRecords.where((r) {
      final date = DateTime.parse(r['date']);
      final endOfNow = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return date.isAfter(startDate.subtract(const Duration(seconds: 1))) && date.isBefore(endOfNow);
    }).toList();

    if (filteredRecords.isEmpty) {
      _resetChartData();
      _dateRangeText = _formatDateRange(startDate, now);
      return;
    }

    // Generate Spots
    List<FlSpot> spots = [];
    Map<int, List<double>> groupedData = {};
    
    for (var r in filteredRecords) {
      final date = DateTime.parse(r['date']);
      final weight = (r['weight'] as num).toDouble();
      int key;
      
      if (_selectedTimeRangeIndex == 0) {
        key = date.hour; // Group by hour
      } else if (_selectedTimeRangeIndex == 1 || _selectedTimeRangeIndex == 2) {
        key = date.difference(startDate).inDays; // Group by day offset
      } else {
        // 6M, Year: Group by month offset
        key = (date.year - startDate.year) * 12 + date.month - startDate.month;
      }
      
      groupedData.putIfAbsent(key, () => []).add(weight);
    }
    
    final sortedKeys = groupedData.keys.toList()..sort();
    
    for (var key in sortedKeys) {
      final weights = groupedData[key]!;
      final avg = weights.reduce((a, b) => a + b) / weights.length;
      spots.add(FlSpot(key.toDouble(), avg));
    }
    
    _chartSpots = spots;
    
    // Calculate Average
    double totalWeight = filteredRecords.fold(0.0, (sum, r) => sum + (r['weight'] as num).toDouble());
    _averageWeight = totalWeight / filteredRecords.length;

    // Min/Max Y
    if (spots.isNotEmpty) {
      double minW = spots.map((s) => s.y).reduce(math.min);
      double maxW = spots.map((s) => s.y).reduce(math.max);
      _minY = (minW - 2).floorToDouble();
      _maxY = (maxW + 2).ceilToDouble();
      if (_minY < 0) _minY = 0;
    } else {
      _minY = 0;
      _maxY = 100;
    }

    // Date Range Text
    _dateRangeText = _formatDateRange(startDate, now);
  }

  void _resetChartData() {
    _chartSpots = [];
    _averageWeight = 0.0;
    _dateRangeText = '';
    _minY = 0;
    _maxY = 100;
  }

  String _formatDateRange(DateTime start, DateTime end) {
    final fmt = DateFormat('yyyy年MM月dd日');
    return '${fmt.format(start)}至${fmt.format(end)}';
  }

  Future<void> _showPetSelector() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择宠物',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 20),
            ListView.builder(
              shrinkWrap: true,
              itemCount: _allPets.length,
              itemBuilder: (context, index) {
                final pet = _allPets[index];
                final petId = pet['id'] as String;
                final petName = pet['name'] as String;
                final isSelected = petId == _currentPetId;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentPetId = petId;
                      _currentPetName = petName;
                    });
                    _refreshWeightRecords();
                    Navigator.pop(context);
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF2F2F7) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected 
                          ? Border.all(color: const Color(0xFFBF5AF2), width: 2)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          petName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFFBF5AF2),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddWeightDialog() async {
    if (_currentPetId.isEmpty) return;
    
    final TextEditingController weightController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('记录体重', style: TextStyle(color: Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: '体重 (kg)',
                labelStyle: TextStyle(color: Colors.grey),
                suffixText: 'kg',
                suffixStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFBF5AF2))),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('日期', style: TextStyle(color: Colors.grey)),
              trailing: Text(
                DateFormat('yyyy-MM-dd').format(selectedDate),
                style: const TextStyle(color: Colors.black),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Color(0xFFBF5AF2),
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: Colors.black,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  selectedDate = picked;
                  (context as Element).markNeedsBuild(); // Force rebuild to update date text
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final weight = double.tryParse(weightController.text);
              if (weight != null) {
                await _supabaseService.insertWeightRecord({
                  'pet_id': _currentPetId,
                  'weight': weight,
                  'date': selectedDate.toIso8601String(),
                });
                if (mounted) {
                  Navigator.pop(context);
                  _refreshWeightRecords();
                }
              }
            },
            child: const Text('保存', style: TextStyle(color: Color(0xFFBF5AF2))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8), // Removed to let parent control spacing
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.8),
                  Colors.white.withOpacity(0.4),
                ],
              ),
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部标题栏
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                      HapticFeedback.selectionClick();
                    },
                    behavior: HitTestBehavior.translucent,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.monitor_weight_rounded,
                            color: Color(0xFFBF5AF2),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '体重趋势',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            if (_allPets.length > 1)
                              GestureDetector(
                                onTap: _showPetSelector,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F2F7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _currentPetName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF8E8E93),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.expand_more,
                                        size: 16,
                                        color: Color(0xFFBF5AF2),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else if (_currentPetName.isNotEmpty)
                              Text(
                                _currentPetName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8E8E93),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, size: 20, color: Color(0xFFBF5AF2)),
                        ),
                        onPressed: () {
                          _showAddWeightDialog();
                          HapticFeedback.lightImpact();
                        },
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                          HapticFeedback.selectionClick();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // 可折叠内容区域
              AnimatedCrossFade(
                firstChild: Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        // Time Range Selector
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: List.generate(_timeRanges.length, (index) {
                              final isSelected = index == _selectedTimeRangeIndex;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedTimeRangeIndex = index;
                                      _processData();
                                    });
                                    HapticFeedback.selectionClick();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: isSelected ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ] : [],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _timeRanges[index],
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSelected ? AppColors.textDark : const Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                              }),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Summary
                        const Text('平均', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _averageWeight.toStringAsFixed(1),
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 36,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'SF Pro Display',
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '公斤',
                              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateRangeText.length >= 5 
                              ? _dateRangeText.split('至')[0].substring(0, 5) 
                              : '', // Just show Year like "2025年"
                          style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                        ),

                        const SizedBox(height: 32),

                        // Chart
                        SizedBox(
                          height: 220,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawHorizontalLine: false,
                                drawVerticalLine: true,
                                getDrawingVerticalLine: (value) {
                                  return FlLine(
                                    color: const Color(0xFFE5E5EA),
                                    strokeWidth: 1,
                                    dashArray: [4, 4],
                                  );
                                },
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) {
                                  if (value == _minY || value == _maxY) return const SizedBox();
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 12),
                                  );
                                },
                                interval: (_maxY - _minY) / 4,
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  String text = '';
                                  int valInt = value.toInt();
                                  
                                  if (_selectedTimeRangeIndex == 0) { // Day
                                    if (valInt % 6 == 0) text = '$valInt:00';
                                  } else if (_selectedTimeRangeIndex == 1) { // Week
                                    final date = _currentStartDate.add(Duration(days: valInt));
                                    text = DateFormat('E', 'zh_CN').format(date);
                                  } else if (_selectedTimeRangeIndex == 2) { // Month
                                    if (valInt % 7 == 0) {
                                      final date = _currentStartDate.add(Duration(days: valInt));
                                      text = '${date.day}';
                                    }
                                  } else if (_selectedTimeRangeIndex == 3) { // 6 Months
                                    final date = DateTime(_currentStartDate.year, _currentStartDate.month + valInt);
                                    text = '${date.month}';
                                  } else { // Year
                                    if (valInt % 2 == 0) {
                                      final date = DateTime(_currentStartDate.year, _currentStartDate.month + valInt);
                                      text = '${date.month}';
                                    }
                                  }
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      text,
                                      style: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 12),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: _getMaxX(),
                          minY: _minY,
                          maxY: _maxY,
                          lineBarsData: [
                            LineChartBarData(
                              spots: _chartSpots,
                              isCurved: true,
                              color: const Color(0xFFBF5AF2),
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 4,
                                    color: Colors.white,
                                    strokeWidth: 2,
                                    strokeColor: const Color(0xFFBF5AF2),
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(show: false),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (touchedSpot) => Colors.white,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  return LineTooltipItem(
                                    '${spot.y.toStringAsFixed(1)} kg',
                                    const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
                                  );
                                }).toList();
                              },
                            ),
                            handleBuiltInTouches: true,
                            getTouchedSpotIndicator: (barData, spotIndexes) {
                              return spotIndexes.map((index) {
                                return TouchedSpotIndicatorData(
                                  FlLine(color: const Color(0xFFBF5AF2), strokeWidth: 1),
                                  FlDotData(
                                    getDotPainter: (spot, percent, barData, index) {
                                      return FlDotCirclePainter(
                                        radius: 6,
                                        color: const Color(0xFFBF5AF2),
                                        strokeWidth: 2,
                                        strokeColor: Colors.white,
                                      );
                                    },
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                secondChild: const SizedBox(width: double.infinity),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 300),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  double _getMaxX() {
    switch (_selectedTimeRangeIndex) {
      case 0: return 24; // Day
      case 1: return 6; // Week
      case 2: return 30; // Month
      case 3: return 5; // 6 Months
      case 4: return 11; // Year
      default: return 30;
    }
  }
}
