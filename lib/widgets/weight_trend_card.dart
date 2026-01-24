import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui';

class WeightTrendCard extends StatefulWidget {
  const WeightTrendCard({super.key});

  @override
  State<WeightTrendCard> createState() => _WeightTrendCardState();
}

class _WeightTrendCardState extends State<WeightTrendCard> {
  bool _isExpanded = false; // 控制折叠状态
  int _selectedTimeRangeIndex = 3; // 默认选中 "6个月"
  final List<String> _timeRanges = ['日', '周', '月', '6个月', '年'];
  
  // 模拟数据
  final List<double> _sixMonthData = [7.3, 7.5, 7.4, 7.8, 8.2, 8.0];
  final List<String> _sixMonthLabels = ['7月', '8月', '9月', '10月', '11月', '12月'];
  
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
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
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
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
                          // TODO: 添加体重记录
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

                  // 时间范围选择器
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
                                          color: Colors.black.withOpacity(0.1),
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
                                  color:
                                      isSelected ? Colors.black : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 当前数值展示
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '平均 7.8 kg',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D1D1F),
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '2025年7月8日至12月6日',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 图表区域
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _sixMonthData.reduce(math.max) * 1.2,
                        minY: 0,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => Colors.black87,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${rod.toY} kg\n${_sixMonthLabels[group.x.toInt()]}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
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
                              _touchedIndex =
                                  barTouchResponse.spot!.touchedBarGroupIndex;
                            });
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                if (value.toInt() >= 0 &&
                                    value.toInt() < _sixMonthLabels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      _sixMonthLabels[value.toInt()],
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
                                if (value == 5 || value == 10) {
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
                              y: 7.7, // 模拟平均值
                              color: const Color(0xFF8E8E93),
                              strokeWidth: 2,
                              dashArray: [5, 5],
                              label: HorizontalLineLabel(
                                show: true,
                                alignment: Alignment.topRight,
                                padding:
                                    const EdgeInsets.only(right: 5, bottom: 5),
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
                        barGroups: List.generate(_sixMonthData.length, (index) {
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: _sixMonthData[index],
                                color: _touchedIndex == index
                                    ? const Color(0xFFFF5E62)
                                    : const Color(0xFFFF5E62).withOpacity(0.3),
                                width: 16,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4)),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: _sixMonthData.reduce(math.max) * 1.2,
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

                  // 趋势分析
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
                                '你过去6个月的体重有所上升。',
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      const Color(0xFF1D1D1F).withOpacity(0.8),
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
