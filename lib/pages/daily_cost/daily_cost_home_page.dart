import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/daily_cost_item.dart';
import '../../services/supabase_service.dart';
import 'add_daily_cost_page.dart';

/// 宠物消费日均成本追踪器主页
class DailyCostHomePage extends StatefulWidget {
  const DailyCostHomePage({super.key});

  @override
  State<DailyCostHomePage> createState() => _DailyCostHomePageState();
}

class _DailyCostHomePageState extends State<DailyCostHomePage> {
  final SupabaseService _supabaseService = SupabaseService();
  List<DailyCostItem> _items = [];
  double _totalDailyCost = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  /// 加载消费品数据
  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 优先从 Supabase 加载
      final itemsData = await _supabaseService.getAllDailyCostItems();
      final items = itemsData.map((e) => DailyCostItem.fromMap(e)).toList();

      // 前端计算总日均成本
      double totalDailyCost = 0.0;
      for (final item in items) {
        totalDailyCost += item.dailyCost;
      }

      if (mounted) {
        setState(() {
          _items = items;
          _totalDailyCost = totalDailyCost;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    }
  }

  /// 删除消费品记录
  Future<void> _deleteItem(DailyCostItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${item.itemName}" 的记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && item.id != null) {
      await _supabaseService.deleteDailyCostItem(item.id!);
      _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('记录已删除')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text(
          '宠物成本追踪',
          style: TextStyle(
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
          : RefreshIndicator(
              onRefresh: _loadItems,
              child: CustomScrollView(
                slivers: [
                  // 顶部总日均成本卡片
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: _buildTotalCostCard(),
                    ),
                  ),

                  // 消费品列表标题
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '消费品列表',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          Text(
                            '共 ${_items.length} 项',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // 消费品列表
                  _items.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_basket_outlined,
                                  size: 80,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '还没有消费品记录',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '点击右下角 + 号添加第一项',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final item = _items[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: _buildItemCard(item),
                              );
                            }, childCount: _items.length),
                          ),
                        ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
      // 悬浮添加按钮
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDailyCostPage()),
          );
          if (result == true) {
            _loadItems();
          }
        },
        backgroundColor: const Color(0xFF5D5FEF),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  /// 构建总日均成本卡片
  Widget _buildTotalCostCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 12.0,
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '总日均成本',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '¥${_totalDailyCost.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '每天平均花费 • 共 ${_items.length} 项消费品',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建单个消费品卡片
  Widget _buildItemCard(DailyCostItem item) {
    final purchaseDate = DateTime.parse(item.purchaseDate);
    final purchaseDateStr = DateFormat('yyyy/MM/dd').format(purchaseDate);

    String finishDateStr = '使用中';
    if (item.finishDate != null) {
      final finishDate = DateTime.parse(item.finishDate!);
      finishDateStr = DateFormat('yyyy/MM/dd').format(finishDate);
    }

    return Dismissible(
      key: Key(item.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        await _deleteItem(item);
        return false;
      },
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddDailyCostPage(item: item),
            ),
          );
          if (result == true) {
            _loadItems();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 第一行：物品名称和宠物标签
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.itemName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.petName != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5D5FEF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.pets,
                              size: 14,
                              color: Color(0xFF5D5FEF),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.petName!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF5D5FEF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // 第二行：价格和日期信息
                Row(
                  children: [
                    // 总价格
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '总价格',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '¥${item.totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 使用天数
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '使用天数',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.usageDays} 天',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 日均成本（突出显示）
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            '日均成本',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFFF6B6B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '¥${item.dailyCost.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF6B6B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 第三行：日期信息
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Color(0xFF8E8E93),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        purchaseDateStr,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: Color(0xFF8E8E93),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        finishDateStr,
                        style: TextStyle(
                          fontSize: 13,
                          color: item.finishDate == null
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF8E8E93),
                          fontWeight: item.finishDate == null
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),

                // 备注（如果有）
                if (item.note != null && item.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.note!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8E8E93),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
