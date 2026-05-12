import 'package:flutter/material.dart';
import '../../../shared/models/fitness_course.dart';
import '../../../shared/data/fitness_courses_data.dart';
import '../../../services/fitness_courses_manager.dart';
import 'partner_fit_course_detail_page.dart';
import 'partner_fit_history_page.dart';

/// "活力伙伴"健身房主页面 - 左右分栏布局
class PartnerFitGymPage extends StatefulWidget {
  const PartnerFitGymPage({super.key});

  @override
  State<PartnerFitGymPage> createState() => _PartnerFitGymPageState();
}

class _PartnerFitGymPageState extends State<PartnerFitGymPage> {
  // 左侧分类索引（锻炼强度）
  int _selectedCategoryIndex = 0;

  // 右侧宠物类型筛选
  String _selectedPetType = '全部';

  // 搜索关键词
  String _searchKeyword = '';

  // 课程列表（状态变量）
  List<FitnessCourse> _courses = [];

  // 加载状态
  bool _isLoading = true;
  bool _isLoadingMore = false;

  // 分类列表（锻炼强度）
  final List<String> _categories = [
    '全部',
    '低 - 拉伸与平静',
    '中 - 塑形与核心',
    '高 - 燃脂与心肺',
  ];

  // 宠物类型列表
  final List<String> _petTypes = ['全部', '狗狗专属', '猫咪专属'];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  // 加载课程（渐进式加载）
  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);

    try {
      // 先加载核心课程并立即显示
      final coreCourses = FitnessCoursesManager().getCoreCourses();
      if (mounted) {
        setState(() {
          _courses = coreCourses;
          _isLoading = false;
          _isLoadingMore = true;
        });
      }

      // 异步加载扩展课程
      final allCourses = await FitnessCoursesManager().getAllCourses();
      if (mounted) {
        setState(() {
          _courses = allCourses;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });

        // 改进错误处理：提供友好的用户提示和重试选项
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载扩展课程失败，已显示核心课程'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '重试',
              onPressed: _loadCourses,
            ),
          ),
        );
      }
    }
  }

  // 刷新功能
  Future<void> _refreshCourses() async {
    setState(() => _isLoadingMore = true);
    try {
      await FitnessCoursesManager().refreshCache();
      await _loadCourses();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刷新失败: $e')),
        );
      }
    }
  }

  // 获取筛选后的课程列表
  List<FitnessCourse> get filteredCourses {
    var courses = _courses;

    // 按锻炼强度筛选
    if (_selectedCategoryIndex > 0) {
      final intensityMap = {
        1: 'low', // 低 - 拉伸与平静
        2: 'medium', // 中 - 塑形与核心
        3: 'high', // 高 - 燃脂与心肺
      };
      final intensity = intensityMap[_selectedCategoryIndex];
      if (intensity != null) {
        courses = courses.where((c) => c.intensity == intensity).toList();
      }
    }

    // 按宠物类型筛选
    if (_selectedPetType == '狗狗专属') {
      courses = courses.where((c) => c.petType == 'dog').toList();
    } else if (_selectedPetType == '猫咪专属') {
      courses = courses.where((c) => c.petType == 'cat').toList();
    }

    // 按搜索关键词筛选
    if (_searchKeyword.isNotEmpty) {
      courses = courses
          .where(
            (c) =>
                c.name.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
                c.description.toLowerCase().contains(
                      _searchKeyword.toLowerCase(),
                    ),
          )
          .toList();
    }

    return courses;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8F8),
        foregroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFF424242)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PartnerFitHistoryPage(),
                ),
              );
            },
            tooltip: '训练记录',
          ),
        ],
      ),
      body: Column(
        children: [
          // 第1步：搜索框
          _buildSearchBar(),

          // 第2步：分栏布局
          Expanded(
            child: Row(
              children: [
                // 左侧 Master 栏（主分类 - 锻炼强度）
                _buildMasterPanel(),

                // 右侧 Detail 栏（课程网格）
                _buildDetailPanel(),
              ],
            ),
          ),
        ],
      ),
      // 添加底部安全区域，避免内容被液态导航栏遮挡
      bottomNavigationBar: const SizedBox(height: 20),
    );
  }

  // 搜索框
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: const Color(0xFFF8F8F8),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchKeyword = value;
          });
        },
        decoration: InputDecoration(
          hintText: '搜索课程名称',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF424242),
            size: 22,
          ),
          filled: true,
          fillColor: const Color(0xFFF0F2F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  // 左侧 Master 栏（主分类）
  Widget _buildMasterPanel() {
    return Container(
      width: 88,
      color: Colors.white,
      child: ListView.builder(
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          return InkWell(
            onTap: () {
              setState(() {
                _selectedCategoryIndex = index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF0F2F5) : Colors.white,
                border: Border(
                  left: BorderSide(
                    color: isSelected
                        ? const Color(0xFF5A8EFA)
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                _categories[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF5A8EFA)
                      : const Color(0xFF424242),
                  height: 1.3,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 右侧 Detail 栏
  Widget _buildDetailPanel() {
    return Expanded(
      flex: 3,
      child: Column(
        children: [
          // 二级筛选（宠物类型）
          _buildPetTypeFilter(),

          // 课程网格
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredCourses.isEmpty
                    ? _buildEmptyState()
                    : Stack(
                        children: [
                          RefreshIndicator(
                            onRefresh: _refreshCourses,
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.0,
                              ),
                              itemCount: filteredCourses.length,
                              itemBuilder: (context, index) {
                                return _buildGridCard(filteredCourses[index]);
                              },
                            ),
                          ),
                          // 增量加载指示器
                          if (_isLoadingMore)
                            Positioned(
                              top: 8,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          const Color(0xFF5A8EFA),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '加载中...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF424242),
                                      ),
                                    ),
                                  ],
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

  // 宠物类型筛选（横向 Chip）
  Widget _buildPetTypeFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFFF8F8F8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _petTypes.length,
        itemBuilder: (context, index) {
          final type = _petTypes[index];
          final isSelected = _selectedPetType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilterChip(
              label: Text(type),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedPetType = type;
                });
              },
              selectedColor: const Color(0xFF5A8EFA),
              checkmarkColor: Colors.white,
              backgroundColor: const Color(0xFFF0F2F5),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF424242),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  // 新卡片样式（Grid卡片）
  Widget _buildGridCard(FitnessCourse course) {
    final isCoreCourse = FitnessCoursesData.coreCourseIds.contains(course.id);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PartnerFitCourseDetailPage(course: course),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 图标容器
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5A8EFA).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        course.iconEmoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 标题
                  Flexible(
                    child: Text(
                      course.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E1E1E),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 时长和标签
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 2,
                    children: [
                      Icon(Icons.access_time,
                          size: 11, color: Colors.grey[600]),
                      Text(
                        '${course.durationMinutes}分钟',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '·',
                        style: TextStyle(color: Colors.grey[400], fontSize: 10),
                      ),
                      Text(
                        course.petType == 'dog' ? '🐶' : '🐱',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 核心课程标识
            if (isCoreCourse)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '核心课程',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '没有找到符合条件的课程',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCategoryIndex = 0;
                _selectedPetType = '全部';
                _searchKeyword = '';
              });
            },
            child: const Text('重置筛选条件'),
          ),
        ],
      ),
    );
  }
}
