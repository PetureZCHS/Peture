import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/presentation/email_login_page.dart';
import '../data/analytics_dashboard_service.dart';

class AdminAnalyticsApp extends StatefulWidget {
  const AdminAnalyticsApp({super.key});

  @override
  State<AdminAnalyticsApp> createState() => _AdminAnalyticsAppState();
}

class _AdminAnalyticsAppState extends State<AdminAnalyticsApp> {
  Session? _session;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      setState(() => _session = authState.session);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1565C0),
        secondary: Color(0xFF00897B),
        surface: Colors.white,
        onSurface: Color(0xFF17202A),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Peture 埋点看板',
      theme: theme,
      home: _session == null
          ? const EmailLoginPage()
          : const AdminAnalyticsDashboardPage(),
    );
  }
}

class AdminAnalyticsDashboardPage extends StatefulWidget {
  const AdminAnalyticsDashboardPage({super.key});

  @override
  State<AdminAnalyticsDashboardPage> createState() =>
      _AdminAnalyticsDashboardPageState();
}

class _AdminAnalyticsDashboardPageState
    extends State<AdminAnalyticsDashboardPage> {
  final _service = AnalyticsDashboardService();
  String _range = '7d';
  String _platform = 'all';
  String _module = 'all';
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    return _service.loadDashboard(
      range: _range,
      platform: _platform,
      module: _module,
    );
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(
                    range: _range,
                    platform: _platform,
                    module: _module,
                    onRangeChanged: (value) {
                      _range = value;
                      _refresh();
                    },
                    onPlatformChanged: (value) {
                      _platform = value;
                      _refresh();
                    },
                    onModuleChanged: (value) {
                      _module = value;
                      _refresh();
                    },
                    onRefresh: _refresh,
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    child: _ErrorState(
                      message: snapshot.error.toString(),
                      onRetry: _refresh,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    sliver: SliverToBoxAdapter(
                      child: _DashboardContent(data: snapshot.data ?? {}),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String range;
  final String platform;
  final String module;
  final ValueChanged<String> onRangeChanged;
  final ValueChanged<String> onPlatformChanged;
  final ValueChanged<String> onModuleChanged;
  final VoidCallback onRefresh;

  const _Header({
    required this.range,
    required this.platform,
    required this.module,
    required this.onRangeChanged,
    required this.onPlatformChanged,
    required this.onModuleChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Peture 埋点数据看板',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '全站行为、页面、功能、AI 与错误趋势',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
              ),
            ],
          );
          final filters = Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _DropdownFilter(
                value: range,
                items: const {
                  'today': '今日',
                  '7d': '近 7 日',
                  '30d': '近 30 日',
                },
                onChanged: onRangeChanged,
              ),
              _DropdownFilter(
                value: platform,
                items: const {
                  'all': '全部平台',
                  'android': 'Android',
                  'ios': 'iOS',
                  'web': 'Web',
                  'windows': 'Windows',
                },
                onChanged: onPlatformChanged,
              ),
              _DropdownFilter(
                value: module,
                items: const {
                  'all': '全部模块',
                  'diary': '日记',
                  'ai_image': 'AI 生图',
                  'expense': '记账',
                  'pet_profile': '宠物档案',
                  'ai_chat': 'AI 问诊',
                },
                onChanged: onModuleChanged,
              ),
              IconButton.filledTonal(
                tooltip: '刷新',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          );

          if (constraints.maxWidth < 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 16),
                filters,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: title),
              filters,
            ],
          );
        },
      ),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  const _DropdownFilter({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E5EA)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            items: items.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final Map<String, dynamic> data;

  const _DashboardContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final overview = _asMap(data['overview']);
    final aiUsage = _asMap(data['ai_usage']);
    final pages = _asList(data['page_rankings']);
    final features = _asList(data['feature_rankings']);
    final errors = _asList(data['error_rankings']);
    final funnel = _asList(data['funnel']);

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 1100 ? 4 : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.7,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              children: [
                _MetricCard(
                  label: '活跃用户',
                  value: '${overview['active_users'] ?? 0}',
                  caption: '按 user / anonymous 去重',
                ),
                _MetricCard(
                  label: '事件总数',
                  value: '${overview['event_count'] ?? 0}',
                  caption: '当前筛选范围',
                ),
                _MetricCard(
                  label: '会话数',
                  value: '${overview['session_count'] ?? 0}',
                  caption: 'session_id 去重',
                ),
                _MetricCard(
                  label: 'AI 成功率',
                  value: _percent(aiUsage['success_rate']),
                  caption: '${aiUsage['success_count'] ?? 0} 次成功',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth > 980;
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                SizedBox(
                  width: twoColumns
                      ? (constraints.maxWidth - 18) / 2
                      : constraints.maxWidth,
                  child: _TrendPanel(series: _asList(overview['dau_series'])),
                ),
                SizedBox(
                  width: twoColumns
                      ? (constraints.maxWidth - 18) / 2
                      : constraints.maxWidth,
                  child: _TablePanel(
                    title: '页面排行',
                    columns: const ['页面', 'PV', 'UV', '平均停留'],
                    rows: pages
                        .map((row) => [
                              '${row['page_name'] ?? '-'}',
                              '${row['pv'] ?? 0}',
                              '${row['uv'] ?? 0}',
                              _ms(row['avg_duration_ms']),
                            ])
                        .toList(),
                  ),
                ),
                SizedBox(
                  width: twoColumns
                      ? (constraints.maxWidth - 18) / 2
                      : constraints.maxWidth,
                  child: _TablePanel(
                    title: '功能排行',
                    columns: const ['事件', '次数', '用户'],
                    rows: features
                        .map((row) => [
                              '${row['event_name'] ?? '-'}',
                              '${row['count'] ?? 0}',
                              '${row['users'] ?? 0}',
                            ])
                        .toList(),
                  ),
                ),
                SizedBox(
                  width: twoColumns
                      ? (constraints.maxWidth - 18) / 2
                      : constraints.maxWidth,
                  child: _TablePanel(
                    title: '错误排行',
                    columns: const ['错误码', '次数', '影响用户'],
                    rows: errors
                        .map((row) => [
                              '${row['error_code'] ?? '-'}',
                              '${row['count'] ?? 0}',
                              '${row['affected_users'] ?? 0}',
                            ])
                        .toList(),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _TablePanel(
                    title: '日记核心漏斗',
                    columns: const ['步骤', '用户数'],
                    rows: funnel
                        .map((row) => [
                              '${row['step'] ?? '-'}',
                              '${row['users'] ?? 0}',
                            ])
                        .toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String caption;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Color(0xFF17202A),
            ),
          ),
          const SizedBox(height: 4),
          Text(caption, style: const TextStyle(color: Colors.black45)),
        ],
      ),
    );
  }
}

class _TrendPanel extends StatelessWidget {
  final List<Map<String, dynamic>> series;

  const _TrendPanel({required this.series});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < series.length; i++) {
      spots.add(FlSpot(i.toDouble(), _toDouble(series[i]['users'])));
    }

    return Container(
      height: 330,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DAU 趋势',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: spots.isEmpty
                ? const Center(child: Text('暂无数据'))
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          barWidth: 3,
                          color: const Color(0xFF1565C0),
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TablePanel extends StatelessWidget {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;

  const _TablePanel({
    required this.title,
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const SizedBox(height: 160, child: Center(child: Text('暂无数据')))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 42,
                dataRowMaxHeight: 52,
                columns: columns
                    .map((column) => DataColumn(label: Text(column)))
                    .toList(),
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: row
                            .map(
                              (cell) => DataCell(
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 220),
                                  child: Text(
                                    cell,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        decoration: _panelDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 42, color: Color(0xFFB00020)),
            const SizedBox(height: 12),
            const Text(
              '无法加载埋点看板',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: const Color(0xFFE4E8EE)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0F000000),
        blurRadius: 18,
        offset: Offset(0, 8),
      ),
    ],
  );
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asList(Object? value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _percent(Object? value) {
  final rate = _toDouble(value);
  return '${(rate * 100).toStringAsFixed(1)}%';
}

String _ms(Object? value) {
  final ms = _toDouble(value);
  if (ms >= 1000) return '${(ms / 1000).toStringAsFixed(1)}s';
  return '${ms.round()}ms';
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
