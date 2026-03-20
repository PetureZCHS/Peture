import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:path/path.dart' as path;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/utils/ui_helpers.dart';
import 'loading_page.dart';

class AppColors {
  static const Color background = Color(0xFFF2F2F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF5D5FEF);
  static const Color textDark = Color(0xFF1D1D1F);
  static const Color textGrey = Color(0xFF8E8E93);
  static const Color textLight = Color(0xFFAEAEB2);

  static const Color orb1 = Color(0xFFC4E0E5);
  static const Color orb2 = Color(0xFFE2D1F9);
  static const Color orb3 = Color(0xFFFFDFC4);
}

class FadePageRoute extends PageRouteBuilder {
  final Widget page;

  FadePageRoute({required this.page})
      : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) =>
              FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
}

class PreparationPage extends StatefulWidget {
  static const String routeName = '/preparation';
  final File? initialSelectedImage;
  final int initialStyleIndex;

  const PreparationPage(
      {super.key, this.initialSelectedImage, this.initialStyleIndex = 0});

  @override
  State<PreparationPage> createState() => _PreparationPageState();
}

enum UploadStatus {
  idle,
  uploading,
  success,
  failed,
}

class AiStylePreset {
  final String id;
  final String name;
  final String aspectRatio;
  final DateTime createdAt;
  final String? localImagePath;

  const AiStylePreset({
    required this.id,
    required this.name,
    required this.aspectRatio,
    required this.createdAt,
    this.localImagePath,
  });

  factory AiStylePreset.fromDb(Map<String, dynamic> json) {
    return AiStylePreset(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      aspectRatio: (json['aspect_ratio'] as String? ?? '1:1').trim(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory AiStylePreset.fromCache(Map<String, dynamic> json) {
    return AiStylePreset(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      aspectRatio: (json['aspect_ratio'] as String? ?? '1:1').trim(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      localImagePath: (json['local_image_path'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'id': id,
      'name': name,
      'aspect_ratio': aspectRatio,
      'created_at': createdAt.toIso8601String(),
      'local_image_path': localImagePath,
    };
  }

  AiStylePreset copyWith({
    String? localImagePath,
  }) {
    return AiStylePreset(
      id: id,
      name: name,
      aspectRatio: aspectRatio,
      createdAt: createdAt,
      localImagePath: localImagePath,
    );
  }
}

class _PreparationPageState extends State<PreparationPage>
    with TickerProviderStateMixin {
  static const String _presetView = 'vw_ai_image_presets';
  static const String _presetBucket = 'assets';
  static const String _defaultAspectRatio = '1:1';
  static const String _cacheVersion = 'v1_1_4';
  static const String _lastSelectedIndexKeyPrefix =
      'img_gen_last_selected_index_v1_1_4';

  File? _selectedImage;
  int _selectedStyleIndex = 0;

  late final ScrollController _styleScrollController;

  UploadStatus _uploadStatus = UploadStatus.idle;
  double _uploadProgress = 0.0;
  String _uploadError = '';

  bool _isStartingTask = false;
  bool _hasNavigatedToLoadingPage = false;
  bool _isLoadingStyles = true;
  String _selectedAspectRatio = _defaultAspectRatio;
  int _styleLoadEpoch = 0;
  final Map<String, int> _lastSelectedIndexByAspectRatio = {
    _defaultAspectRatio: 0,
  };

  late AnimationController _orbController;

  List<AiStylePreset> _styles = const [];

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _styleScrollController = ScrollController();

    unawaited(_initializeStyleSelectionAndLoad());

    if (widget.initialSelectedImage != null) {
      _selectedImage = widget.initialSelectedImage;
      _selectedStyleIndex = widget.initialStyleIndex;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedStyle(animated: false);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isStartingTask) {
          setState(() {
            _isStartingTask = false;
          });
        }
      });

      _hasNavigatedToLoadingPage = false;
    }
  }

  String _normalizedAspectRatio(String aspectRatio) {
    return aspectRatio.replaceAll(':', '_');
  }

  String _cacheStylesKey(String aspectRatio) =>
      'img_gen_preset_cache_${_cacheVersion}_${_normalizedAspectRatio(aspectRatio)}';

  String _cacheLastSyncKey(String aspectRatio) =>
      'img_gen_preset_last_sync_${_cacheVersion}_${_normalizedAspectRatio(aspectRatio)}';

  String _cacheLatestCreatedAtKey(String aspectRatio) =>
      'img_gen_preset_latest_created_at_${_cacheVersion}_${_normalizedAspectRatio(aspectRatio)}';

  String _cacheCountKey(String aspectRatio) =>
      'img_gen_preset_count_${_cacheVersion}_${_normalizedAspectRatio(aspectRatio)}';

  String _lastSelectedIndexKey(String aspectRatio) =>
      '${_lastSelectedIndexKeyPrefix}_${_normalizedAspectRatio(aspectRatio)}';

  Future<void> _initializeStyleSelectionAndLoad() async {
    await _restoreLastSelectedIndices();
    if (!mounted) return;
    await _loadAndSyncStylePresets(aspectRatio: _selectedAspectRatio);
  }

  Future<void> _restoreLastSelectedIndices() async {
    final prefs = await SharedPreferences.getInstance();
    for (final aspectRatio in const ['1:1', '9:16']) {
      final stored = prefs.getInt(_lastSelectedIndexKey(aspectRatio));
      if (stored != null && stored >= 0) {
        _lastSelectedIndexByAspectRatio[aspectRatio] = stored;
      }
    }
    _selectedStyleIndex = _getRememberedStyleIndex(_selectedAspectRatio);
  }

  int _getRememberedStyleIndex(String aspectRatio) {
    return _lastSelectedIndexByAspectRatio[aspectRatio] ?? 0;
  }

  int _clampedRememberedStyleIndex(String aspectRatio, int maxLength) {
    if (maxLength <= 0) return 0;
    final remembered = _getRememberedStyleIndex(aspectRatio);
    return remembered.clamp(0, maxLength - 1);
  }

  void _rememberSelectedStyleIndex(String aspectRatio, int index) {
    _lastSelectedIndexByAspectRatio[aspectRatio] = index;
    unawaited(_persistLastSelectedIndex(aspectRatio, index));
  }

  Future<void> _persistLastSelectedIndex(String aspectRatio, int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSelectedIndexKey(aspectRatio), index);
  }

  Future<void> _loadAndSyncStylePresets({required String aspectRatio}) async {
    await _loadStylesFromCache(aspectRatio: aspectRatio);
    await _syncStylePresetsIncrementally(aspectRatio: aspectRatio);
  }

  Future<void> _loadStylesFromCache({required String aspectRatio}) async {
    final int epoch = _styleLoadEpoch;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheStylesKey(aspectRatio));
    if (raw == null || raw.isEmpty) {
      if (mounted && epoch == _styleLoadEpoch) {
        setState(() {
          _isLoadingStyles = true;
        });
      }
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final cached = <AiStylePreset>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final preset = AiStylePreset.fromCache(item);
          if (preset.id.isNotEmpty && preset.name.isNotEmpty) {
            final localPath = preset.localImagePath;
            if (localPath != null && localPath.isNotEmpty) {
              final localFile = File(localPath);
              if (await localFile.exists()) {
                cached.add(preset);
                continue;
              }
            }
            cached.add(preset.copyWith(localImagePath: null));
          }
        }
      }

      if (!mounted || epoch != _styleLoadEpoch) return;
      setState(() {
        _styles = cached;
        _selectedStyleIndex =
            _clampedRememberedStyleIndex(aspectRatio, cached.length);
        _isLoadingStyles = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedStyle(animated: false);
      });
    } catch (e) {
      debugPrint('加载风格缓存失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingStyles = true;
        });
      }
    }
  }

  Future<void> _syncStylePresetsIncrementally({
    required String aspectRatio,
  }) async {
    try {
      final int epoch = _styleLoadEpoch;
      final prefs = await SharedPreferences.getInstance();
      final supabase = Supabase.instance.client;

      final latestRow = await supabase
          .from(_presetView)
          .select('created_at')
          .eq('aspect_ratio', aspectRatio)
          .order('created_at', ascending: false)
          .limit(1);

      final currentLatestCreatedAt =
          latestRow.isNotEmpty ? latestRow.first['created_at']?.toString() : '';

      final countRows = await supabase
          .from(_presetView)
          .select('id')
          .eq('aspect_ratio', aspectRatio);
      final currentCount = countRows.length;

        final cachedLatestCreatedAt =
          prefs.getString(_cacheLatestCreatedAtKey(aspectRatio));
        final cachedCount = prefs.getInt(_cacheCountKey(aspectRatio));

      if (_styles.isNotEmpty &&
          cachedLatestCreatedAt == currentLatestCreatedAt &&
          cachedCount == currentCount) {
        if (mounted) {
          setState(() {
            _isLoadingStyles = false;
          });
        }
        return;
      }

        final String? lastSyncAt = prefs.getString(_cacheLastSyncKey(aspectRatio));
      final bool shouldFullRefresh =
          _styles.isEmpty || cachedCount == null || currentCount < cachedCount;

      List<Map<String, dynamic>> rows;
      if (shouldFullRefresh || lastSyncAt == null || lastSyncAt.isEmpty) {
        final data = await supabase
            .from(_presetView)
            .select('id,name,aspect_ratio,created_at')
            .eq('aspect_ratio', aspectRatio)
            .order('created_at', ascending: true);
        rows = List<Map<String, dynamic>>.from(data);
      } else {
        final data = await supabase
            .from(_presetView)
            .select('id,name,aspect_ratio,created_at')
            .eq('aspect_ratio', aspectRatio)
            .gt('created_at', lastSyncAt)
            .order('created_at', ascending: true);
        rows = List<Map<String, dynamic>>.from(data);
      }

      final Map<String, AiStylePreset> mergedMap = {
        for (final preset in _styles) preset.id: preset,
      };

      if (shouldFullRefresh) {
        mergedMap.clear();
      }

      for (final row in rows) {
        final remotePreset = AiStylePreset.fromDb(row);
        if (remotePreset.id.isEmpty || remotePreset.name.isEmpty) continue;
        final withImage =
            await _ensurePresetImageCached(remotePreset, keepOldPath: true);
        mergedMap[withImage.id] = withImage;
      }

      final merged = mergedMap.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final nowIso = DateTime.now().toIso8601String();
      await prefs.setString(_cacheStylesKey(aspectRatio),
          jsonEncode(merged.map((e) => e.toCacheJson()).toList()));
      await prefs.setString(_cacheLastSyncKey(aspectRatio), nowIso);
      await prefs.setString(
          _cacheLatestCreatedAtKey(aspectRatio), currentLatestCreatedAt ?? '');
      await prefs.setInt(_cacheCountKey(aspectRatio), currentCount);

      if (!mounted || epoch != _styleLoadEpoch) return;
      setState(() {
        _styles = merged;
        _selectedStyleIndex =
            _clampedRememberedStyleIndex(aspectRatio, merged.length);
        _isLoadingStyles = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedStyle(animated: false);
      });
    } catch (e, st) {
      debugPrint('同步风格预设失败: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoadingStyles = false;
        });
      }
    }
  }

  Future<AiStylePreset> _ensurePresetImageCached(
    AiStylePreset preset, {
    required bool keepOldPath,
  }) async {
    final existingPreset = keepOldPath
        ? _styles.cast<AiStylePreset?>().firstWhere(
              (item) => item?.id == preset.id,
              orElse: () => null,
            )
        : null;
    final existingPath = existingPreset?.localImagePath;

    if (existingPath != null && existingPath.isNotEmpty) {
      final existingFile = File(existingPath);
      if (await existingFile.exists()) {
        return preset.copyWith(localImagePath: existingPath);
      }
    }

    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final ratioFolder = _normalizedAspectRatio(preset.aspectRatio);
      final cacheDir =
          Directory(path.join(baseDir.path, 'ai_style_cache', ratioFolder));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final fileName = '${preset.id}.jpg';
      final localPath = path.join(cacheDir.path, fileName);
      final localFile = File(localPath);

      if (!await localFile.exists()) {
        final storagePath = 'ai_image_presets/$ratioFolder/${preset.id}.jpg';
        final bytes = await Supabase.instance.client.storage
            .from(_presetBucket)
            .download(storagePath);
        await localFile.writeAsBytes(bytes, flush: true);
      }

      return preset.copyWith(localImagePath: localPath);
    } catch (e) {
      debugPrint('缓存风格示例图失败(${preset.id}): $e');
      return preset;
    }
  }

  void _onAspectRatioChanged(String aspectRatio) {
    if (_selectedAspectRatio == aspectRatio) return;
    _rememberSelectedStyleIndex(_selectedAspectRatio, _selectedStyleIndex);

    final nextIndex = _getRememberedStyleIndex(aspectRatio);
    setState(() {
      _selectedAspectRatio = aspectRatio;
      _styles = const [];
      _selectedStyleIndex = nextIndex;
      _isLoadingStyles = true;
      _uploadError = '';
      _styleLoadEpoch += 1;
    });
    unawaited(_loadAndSyncStylePresets(aspectRatio: aspectRatio));
  }

  @override
  void dispose() {
    _orbController.dispose();
    _styleScrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  void _onImageAreaTap() {
    if (_selectedImage == null) {
      _pickImage();
    } else {
      Navigator.of(context).push(
        TransparentImageRoute(
          builder: (_) => FullscreenImagePage(
            imageFile: _selectedImage!,
            heroTag: 'pet_photo_hero',
          ),
        ),
      );
    }
  }

  Future<String?> _uploadImageToSupabaseStorage(File originalFile) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      debugPrint('❌ 用户未认证，无法上传文件');
      if (mounted) {
        setState(() {
          _uploadStatus = UploadStatus.failed;
          _uploadError = '请先登录后再尝试上传图片';
        });
      }
      return null;
    }

    try {
      setState(() {
        _uploadStatus = UploadStatus.uploading;
        _uploadProgress = 0.0;
        _uploadError = '';
      });

      final userId = user.id;

      final File fileToUpload =
          await _compressAndConvertImage(originalFile) ?? originalFile;

      final fileExtension = '.jpg';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final uniqueId = const Uuid().v4();

      final fileName = '${timestamp}_$uniqueId$fileExtension';
      final filePath = '$userId/original/$fileName';
      debugPrint('准备上传到: $filePath');

      final bool usedCompressedTempFile =
          fileToUpload.path != originalFile.path;

      final uploadFuture = supabase.storage.from('ai-wallpapers').upload(
            filePath,
            fileToUpload,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      final progressTimer =
          Timer.periodic(const Duration(milliseconds: 200), (timer) {
        if (!mounted) return;
        setState(() {
          _uploadProgress = (_uploadProgress + 0.05).clamp(0.1, 0.95);
        });
      });

      try {
        await uploadFuture;

        if (mounted) {
          setState(() {
            _uploadProgress = 1.0;
            _uploadStatus = UploadStatus.success;
          });
        }
        debugPrint('✅ 图片上传成功: $filePath');
        return fileName;
      } finally {
        if (progressTimer.isActive) {
          progressTimer.cancel();
        }
        if (usedCompressedTempFile) {
          try {
            if (await fileToUpload.exists()) {
              await fileToUpload.delete();
              debugPrint('已删除临时压缩文件: ${fileToUpload.path}');
            }
          } catch (e) {
            debugPrint('删除临时压缩文件失败: $e');
          }
        }
      }
    } on StorageException catch (e) {
      debugPrint('❌ StorageException: ${e.message}, Status: ${e.statusCode}');
      final errorMessage =
          e.statusCode == '403' ? '权限不足，无法上传图片' : '存储服务错误: ${e.message}';
      _showErrorSnackBar(errorMessage);
      return null;
    } on SocketException catch (e) {
      debugPrint('❌ 网络错误 (SocketException): $e');
      final errorMessage = '网络连接失败：请检查您的网络后重试';
      _showErrorSnackBar(errorMessage);
      return null;
    } on TimeoutException catch (e) {
      debugPrint('❌ 请求超时: $e');
      final errorMessage = '请求超时：请稍后重试';
      _showErrorSnackBar(errorMessage);
      return null;
    } on HttpException catch (e) {
      debugPrint('❌ HTTP 错误: $e');
      final errorMessage = '网络错误：${e.message}';
      _showErrorSnackBar(errorMessage);
      return null;
    } catch (e, st) {
      debugPrint('❌ 图片上传异常: $e\n$st');
      final errorMessage = '上传失败：发生未知错误（${e.runtimeType}）';
      _showErrorSnackBar(errorMessage);
      return null;
    }
  }

  Future<File?> _compressAndConvertImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(dir.path, '${const Uuid().v4()}.jpg');

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 80,
        format: CompressFormat.jpeg,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result == null) {
        debugPrint('⚠️ 压缩失败，将使用原图上传');
        return null;
      }

      debugPrint(
          '📉 图片压缩完成: 原图 ${(file.lengthSync() / 1024).toStringAsFixed(2)}KB -> 压缩后 ${(await result.length() / 1024).toStringAsFixed(2)}KB');

      return File(result.path);
    } catch (e) {
      debugPrint('⚠️ 压缩过程出错: $e');
      return null;
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      setState(() {
        _uploadStatus = UploadStatus.failed;
        _uploadError = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hasNavigatedToLoadingPage) {
        _hasNavigatedToLoadingPage = false;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Peture AI 图像实验室"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Stack(
            children: [
              Container(color: AppColors.background),
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, child) {
                  final curvedValue = CurvedAnimation(
                          parent: _orbController, curve: Curves.easeInOut)
                      .value;
                  return Positioned(
                    top: -100 + (curvedValue * 40),
                    left: -50 + (curvedValue * 20),
                    child: Container(
                      width: 500,
                      height: 500,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.orb1.withOpacity(0.5),
                      ),
                    ).blurred(sigmaX: 90, sigmaY: 90),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, child) {
                  final curvedValue = CurvedAnimation(
                          parent: _orbController, curve: Curves.easeInOut)
                      .value;
                  return Positioned(
                    top: 300 + (math.sin(curvedValue * math.pi) * 60),
                    right: -100,
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.orb3.withOpacity(0.4),
                      ),
                    ).blurred(sigmaX: 80, sigmaY: 80),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, child) {
                  final curvedValue = CurvedAnimation(
                          parent: _orbController, curve: Curves.easeInOut)
                      .value;
                  return Positioned(
                    bottom: -150,
                    left: -80 + (curvedValue * 150),
                    child: Container(
                      width: 600,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.orb2.withOpacity(0.5),
                      ),
                    ).blurred(sigmaX: 100, sigmaY: 100),
                  );
                },
              ),
            ],
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _onImageAreaTap,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                              width: 1.2,
                            ),
                            gradient: RadialGradient(
                              radius: 1.8,
                              center: Alignment.topCenter,
                              colors: [
                                AppColors.surface.withOpacity(0.15),
                                AppColors.surface.withOpacity(0.3),
                                AppColors.surface.withOpacity(0.45),
                              ],
                              stops: const [0.0, 0.6, 1.0],
                            ),
                          ),
                          child: _selectedImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.primary.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 40,
                                        color: const Color(0xFF5D5FEF)
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "选择宠物生活照",
                                      style: TextStyle(
                                        color: const Color(0xFF8E8E93)
                                            .withOpacity(0.9),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "尽量包含宠物全身",
                                      style: TextStyle(
                                        color: Color(0xFFAEAEB2),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      "确保面部清晰可见",
                                      style: TextStyle(
                                        color: Color(0xFFAEAEB2),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                )
                              : Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Hero(
                                        tag: 'pet_photo_hero',
                                        child: Image.file(
                                          _selectedImage!,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 8,
                                      bottom: 8,
                                      child: GestureDetector(
                                        onTap: () async {
                                          await _pickImage();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.5),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.refresh,
                                                  size: 14,
                                                  color: Colors.white),
                                              SizedBox(width: 4),
                                              Text(
                                                "重新选择",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "选择样式",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D1D1F),
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildAspectRatioButton(
                          label: '头像 1:1',
                          value: '1:1',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildAspectRatioButton(
                          label: '封面 / 壁纸 9:16',
                          value: '9:16',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 160,
                  child: _isLoadingStyles && _styles.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 10),
                              Text(
                                '正在从云端载入样式，请等待',
                                style: TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _styles.isEmpty
                          ? const Center(
                              child: Text(
                                '暂无可用风格',
                                style: TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              scrollDirection: Axis.horizontal,
                              itemCount: _styles.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (ctx, index) {
                                final isSelected = _selectedStyleIndex == index;
                                return _buildTechStyleCard(index, isSelected);
                              },
                              controller: _styleScrollController,
                            ),
                ),
                const Spacer(),
                if (_uploadError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _uploadError,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            if (_selectedImage != null) {
                              setState(() {
                                _uploadStatus = UploadStatus.uploading;
                                _uploadError = '';
                                _isStartingTask = false;
                              });
                              _uploadImageToSupabaseStorage(_selectedImage!);
                            }
                          },
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                Container(
                  height: 80,
                  padding: const EdgeInsets.all(20.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.6),
                                width: 1.2,
                              ),
                              gradient: RadialGradient(
                                radius: 1.8,
                                center: Alignment.topCenter,
                                colors: [
                                  Colors.white.withOpacity(0.25),
                                  Colors.white.withOpacity(0.5),
                                  Colors.white.withOpacity(0.7),
                                ],
                                stops: const [0.0, 0.6, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: (_selectedImage != null &&
                                  _styles.isNotEmpty &&
                                  !_isStartingTask &&
                                  _uploadStatus != UploadStatus.uploading)
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF5D5FEF),
                                    Color(0xFF8B77FF)
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFFC0C0C0),
                                    Color(0xFFA0A0A0)
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: (_selectedImage != null)
                                  ? const Color(0xFF5D5FEF).withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: -1,
                              offset: const Offset(0, 3),
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.4),
                              blurRadius: 1,
                              offset: const Offset(0, -1),
                              blurStyle: BlurStyle.inner,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: (_selectedImage != null &&
                                    _styles.isNotEmpty &&
                                    _uploadStatus != UploadStatus.uploading &&
                                    !_isStartingTask)
                                ? () async {
                                    final uploadedFileName =
                                        await _uploadImageToSupabaseStorage(
                                            _selectedImage!);

                                    if (uploadedFileName != null && mounted) {
                                      setState(() {
                                        _isStartingTask = true;
                                      });

                                      if (uploadedFileName.isNotEmpty) {
                                        if (_selectedStyleIndex < 0 ||
                                            _selectedStyleIndex >=
                                                _styles.length) {
                                          setState(() {
                                            _isStartingTask = false;
                                            _uploadStatus = UploadStatus.failed;
                                            _uploadError = '风格索引异常，请重试';
                                          });
                                          return;
                                        }

                                        final style =
                                            _styles[_selectedStyleIndex].id;

                                        final supabase =
                                            Supabase.instance.client;
                                        final token = supabase
                                            .auth.currentSession?.accessToken;

                                        if (token == null) {
                                          setState(() {
                                            _isStartingTask = false;
                                            _uploadStatus = UploadStatus.failed;
                                            _uploadError = '未登录或会话已过期';
                                          });
                                          return;
                                        }

                                        // 核心变更：立刻创建生图请求的 Future
                                        final generationFuture =
                                            supabase.functions.invoke(
                                          'img-gen',
                                          body: {
                                            'file_name': uploadedFileName,
                                            'style': style,
                                          },
                                          headers: {
                                            'Authorization': 'Bearer $token',
                                            'Content-Type': 'application/json',
                                          },
                                        );

                                        setState(() {
                                          _hasNavigatedToLoadingPage = true;
                                        });

                                        if (!context.mounted) return;
                                        // 核心变更：将 Future 传给 LoadingPage
                                        await Navigator.push(
                                          context,
                                          FadePageRoute(
                                            page: LoadingPage(
                                              originalImage: _selectedImage!,
                                              uploadedFileName:
                                                  uploadedFileName,
                                              style: style,
                                              generationFuture:
                                                  generationFuture,
                                            ),
                                          ),
                                        );

                                        if (mounted) {
                                          setState(() {
                                            _isStartingTask = false;
                                            _hasNavigatedToLoadingPage = false;
                                            _uploadStatus = UploadStatus.idle;
                                            _uploadProgress = 0.0;
                                          });
                                        }
                                      }
                                    }
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(25),
                            child: Center(
                              child: _uploadStatus == UploadStatus.uploading
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '上传中...',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 16,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black26,
                                                offset: Offset(0, 1),
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : _isStartingTask
                                      ? const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              '正在进入生成流程...',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontSize: 16,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black26,
                                                    offset: Offset(0, 1),
                                                    blurRadius: 2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          '开始生成',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 16,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black26,
                                                offset: Offset(0, 1),
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                            ),
                          ),
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
    );
  }

  Widget _buildTechStyleCard(int index, bool isSelected) {
    final preset = _styles[index];

    return GestureDetector(
      onTap: () => setState(() => _onStyleSelected(index)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        transform:
            isSelected ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: const Color(0xFF5D5FEF), width: 2)
              : Border.all(color: Colors.white.withOpacity(0.6), width: 1.2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF5D5FEF).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: RadialGradient(
                  radius: 2.0,
                  center: Alignment.topCenter,
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.4),
                    Colors.white.withOpacity(0.6),
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(10)),
                      child: _buildPresetImage(preset),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF5D5FEF)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(12)),
                    ),
                    child: Text(
                      preset.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            isSelected ? Colors.white : const Color(0xFF1D1D1F),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAspectRatioButton({
    required String label,
    required String value,
  }) {
    final isSelected = _selectedAspectRatio == value;
    return GestureDetector(
      onTap: () => _onAspectRatioChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? const Color(0xFF5D5FEF)
              : Colors.white.withOpacity(0.65),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF5D5FEF)
                : Colors.white.withOpacity(0.9),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF5D5FEF).withOpacity(0.22)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF1D1D1F),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildPresetImage(AiStylePreset preset) {
    final localPath = preset.localImagePath;
    if (localPath != null && localPath.isNotEmpty) {
      final localFile = File(localPath);
      if (localFile.existsSync()) {
        return Image.file(
          localFile,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPresetImageFallback(preset),
        );
      }
    }

    return _buildPresetImageFallback(preset);
  }

  Widget _buildPresetImageFallback(AiStylePreset preset) {
    return Container(
      color: const Color(0xFFE5E5EA),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            color: Color(0xFF8E8E93),
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            preset.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF636366),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '示例图待上传',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  void _onStyleSelected(int index) {
    setState(() {
      _selectedStyleIndex = index;
    });
    _rememberSelectedStyleIndex(_selectedAspectRatio, index);
    _scrollToSelectedStyle();
  }

  void _scrollToSelectedStyle({bool animated = true}) {
    if (!_styleScrollController.hasClients) return;

    const double itemExtent = 112.0;
    final target = (_selectedStyleIndex * itemExtent) -
        (MediaQuery.of(context).size.width / 2) +
        (itemExtent / 2);
    final clamped =
        target.clamp(0.0, _styleScrollController.position.maxScrollExtent);

    if (animated) {
      _styleScrollController.animateTo(clamped,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    } else {
      _styleScrollController.jumpTo(clamped);
    }
  }
}

class TransparentImageRoute extends PageRouteBuilder {
  TransparentImageRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          opaque: false,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 200),
        );
}

class FullscreenImagePage extends StatefulWidget {
  final File imageFile;
  final String heroTag;

  const FullscreenImagePage({
    super.key,
    required this.imageFile,
    required this.heroTag,
  });

  @override
  State<FullscreenImagePage> createState() => _FullscreenImagePageState();
}

class _FullscreenImagePageState extends State<FullscreenImagePage>
    with SingleTickerProviderStateMixin {
  double dragOffsetY = 0;
  late AnimationController _controller;
  late Animation<double> _reboundAnimation;

  static const double dismissThreshold = 150;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    super.dispose();
  }

  void _runReboundAnimation() {
    _reboundAnimation =
        Tween<double>(begin: dragOffsetY, end: 0).animate(_controller)
          ..addListener(() {
            setState(() {
              dragOffsetY = _reboundAnimation.value;
            });
          });
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final dragPercent = (dragOffsetY / screenHeight).clamp(0.0, 1.0);
    final scale = 1.0 - dragPercent * 0.4;
    final bgOpacity = (1.0 - dragPercent).clamp(0.0, 1.0);

    return Stack(
      children: [
        Opacity(
          opacity: bgOpacity,
          child: Container(color: Colors.black),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            onVerticalDragUpdate: (details) {
              setState(() {
                dragOffsetY += details.delta.dy;
                if (dragOffsetY < 0) dragOffsetY = 0;
              });
            },
            onVerticalDragEnd: (_) {
              if (dragOffsetY > dismissThreshold) {
                Navigator.pop(context);
              } else {
                _runReboundAnimation();
              }
            },
            child: Transform.translate(
              offset: Offset(0, dragOffsetY),
              child: Transform.scale(
                scale: scale,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(
                    child: Hero(
                      tag: widget.heroTag,
                      child: Image.file(
                        widget.imageFile,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
