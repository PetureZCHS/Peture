import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:path/path.dart' as path;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/page_tracker_mixin.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/design_system/peture_design_system.dart';
import '../../../shared/models/pet.dart';
import '../../../shared/utils/data_change_notifier.dart';
import '../../../shared/utils/ui_helpers.dart';
import '../../moderation/data/moderation_client.dart';
import '../../moderation/domain/moderation_scene.dart';
import '../../moderation/utils/moderation_guard.dart';
import 'loading_page.dart';

class AppColors {
  static const Color background = PetureColors.background;
  static const Color surface = PetureColors.surfacePure;
  static const Color primary = PetureColors.violet;
  static const Color secondary = PetureColors.blue;
  static const Color accent = PetureColors.primary;
  static const Color textDark = PetureColors.textPrimary;
  static const Color textGrey = PetureColors.textSecondary;
  static const Color textLight = PetureColors.textTertiary;

  static const Color orb1 = PetureColors.surfaceMuted;
  static const Color orb2 = PetureColors.backgroundAlt;
  static const Color orb3 = PetureColors.border;

  static const List<Color> primaryGradient = [
    PetureColors.violet,
    PetureColors.blue,
    PetureColors.primary,
  ];
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

class ImagePrecheckResult {
  final bool pass;
  final String reason;

  const ImagePrecheckResult({
    required this.pass,
    required this.reason,
  });
}

class AiStylePreset {
  final String id;
  final String name;
  final String aspectRatio;
  final DateTime createdAt;
  final String? localImagePath;
  final String? imageUrl;

  const AiStylePreset({
    required this.id,
    required this.name,
    required this.aspectRatio,
    required this.createdAt,
    this.localImagePath,
    this.imageUrl,
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
      imageUrl: (json['image_url'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'id': id,
      'name': name,
      'aspect_ratio': aspectRatio,
      'created_at': createdAt.toIso8601String(),
      'local_image_path': localImagePath,
      'image_url': imageUrl,
    };
  }

  AiStylePreset copyWith({
    String? localImagePath,
    String? imageUrl,
  }) {
    return AiStylePreset(
      id: id,
      name: name,
      aspectRatio: aspectRatio,
      createdAt: createdAt,
      localImagePath: localImagePath ?? this.localImagePath,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class _PreparationPageState extends State<PreparationPage>
    with TickerProviderStateMixin, PageTrackerMixin<PreparationPage> {
  late final ModerationGuard _moderationGuard;

  static const String _presetView = 'vw_ai_image_presets';
  static const String _presetBucket = 'assets';
  static const String _defaultAspectRatio = '1:1';
  static const String _cacheVersion = 'v1_1_4';
  static const String _lastSelectedIndexKeyPrefix =
      'img_gen_last_selected_index_v1_1_4';

  final SupabaseService _supabaseService = SupabaseService();

  File? _selectedImage;
  String? _selectedImageUrl; // Web 平台使用 URL 而不是 File
  int _selectedStyleIndex = 0;

  List<Pet> _pets = const [];
  Pet? _selectedPet;

  late final ScrollController _styleScrollController;

  UploadStatus _uploadStatus = UploadStatus.idle;
  double _uploadProgress = 0.0;
  String _uploadError = '';

  bool _isLoadingPets = false;
  bool _isPetSelectorExpanded = false;
  bool _isStartingTask = false;
  bool _isPrecheckingImage = false;
  bool _isPickingImage = false;
  bool _isUsingSelectedPetLifePhoto = false;
  bool _isLoadingStyles = true;
  String _selectedAspectRatio = _defaultAspectRatio;
  int _styleLoadEpoch = 0;
  int _petImageLoadEpoch = 0;
  final Map<String, int> _lastSelectedIndexByAspectRatio = {
    _defaultAspectRatio: 0,
  };

  late AnimationController _orbController;

  List<AiStylePreset> _styles = const [];
  Set<String> _imageCachingPresetIds = <String>{};
  Set<String> _imageCacheFailedPresetIds = <String>{};

  @override
  String get analyticsPageName => 'ai_image_preparation';

  @override
  void initState() {
    super.initState();
    _moderationGuard = ModerationGuard(ModerationClient());
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _styleScrollController = ScrollController();

    unawaited(_initializeStyleSelectionAndLoad());
    unawaited(_loadPets());

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
    }
  }

  Future<void> _loadPets() async {
    if (!mounted) return;
    setState(() => _isLoadingPets = true);

    try {
      final petsData = await _supabaseService.getAllPets();
      if (!mounted) return;
      setState(() {
        _pets = petsData.map((data) => Pet.fromMap(data)).toList();
        _isLoadingPets = false;
      });
    } catch (e) {
      debugPrint('加载宠物列表失败: $e');
      if (mounted) {
        setState(() => _isLoadingPets = false);
      }
    }
  }

  Future<void> _onPetSelected(Pet pet) async {
    final int epoch = ++_petImageLoadEpoch;
    setState(() {
      _selectedPet = pet;
      _isPetSelectorExpanded = false;
      _uploadError = '';
    });

    final lifePhoto = pet.lifePhoto?.trim();
    if (lifePhoto == null || lifePhoto.isEmpty) {
      if (!mounted || epoch != _petImageLoadEpoch) return;
      setState(() {
        _selectedImage = null;
        _selectedImageUrl = null;
        _isUsingSelectedPetLifePhoto = false;
      });
      return;
    }

    // Web 平台：直接使用 URL
    if (kIsWeb) {
      if (!mounted || epoch != _petImageLoadEpoch) return;
      setState(() {
        _selectedImage = null;
        _selectedImageUrl = lifePhoto;
        _isUsingSelectedPetLifePhoto = true;
      });
      return;
    }

    // Native 平台：下载到本地文件
    final resolvedFile = await _resolvePetLifePhotoFile(
      petId: pet.id ?? pet.name,
      source: lifePhoto,
    );

    if (!mounted || epoch != _petImageLoadEpoch) return;

    setState(() {
      _selectedImage = resolvedFile;
      _selectedImageUrl = null;
      _isUsingSelectedPetLifePhoto = resolvedFile != null;
    });
  }

  bool _isRemoteSource(String source) {
    return source.startsWith('http://') || source.startsWith('https://');
  }

  bool _isLocalFilePath(String? source) {
    if (source == null || source.isEmpty) return false;
    return !_isRemoteSource(source);
  }

  File _fileFromPath(String source) {
    return source.startsWith('file://')
        ? File(Uri.parse(source).toFilePath())
        : File(source);
  }

  Future<String?> _downloadToTempFileFromUrl(String url, String petId) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return null;

      final dir = await getTemporaryDirectory();
      final cacheDir = Directory(path.join(dir.path, 'ai_pet_lifephoto_cache'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final targetPath = path.join(
        cacheDir.path,
        '${petId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final file = File(targetPath);
      await file.writeAsBytes(res.bodyBytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('下载宠物生活照失败: $e');
      return null;
    }
  }

  Future<File?> _resolvePetLifePhotoFile({
    required String petId,
    required String source,
  }) async {
    try {
      if (_isLocalFilePath(source)) {
        final file = _fileFromPath(source);
        if (await file.exists()) {
          return file;
        }
      }

      if (_isRemoteSource(source)) {
        final baseDir = await getApplicationDocumentsDirectory();
        final lifePhotoDir = Directory(
          path.join(baseDir.path, 'ai_pet_lifephoto_cache'),
        );
        if (!await lifePhotoDir.exists()) {
          await lifePhotoDir.create(recursive: true);
        }

        final cachedPath = path.join(
          lifePhotoDir.path,
          '${petId}_${source.hashCode}.jpg',
        );
        final cachedFile = File(cachedPath);
        if (await cachedFile.exists()) {
          return cachedFile;
        }

        final downloadedPath = await _downloadToTempFileFromUrl(source, petId);
        if (downloadedPath == null) return null;

        final downloadedFile = File(downloadedPath);
        if (!await downloadedFile.exists()) return null;

        try {
          await downloadedFile.copy(cachedPath);
          return cachedFile;
        } catch (_) {
          return downloadedFile;
        }
      }

      return null;
    } catch (e) {
      debugPrint('解析宠物生活照失败: $e');
      return null;
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
    for (final aspectRatio in const ['1:1', '9:16', '16:9']) {
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
            // Web 平台：直接使用缓存的 preset，不需要检查本地文件
            if (kIsWeb) {
              cached.add(preset);
              continue;
            }

            // Native 平台：检查本地文件是否存在
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
      final missingImageIds = cached
          .where((preset) =>
              preset.localImagePath == null || preset.localImagePath!.isEmpty)
          .map((preset) => preset.id)
          .toSet();
      setState(() {
        _styles = cached;
        _selectedStyleIndex =
            _clampedRememberedStyleIndex(aspectRatio, cached.length);
        _imageCachingPresetIds = missingImageIds;
        _imageCacheFailedPresetIds = <String>{};
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

      final hasMissingPreviewImage = _styles.any((preset) {
        final localPath = preset.localImagePath;
        if (localPath == null || localPath.isEmpty) return true;
        return !File(localPath).existsSync();
      });

      if (_styles.isNotEmpty &&
          !hasMissingPreviewImage &&
          cachedLatestCreatedAt == currentLatestCreatedAt &&
          cachedCount == currentCount) {
        if (mounted) {
          setState(() {
            _imageCachingPresetIds = <String>{};
            _isLoadingStyles = false;
          });
        }
        return;
      }

      final String? lastSyncAt =
          prefs.getString(_cacheLastSyncKey(aspectRatio));
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
        final existing = mergedMap[remotePreset.id];
        mergedMap[remotePreset.id] = remotePreset.copyWith(
          localImagePath: existing?.localImagePath,
          imageUrl: existing?.imageUrl,
        );
      }

      final merged = mergedMap.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Web 平台：所有 preset 都需要加载图片（使用网络 URL）
      // Native 平台：检查本地文件是否存在
      final pendingImageIds = kIsWeb
          ? merged
              .where((preset) =>
                  preset.imageUrl == null || preset.imageUrl!.isEmpty)
              .map((preset) => preset.id)
              .toSet()
          : merged
              .where((preset) {
                final localPath = preset.localImagePath;
                if (localPath == null || localPath.isEmpty) return true;
                return !File(localPath).existsSync();
              })
              .map((preset) => preset.id)
              .toSet();

      // Use server-derived latest createdAt as the incremental sync cursor,
      // falling back to local time only if none is available.
      final syncCursorIso =
          currentLatestCreatedAt ?? DateTime.now().toIso8601String();
      await prefs.setString(_cacheStylesKey(aspectRatio),
          jsonEncode(merged.map((e) => e.toCacheJson()).toList()));
      await prefs.setString(_cacheLastSyncKey(aspectRatio), syncCursorIso);
      await prefs.setString(
          _cacheLatestCreatedAtKey(aspectRatio), syncCursorIso);
      await prefs.setInt(_cacheCountKey(aspectRatio), currentCount);

      if (!mounted || epoch != _styleLoadEpoch) return;
      setState(() {
        _styles = merged;
        _selectedStyleIndex =
            _clampedRememberedStyleIndex(aspectRatio, merged.length);
        _imageCachingPresetIds = pendingImageIds;
        _imageCacheFailedPresetIds = <String>{};
        _isLoadingStyles = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedStyle(animated: false);
      });

      if (pendingImageIds.isNotEmpty) {
        unawaited(_cachePresetImagesInBackground(
          aspectRatio: aspectRatio,
          epoch: epoch,
          initialPresets: merged,
        ));
      }
    } catch (e, st) {
      debugPrint('同步风格预设失败: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoadingStyles = false;
        });
      }
    }
  }

  Future<void> _cachePresetImagesInBackground({
    required String aspectRatio,
    required int epoch,
    required List<AiStylePreset> initialPresets,
  }) async {
    if (initialPresets.isEmpty) return;

    // Web 平台：直接构建公开 URL，不需要后台下载
    if (kIsWeb) {
      var hasAnyUpdate = false;

      for (final preset in initialPresets) {
        if (!mounted ||
            epoch != _styleLoadEpoch ||
            _selectedAspectRatio != aspectRatio) {
          return;
        }

        // 如果已经有 imageUrl，跳过
        if (preset.imageUrl != null && preset.imageUrl!.isNotEmpty) {
          continue;
        }

        // 构建公开 URL
        final withImage =
            await _ensurePresetImageCached(preset, keepOldPath: true);

        if (!mounted ||
            epoch != _styleLoadEpoch ||
            _selectedAspectRatio != aspectRatio) {
          return;
        }

        setState(() {
          final index = _styles.indexWhere((item) => item.id == withImage.id);
          if (index >= 0) {
            _styles = List<AiStylePreset>.from(_styles)..[index] = withImage;
            hasAnyUpdate = true;
          }
          _imageCachingPresetIds.remove(withImage.id);
          // Web 平台：如果 imageUrl 存在，则认为加载成功
          if (withImage.imageUrl != null && withImage.imageUrl!.isNotEmpty) {
            _imageCacheFailedPresetIds.remove(withImage.id);
          } else {
            _imageCacheFailedPresetIds.add(withImage.id);
          }
        });
      }

      if (hasAnyUpdate && mounted && epoch == _styleLoadEpoch) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _cacheStylesKey(aspectRatio),
          jsonEncode(_styles.map((e) => e.toCacheJson()).toList()),
        );
      }
      return;
    }

    // Native 平台：使用本地文件缓存
    final pending = initialPresets.where((preset) {
      final localPath = preset.localImagePath;
      if (localPath == null || localPath.isEmpty) return true;
      return !File(localPath).existsSync();
    }).toList(growable: false);

    if (pending.isEmpty) return;

    var hasAnyUpdate = false;

    for (final preset in pending) {
      if (!mounted ||
          epoch != _styleLoadEpoch ||
          _selectedAspectRatio != aspectRatio) {
        return;
      }

      final withImage =
          await _ensurePresetImageCached(preset, keepOldPath: true);

      if (!mounted ||
          epoch != _styleLoadEpoch ||
          _selectedAspectRatio != aspectRatio) {
        return;
      }

      final resolvedPath = withImage.localImagePath;
      final hasImage = resolvedPath != null &&
          resolvedPath.isNotEmpty &&
          await File(resolvedPath).exists();

      setState(() {
        final index = _styles.indexWhere((item) => item.id == withImage.id);
        if (index >= 0) {
          _styles = List<AiStylePreset>.from(_styles)..[index] = withImage;
          hasAnyUpdate = true;
        }
        _imageCachingPresetIds.remove(withImage.id);
        if (hasImage) {
          _imageCacheFailedPresetIds.remove(withImage.id);
        } else {
          _imageCacheFailedPresetIds.add(withImage.id);
        }
      });
    }

    if (hasAnyUpdate && mounted && epoch == _styleLoadEpoch) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheStylesKey(aspectRatio),
        jsonEncode(_styles.map((e) => e.toCacheJson()).toList()),
      );
    }
  }

  Future<AiStylePreset> _ensurePresetImageCached(
    AiStylePreset preset, {
    required bool keepOldPath,
  }) async {
    // Web 平台：直接使用公开 URL，不需要本地缓存
    if (kIsWeb) {
      // 如果已经有 imageUrl，直接返回
      if (preset.imageUrl != null && preset.imageUrl!.isNotEmpty) {
        return preset;
      }

      // 构建公开 URL
      try {
        final ratioFolder = _normalizedAspectRatio(preset.aspectRatio);
        final storagePath = 'ai_image_presets/$ratioFolder/${preset.id}.jpg';
        final publicUrl = Supabase.instance.client.storage
            .from(_presetBucket)
            .getPublicUrl(storagePath);

        return preset.copyWith(imageUrl: publicUrl);
      } catch (e) {
        debugPrint('构建示例图公开URL失败(${preset.id}): $e');
        return preset;
      }
    }

    // Native 平台：使用本地文件缓存
    final presetLocalPath = preset.localImagePath;
    if (presetLocalPath != null && presetLocalPath.isNotEmpty) {
      final presetLocalFile = File(presetLocalPath);
      if (await presetLocalFile.exists()) {
        return preset;
      }
    }

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
    if (pickedFile == null || !mounted) return;

    setState(() => _isPickingImage = true);
    try {
      final file = File(pickedFile.path);
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final passed = await _moderationGuard.runImageGuardByBytes(
        context: context,
        scene: ModerationScene.imageInput,
        bytes: bytes,
        onPassed: () async {},
      );
      if (!passed || !mounted) return;
      setState(() {
        _selectedImage = file;
        _uploadError = '';
        _uploadStatus = UploadStatus.idle;
        _isUsingSelectedPetLifePhoto = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<bool> _moderateSelectedImageBeforeGeneration() async {
    Uint8List? bytes;
    if (_selectedImage != null) {
      bytes = await _selectedImage!.readAsBytes();
    } else if (_selectedImageUrl != null && _selectedImageUrl!.isNotEmpty) {
      final response = await http.get(Uri.parse(_selectedImageUrl!));
      if (response.statusCode == 200) {
        bytes = response.bodyBytes;
      }
    }
    if (!mounted || bytes == null) return bytes != null;
    return _moderationGuard.runImageGuardByBytes(
      context: context,
      scene: ModerationScene.imageInput,
      bytes: bytes,
      onPassed: () async {},
    );
  }

  void _onImageAreaTap() {
    // 检查是否有选中的图片（File 或 URL）
    final hasSelectedImage =
        _selectedImage != null || _selectedImageUrl != null;

    if (!hasSelectedImage) {
      // No image selected yet
      if (_selectedPet == null) {
        // No pet selected, allow picking
        _pickImage();
      } else {
        // Pet selected
        final lifePhoto = _selectedPet!.lifePhoto?.trim();
        if (lifePhoto == null || lifePhoto.isEmpty) {
          // Pet has no life photo, allow picking
          _pickImage();
        } else {
          // Pet has life photo but still loading (or failed). Ignore tap.
          // Optionally show a message.
        }
      }
    } else {
      // Web 平台：暂时不支持全屏查看网络图片
      if (kIsWeb) {
        return;
      }

      // Native 平台：打开全屏查看
      if (_selectedImage != null) {
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

  Future<void> _syncPetLifePhotoIfNeeded() async {
    final pet = _selectedPet;
    if (pet == null) return;
    final petId = pet.id?.trim() ?? '';
    if (petId.isEmpty) return;

    final existingLifePhoto = pet.lifePhoto?.trim();
    if (existingLifePhoto != null && existingLifePhoto.isNotEmpty) return;

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    String? syncedUrl;

    try {
      if (_selectedImage != null) {
        syncedUrl = await _supabaseService.uploadPetLifePhoto(
          file: _selectedImage!,
          petId: petId,
        );
      } else if (_selectedImageUrl != null && _selectedImageUrl!.isNotEmpty) {
        final uri = Uri.parse(_selectedImageUrl!);
        final resp = await http.get(uri);
        if (resp.statusCode == 200) {
          final storagePath =
              '$userId/$petId/lifephoto_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await supabase.storage.from('user-avatars').uploadBinary(
                storagePath,
                resp.bodyBytes,
                fileOptions: const FileOptions(
                  upsert: true,
                  contentType: 'image/jpeg',
                ),
              );
          syncedUrl = supabase.storage
              .from('user-avatars')
              .getPublicUrl(storagePath)
              .split('?')
              .first;
          syncedUrl = '$syncedUrl?t=${DateTime.now().millisecondsSinceEpoch}';
          await supabase.from('pets').update({
            'life_photo': syncedUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', petId).eq('user_id', userId);
        }
      }
    } catch (e) {
      debugPrint('同步宠物生活照失败: $e');
      return;
    }

    if (syncedUrl == null || syncedUrl.isEmpty || !mounted) return;

    setState(() {
      _selectedPet = Pet(
        id: pet.id,
        type: pet.type,
        name: pet.name,
        age: pet.age,
        gender: pet.gender,
        breed: pet.breed,
        avatar: pet.avatar,
        lifePhoto: syncedUrl,
        birthDate: pet.birthDate,
        neuterStatus: pet.neuterStatus,
        weight: pet.weight,
        ownerNickname: pet.ownerNickname,
        useCustomNickname: pet.useCustomNickname,
      );
      _isUsingSelectedPetLifePhoto = true;

      _pets = _pets.map((item) {
        if (item.id == pet.id) {
          return Pet(
            id: item.id,
            type: item.type,
            name: item.name,
            age: item.age,
            gender: item.gender,
            breed: item.breed,
            avatar: item.avatar,
            lifePhoto: syncedUrl,
            birthDate: item.birthDate,
            neuterStatus: item.neuterStatus,
            weight: item.weight,
            ownerNickname: item.ownerNickname,
            useCustomNickname: item.useCustomNickname,
          );
        }
        return item;
      }).toList(growable: false);
    });

    DataChangeNotifier.markPetDataChanged();
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

  double _styleCardWidthForAspectRatio(String aspectRatio) {
    if (aspectRatio == '16:9') {
      return 126.0;
    }
    return 100.0;
  }

  double _styleListHeightForAspectRatio(String aspectRatio) {
    return 160.0;
  }

  double _styleItemExtentForAspectRatio(String aspectRatio) {
    return _styleCardWidthForAspectRatio(aspectRatio) + 12.0;
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      setState(() {
        _uploadStatus = UploadStatus.failed;
        _uploadError = message;
      });
    }
  }

  Map<String, String> _functionAuthHeaders() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  bool _shouldTreatAsAuthExpired(FunctionException e) {
    final client = Supabase.instance.client;
    final hasSession = client.auth.currentSession != null;
    final hasUser = client.auth.currentUser != null;
    final message = e.toString().toLowerCase();
    final details = (e.details?.toString().toLowerCase() ?? '');
    final combined = '$message $details';

    final hasExplicitAuthHint = combined.contains('jwt') ||
        combined.contains('token') ||
        combined.contains('not logged in') ||
        combined.contains('auth') ||
        combined.contains('unauthorized') ||
        combined.contains('invalid claim') ||
        combined.contains('expired');

    // 仅在本地会话缺失，或服务端明确给出鉴权失效信号时，才提示重新登录。
    return !hasSession || !hasUser || hasExplicitAuthHint;
  }

  Future<ImagePrecheckResult> _precheckUploadedImage({
    required String uploadedFileName,
  }) async {
    final supabase = Supabase.instance.client;
    const precheckTimeout = Duration(seconds: 15);

    try {
      final response = await supabase.functions
          .invoke(
            'img-gen-precheck',
            body: {
              'file_name': uploadedFileName,
            },
            headers: _functionAuthHeaders(),
          )
          .timeout(precheckTimeout);

      dynamic payload = response.data;
      if (payload is String && payload.isNotEmpty) {
        payload = jsonDecode(payload);
      }

      if (payload is! Map) {
        return const ImagePrecheckResult(
          pass: false,
          reason: '图片检测服务返回了无效结果，请稍后重试',
        );
      }

      final bool pass = payload['pass'] == true;
      final String reason = (payload['reason'] as String? ?? '').trim();

      if (pass) {
        return const ImagePrecheckResult(pass: true, reason: '');
      }

      return ImagePrecheckResult(
        pass: false,
        reason: reason.isNotEmpty ? reason : '图片不符合生成要求，请更换后重试',
      );
    } on SocketException {
      return const ImagePrecheckResult(
        pass: false,
        reason: '图片检测失败：网络连接异常，请检查网络后重试',
      );
    } on TimeoutException {
      return const ImagePrecheckResult(
        pass: false,
        reason: '图片检测超时，请稍后再试',
      );
    } on FunctionException catch (e) {
      debugPrint('❌ 预检函数调用失败: $e');
      final message = e.toString().toLowerCase();
      if (message.contains('401') ||
          message.contains('403') ||
          message.contains('unauthorized') ||
          message.contains('forbidden')) {
        if (_shouldTreatAsAuthExpired(e)) {
          return const ImagePrecheckResult(
            pass: false,
            reason: '登录状态已失效，请重新登录后重试',
          );
        }
        return const ImagePrecheckResult(
          pass: false,
          reason: '图片检测服务暂时不可用，请稍后重试',
        );
      }
      if (message.contains('timeout')) {
        return const ImagePrecheckResult(
          pass: false,
          reason: '图片检测超时，请稍后再试',
        );
      }
      if (message.contains('network') || message.contains('fetch')) {
        return const ImagePrecheckResult(
          pass: false,
          reason: '图片检测失败：网络连接异常，请检查网络后重试',
        );
      }

      return const ImagePrecheckResult(
        pass: false,
        reason: '图片检测服务暂时不可用，请稍后重试',
      );
    } catch (e, st) {
      debugPrint('❌ 图片预检异常: $e\n$st');
      return const ImagePrecheckResult(
        pass: false,
        reason: '图片检测失败，请检查网络后重试',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "AI 图像实验室",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(color: AppColors.textDark),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withOpacity(0.85),
                    AppColors.background.withOpacity(0.4),
                  ],
                ),
              ),
            ),
          ),
        ),
        foregroundColor: AppColors.textDark,
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
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildPetSelector(),
                        ),
                        if (_selectedPet != null) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _onImageAreaTap,
                            child: Container(
                              height: 200,
                              width: double.infinity,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
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
                                    child: (_selectedImage == null &&
                                            _selectedImageUrl == null)
                                        ? Stack(
                                            children: [
                                              Positioned.fill(
                                                child: LayoutBuilder(
                                                  builder: (context, constraints) {
                                                    return SingleChildScrollView(
                                                      padding: const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                      ),
                                                      child: ConstrainedBox(
                                                        constraints: BoxConstraints(
                                                          minHeight: constraints.maxHeight - 24,
                                                        ),
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment.center,
                                                          children: [
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                      16),
                                                              decoration: BoxDecoration(
                                                                color: AppColors.primary
                                                                    .withOpacity(0.1),
                                                                shape: BoxShape.circle,
                                                              ),
                                                              child: Icon(
                                                                Icons
                                                                    .add_photo_alternate_outlined,
                                                                size: 40,
                                                                color: AppColors.primary
                                                                    .withOpacity(0.7),
                                                              ),
                                                            ),
                                                            const SizedBox(height: 16),
                                                            Text(
                                                              (_selectedPet!.lifePhoto ==
                                                                          null ||
                                                                      _selectedPet!
                                                                          .lifePhoto!
                                                                          .isEmpty)
                                                                  ? '您还未上传${_selectedPet!.name}的生活照\n请上传'
                                                                  : '正在载入 ${_selectedPet!.name} 的生活照',
                                                              textAlign:
                                                                  TextAlign.center,
                                                              style: TextStyle(
                                                                color: AppColors.textGrey
                                                                    .withOpacity(0.9),
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight.w500,
                                                                height: 1.25,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 10),
                                                            Padding(
                                                              padding: const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 18),
                                                              child: Text(
                                                                '请上传仅含这只毛孩子的清晰照片\n确保面部清晰、无其他人或动物',
                                                                textAlign:
                                                                    TextAlign.center,
                                                                style: TextStyle(
                                                                  color: AppColors
                                                                      .textLight,
                                                                  fontSize: 11,
                                                                  height: 1.35,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              if (_isPickingImage)
                                                Container(
                                                  color: Colors.white
                                                      .withOpacity(0.72),
                                                  child: const Center(
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        SizedBox(
                                                          width: 24,
                                                          height: 24,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2.2,
                                                          ),
                                                        ),
                                                        SizedBox(height: 10),
                                                        Text(
                                                          '正在处理照片...',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: AppColors
                                                                .textDark,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          )
                                        : Stack(
                                            children: [
                                              Positioned.fill(
                                                child: Hero(
                                                  tag: 'pet_photo_hero',
                                                  // Web 平台使用网络图片，Native 平台使用本地文件
                                                  child: _selectedImageUrl !=
                                                          null
                                                      ? Image.network(
                                                          _selectedImageUrl!,
                                                          fit: BoxFit.contain,
                                                          loadingBuilder: (context,
                                                              child,
                                                              loadingProgress) {
                                                            if (loadingProgress ==
                                                                null) {
                                                              return child;
                                                            }
                                                            return Center(
                                                              child:
                                                                  CircularProgressIndicator(
                                                                value: loadingProgress
                                                                            .expectedTotalBytes !=
                                                                        null
                                                                    ? loadingProgress
                                                                            .cumulativeBytesLoaded /
                                                                        loadingProgress
                                                                            .expectedTotalBytes!
                                                                    : null,
                                                              ),
                                                            );
                                                          },
                                                          errorBuilder:
                                                              (_, __, ___) =>
                                                                  Container(
                                                            color: Colors
                                                                .grey[200],
                                                            child: const Icon(
                                                              Icons
                                                                  .error_outline,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                          ),
                                                        )
                                                      : Image.file(
                                                          _selectedImage!,
                                                          fit: BoxFit.contain,
                                                        ),
                                                ),
                                              ),
                                              Positioned(
                                                right: 8,
                                                bottom: 8,
                                                child: GestureDetector(
                                                  onTap: _isPickingImage
                                                      ? null
                                                      : () async {
                                                    await _pickImage();
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.5),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.refresh,
                                                            size: 14,
                                                            color:
                                                                Colors.white),
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
                                              if (_isPickingImage)
                                                Positioned.fill(
                                                  child: Container(
                                                    color: Colors.black
                                                        .withOpacity(0.24),
                                                    alignment: Alignment.center,
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 14,
                                                          vertical: 10),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black
                                                            .withOpacity(0.55),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(14),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          SizedBox(
                                                            width: 18,
                                                            height: 18,
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2.1,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                          SizedBox(width: 10),
                                                          Text(
                                                            '正在处理照片...',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
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
                        ],
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "选择样式",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildAspectRatioButton(
                                  label: '头像\n1:1',
                                  value: '1:1',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildAspectRatioButton(
                                  label: '书封 / 手机壁纸\n9:16',
                                  value: '9:16',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildAspectRatioButton(
                                  label: '电脑壁纸\n16:9',
                                  value: '16:9',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          height: _styleListHeightForAspectRatio(
                              _selectedAspectRatio),
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
                                        final isSelected =
                                            _selectedStyleIndex == index;
                                        return _buildTechStyleCard(
                                            index, isSelected);
                                      },
                                      controller: _styleScrollController,
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_uploadError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: _buildUploadErrorBanner(_uploadError),
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
                          gradient: ((_selectedImage != null ||
                                      _selectedImageUrl != null) &&
                                  _styles.isNotEmpty &&
                                  !_isStartingTask &&
                                  _uploadStatus != UploadStatus.uploading)
                              ? const LinearGradient(
                                  colors: AppColors.primaryGradient,
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF9CA3AF),
                                    Color(0xFF9CA3AF)
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: (_selectedImage != null ||
                                      _selectedImageUrl != null)
                                  ? AppColors.primary.withOpacity(0.3)
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
                            onTap: ((_selectedImage != null ||
                                        _selectedImageUrl != null) &&
                                    _styles.isNotEmpty &&
                                    _uploadStatus != UploadStatus.uploading &&
                                    !_isStartingTask)
                                ? () async {
                                    if (mounted) {
                                      setState(() {
                                        _isStartingTask = true;
                                        _isPrecheckingImage = false;
                                        _uploadError = '';
                                      });
                                    }

                                    final inputPassed =
                                        await _moderateSelectedImageBeforeGeneration();
                                    if (!inputPassed || !context.mounted) {
                                      if (mounted) {
                                        setState(() {
                                          _isStartingTask = false;
                                          _isPrecheckingImage = false;
                                        });
                                      }
                                      return;
                                    }

                                    // 保存 messenger 引用，避免 async 后 context 失效
                                    final messenger =
                                        ScaffoldMessenger.of(context);

                                    // 网络检查（Native 平台）
                                    // Web 平台跳过检查，浏览器会自动处理网络状态
                                    if (!kIsWeb) {
                                      try {
                                        await InternetAddress.lookup(
                                                'www.baidu.com')
                                            .timeout(
                                                const Duration(seconds: 3));
                                      } catch (_) {
                                        if (mounted) {
                                          setState(() {
                                            _isStartingTask = false;
                                            _isPrecheckingImage = false;
                                          });
                                          messenger.showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text('无网络连接，请检查网络设置。')),
                                          );
                                        }
                                        return;
                                      }
                                    }

                                    // Web 平台：只有来源和文件名都符合规则才跳过上传
                                    String? uploadedFileName;
                                    if (kIsWeb && _selectedImageUrl != null) {
                                      // 规则：URL 必须来自 ai-wallpapers，文件名必须是 <ts>_<uuid36>.<ext>
                                      final uri = Uri.parse(_selectedImageUrl!);
                                      final rawName =
                                          uri.pathSegments.isNotEmpty
                                              ? uri.pathSegments.last
                                              : '';
                                      final fileNameFromUrl =
                                          rawName.split('?').first;
                                      final strictWallpaperRe = RegExp(
                                        r'^\d+_[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\.(jpg|jpeg|png|webp)$',
                                        caseSensitive: false,
                                      );
                                      final isAiWallpapersUrl = uri.pathSegments
                                          .contains('ai-wallpapers');
                                      final fileNameMatches = strictWallpaperRe
                                          .hasMatch(fileNameFromUrl);

                                      if (isAiWallpapersUrl &&
                                          fileNameMatches) {
                                        uploadedFileName = fileNameFromUrl;
                                      } else {
                                        // 否则尝试下载该 URL 的二进制并上传到 ai-wallpapers（与原生分支一致）
                                        try {
                                          final resp = await http.get(uri);
                                          if (resp.statusCode == 200) {
                                            final bytes = resp.bodyBytes;
                                            final user = Supabase.instance
                                                .client.auth.currentUser;
                                            final userId = user?.id;
                                            if (userId == null) {
                                              uploadedFileName = null;
                                            } else {
                                              final timestamp = DateTime.now()
                                                  .millisecondsSinceEpoch
                                                  .toString();
                                              final uniqueId =
                                                  const Uuid().v4();
                                              final newFileName =
                                                  '${timestamp}_$uniqueId.jpg';
                                              final filePath =
                                                  '$userId/original/$newFileName';
                                              try {
                                                await Supabase
                                                    .instance.client.storage
                                                    .from('ai-wallpapers')
                                                    .uploadBinary(
                                                      filePath,
                                                      bytes,
                                                      fileOptions:
                                                          const FileOptions(
                                                        cacheControl: '3600',
                                                        upsert: false,
                                                        contentType:
                                                            'image/jpeg',
                                                      ),
                                                    );
                                                uploadedFileName = newFileName;
                                              } catch (e) {
                                                debugPrint(
                                                    'Web: 上传远程图片到 ai-wallpapers 失败: $e');
                                                uploadedFileName = null;
                                              }
                                            }
                                          } else {
                                            debugPrint(
                                                'Web: 下载远程图片失败, status=${resp.statusCode}');
                                            uploadedFileName = null;
                                          }
                                        } catch (e) {
                                          debugPrint('Web: 下载或上传远程图片异常: $e');
                                          uploadedFileName = null;
                                        }
                                      }
                                    } else if (_selectedImage != null) {
                                      // Native 平台：上传本地文件
                                      uploadedFileName =
                                          await _uploadImageToSupabaseStorage(
                                              _selectedImage!);
                                    }

                                    // 仅当生活照发生变化时才执行 precheck。
                                    // 若沿用宠物已有 life_photo，则跳过重复 precheck。
                                    final shouldRunPrecheckForLifePhoto =
                                        _selectedPet == null
                                            ? true
                                            : !_isUsingSelectedPetLifePhoto;

                                    // 如果该宠物原本没有生活照，则同步到宠物档案（Storage + Database）
                                    await _syncPetLifePhotoIfNeeded();

                                    if (uploadedFileName != null && mounted) {
                                      setState(() {
                                        _isStartingTask = true;
                                        _isPrecheckingImage =
                                            shouldRunPrecheckForLifePhoto;
                                        _uploadError = '';
                                      });

                                      if (uploadedFileName.isNotEmpty) {
                                        if (_selectedStyleIndex < 0 ||
                                            _selectedStyleIndex >=
                                                _styles.length) {
                                          setState(() {
                                            _isStartingTask = false;
                                            _isPrecheckingImage = false;
                                            _uploadStatus = UploadStatus.failed;
                                            _uploadError = '风格索引异常，请重试';
                                          });
                                          return;
                                        }

                                        final style =
                                            _styles[_selectedStyleIndex].id;

                                        final supabase =
                                            Supabase.instance.client;

                                        if (shouldRunPrecheckForLifePhoto) {
                                          final precheckResult =
                                              await _precheckUploadedImage(
                                            uploadedFileName: uploadedFileName,
                                          );

                                          if (!precheckResult.pass) {
                                            // 预检不通过，清理已上传的原图，避免存储泄漏和隐私残留
                                            final cleanupUserId =
                                                supabase.auth.currentUser?.id;
                                            if (cleanupUserId != null) {
                                              final cleanupPath =
                                                  '$cleanupUserId/original/$uploadedFileName';
                                              try {
                                                await supabase.storage
                                                    .from('ai-wallpapers')
                                                    .remove([cleanupPath]);
                                                debugPrint(
                                                    '🗑️ 预检不通过，已清理上传文件: $cleanupPath');
                                              } catch (e) {
                                                debugPrint('⚠️ 清理上传文件失败: $e');
                                              }
                                            }
                                            if (mounted) {
                                              setState(() {
                                                _isStartingTask = false;
                                                _isPrecheckingImage = false;
                                                _uploadStatus =
                                                    UploadStatus.failed;
                                                _uploadError =
                                                    precheckResult.reason;
                                              });
                                            }
                                            return;
                                          }
                                        }

                                        if (mounted) {
                                          setState(() {
                                            _isPrecheckingImage = false;
                                          });
                                        }

                                        // 核心变更：立刻创建生图请求的 Future
                                        final generationFuture =
                                            supabase.functions.invoke(
                                          'img-gen',
                                          body: {
                                            'file_name': uploadedFileName,
                                            'style': style,
                                          },
                                          headers: _functionAuthHeaders(),
                                        );

                                        if (!context.mounted) return;
                                        // 核心变更：将 Future 传给 LoadingPage
                                        await Navigator.push(
                                          context,
                                          FadePageRoute(
                                            page: LoadingPage(
                                              originalImage: _selectedImage,
                                              originalImageUrl:
                                                  _selectedImageUrl,
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
                                            _isPrecheckingImage = false;
                                            _uploadStatus = UploadStatus.idle;
                                            _uploadProgress = 0.0;
                                          });
                                        }
                                      } else {
                                        setState(() {
                                          _isStartingTask = false;
                                          _isPrecheckingImage = false;
                                          _uploadStatus = UploadStatus.failed;
                                          _uploadError = '上传结果异常，请重新尝试';
                                        });
                                      }
                                    }
                                    if (uploadedFileName == null && mounted) {
                                      setState(() {
                                        _isStartingTask = false;
                                        _isPrecheckingImage = false;
                                        _uploadStatus = UploadStatus.failed;
                                        _uploadError = '上传失败，请重试';
                                      });
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
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _isPrecheckingImage
                                                  ? '正在检测图片...'
                                                  : '正在进入生成流程...',
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
    final cardWidth = _styleCardWidthForAspectRatio(_selectedAspectRatio);
    final selectedScale = _selectedAspectRatio == '16:9' ? 1.02 : 1.05;

    return GestureDetector(
      onTap: () => _onStyleSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: cardWidth,
        transform: isSelected
            ? (Matrix4.identity()..scale(selectedScale))
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : Border.all(color: Colors.white.withOpacity(0.6), width: 1.2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
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
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
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
                          const BorderRadius.vertical(top: Radius.circular(18)),
                      child: _buildPresetImage(preset),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20)),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          preset.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                isSelected ? Colors.white : AppColors.textDark,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isSelected)
                          const Positioned(
                            right: 10,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox(width: 6, height: 6),
                            ),
                          ),
                      ],
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

  Widget _buildPetSelector() {
    if (_isLoadingPets) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              '正在加载主角列表',
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_pets.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pets_rounded,
                color: AppColors.primary.withOpacity(0.7),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '还没有可选主角，先去宠物资料里添加一只吧',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasSelectedPet = _selectedPet != null;

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isPetSelectorExpanded = !_isPetSelectorExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isPetSelectorExpanded
                  ? Colors.white.withOpacity(0.9)
                  : Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(_isPetSelectorExpanded ? 6 : 20),
                bottomRight: Radius.circular(_isPetSelectorExpanded ? 6 : 20),
              ),
              border: Border.all(
                color: _isPetSelectorExpanded
                    ? AppColors.primary.withOpacity(0.25)
                    : Colors.white.withOpacity(0.9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                if (!hasSelectedPet) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.pets,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '选择主角',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else ...[
                  _buildPetAvatar(_selectedPet!),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPet!.name,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedPet!.lifePhoto != null &&
                                  _selectedPet!.lifePhoto!.isNotEmpty
                              ? '已切换到生活照作为默认原图'
                              : '该主角暂时没有生活照',
                          style: TextStyle(
                            color: AppColors.textGrey.withOpacity(0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                AnimatedRotation(
                  turns: _isPetSelectorExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _isPetSelectorExpanded
                        ? AppColors.primary
                        : AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          child: Container(
            height: _isPetSelectorExpanded ? null : 0,
            constraints: const BoxConstraints(maxHeight: 280),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.12),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(10),
              itemCount: _pets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final pet = _pets[index];
                final isSelected = _selectedPet?.id == pet.id;
                return _buildPetSelectorItem(pet: pet, isSelected: isSelected);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPetSelectorItem({
    required Pet pet,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _onPetSelected(pet),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withOpacity(0.22)
                : Colors.grey.withOpacity(0.12),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _buildPetAvatar(pet),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pet.name,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [pet.type, pet.breed, pet.gender]
                        .where((item) => item.trim().isNotEmpty)
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textGrey.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pet.lifePhoto != null && pet.lifePhoto!.isNotEmpty
                        ? '点击后会自动把生活照作为原图'
                        : '您还未上传生活照',
                    style: TextStyle(
                      color: pet.lifePhoto != null && pet.lifePhoto!.isNotEmpty
                          ? AppColors.textGrey.withOpacity(0.75)
                          : AppColors.accent.withOpacity(0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetAvatar(Pet pet) {
    final avatar = pet.avatar;
    final fallback = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withOpacity(0.08),
      ),
      child: Icon(
        Icons.pets_rounded,
        color: AppColors.primary.withOpacity(0.7),
        size: 22,
      ),
    );

    if (avatar == null || avatar.isEmpty) {
      return fallback;
    }

    if (_isRemoteSource(avatar)) {
      return ClipOval(
        child: Image.network(
          avatar,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }

    final file = _fileFromPath(avatar);
    if (file.existsSync()) {
      return ClipOval(
        child: Image.file(
          file,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }

    return fallback;
  }

  Widget _buildAspectRatioButton({
    required String label,
    required String value,
  }) {
    final isSelected = _selectedAspectRatio == value;
    final lines = label.split('\n');
    final title = lines.isNotEmpty ? lines.first : label;
    final ratio = lines.length > 1 ? lines.sublist(1).join(' ') : '';

    return GestureDetector(
      onTap: () => _onAspectRatioChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 46,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color:
              isSelected ? AppColors.primary : Colors.white.withOpacity(0.65),
          border: Border.all(
            color:
                isSelected ? AppColors.primary : Colors.white.withOpacity(0.9),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.34)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 12 : 6,
              spreadRadius: isSelected ? -1 : 0,
              offset: const Offset(0, 3),
            ),
            if (isSelected)
              BoxShadow(
                color: Colors.white.withOpacity(0.35),
                blurRadius: 1,
                offset: const Offset(0, -1),
                blurStyle: BlurStyle.inner,
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                height: 1.0,
              ),
            ),
            if (ratio.isNotEmpty) const SizedBox(height: 2),
            if (ratio.isNotEmpty)
              Text(
                ratio,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  height: 1.0,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetImage(AiStylePreset preset) {
    // 优先使用本地文件路径（Native 平台）
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

    // 其次使用网络 URL（Web 平台）
    final imageUrl = preset.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPresetImageFallback(preset, isLoading: true);
        },
        errorBuilder: (_, __, ___) =>
            _buildPresetImageFallback(preset, isFailed: true),
      );
    }

    // 都没有则显示回退 UI
    return _buildPresetImageFallback(
      preset,
      isLoading: _imageCachingPresetIds.contains(preset.id),
      isFailed: _imageCacheFailedPresetIds.contains(preset.id),
    );
  }

  Widget _buildPresetImageFallback(
    AiStylePreset preset, {
    bool isLoading = false,
    bool isFailed = false,
  }) {
    final hintText = isLoading
        ? '正在载入示例图'
        : isFailed
            ? '示例图载入失败'
            : '暂无示例图';

    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.textGrey,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            preset.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hintText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadErrorBanner(String message) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0).withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFC1BD),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x33FF6A5B),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFFFF6B5E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF9B1C13),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
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

    final itemExtent = _styleItemExtentForAspectRatio(_selectedAspectRatio);
    final cardWidth = _styleCardWidthForAspectRatio(_selectedAspectRatio);
    final target = (_selectedStyleIndex * itemExtent) -
        (MediaQuery.of(context).size.width / 2) +
        (cardWidth / 2);
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
