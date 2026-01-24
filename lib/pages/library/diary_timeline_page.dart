import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/pet_diary.dart';
import '../../services/supabase_service.dart';
import 'diary_detail_page.dart';

class DiaryTimelinePage extends StatefulWidget {
  const DiaryTimelinePage({super.key});

  @override
  State<DiaryTimelinePage> createState() => _DiaryTimelinePageState();
}

class _DiaryTimelinePageState extends State<DiaryTimelinePage> {
  List<PetDiary> _allDiaries = [];
  List<PetDiary> _filteredDiaries = [];
  bool _isLoading = true;
  bool _isAscending = false; // Default to Newest -> Oldest
  String? _selectedTag; // Null means all

  final List<String> _availableTags = ['哲学', '搞笑', '治愈', '中二', '小红书'];

  @override
  void initState() {
    super.initState();
    _fetchDiaries();
  }

  Future<void> _fetchDiaries() async {
    setState(() => _isLoading = true);
    try {
      final diaries = await SupabaseService().getAllDiaries();
      if (mounted) {
        setState(() {
          _allDiaries = diaries;
          _applyFilterAndSort();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching diaries: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilterAndSort() {
    List<PetDiary> temp = List.from(_allDiaries);

    // Filter
    if (_selectedTag != null) {
      temp = temp.where((d) => d.style == _selectedTag).toList();
    }

    // Sort
    temp.sort((a, b) {
      return _isAscending
          ? a.timestamp.compareTo(b.timestamp)
          : b.timestamp.compareTo(a.timestamp);
    });

    setState(() {
      _filteredDiaries = temp;
    });
  }

  void _toggleSort() {
    setState(() {
      _isAscending = !_isAscending;
      _applyFilterAndSort();
    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '筛选标签',
              style: GoogleFonts.notoSerif(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilterChip(
                  label: const Text('全部'),
                  selected: _selectedTag == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedTag = null;
                      _applyFilterAndSort();
                    });
                    Navigator.pop(context);
                  },
                ),
                ..._availableTags.map((tag) => FilterChip(
                      label: Text(tag),
                      selected: _selectedTag == tag,
                      onSelected: (selected) {
                        setState(() {
                          _selectedTag = selected ? tag : null;
                          _applyFilterAndSort();
                        });
                        Navigator.pop(context);
                      },
                    )),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '时光轴',
          style: GoogleFonts.notoSerif(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
              color: Colors.black87,
            ),
            onPressed: _toggleSort,
            tooltip: _isAscending ? '按时间正序' : '按时间倒序',
          ),
          IconButton(
            icon: Icon(
              _selectedTag == null ? Icons.filter_alt_outlined : Icons.filter_alt,
              color: _selectedTag == null ? Colors.black87 : Colors.blue,
            ),
            onPressed: _showFilterDialog,
            tooltip: '筛选',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDiaries,
              child: _filteredDiaries.isEmpty
                  ? _buildEmptyState()
                  : _buildTimelineList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_edu, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '暂无日记',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _filteredDiaries.length,
      itemBuilder: (context, index) {
        final diary = _filteredDiaries[index];
        final isFirst = index == 0;
        final isLast = index == _filteredDiaries.length - 1;
        
        // Check if we need to show date header (Group by Date)
        bool showDate = true;
        if (index > 0) {
          final prevDiary = _filteredDiaries[index - 1];
          if (isSameDay(prevDiary.timestamp, diary.timestamp)) {
            showDate = false;
          }
        }

        return _buildTimelineItem(diary, showDate, isFirst, isLast);
      },
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildTimelineItem(PetDiary diary, bool showDate, bool isFirst, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Date & Time
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (showDate) ...[
                  Text(
                    DateFormat('MM月dd日').format(diary.timestamp),
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  DateFormat('HH:mm').format(diary.timestamp),
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Middle: Line & Node
          SizedBox(
            width: 40,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Vertical Line
                Container(
                  width: 2,
                  color: Colors.grey[300],
                  margin: const EdgeInsets.only(top: 0), // Extend to top
                ),
                // Node
                Container(
                  margin: const EdgeInsets.only(top: 2), // Align with text roughly
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _getTagColor(diary.style), width: 3),
                  ),
                ),
              ],
            ),
          ),

          // Right: Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DiaryDetailPage(diary: diary),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _getTagIcon(diary.style),
                        const SizedBox(width: 8),
                        Text(
                          diary.style,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      diary.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Color _getTagColor(String style) {
    switch (style) {
      case '哲学': return Colors.purple;
      case '搞笑': return Colors.orange;
      case '治愈': return Colors.green;
      case '中二': return Colors.red;
      case '小红书': return Colors.pink;
      default: return Colors.blue;
    }
  }

  Widget _getTagIcon(String style) {
    IconData icon;
    Color color = _getTagColor(style);
    
    switch (style) {
      case '哲学': icon = Icons.lightbulb_outline; break;
      case '搞笑': icon = Icons.sentiment_very_satisfied; break;
      case '治愈': icon = Icons.spa_outlined; break;
      case '中二': icon = Icons.flash_on; break;
      case '小红书': icon = Icons.favorite_border; break;
      default: icon = Icons.article_outlined;
    }

    return Icon(icon, size: 16, color: color);
  }
}
