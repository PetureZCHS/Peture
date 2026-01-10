import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:path/path.dart' as path;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/ui_helpers.dart';
import 'loading_page.dart';

// 添加颜色常量定义，与chat_page.dart保持一致
class AppColors {
  static const Color background = Color(0xFFF2F2F7);
  static const Color surface = Color(0xFFFFFFFF); // 卡片表面颜色
  static const Color primary = Color(0xFF5D5FEF);
  static const Color textDark = Color(0xFF1D1D1F);
  static const Color textGrey = Color(0xFF8E8E93);
  static const Color textLight = Color(0xFFAEAEB2); // 更淡的文字颜色

  static const Color orb1 = Color(0xFFC4E0E5);
  static const Color orb2 = Color(0xFFE2D1F9);
  static const Color orb3 = Color(0xFFFFDFC4);
}

// 添加自定义PageRoute以实现更好的过渡效果
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
  final File? initialSelectedImage;
  final int initialStyleIndex;

  const PreparationPage({super.key, this.initialSelectedImage, this.initialStyleIndex = 0});

  @override
  State<PreparationPage> createState() => _PreparationPageState();
}

// 上传状态枚举
enum UploadStatus {
  idle,
  uploading,
  success,
  failed,
}

class _PreparationPageState extends State<PreparationPage>
    with TickerProviderStateMixin {
  File? _selectedImage;
  int _selectedStyleIndex = 0;

  // 控制风格列表的滚动，以便恢复时滚动到已选项
  late final ScrollController _styleScrollController;

  // 上传状态管理
  UploadStatus _uploadStatus = UploadStatus.idle;
  double _uploadProgress = 0.0;
  String _uploadError = '';


  // 是否正在向后端发起 AI 生图任务（用于按钮内提示）
  bool _isStartingTask = false;

  // Orb动画控制器
  late AnimationController _orbController;

  // 风格数据源
  final List<Map<String, String>> _styles = [
    {'name': '奔向你', 'img': 'assets/image_styles/style_run.jpg'},
    {'name': '自信探险家', 'img': 'assets/image_styles/style_explorer.jpg'},
    {'name': '时尚杂志', 'img': 'assets/image_styles/style_bazaar.jpg'},
    {'name': '复古牛仔', 'img': 'assets/image_styles/style_cowboy.jpg'},
    {'name': '多宫格', 'img': 'assets/image_styles/style_grid.jpg'},
    {'name': '秋叶', 'img': 'assets/image_styles/style_autumn.jpg'},
  ];

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    // 初始化风格滚动控制器
    _styleScrollController = ScrollController();

    // 如果有来自上一次的选择（由 LoadingPage 在失败时传回），则恢复图片和风格索引
    if (widget.initialSelectedImage != null) {
      _selectedImage = widget.initialSelectedImage;
    }
    _selectedStyleIndex = widget.initialStyleIndex;

    // 在首帧后滚动到选中的风格，确保可见
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedStyle(animated: false);
    });
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

    // 1. 🔍 优先检查登录状态 (Fail Fast 原则)
    if (user == null) {
      print('❌ 用户未认证，无法上传文件');
      if (mounted) {
        setState(() {
          _uploadStatus = UploadStatus.failed;
          _uploadError = '请先登录后再尝试上传图片';
        });
      }
      return null;
    }

    try {
      // 重置上传状态
      setState(() {
        _uploadStatus = UploadStatus.uploading;
        _uploadProgress = 0.0;
        _uploadError = '';
      });

      final userId = user.id;

      // 2. 🗜️ 压缩图片并统一格式为 JPG
      // 这一步会显著减少上传时间和流量
      final File fileToUpload =
          await _compressAndConvertImage(originalFile) ?? originalFile;

      // 3. 📝 生成路径
      // 统一使用 .jpg 后缀，因为我们在压缩步骤已经转换了格式
      final fileExtension = '.jpg';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final uniqueId = const Uuid().v4();

      // 路径格式: userId/original/timestamp_uuid.jpg
      final fileName = '${timestamp}_$uniqueId$fileExtension';
      final filePath = '$userId/original/$fileName';
      print('准备上传到: $filePath');

      // 4. 🚀 上传到 Supabase Storage
      // 注意：当前Supabase Flutter SDK版本可能不支持onProgress参数
      // 这里使用模拟进度来提供用户反馈（上限到 0.95），并在 finally 中确保计时器被取消
      final uploadFuture = supabase.storage.from('ai-wallpapers').upload(
            filePath,
            fileToUpload,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // 使用定时器模拟进度更新（上限 0.95）
      final progressTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
        if (!mounted) return;
        setState(() {
          // 模拟进度逐步提升，但不超过 0.95
          _uploadProgress = (_uploadProgress + 0.05).clamp(0.1, 0.95);
        });
      });

      try {
        // 等待上传完成
        await uploadFuture;

        // 上传成功：跳到 1.0 并设置状态
        if (mounted) {
          setState(() {
            _uploadProgress = 1.0;
            _uploadStatus = UploadStatus.success;
          });
        }

        print('✅ 图片上传成功: $filePath');
        return fileName;
      } finally {
        // 无论成功或失败都取消定时器，防止泄露或假进度继续运行
        if (progressTimer.isActive) {
          progressTimer.cancel();
        }
      }
    } on StorageException catch (e) {
      // Supabase 存储特定错误
      print('❌ StorageException: ${e.message}, Status: ${e.statusCode}');
      final errorMessage = e.statusCode == '403' ? '权限不足，无法上传图片' : '存储服务错误: ${e.message}';
      setState(() {
        _uploadStatus = UploadStatus.failed;
        _uploadProgress = 0.0;
        _uploadError = errorMessage;
      });
      _showErrorSnackBar(errorMessage);
      return null;
    } catch (e) {
      // 通用错误
      print('❌ 图片上传异常: $e');
      final errorMessage = '图片上传失败: 请检查网络';
      setState(() {
        _uploadStatus = UploadStatus.failed;
        _uploadProgress = 0.0;
        _uploadError = errorMessage;
      });
      _showErrorSnackBar(errorMessage);
      return null;
    }
  }

  /// 辅助方法：压缩并转换图片格式
  Future<File?> _compressAndConvertImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      // 生成一个临时的目标路径，确保后缀是 .jpg
      final targetPath = path.join(dir.path, '${const Uuid().v4()}.jpg');

      // 执行压缩
      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 80, // 压缩质量 0-100，80 是很好的平衡点
        format: CompressFormat.jpeg, // 强制转为 JPEG
        // 如果原图特别大，可以限制宽高，例如：
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result == null) {
        print('⚠️ 压缩失败，将使用原图上传');
        return null;
      }

      print(
          '📉 图片压缩完成: 原图 ${(file.lengthSync() / 1024).toStringAsFixed(2)}KB -> 压缩后 ${(await result.length() / 1024).toStringAsFixed(2)}KB');

      return File(result.path);
    } catch (e) {
      print('⚠️ 压缩过程出错: $e');
      return null; // 出错时返回 null，上层逻辑会回退使用原图
    }
  }

  /// 将错误消息挂载到页面状态，以便在页面内显示（不使用 SnackBar）
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
          // 背景层 - 添加orb动画效果
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

          // 内容层
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // 1. 图片上传 / 预览区域
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
                                AppColors.surface.withOpacity(0.15), // 降低透明度
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
                                      padding: EdgeInsets.all(16),
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
                                    // 使用分点说明型提示
                                    Text(
                                      "尽量包含宠物全身",
                                      style: TextStyle(
                                        color: const Color(0xFFAEAEB2),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "确保面部清晰可见",
                                      style: TextStyle(
                                        color: const Color(0xFFAEAEB2),
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
                                          fit: BoxFit.contain, // 列表页完整展示
                                        ),
                                      ),
                                    ),
                                    // 右下角「重新选择」
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

                // 2. 风格选择区标题
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "选择风格",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800, // 更粗的字重
                        color: Color(0xFF1D1D1F),
                        height: 1.2, // 行高控制
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. 风格选择区
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: _styles.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (ctx, index) {
                      final isSelected = _selectedStyleIndex == index;
                      return _buildTechStyleCard(index, isSelected);
                    },
                    controller: _styleScrollController,
                  ),
                ),

                const Spacer(),

                // 上传进度提示已移除（按钮内展示上传状态），以减少视觉冗余。

                // 内联错误提示（替代 SnackBar）
                if (_uploadError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _uploadError,
                            style: TextStyle(color: Colors.red, fontSize: 14),
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

                // 5. 开始生成按钮 - 使用毛玻璃效果
                Container(
                  height: 80,
                  padding: const EdgeInsets.all(20.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 毛玻璃背景效果
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

                      // 渐变色前景按钮
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: (_selectedImage != null && !_isStartingTask && _uploadStatus != UploadStatus.uploading)
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
                            onTap: (_selectedImage != null && _uploadStatus != UploadStatus.uploading && !_isStartingTask)
                                ? () async {
                                    // 上传图片到Supabase Storage
                                    final uploadedFileName =
                                        await _uploadImageToSupabaseStorage(
                                            _selectedImage!);

                                    // 如果上传成功，则导航到LoadingPage
                                    if (uploadedFileName != null && mounted) {
                                      // 上传成功，准备发起生成任务

                                      // 立即跳转到 LoadingPage（Uploading 已完成），由 LoadingPage 发起 img-gen-start 并轮询状态
                                      if (uploadedFileName.isNotEmpty) {
                                        // 根据_selectedStyleIndex确定style值
                                        final styleMap = {
                                          0: 'run',
                                          1: 'explorer',
                                          2: 'bazaar',
                                          3: 'cowboy',
                                          4: 'grid',
                                          5: 'autumn',
                                        };
                                        final style = styleMap[_selectedStyleIndex] ?? 'run';

                                        // 在按钮内显示“正在发起”状态，避免使用持久 SnackBar
                                        setState(() {
                                          _isStartingTask = true;
                                        });

                                        // 调用 img-gen-start，等待返回 taskId，然后再导航到 LoadingPage
                                        try {
                                          final supabase = Supabase.instance.client;

                                          final res = await supabase.functions.invoke(
                                            'img-gen-start',
                                            body: {
                                              'file_name': uploadedFileName,
                                              'style': style,
                                            },
                                          );
                                          final data = res.data;

                                          if (data is Map<String, dynamic>) {
                                            final taskId = data['task_id'] as String?;

                                            // 输出 task_id 到终端，方便调试
                                            if (taskId != null && taskId.isNotEmpty) {
                                              print('task_id: $taskId');
                                              Navigator.push(
                                                context,
                                                FadePageRoute(
                                                  page: LoadingPage(
                                                    originalImage: _selectedImage!,
                                                    uploadedFileName: uploadedFileName,
                                                    taskId: taskId, // 传递任务ID
                                                    style: style,
                                                  ),
                                                ),
                                              );
                                              return;
                                            } else {
                                              throw Exception('未能获取有效的任务ID');
                                            }
                                          } else {
                                            throw Exception('服务器返回格式错误');
                                          }
                                        } catch (e) {
                                          // 启动任务失败：记录错误并恢复按钮状态（不使用 SnackBar）
                                          if (mounted) {
                                            setState(() {
                                              _isStartingTask = false;
                                              _uploadStatus = UploadStatus.failed;
                                              _uploadError = 'AI生图任务启动失败: ${e.toString()}';
                                            });
                                          }
                                          return;
                                        }
                                      
                                        } else {
                                          // 如果上传失败，显示错误提示（不使用 SnackBar）
                                          if (mounted) {
                                            setState(() {
                                              _uploadStatus = UploadStatus.failed;
                                              _uploadError = '图片上传失败，请重试';
                                            });
                                          }
                                          return;
                                        }
                                    } else if (mounted && _uploadStatus == UploadStatus.failed) {
                                      // 上传失败：页面内显示错误并提供重试（通过下方的错误提示区）
                                    }
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(25),
                            child: Center(
                              child: _uploadStatus == UploadStatus.uploading
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
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
                                          "上传中...",
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
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
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
                                              "正在发起 AI 生图任务...",
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
                                      : Text(
                                          "开始生成",
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
    return GestureDetector(
      onTap: () => setState(() => _onStyleSelected(index)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        transform: isSelected
            ? (Matrix4.identity()..scale(1.05)) // 选中时轻微放大
            : Matrix4.identity(),
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
                      child: Image.asset(
                        _styles[index]['img']!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 6), // 增加垂直内边距，从4增加到6
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF5D5FEF)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(12)),
                    ),
                    child: Text(
                      _styles[index]['name']!,
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

  void _onStyleSelected(int index) {
    setState(() {
      _selectedStyleIndex = index;
    });
    _scrollToSelectedStyle();
  }

  void _scrollToSelectedStyle({bool animated = true}) {
    if (!_styleScrollController.hasClients) return;

    // 每个卡片宽度 100 + 间距 12
    const double itemExtent = 112.0;
    final target = (_selectedStyleIndex * itemExtent) - (MediaQuery.of(context).size.width / 2) + (itemExtent / 2);
    final clamped = target.clamp(0.0, _styleScrollController.position.maxScrollExtent);

    if (animated) {
      _styleScrollController.animateTo(clamped, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    } else {
      _styleScrollController.jumpTo(clamped);
    }
  }
}

/// 透明背景路由：让下层页面在预览时直接可见
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

/// 全屏图片页
/// 特性：
/// 1. 独立全屏黑色背景，只负责暗化，不参与缩放。
/// 2. 图片层铺满全屏，InteractiveViewer 负责双指缩放，放大时覆盖全屏无死角。
/// 3. 支持下滑整体缩小 + 背景渐显。
/// 4. 隐藏状态栏。
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
    // 缩放比例
    final scale = 1.0 - dragPercent * 0.4;
    // 背景透明度
    final bgOpacity = (1.0 - dragPercent).clamp(0.0, 1.0);

    return Stack(
      children: [
        // 1. 全屏黑色背景：固定不动，只变透明度
        Opacity(
          opacity: bgOpacity,
          child: Container(color: Colors.black),
        ),

        // 2. 交互层：铺满全屏，确保放大时不会被裁剪
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
                  // 让 child 居中，但 InteractiveViewer 本身是占满全屏的
                  child: Center(
                    child: Hero(
                      tag: widget.heroTag,
                      child: Image.file(
                        widget.imageFile,
                        fit: BoxFit.contain, // 初始完整显示
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
