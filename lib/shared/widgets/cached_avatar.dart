import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/avatar_cache_service.dart';

/// 带缓存的头像显示组件
/// 
/// 支持用户头像和宠物头像，自动使用本地缓存避免重复下载。
/// 
/// 使用示例：
/// ```dart
/// // 用户头像
/// CachedAvatar(
///   avatarUrl: userAvatarUrl,
///   type: AvatarType.user,
///   radius: 24,
///   fallbackText: 'U',
/// )
/// 
/// // 宠物头像
/// CachedAvatar(
///   avatarUrl: petAvatarUrl,
///   type: AvatarType.pet,
///   radius: 20,
///   fallbackText: '🐶',
/// )
/// ```
class CachedAvatar extends StatefulWidget {
  final String? avatarUrl;
  final AvatarType type;
  final double radius;
  final String? fallbackText;
  final Color? backgroundColor;
  final TextStyle? textStyle;
  final VoidCallback? onTap;

  const CachedAvatar({
    super.key,
    this.avatarUrl,
    required this.type,
    this.radius = 24,
    this.fallbackText,
    this.backgroundColor,
    this.textStyle,
    this.onTap,
  });

  @override
  State<CachedAvatar> createState() => _CachedAvatarState();
}

class _CachedAvatarState extends State<CachedAvatar> {
  final AvatarCacheService _cacheService = AvatarCacheService();
  Uint8List? _imageBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  void didUpdateWidget(CachedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _loadAvatar();
    }
  }

  Future<void> _loadAvatar() async {
    if (widget.avatarUrl == null || widget.avatarUrl!.isEmpty) {
      setState(() => _imageBytes = null);
      return;
    }

    setState(() => _isLoading = true);

    final bytes = await _cacheService.getAvatarBytes(
      widget.avatarUrl!,
      type: widget.type,
    );

    if (mounted) {
      setState(() {
        _imageBytes = bytes;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar;

    if (_isLoading) {
      // 加载中显示占位符
      avatar = CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor ?? Colors.grey[200],
        child: SizedBox(
          width: widget.radius * 0.6,
          height: widget.radius * 0.6,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        ),
      );
    } else if (_imageBytes != null) {
      // 显示缓存的图片
      avatar = CircleAvatar(
        radius: widget.radius,
        backgroundImage: MemoryImage(_imageBytes!),
      );
    } else {
      // 显示文字占位符
      avatar = CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor ?? Colors.blue.withOpacity(0.1),
        child: Text(
          widget.fallbackText ?? '?',
          style: widget.textStyle ??
              TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: widget.radius * 0.6,
              ),
        ),
      );
    }

    if (widget.onTap != null) {
      avatar = GestureDetector(
        onTap: widget.onTap,
        child: avatar,
      );
    }

    return avatar;
  }
}
