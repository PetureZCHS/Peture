import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../models/pet_diary.dart';
import 'pet_diary_result_page.dart';
import 'package:intl/intl.dart';

/// 宠物日记列表页面
class PetDiaryListPage extends StatefulWidget {
  const PetDiaryListPage({super.key});

  @override
  State<PetDiaryListPage> createState() => _PetDiaryListPageState();
}

class _PetDiaryListPageState extends State<PetDiaryListPage> {
  List<PetDiary> _diaries = [];
  bool _isLoading = true;
  final _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadDiaries();
  }

  Future<void> _loadDiaries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final diaries = await _supabaseService.getAllDiaries();
      if (mounted) {
        setState(() {
          _diaries = diaries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteDiary(String id) async {
    try {
      final success = await _supabaseService.deleteDiary(id);
      if (success) {
        _loadDiaries();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('日记已删除'),
              backgroundColor: Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('删除失败，请检查网络连接'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '我的日记',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7B95FF)),
            )
          : _diaries.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadDiaries,
                  color: const Color(0xFF7B95FF),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _diaries.length,
                    itemBuilder: (context, index) {
                      final diary = _diaries[index];
                      return _buildDiaryCard(diary);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7B95FF).withOpacity(0.2),
                  const Color(0xFF9B7FFF).withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(Icons.pets, size: 60, color: Color(0xFF7B95FF)),
          ),
          const SizedBox(height: 24),
          const Text(
            '还没有保存的日记',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '去撰写一篇日记吧！',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaryCard(PetDiary diary) {
    final dateFormat = DateFormat('yyyy年MM月dd日 HH:mm');
    final formattedDate = dateFormat.format(diary.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PetDiaryResultPage(
                  originalText: diary.originalText,
                  diaryContent: diary.content,
                  style: diary.style,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部：日期和风格
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Color(0xFF7B95FF),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B95FF), Color(0xFF9B7FFF)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        diary.style,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.grey,
                      ),
                      onPressed: () => _showDeleteDialog(diary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 日记内容预览
                Text(
                  diary.content.length > 100
                      ? '${diary.content.substring(0, 100)}...'
                      : diary.content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.grey[800],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(PetDiary diary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除日记'),
        content: const Text('确定要删除这篇日记吗？'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (diary.id != null) {
                _deleteDiary(diary.id!);
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
