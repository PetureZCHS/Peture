import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';

class WeightTrendCard extends StatefulWidget {
  final String? petId; // 可选，如果为 null 则显示所有宠物的数据

  const WeightTrendCard({
    super.key,
    this.petId,
  });

  @override
  State<WeightTrendCard> createState() => _WeightTrendCardState();
}

class _WeightTrendCardState extends State<WeightTrendCard> {
  bool _isExpanded = false; // 控制折叠状态
  int _selectedTimeRangeIndex = 3; // 默认选中 "6个月"
  final List<String> _timeRanges = ['日', '周', '月', '6个月', '年'];

  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _weightRecords = [];
  List<double> _chartData = [];
  List<String> _chartLabels = [];
  double _averageWeight = 0.0;
  String _dateRange = '';
  String _trendText = '';

  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _loadWeightData();
  }

  Future<void> _loadWeightData() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> records;
      if (widget.petId != null) {
        // 获取特定宠物的体重记录
        records = await _supabaseService.getWeightRecordsForPet(widget.petId!);
      } else {
        // 获取所有宠物的体重记录
        records = await _supabaseService.getAllWeightRecords();
      }
      setState(() {
        _weightRecords = records;
      });
      _processData();
    } catch (e) {
      debugPrint('加载体重数据失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _processData() {
    if (_weightRecords.isEmpty) {
      if (mounted) {
        setState(() {
          _chartData = [];
          _chartLabels = [];
          _averageWeight = 0.0;
          _dateRange = '暂无数据';
          _trendText = '暂无体重记录';
        });
      }
      return;
    }

    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedTimeRangeIndex) {
      case 0: // 日
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 1: // 周
        startDate = now.subtract(const Duration(days: 30));
        break;
      case 2: // 月
        startDate = now.subtract(const Duration(days: 90));
        break;
      case 3: // 6个月
        startDate = now.subtract(const Duration(days: 180));
        break;
      case 4: // 年
        startDate = now.subtract(const Duration(days: 365));
        break;
      default:
        startDate = now.subtract(const Duration(days: 180));
    }

    // 筛选数据
    final filteredRecords = _weightRecords.where((record) {
      final dateStr = record['date'] as String?;
      if (dateStr == null) return false;
      final date = DateTime.parse(dateStr);
      return date.isAfter(startDate) || date.isAtSameMomentAs(startDate);
    }).toList();

    if (filteredRecords.isEmpty) {
      if (mounted) {
        setState(() {
          _chartData = [];
          _chartLabels = [];
          _averageWeight = 0.0;
          _dateRange = '暂无数据';
          _trendText = '该时间段内暂无体重记录';
        });
      }
      return;
    }

    // 按日期排序
    filteredRecords.sort((a, b) {
      final dateA = DateTime.parse(a['date'] as String);
      final dateB = DateTime.parse(b['date'] as String);
      return dateA.compareTo(dateB);
    });

    List<double> tempData = [];
    List<String> tempLabels = [];

    // 按月分组（6个月视图 或 年视图）
    if (_selectedTimeRangeIndex >= 3) {
      final Map<String, List<double>> monthlyData = {};
      for (var record in filteredRecords) {
        final date = DateTime.parse(record['date'] as String);
        final monthKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}';
        final weight = (record['weight'] as num?)?.toDouble() ?? 0.0;
        monthlyData.putIfAbsent(monthKey, () => []).add(weight);
      }

      final sortedMonths = monthlyData.keys.toList()..sort();
      tempData = sortedMonths.map((month) {
        final weights = monthlyData[month]!;
        return weights.reduce((a, b) => a + b) / weights.length; // 月平均
      }).toList();

      tempLabels = sortedMonths.map((month) {
        final parts = month.split('-');
        final monthNum = int.parse(parts[1]);
        return '${monthNum}月';
      }).toList();
    } else {
      // 其他时间范围：直接使用所有数据点
      tempData = filteredRecords.map((record) {
        return (record['weight'] as num?)?.toDouble() ?? 0.0;
      }).toList();

      tempLabels = filteredRecords.map((record) {
        final date = DateTime.parse(record['date'] as String);
        if (_selectedTimeRangeIndex == 0) {
          return DateFormat('M/d', 'zh_CN').format(date);
        } else if (_selectedTimeRangeIndex == 1) {
          return DateFormat('M/d', 'zh_CN').format(date);
        } else {
          return DateFormat('M月', 'zh_CN').format(date);
        }
      }).toList();
    }

    double tempAvg = 0.0;
    // 计算平均值
    if (tempData.isNotEmpty) {
      tempAvg = tempData.reduce((a, b) => a + b) / tempData.length;
    }

    String tempDateRange = '';
    // 计算日期范围
    if (filteredRecords.isNotEmpty) {
      final firstDate = DateTime.parse(filteredRecords.first['date'] as String);
      final lastDate = DateTime.parse(filteredRecords.last['date'] as String);
      tempDateRange =
          '${DateFormat('yyyy年M月d日', 'zh_CN').format(firstDate)}至${DateFormat('M月d日', 'zh_CN').format(lastDate)}';
    }

    String tempTrend = '';
    // 计算趋势
    if (tempData.length >= 2) {
      final firstHalf =
          tempData.take(tempData.length ~/ 2).reduce((a, b) => a + b) /
              (tempData.length ~/ 2);
      final secondHalf =
          tempData.skip(tempData.length ~/ 2).reduce((a, b) => a + b) /
              (tempData.length - tempData.length ~/ 2);
      if (secondHalf > firstHalf * 1.05) {
        tempTrend = '过去${_timeRanges[_selectedTimeRangeIndex]}的体重有所上升。';
      } else if (secondHalf < firstHalf * 0.95) {
        tempTrend = '过去${_timeRanges[_selectedTimeRangeIndex]}的体重有所下降。';
      } else {
        tempTrend = '过去${_timeRanges[_selectedTimeRangeIndex]}的体重保持稳定。';
      }
    } else {
      tempTrend = '数据不足，无法分析趋势。';
    }

    if (mounted) {
      setState(() {
        _chartData = tempData;
        _chartLabels = tempLabels;
        _averageWeight = tempAvg;
        _dateRange = tempDateRange;
        _trendText = tempTrend;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ----------------- 使用 develop 分支的 UI 框架 -----------------
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
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
              border:
                  Border.all(color: Colors.white.withOpacity(0.6), width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
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
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                    HapticFeedback.selectionClick();
                  },
                  behavior: HitTestBehavior.translucent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5E62).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.monitor_weight_rounded,
                              color: Color(0xFFFF5E62),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '体重趋势',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D1D1F),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            color: const Color(0xFFFF5E62),
                            onPressed: () {
                              // TODO: 添加体重记录功能
                              HapticFeedback.lightImpact();
                            },
                          ),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: const Color(0xFF8E8E93),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 可折叠内容区域
                AnimatedCrossFade(
                  firstChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      // 时间范围选择器 - 保持 develop 样式
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: List.generate(_timeRanges.length, (index) {
                            final isSelected = index == _selectedTimeRangeIndex;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedTimeRangeIndex = index;
                                  });
                                  _processData(); // 调用数据处理
                                  HapticFeedback.selectionClick();
                                },
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            )
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _timeRanges[index],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 当前数值展示 - 接入动态数据
                      _isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _chartData.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Text(
                                      '暂无体重数据',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '平均 ${_averageWeight.toStringAsFixed(1)} kg',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1D1D1F),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _dateRange,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ],
                                ),

                      const SizedBox(height: 24),

                      // 图表区域 - 保持 develop 样式，接入动态数据
                      if (!_isLoading && _chartData.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: _chartData.reduce(math.max) * 1.2,
                              minY: 0,
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipColor: (group) => Colors.black87,
                                  getTooltipItem:
                                      (group, groupIndex, rod, rodIndex) {
                                    if (group.x.toInt() >= 0 &&
                                        group.x.toInt() < _chartLabels.length) {
                                      return BarTooltipItem(
                                        '${rod.toY.toStringAsFixed(1)} kg\n${_chartLabels[group.x.toInt()]}',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      );
                                    }
                                    return null;
                                  },
                                ),
                                touchCallback:
                                    (FlTouchEvent event, barTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        barTouchResponse == null ||
                                        barTouchResponse.spot == null) {
                                      _touchedIndex = -1;
                                      return;
                                    }
                                    _touchedIndex = barTouchResponse
                                        .spot!.touchedBarGroupIndex;
                                  });
                                },
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget:
                                        (double value, TitleMeta meta) {
                                      if (value.toInt() >= 0 &&
                                          value.toInt() < _chartLabels.length) {
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            _chartLabels[value.toInt()],
                                            style: const TextStyle(
                                              color: Color(0xFF8E8E93),
                                              fontSize: 11,
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                    reservedSize: 30,
                                  ),
                                ),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) {
                                      // 简单的 Y 轴标签逻辑
                                      if (value % 5 == 0 && value > 0) {
                                        return Text(
                                          '${value.toInt()}',
                                          style: const TextStyle(
                                            color: Color(0xFFC7C7CC),
                                            fontSize: 11,
                                          ),
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                  ),
                                ),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: const Color(0xFFE5E5EA),
                                    strokeWidth: 1,
                                    dashArray: [4, 4],
                                  );
                                },
                              ),
                              extraLinesData: ExtraLinesData(
                                horizontalLines: [
                                  HorizontalLine(
                                    y: _averageWeight,
                                    color: const Color(0xFF8E8E93),
                                    strokeWidth: 2,
                                    dashArray: [5, 5],
                                    label: HorizontalLineLabel(
                                      show: true,
                                      alignment: Alignment.topRight,
                                      padding: const EdgeInsets.only(
                                          right: 5, bottom: 5),
                                      style: const TextStyle(
                                        color: Color(0xFF8E8E93),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      labelResolver: (line) => '平均',
                                    ),
                                  ),
                                ],
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups:
                                  List.generate(_chartData.length, (index) {
                                return BarChartGroupData(
                                  x: index,
                                  barRods: [
                                    BarChartRodData(
                                      toY: _chartData[index],
                                      color: _touchedIndex == index
                                          ? const Color(0xFFFF5E62)
                                          : const Color(0xFFFF5E62)
                                              .withOpacity(0.3),
                                      width: 16,
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(4)),
                                      backDrawRodData:
                                          BackgroundBarChartRodData(
                                        show: true,
                                        toY: _chartData.reduce(math.max) * 1.2,
                                        color: const Color(0xFFF2F2F7),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // 趋势分析 - 保持 develop 样式，接入动态文本
                      if (!_isLoading && _chartData.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.trending_up_rounded,
                                color: Color(0xFFFF5E62),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '趋势',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1D1D1F),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _trendText,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: const Color(0xFF1D1D1F)
                                            .withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
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
}
