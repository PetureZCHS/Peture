import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/supabase_service.dart';

/// 发帖页：多图 + 文案 + 话题，支持寻宠/搭档分享预填
class PublishPostPage extends StatefulWidget {
  const PublishPostPage({
    super.key,
    this.initialImageFile,
    this.initialImageBytes,
    this.initialContent,
    this.sourceType = 'normal',
  });

  final File? initialImageFile;
  final Uint8List? initialImageBytes;
  final String? initialContent;
  final String sourceType;

  @override
  State<PublishPostPage> createState() => _PublishPostPageState();
}

class _PublishPostPageState extends State<PublishPostPage> {
  final SupabaseService _supabase = SupabaseService();
  final TextEditingController _contentController = TextEditingController();
  final List<File> _pickedFiles = [];
  final Set<String> _selectedTopics = {};
  bool _loading = false;
  bool _initialImageRemoved = false;

  static const List<String> _topicOptions = [
    '寻宠求助',
    '日常分享',
    '健身打卡',
    '萌宠日常',
    '养宠心得',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      _contentController.text = widget.initialContent!;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  bool get _hasInitialImage =>
      !_initialImageRemoved &&
      (widget.initialImageFile != null || widget.initialImageBytes != null);

  int get _totalImageCount => (_hasInitialImage ? 1 : 0) + _pickedFiles.length;

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final list = await picker.pickMultiImage(
      imageQuality: 85,
      limit: 9 - _totalImageCount,
    );
    if (!mounted) return;
    if (list.isEmpty) return;
    setState(() {
      for (final x in list) {
        if (x.path.isNotEmpty) _pickedFiles.add(File(x.path));
      }
    });
  }

  void _removePickedAt(int index) {
    setState(() {
      _pickedFiles.removeAt(index);
    });
  }

  void _removeInitialImage() {
    setState(() => _initialImageRemoved = true);
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写点内容吧～')),
      );
      return;
    }
    if (_totalImageCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少添加一张图片')),
      );
      return;
    }

    final userId = await _supabase.currentUserId;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录')),
      );
      return;
    }

    setState(() => _loading = true);

    final ts = DateTime.now().millisecondsSinceEpoch;
    final List<String> imageUrls = [];

    try {
      if (widget.initialImageBytes != null) {
        final path = '$userId/${ts}_0.jpg';
        final url = await _supabase.uploadPostImageBytes(
            widget.initialImageBytes!, path);
        if (url != null) imageUrls.add(url);
      } else if (widget.initialImageFile != null) {
        final path = '$userId/${ts}_0.jpg';
        final url =
            await _supabase.uploadPostImage(widget.initialImageFile!, path);
        if (url != null) imageUrls.add(url);
      }

      for (var i = 0; i < _pickedFiles.length; i++) {
        final idx = imageUrls.length;
        final path = '$userId/${ts}_$idx.jpg';
        final url = await _supabase.uploadPostImage(_pickedFiles[i], path);
        if (url != null) imageUrls.add(url);
      }

      if (imageUrls.isEmpty) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('图片上传失败，请重试')),
        );
        return;
      }

      final topicIds = _selectedTopics.toList();
      final post = await _supabase.createCommunityPost(
        content: content,
        imageUrls: imageUrls,
        topicIds: topicIds,
        sourceType: widget.sourceType,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (post == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发布失败，请重试')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('发布成功'), backgroundColor: Colors.green),
      );
      // 只需要pop返回，通过返回值true通知调用方刷新数据
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发布失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1E1E1E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '发布动态',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '发布',
                    style: TextStyle(
                      color: Color(0xFFFF2442),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _contentController,
              maxLines: 6,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: '分享你的宠物日常吧～',
                border: InputBorder.none,
                filled: true,
                fillColor: Colors.white,
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '添加图片',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                const crossCount = 3;
                const gap = 8.0;
                final size = (constraints.maxWidth - (crossCount - 1) * gap) /
                    crossCount;
                final list = <Widget>[];
                if (_hasInitialImage) {
                  list.add(_buildImagePreview(
                    isInitial: true,
                    size: size,
                    onRemove: _hasInitialImage ? _removeInitialImage : null,
                    child: widget.initialImageBytes != null
                        ? Image.memory(
                            widget.initialImageBytes!,
                            fit: BoxFit.cover,
                            width: size,
                            height: size,
                          )
                        : widget.initialImageFile != null
                            ? Image.file(
                                widget.initialImageFile!,
                                fit: BoxFit.cover,
                                width: size,
                                height: size,
                              )
                            : const SizedBox(),
                  ));
                }
                for (var i = 0; i < _pickedFiles.length; i++) {
                  list.add(_buildImagePreview(
                    size: size,
                    onRemove: () => _removePickedAt(i),
                    child: Image.file(
                      _pickedFiles[i],
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                    ),
                  ));
                }
                if (_totalImageCount < 9) {
                  list.add(
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEEEEEE)),
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 40,
                          color: Color(0xFFCCCCCC),
                        ),
                      ),
                    ),
                  );
                }
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: list,
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              '选择话题',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _topicOptions.map((t) {
                final selected = _selectedTopics.contains(t);
                return FilterChip(
                  label: Text(t),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedTopics.add(t);
                      } else {
                        _selectedTopics.remove(t);
                      }
                    });
                  },
                  selectedColor: const Color(0xFFFF2442).withOpacity(0.2),
                  checkmarkColor: const Color(0xFFFF2442),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview({
    required double size,
    Widget? child,
    VoidCallback? onRemove,
    bool isInitial = false,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: size,
            height: size,
            child: child,
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
