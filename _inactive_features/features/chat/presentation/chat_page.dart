import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ✅ 使用新的 Supabase Dify 服务
import '../../../services/supabase_edge_service.dart';
import '../../../services/supabase_service.dart'; 
import '../../../shared/models/pet.dart'; 
// ================== 所有必需的导入 ==================
import '../../../shared/models/conversation.dart';
import '../../../shared/utils/ui_helpers.dart';
import '../../../shared/widgets/diagnostic_report_card.dart';
import '../../../shared/widgets/recommendation_card.dart'; 
import '../../auth/presentation/login_page.dart';
import '../../shop/presentation/cart_page.dart'; 
import 'dart:convert'; // Ensure dart:convert is available for JSON parsing

// ===============================================

// =======================================================================
// ChatMessage 类
// =======================================================================
class ChatMessage {
  final String text;
  final bool isUser;
  bool isLiked;
  bool isDisliked;
  final RecommendationData? recommendationData;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isLiked = false,
    this.isDisliked = false,
    this.recommendationData,
  });
}

// =======================================================================
// UI 常量管理
// =======================================================================
class _UIConstants {
  static const double borderRadius = 22.0;
  static const double horizontalPadding = 16.0;
  static const double verticalPadding = 10.0;
  static const Duration autoScrollDuration = Duration(milliseconds: 300);
  static const Curve autoScrollCurve = Curves.easeOutCubic;
}

// =======================================================================
// 主页面 - 集成数据库版本
// =======================================================================
class ChatPageWithDatabase extends StatefulWidget {
  const ChatPageWithDatabase({super.key});

  @override
  State<ChatPageWithDatabase> createState() => _ChatPageWithDatabaseState();
}

class _ChatPageWithDatabaseState extends State<ChatPageWithDatabase>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? "anonymous";
  bool _hasStartedChat = false;
  bool _isComposing = false;
  final math.Random _random = math.Random();
  List<String> _currentSuggestions = [];
  String? _conversationId; // Dify 的 conversation_id
  String? _supabaseConversationId; // Supabase 的 conversation ID

  // 打字机效果相关
  String _currentTypingText = '';
  // 打字机文本高频变更，避免整页 setState 导致大范围重建
  final ValueNotifier<String> _typingTextNotifier =
      ValueNotifier<String>('');
  Timer? _typingTimer;
  final List<String> _pendingChunks = [];
  bool _isTyping = false;
  bool _shouldAutoScroll = true;
  bool _isStreamDone = false;
  bool _userScrolledUp = false;

  // 用于保存完整的对话内容
  String? _pendingSaveQuestion;
  String _fullResponseText = '';

  bool _isDoctorMode = false; // 默认为普通模式
  bool _isAgentMode = false; // ✅ 新增：Agent 模式状态
  Pet? _selectedConsultationPet; // ✅ 新增：当前问诊的宠物
  static const int _maxPendingImages = 3;
  final ImagePicker _imagePicker = ImagePicker();
  final List<Map<String, String>> _pendingImages = [];

  // ✅ 使用新的 Supabase Edge Function 服务
  final SupabaseEdgeFunctionService _difyService =
      SupabaseEdgeFunctionService();
  final SupabaseService _supabaseService = SupabaseService();
  final List<String> _allSuggestions = [
    "猫咪呼吸似乎有点困难，嘴巴张开呼吸，像小狗一样喘气",
    "猫咪的耳朵有异味，耳道有褐色分泌物，频繁地抓耳挠腮",
    "猫咪呕吐，呕吐物是白色泡沫还有血丝",
    "狗狗最近总是舔爪子,爪子都变红了，是怎么回事？",
    "我的兔子不吃东西，精神也不好，怎么办？",
    "狗狗身上发现了蜱虫，应该怎么处理？",
    "猫咪最近喝水很多，上厕所也很多，是生病了吗？",
    "我家狗狗眼睛里有红血丝，还总流眼泪。",
    "小猫打喷嚏，流鼻涕，是感冒了吗？",
    "狗狗的鼻子很干，是正常的吗？",
    "猫咪的牙龈很红，还有口臭，是什么问题？",
  ];

  late AnimationController _suggestionFadeController;
  late AnimationController _orbController;

  @override
  void initState() {
    super.initState();
    _suggestionFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _updateSuggestions();
    _textController.addListener(_onTextChange);
  }

  void _onTextChange() {
    if (mounted) {
      final isComposing =
          _textController.text.isNotEmpty || _pendingImages.isNotEmpty;
      if (isComposing != _isComposing) {
        setState(() {
          _isComposing = isComposing;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChange);
    _textController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _typingTextNotifier.dispose();
    _suggestionFadeController.dispose();
    _orbController.dispose();
    // ✅ Edge Function 服务不需要 dispose
    super.dispose();
  }

  Future<void> _showPetSelectionDialog() async {
    // Show loading indicator in dialog if needed, but for now just fetch
    final petsData = await _supabaseService.getAllPets();
    final pets = petsData.map((data) => Pet.fromMap(data)).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "请选择要问诊的宠物",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "关联档案后，AI将根据历史病历提供更精准的建议",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (pets.isEmpty)
                Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text("暂无宠物档案，请先在个人中心添加"),
                    ),
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("确定"))
                  ],
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: pets.length,
                    itemBuilder: (context, index) {
                      final pet = pets[index];
                      return ListTile(
                        leading: ClipOval(
                          child: Container(
                            width: 40,
                            height: 40,
                            color: Colors.blue.shade100,
                            child: pet.avatar != null && pet.avatar!.isNotEmpty
                                ? Image.network(
                                    pet.avatar!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => Center(
                                        child: Text(pet.name.isNotEmpty
                                            ? pet.name[0]
                                            : "?")),
                                  )
                                : Center(
                                    child: Text(pet.name.isNotEmpty
                                        ? pet.name[0]
                                        : "?")),
                          ),
                        ),
                        title: Text(pet.name),
                        subtitle: Text("${pet.breed} · ${pet.age}"),
                        onTap: () {
                          setState(() {
                            _selectedConsultationPet = pet;
                            _isDoctorMode = true; // 自动切换到医生模式
                            _isAgentMode = false;
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已关联【${pet.name}】，进入深度问诊模式'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedConsultationPet = null;
                    _isDoctorMode = true; // 即使不关联宠物，也开启医生模式
                    _isAgentMode = false;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已进入通用问诊模式')),
                  );
                },
                child: const Text("不关联档案，直接问诊"),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveConversation(String question, String answer) async {
    if (question.trim().isEmpty ||
        answer.trim().isEmpty ||
        answer.startsWith("出现错误")) {
      return;
    }

    // 生成对话标题（使用问题的前30个字符，或完整问题如果更短）
    final title =
        question.length > 30 ? '${question.substring(0, 30)}...' : question;

    // 1. 先创建或获取 conversation（只保存标题）
    String? conversationId = _supabaseConversationId;
    if (conversationId == null) {
      // 创建新的 conversation，同时保存 Dify 的 conversation_id
      final conversation = Conversation(
        title: title,
        timestamp: DateTime.now(),
        difyConversationId: _conversationId, // 保存 Dify 的 conversation_id
      );
      final id = await _supabaseService.insertConversation(conversation);
      if (id == null) {
        debugPrint("❌ 对话保存失败: 无法创建 conversation");
        return;
      }
      conversationId = id;
      // 保存 Supabase conversation ID 以便后续使用
      _supabaseConversationId = id;
    } else if (_conversationId != null) {
      // 如果已有 Supabase conversation，但 Dify conversation_id 更新了，只更新 dify_conversation_id
      // 注意：不更新 title，因为 title 在创建时已经确定，不应该变动
      await _supabaseService.updateConversationDifyId(
        conversationId: conversationId,
        difyConversationId: _conversationId,
      );
    }

    // 2. 保存用户消息到 chat_message 表
    final userMessageId = await _supabaseService.insertChatMessage(
      conversationId: conversationId,
      text: question,
      isUser: true,
    );

    // 3. 保存 AI 回复到 chat_message 表
    final aiMessageId = await _supabaseService.insertChatMessage(
      conversationId: conversationId,
      text: answer,
      isUser: false,
    );

    if (userMessageId != null && aiMessageId != null) {
      debugPrint(
          "✅ 对话已保存到 Supabase: conversation_id=$conversationId, title=$title");
    } else {
      debugPrint("❌ 消息保存失败: conversation_id=$conversationId");
    }
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _textController.clear();
      _hasStartedChat = false;
      _isLoading = false;
      _conversationId = null; // 清空 Dify conversation_id
      _supabaseConversationId = null; // 清空 Supabase conversation ID
      _typingTimer?.cancel();
      _pendingChunks.clear();
      _isTyping = false;
      _currentTypingText = '';
      _typingTextNotifier.value = '';
      _fullResponseText = '';
      _pendingSaveQuestion = null;
      _updateSuggestions();
    });
    debugPrint("新对话已开始, conversationId 已清空。");
  }

  // 添加这个新方法来加载历史对话
  Future<void> _loadConversation(Conversation conversation) async {
    if (conversation.id == null) {
      debugPrint("❌ 无法加载对话：conversation.id 为 null");
      return;
    }

    debugPrint("📖 开始加载历史对话...");
    debugPrint("📖 标题: ${conversation.title}");
    debugPrint("📖 Conversation ID: ${conversation.id}");

    // 从 chat_message 表加载该 conversation 的所有消息
    final messages =
        await _supabaseService.getMessagesByConversationId(conversation.id!);

    if (mounted) {
      setState(() {
        _messages.clear();
        _textController.clear();
        _hasStartedChat = true;
        _isLoading = false;
        // 从 conversation 中恢复 Dify 的 conversation_id（用于接上上文）
        _conversationId = conversation.difyConversationId;
        _supabaseConversationId =
            conversation.id; // 设置当前 Supabase conversation ID
        _typingTimer?.cancel();
        _pendingChunks.clear();
        _isTyping = false;
        _currentTypingText = '';
        _typingTextNotifier.value = '';
        _fullResponseText = '';
        _pendingSaveQuestion = null;

        // 按时间顺序添加消息
        for (final msg in messages) {
          _messages.add(ChatMessage(
            text: msg['text'] as String,
            isUser: msg['is_user'] == true || msg['is_user'] == 1,
          ));
        }

        debugPrint("📖 消息列表已更新，共 ${_messages.length} 条消息");
      });

      // 加载完成后滚动到底部
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
        debugPrint("📖 已滚动到底部");
      });
    }

    debugPrint("✅ 历史对话加载完成");
  }

  // --- 数据库操作方法 ---
  Future<void> _saveMessageToDatabase(String message, bool isUser) async {
    // 注意：当前数据库设计是保存完整对话（问题+答案），而不是单条消息
    // 这个方法暂时只做日志记录，实际保存在对话完成后通过 _saveConversation 进行
    debugPrint("消息记录: ${isUser ? '用户' : 'AI'}: $message");
  }

  Future<void> _updateMessageFeedbackInDatabase(ChatMessage message) async {
    // 注意：当前数据库设计中没有反馈字段
    // 这个方法暂时只做日志记录，未来可以扩展数据库架构来支持反馈功能
    debugPrint("反馈已更新: 点赞=${message.isLiked}, 点踩=${message.isDisliked}");
  }

  // --- 核心逻辑方法 (与原版保持一致) ---
  void _updateSuggestions() {
    HapticFeedback.lightImpact();
    _suggestionFadeController.forward(from: 0.0);
    setState(() {
      _allSuggestions.shuffle(_random);
      _currentSuggestions = _allSuggestions.take(3).toList();
    });
  }

  void _startTypewriterEffect(String chunk) {
    if (chunk.isEmpty) return;
    _pendingChunks.add(chunk);
    if (!_isTyping) {
      _processNextChunk();
    }
  }

  void _processNextChunk() {
    if (_pendingChunks.isEmpty) {
      _isTyping = false;
      if (_isStreamDone && mounted) {
        setState(() {
          _isLoading = false;
          // 打字结束后，将最终文本写回 messages，确保后续逻辑/历史记录一致
          if (_messages.isNotEmpty && !_messages.last.isUser) {
            final lastMessage = _messages.last;
            _messages[_messages.length - 1] = ChatMessage(
              text: _currentTypingText,
              isUser: false,
              isLiked: lastMessage.isLiked,
              isDisliked: lastMessage.isDisliked,
              recommendationData: lastMessage.recommendationData,
            );
          }
        });
        // ✅ 所有内容都显示完成后，保存对话
        if (_pendingSaveQuestion != null && _fullResponseText.isNotEmpty) {
          _saveConversation(_pendingSaveQuestion!, _fullResponseText);
          _pendingSaveQuestion = null;
          _fullResponseText = '';
        }
      }
      return;
    }
    _isTyping = true;
    final chunk = _pendingChunks.removeAt(0);
    final characters = chunk.characters.toList();
    int index = 0;
    _typingTimer?.cancel();
    _typingTimer = Timer.periodic(const Duration(milliseconds: 15), (timer) {
      if (index < characters.length) {
        // 高频更新只更新 notifier，避免整页 setState 触发大范围重建
        _currentTypingText += characters[index];
        _typingTextNotifier.value = _currentTypingText;
        if (index % 10 == 0 || characters[index] == '\n') {
          _smoothScrollToEnd();
        }
        index++;
      } else {
        timer.cancel();
        _processNextChunk();
      }
    });
  }

  void _smoothScrollToEnd() {
    if (!_shouldAutoScroll || !_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: _UIConstants.autoScrollDuration,
          curve: _UIConstants.autoScrollCurve,
        );
      }
    });
  }

  Future<void> _sendMessage({String? text}) async {
    if (_isLoading) return;
    var messageText = (text ?? _textController.text).trim();
    final attachedImages = List<Map<String, String>>.from(_pendingImages);
    if (messageText.isEmpty && attachedImages.isEmpty) return;
    if (messageText.isEmpty && attachedImages.isNotEmpty) {
      // Dify/Edge Function 需要 query；图片单发时补一个合理的默认 query
      messageText = _isDoctorMode
          ? '请根据我上传的图片分析情况，并继续问诊：还需要我补充哪些症状信息？'
          : '请描述并分析我上传的图片。';
    }
    HapticFeedback.mediumImpact();
    _textController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      // 只有在第一次发送消息时，才将 _hasStartedChat 设为 true，以触发动画
      if (!_hasStartedChat) {
        _hasStartedChat = true;
      }
      _messages.add(ChatMessage(text: messageText, isUser: true));
      _messages.add(ChatMessage(text: "", isUser: false));
      _isLoading = true;
      _currentTypingText = '';
      _typingTextNotifier.value = '';
      _pendingChunks.clear();
      _isTyping = false;
      _shouldAutoScroll = true;
      _isStreamDone = false;
      _userScrolledUp = false;
      _pendingImages.clear();
      _isComposing = false;
    });

    _saveMessageToDatabase(messageText, true);
    _scrollToBottom();

    // ✅ 使用 Supabase Dify 服务
    String? petContext;

    // 🐾 注入宠物档案与病历信息 (如果有选中的宠物)
    if (_selectedConsultationPet != null) {
      StringBuffer petInfoBuffer = StringBuffer();
      petInfoBuffer.writeln("\n\n【用户已关联宠物档案】");
      petInfoBuffer.writeln("姓名：${_selectedConsultationPet!.name}");
      petInfoBuffer.writeln("品种：${_selectedConsultationPet!.breed}");
      petInfoBuffer.writeln("年龄：${_selectedConsultationPet!.age}");
      petInfoBuffer.writeln("性别：${_selectedConsultationPet!.gender}");
      petInfoBuffer
          .writeln("绝育状态：${_selectedConsultationPet!.neuterStatus ?? '未知'}");
      if (_selectedConsultationPet!.weight != null) {
        petInfoBuffer.writeln("体重：${_selectedConsultationPet!.weight} kg");
      }

      // 获取病历记录
      try {
        if (_selectedConsultationPet!.id != null) {
          final recordsData = await _supabaseService
              .getMedicalRecordsForPet(_selectedConsultationPet!.id!);

          if (recordsData.isNotEmpty) {
            petInfoBuffer.writeln("\n【该宠物的历史病历】");
            // 取最近 5 条
            final recentRecords = recordsData.take(5);
            for (var record in recentRecords) {
              petInfoBuffer
                  .writeln("- ${record['date']}: ${record['description']}");
            }
          }
        }
      } catch (e) {
        debugPrint("❌ 获取病历失败: $e");
      }

      petContext = petInfoBuffer.toString().trim();
    }

    final stream = _difyService.callDifyChat(
      query: messageText,
      user: _userId,
      conversationId: _conversationId,
      doctorMode: _isDoctorMode,
      agentMode: _isAgentMode,
      petContext: petContext,
      images: attachedImages,
    );

    // 重置完整响应文本和待保存的问题
    _fullResponseText = '';
    _pendingSaveQuestion = messageText;

    stream.listen((event) {
      if (!mounted) return;
      switch (event) {
        case ContentEvent():
          // ✅ 累积完整的响应文本
          _fullResponseText += event.content;
          _startTypewriterEffect(event.content);
          break;

        case DoneEvent():
          _isStreamDone = true;
          // ✅ 从 DoneEvent 获取 conversation_id
          if (event.conversationId != null &&
              event.conversationId != _conversationId) {
            setState(() {
              _conversationId = event.conversationId;
            });
            debugPrint("✅ Conversation ID 已更新: $_conversationId");

            // 如果已有 Supabase conversation，更新 Dify conversation_id 到数据库
            // 注意：只更新 dify_conversation_id，不更新 title
            if (_supabaseConversationId != null) {
              _supabaseService
                  .updateConversationDifyId(
                conversationId: _supabaseConversationId!,
                difyConversationId: _conversationId,
              )
                  .then((success) {
                if (success) {
                  debugPrint("✅ Dify conversation_id 已保存到数据库");
                }
              });
            }
          }
          // ✅ 不在这里保存，而是在打字机效果完成后保存
          // 如果没有打字机效果（_pendingChunks为空且不在打字中），立即保存
          if (_pendingChunks.isEmpty && !_isTyping) {
            setState(() => _isLoading = false);
            if (_pendingSaveQuestion != null && _fullResponseText.isNotEmpty) {
              _saveConversation(_pendingSaveQuestion!, _fullResponseText);
              _pendingSaveQuestion = null;
              _fullResponseText = '';
            }
          }
          break;

        case ErrorEvent():
          if (event.error == 'DIFY_AUTH_INVALID') {
            _typingTimer?.cancel();
            setState(() {
              _messages.last = ChatMessage(
                text: "AI 服务鉴权失败：Dify API Key 无效，请联系管理员更新服务端密钥。",
                isUser: false,
              );
              _isLoading = false;
              _isTyping = false;
            });
            _scrollToBottom();
            return;
          }
          if (event.error == 'AUTH_INVALID') {
            _handleAuthInvalid();
            return;
          }
          _typingTimer?.cancel();
          setState(() {
            _messages.last = ChatMessage(
              text: "出现错误: ${event.error}",
              isUser: false,
            );
            _isLoading = false;
            _isTyping = false;
          });
          _scrollToBottom();
          break;
      }
    });
  }

  void _regenerateResponse() {
    if (_isLoading) return;
    final lastUserMessage = _messages.lastWhere(
      (m) => m.isUser,
      orElse: () => ChatMessage(text: '', isUser: true),
    );
    if (lastUserMessage.text.isEmpty) return;
    HapticFeedback.lightImpact();
    _typingTimer?.cancel();
    setState(() {
      if (_messages.isNotEmpty && !_messages.last.isUser) {
        _messages.removeLast();
      }
      _messages.add(ChatMessage(text: "", isUser: false));
      _isLoading = true;
      _currentTypingText = '';
      _typingTextNotifier.value = '';
      _pendingChunks.clear();
      _isTyping = false;
      _shouldAutoScroll = true;
      _isStreamDone = false;
      _userScrolledUp = false;
    });
    _scrollToBottom();

    if (_conversationId == null) {
      setState(() {
        _messages.last = ChatMessage(
          text: "错误：无法重新生成，因为没有找到当前对话ID。",
          isUser: false,
        );
        _isLoading = false;
      });
      return;
    }

    // ✅ 使用 Supabase Dify 服务
    // 重置完整响应文本和待保存的问题
    _fullResponseText = '';
    _pendingSaveQuestion = lastUserMessage.text;

    final stream = _difyService.callDifyChat(
      query: lastUserMessage.text,
      user: _userId,
      conversationId: _conversationId,
    );

    stream.listen((event) {
      if (!mounted) return;
      switch (event) {
        case ContentEvent():
          // ✅ 累积完整的响应文本
          _fullResponseText += event.content;
          _startTypewriterEffect(event.content);
          break;

        case DoneEvent():
          _isStreamDone = true;
          // ✅ 不在这里保存，而是在打字机效果完成后保存
          if (_pendingChunks.isEmpty && !_isTyping) {
            setState(() => _isLoading = false);
            if (_pendingSaveQuestion != null && _fullResponseText.isNotEmpty) {
              _saveConversation(_pendingSaveQuestion!, _fullResponseText);
              _pendingSaveQuestion = null;
              _fullResponseText = '';
            }
          }
          break;

        case ErrorEvent():
          if (event.error == 'DIFY_AUTH_INVALID') {
            _typingTimer?.cancel();
            setState(() {
              _messages.last = ChatMessage(
                text: "重新生成失败：AI 服务鉴权异常（Dify API Key 无效）。",
                isUser: false,
              );
              _isLoading = false;
              _isTyping = false;
            });
            _scrollToBottom();
            return;
          }
          if (event.error == 'AUTH_INVALID') {
            _handleAuthInvalid();
            return;
          }
          _typingTimer?.cancel();
          setState(() {
            _messages.last = ChatMessage(
              text: "重新生成失败: ${event.error}",
              isUser: false,
            );
            _isLoading = false;
            _isTyping = false;
          });
          _scrollToBottom();
          break;
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: _UIConstants.autoScrollDuration,
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleAuthInvalid() async {
    _typingTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isTyping = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('登录状态已失效，请重新登录')),
    );
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _onLikePressed(ChatMessage message) {
    HapticFeedback.lightImpact();
    setState(() {
      message.isLiked = !message.isLiked;
      if (message.isLiked) message.isDisliked = false;
    });
    _updateMessageFeedbackInDatabase(message);
  }

  void _onDislikePressed(ChatMessage message) {
    HapticFeedback.lightImpact();
    setState(() {
      message.isDisliked = !message.isDisliked;
      if (message.isDisliked) message.isLiked = false;
    });
  }

  Future<void> _onPickImagePressed() async {
    if (_pendingImages.length >= _maxPendingImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('最多上传 $_maxPendingImages 张图片')),
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final fileName = picked.name.isNotEmpty
        ? picked.name
        : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final lower = fileName.toLowerCase();
    String mimeType = 'image/jpeg';
    if (lower.endsWith('.png')) mimeType = 'image/png';
    if (lower.endsWith('.webp')) mimeType = 'image/webp';

    setState(() {
      _pendingImages.add({
        'fileName': fileName,
        'mimeType': mimeType,
        'dataBase64': base64Encode(bytes),
      });
      // 选择图片后也应视为“可发送”
      _isComposing = true;
    });
  }

  Future<void> _onPlusPressed() async {
    HapticFeedback.selectionClick();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('添加图片'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            if (_pendingImages.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  '清空已选图片',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(context, 'clear_images'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'image') {
      await _onPickImagePressed();
      return;
    }
    if (action == 'clear_images') {
      setState(() {
        _pendingImages.clear();
        _isComposing = _textController.text.isNotEmpty;
      });
    }
  }

  void _showPendingImagePreview(String base64Data) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.memory(
              base64Decode(base64Data),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  void _onCopyPressed(ChatMessage message) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: _buildCopyText(message)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("已复制到剪贴板"),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _buildCopyText(ChatMessage message) {
    final raw = message.text;
    final startIndex = raw.indexOf('{');
    final endIndex = raw.lastIndexOf('}');
    if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
      return raw;
    }
    try {
      final jsonString = raw.substring(startIndex, endIndex + 1);
      final jsonMap = jsonDecode(jsonString);
      final type = jsonMap['type'];
      final data = (jsonMap['data'] as Map?)?.cast<String, dynamic>() ?? {};

      if (type == 'report') {
        final petName = (data['pet_name'] as String?)?.trim();
        final diagnosis = (data['diagnosis'] as String?)?.trim() ?? '';
        final urgency = data['urgency_level']?.toString() ?? '';
        final possible = (data['possible_causes'] as List?)
                ?.map((e) => e.toString())
                .where((s) => s.trim().isNotEmpty)
                .toList() ??
            const <String>[];
        final advice = (data['advice_summary'] as String?)?.trim() ?? '';

        final b = StringBuffer();
        b.writeln('Peture AI 辅助诊断报告');
        if (petName != null && petName.isNotEmpty) b.writeln('姓名：$petName');
        if (urgency.isNotEmpty) b.writeln('紧急度：$urgency/5');
        if (diagnosis.isNotEmpty) b.writeln('\n诊断印象：\n$diagnosis');
        if (possible.isNotEmpty) {
          b.writeln('\n检查所见 / 症状分析：');
          for (final c in possible) {
            b.writeln('- $c');
          }
        }
        if (advice.isNotEmpty) b.writeln('\n处置建议：\n$advice');
        return b.toString().trim();
      }

      if (type == 'recommendation') {
        final productName = (data['productName'] as String?)?.trim() ?? '';
        final reason = (data['reason'] as String?)?.trim() ?? '';
        final price = (data['price'] as String?)?.trim() ?? '';
        final rating = (data['rating'] as String?)?.trim() ?? '';
        final safety = (data['safetyCheck'] as String?)?.trim() ?? '';
        final steps = (data['reasoningSteps'] as List?)
                ?.map((e) => e.toString())
                .where((s) => s.trim().isNotEmpty)
                .toList() ??
            const <String>[];

        final b = StringBuffer();
        b.writeln('Peture AI 推荐');
        if (productName.isNotEmpty) b.writeln('商品：$productName');
        if (price.isNotEmpty) b.writeln('价格：$price');
        if (rating.isNotEmpty) b.writeln('评分：$rating');
        if (safety.isNotEmpty) b.writeln('安全检核：$safety');
        if (reason.isNotEmpty) b.writeln('\n理由：\n$reason');
        if (steps.isNotEmpty) {
          b.writeln('\n推理步骤：');
          for (final s in steps) {
            b.writeln('- $s');
          }
        }
        return b.toString().trim();
      }
    } catch (_) {
      // ignore
    }
    return raw;
  }

  void _onMoreOptionsPressed(ChatMessage message) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.report_problem_outlined),
              title: const Text('报告问题'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('翻译'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  // =======================================================================
  // 已更新：build 方法，实现动画切换
  // =======================================================================
  @override
  Widget build(BuildContext context) {
    final drawer = AppDrawer(
      onNewChatPressed: _startNewChat,
      onConversationSelected: _loadConversation,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      endDrawer: drawer,
      body: Stack(
        children: [
          // 背景层
          Stack(
            children: [
              Container(color: AppColors.background),
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, child) {
                  return Positioned(
                    top: -100 + (_orbController.value * 40),
                    left: -50 + (_orbController.value * 20),
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
                  return Positioned(
                    top: 300 + (math.sin(_orbController.value * math.pi) * 60),
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
                  return Positioned(
                    bottom: -150,
                    left: -80 + (_orbController.value * 150),
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
                _buildTopHeader(),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: _isDoctorMode
                      ? _buildDiagnosisProgress()
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOutQuart,
                    switchOutCurve: Curves.easeInQuart,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      final isChatList =
                          child.key == const ValueKey("ChatList");

                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final val = animation.value;
                          double opacity = val;
                          double yOffset = 0.0;
                          double scaleX = 1.0;
                          double scaleY = 1.0;

                          // 科技感核心：模拟高速数据传输的"光速跃迁"效果 (Warp Speed)
                          // 通过动态拉伸和位移，制造物体高速移动的视觉残留

                          if (isChatList) {
                            // 进入 (val 0->1): 数据流从下方高速汇聚
                            yOffset = 120 * (1 - val);
                            // 进场初期(val=0)垂直拉伸严重，随速度减慢恢复正常
                            scaleY = 1.0 + (0.2 * (1 - val));
                            scaleX = 1.0 - (0.05 * (1 - val));
                          } else {
                            // 退出 (val 1->0): 数据流向上高速上传
                            yOffset = -120 * (1 - val);
                            // 离场末期(val=0)垂直拉伸严重
                            scaleY = 1.0 + (0.2 * (1 - val));
                            scaleX = 1.0 - (0.05 * (1 - val));
                          }

                          return Transform.translate(
                            offset: Offset(0, yOffset),
                            child: Transform.scale(
                              scaleX: scaleX,
                              scaleY: scaleY,
                              alignment: Alignment.center,
                              child: Opacity(
                                opacity: opacity.clamp(0.0, 1.0),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    child: (_hasStartedChat || _isDoctorMode)
                        ? Container(
                            key: const ValueKey("ChatList"),
                            child: _buildMessageList(),
                          )
                        : Container(
                            key: const ValueKey("WelcomeScreen"),
                            child: _buildWelcomeScreen(),
                          ),
                  ),
                ),
                _buildInputArea(enabled: !_isLoading),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =======================================================================
  // 新增：深度问诊进度条
  // =======================================================================
  int _getCurrentDiagnosisStep() {
    if (_messages.isEmpty) return 0;

    // Check for report
    final lastMsg = _messages.last;
    if (!lastMsg.isUser && lastMsg.text.contains('"type": "report"')) {
      return 3; // Report
    }

    if (_messages.length >= 6) return 2; // Analysis (after ~3 rounds)
    if (_messages.length >= 2) return 1; // Inquiry (after 1 round)

    return 0; // Symptoms (Start)
  }

  Widget _buildDiagnosisProgress() {
    final currentStep = _getCurrentDiagnosisStep();
    final steps = [
      {'icon': Icons.pets_rounded, 'label': '症状描述'},
      {'icon': Icons.chat_bubble_rounded, 'label': '深度问诊'},
      {'icon': Icons.psychology_rounded, 'label': '智能分析'},
      {'icon': Icons.assignment_rounded, 'label': '生成报告'},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A8EFA).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 底部灰色轨道
          Positioned(
            top: 15,
            left: 36,
            right: 36,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
          // 2. 激活的进度条 (带渐变)
          Positioned(
            top: 15,
            left: 36,
            right: 36,
            child: Row(
              children: List.generate(steps.length - 1, (index) {
                final isActive = index < currentStep;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? const LinearGradient(
                              colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
                            )
                          : null,
                      color: isActive ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                );
              }),
            ),
          ),
          // 3. 节点图标
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              final isCompleted = index < currentStep;
              final isCurrent = index == currentStep;
              final isActive = isCompleted || isCurrent;

              return Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      width: isCurrent ? 34 : 30,
                      height: isCurrent ? 34 : 30,
                      decoration: BoxDecoration(
                        gradient: isActive
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
                              )
                            : null,
                        color: isActive ? null : Colors.white,
                        shape: BoxShape.circle,
                        border: isActive
                            ? null
                            : Border.all(color: Colors.grey.shade200, width: 2),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color:
                                      const Color(0xFF5A8EFA).withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Icon(
                          isCompleted
                              ? Icons.check_rounded
                              : steps[index]['icon'] as IconData,
                          size: isCurrent ? 18 : 14,
                          color: isActive ? Colors.white : Colors.grey.shade300,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.w500,
                        color: isCurrent
                            ? const Color(0xFF5A8EFA)
                            : (isCompleted
                                ? Colors.black87
                                : Colors.grey.shade400),
                      ),
                      child: Text(steps[index]['label'] as String),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // =======================================================================
  // 已更新：_buildTopHeader 方法 (与原版保持一致)
  // =======================================================================
  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_back, size: 28),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '返回',
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Center(
                key: ValueKey(_hasStartedChat ? "chat_title" : "welcome_title"),
                child: Text(
                  "Peture AI",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                ),
              ),
            ),
          ),
          Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
                tooltip: '打开导航菜单',
              );
            },
          ),
        ],
      ),
    );
  }

  // --- 以下是其他未修改的 UI 构建方法 ---

  Widget _buildWelcomeScreen() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutQuart,
      switchOutCurve: Curves.easeInQuart,
      child: _isAgentMode
          ? const _AgentWelcomeView(key: ValueKey('AgentWelcome'))
          : _buildNormalWelcome(key: const ValueKey('NormalWelcome')),
    );
  }

  Widget _buildNormalWelcome({Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          // Kimi 风格精灵小球
          const _KimiBall(),
          const SizedBox(height: 12),
          // 标题区域 - 极简大气的排版
          const Text(
            "Hello, 铲屎官",
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
              letterSpacing: -1.0,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "有什么可以帮助到这个可爱的家伙？",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 40),

          // 建议列表 - 左对齐，宽度自适应，更轻量
          FadeTransition(
            opacity: _suggestionFadeController,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _currentSuggestions
                  .map((text) => _buildMinimalSuggestion(text))
                  .toList(),
            ),
          ),

          const SizedBox(height: 24),
          // 换一换按钮 - 极简风格
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _updateSuggestions,
              icon: Icon(Icons.refresh, size: 16, color: Colors.grey.shade400),
              label: Text(
                "换一换",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMinimalSuggestion(String text) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _sendMessage(text: text),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1F1F1F),
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea({bool enabled = true}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部功能芯片栏
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildActionChip(
                  icon: Icons.medical_services_outlined,
                  label: _selectedConsultationPet == null
                      ? "深度问诊"
                      : "问诊: ${_selectedConsultationPet!.name}",
                  isActive: _isDoctorMode,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (_isDoctorMode) {
                      // 关闭模式
                      setState(() {
                        _isDoctorMode = false;
                        _selectedConsultationPet = null;
                      });
                    } else {
                      // 开启模式 -> 弹出选宠对话框
                      _showPetSelectionDialog();
                      // 注意：对话框选择后会设置 _isDoctorMode = true
                      // 如果用户关闭对话框但想用普通医生模式？
                      // 我们可以在对话框里提供 "不关联宠物" 选项，对话框代码里已经有了 "取消关联 / 不使用档案"
                      // 但是那个按钮目前逻辑是 clear pet 并 pop。
                      // 我们应该修改 dialog 里的逻辑，让 "不关联" 也能进入 doctor mode
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildActionChip(
                  icon: Icons.support_agent_rounded,
                  label: "在线问诊",
                  isActive: !_isDoctorMode && !_isAgentMode,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isDoctorMode = false;
                      _isAgentMode = false;
                      _selectedConsultationPet = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已切换到在线问诊模式')),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _buildActionChip(
                  icon: Icons.psychology_outlined,
                  label: "Agent 模式",
                  isActive: _isAgentMode,
                  onTap: () {
                    setState(() {
                      _isAgentMode = !_isAgentMode;
                      // 如果开启 Agent 模式，关闭医生模式，避免冲突
                      if (_isAgentMode) _isDoctorMode = false;
                    });
                    HapticFeedback.selectionClick();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 底部输入框
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 8), // 调整内边距以对齐图标中心
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(30.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 0,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 相机图标
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined,
                      color: Colors.black87),
                  onPressed: enabled ? _onPickImagePressed : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                if (_pendingImages.isNotEmpty)
                  SizedBox(
                    height: 42,
                    width: 170,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pendingImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 4),
                      itemBuilder: (context, index) {
                        final image = _pendingImages[index];
                        final base64 = image['dataBase64'] ?? '';
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 40,
                                height: 40,
                                color: Colors.grey.shade200,
                                child: GestureDetector(
                                  onTap: base64.isNotEmpty
                                      ? () => _showPendingImagePreview(base64)
                                      : null,
                                  child: base64.isNotEmpty
                                      ? Image.memory(
                                          base64Decode(base64),
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(Icons.image_outlined, size: 18),
                                ),
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _pendingImages.removeAt(index);
                                  _isComposing = _textController.text.isNotEmpty ||
                                      _pendingImages.isNotEmpty;
                                }),
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                if (_pendingImages.isNotEmpty) const SizedBox(width: 8),
                // 输入框
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: enabled,
                    maxLines: 5,
                    minLines: 1,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 10),
                      hintText: '发消息或按住说话...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: enabled ? (value) => _sendMessage() : null,
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                // 语音图标
                if (!_isComposing)
                  IconButton(
                    icon: const Icon(Icons.keyboard_voice_outlined,
                        color: Colors.black87),
                    onPressed: enabled ? () {} : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (!_isComposing) const SizedBox(width: 12),
                // 加号图标 或 发送按钮
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: _isComposing
                      ? GestureDetector(
                          key: const ValueKey('send_btn_active'),
                          onTap: enabled ? () => _sendMessage() : null,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFF5D5FEF), // 主题紫色
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_upward_rounded,
                                color: Colors.white, size: 18),
                          ),
                        )
                      : IconButton(
                          key: const ValueKey('plus_btn'),
                          icon: const Icon(Icons.add_circle_outline,
                              color: Colors.black87),
                          onPressed: enabled ? _onPlusPressed : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEEF0FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF5D5FEF) : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? const Color(0xFF5D5FEF) : Colors.black87,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF5D5FEF) : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo is ScrollUpdateNotification) {
              final metrics = scrollInfo.metrics;
              if (metrics.pixels < metrics.maxScrollExtent - 150) {
                _shouldAutoScroll = false;
                _userScrolledUp = true;
              } else {
                _shouldAutoScroll = true;
                _userScrolledUp = false;
              }
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              vertical: _UIConstants.verticalPadding,
              horizontal: _UIConstants.horizontalPadding,
            ),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final isLastMessageLoading = _isLoading &&
                  index == _messages.length - 1 &&
                  message.text.isEmpty;
              final isLastMessage = index == _messages.length - 1;
              final padding =
                  EdgeInsets.only(bottom: isLastMessage ? 80.0 : 0);

              // 流式打字：只刷新最后一条气泡，避免整页 rebuild
              if (isLastMessageLoading && !message.isUser) {
                return Padding(
                  padding: padding,
                  child: ValueListenableBuilder<String>(
                    valueListenable: _typingTextNotifier,
                    builder: (context, typingText, _) {
                      return _MessageBubble(
                        message: message,
                        consultationPetName: _selectedConsultationPet?.name,
                        overrideText: typingText,
                        isLoading: true,
                        isResponseComplete: false,
                        onLikePressed: () => _onLikePressed(message),
                        onDislikePressed: () => _onDislikePressed(message),
                        onRegeneratePressed: _regenerateResponse,
                        onCopyPressed: () => _onCopyPressed(message),
                        onMoreOptionsPressed: () =>
                            _onMoreOptionsPressed(message),
                      );
                    },
                  ),
                );
              }

              return Padding(
                padding: padding,
                child: _MessageBubble(
                  message: message,
                  consultationPetName: _selectedConsultationPet?.name,
                  isLoading: isLastMessageLoading,
                  isResponseComplete: !_isLoading && !message.isUser,
                  onLikePressed: () => _onLikePressed(message),
                  onDislikePressed: () => _onDislikePressed(message),
                  onRegeneratePressed: _regenerateResponse,
                  onCopyPressed: () => _onCopyPressed(message),
                  onMoreOptionsPressed: () => _onMoreOptionsPressed(message),
                ),
              );
            },
          ),
        ),
        if (_userScrolledUp && _messages.isNotEmpty)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.small(
                heroTag: "new_message_indicator",
                onPressed: _scrollToBottom,
                child: const Icon(Icons.arrow_downward, size: 18),
              ),
            ),
          ),
      ],
    );
  }
}

// =======================================================================
// 应用抽屉组件 (AppDrawer)
// =======================================================================
class AppDrawer extends StatefulWidget {
  final VoidCallback onNewChatPressed;
  final Function(Conversation)? onConversationSelected;
  const AppDrawer({
    super.key,
    required this.onNewChatPressed,
    this.onConversationSelected,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late Future<List<Conversation>> _conversationsFuture;
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  void _loadConversations() {
    setState(() {
      _conversationsFuture =
          _supabaseService.getAllConversations().then((data) {
        data.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.timestamp.compareTo(a.timestamp);
        });
        return data;
      });
    });
  }

  void _showConversationOptions(
    BuildContext context,
    Conversation conversation,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('分享'),
                onTap: () async {
                  Navigator.pop(context);
                  // 从 chat_message 表加载消息用于分享
                  if (conversation.id != null) {
                    final messages = await _supabaseService
                        .getMessagesByConversationId(conversation.id!);
                    final shareContent = messages.map((msg) {
                      final prefix =
                          (msg['is_user'] == true || msg['is_user'] == 1)
                              ? 'Q'
                              : 'A';
                      return "$prefix: ${msg['text']}";
                    }).join('\n\n');
                    Share.share(shareContent);
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  conversation.isPinned ? Icons.star : Icons.star_border,
                ),
                title: Text(conversation.isPinned ? '取消收藏' : '收藏'),
                onTap: () {
                  Navigator.pop(context);
                  _togglePinConversation(conversation);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('重命名'),
                onTap: () {
                  Navigator.pop(context);
                  _renameConversation(context, conversation);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('删除', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteConversation(context, conversation);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _togglePinConversation(Conversation conversation) async {
    final updated = conversation.copyWith(isPinned: !conversation.isPinned);
    await _supabaseService.updateConversation(updated);
    _loadConversations();
  }

  void _renameConversation(
    BuildContext context,
    Conversation conversation,
  ) async {
    final controller = TextEditingController(text: conversation.title);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("重命名对话"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "请输入新标题"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  final updated = conversation.copyWith(
                    title: controller.text,
                  );
                  await _supabaseService.updateConversation(updated);
                  _loadConversations();
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("确定"),
            ),
          ],
        );
      },
    );
  }

  void _deleteConversation(
    BuildContext context,
    Conversation conversation,
  ) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("确认删除？"),
          content: Text("删除后无法恢复：\n\"${conversation.title}\""),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () async {
                if (conversation.id != null) {
                  await _supabaseService.deleteConversation(conversation.id!);
                  _loadConversations();
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("删除", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          bottomLeft: Radius.circular(30),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                bottomLeft: Radius.circular(30),
              ),
              border: Border(
                left:
                    BorderSide(color: Colors.white.withOpacity(0.5), width: 1),
                top: BorderSide(color: Colors.white.withOpacity(0.5), width: 1),
                bottom:
                    BorderSide(color: Colors.white.withOpacity(0.5), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Peture',
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('发起新对话'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNewChatPressed();
                    },
                  ),
                  ListTile(
                    leading: const Icon(CupertinoIcons.compass),
                    title: const Text('探索 Peture'),
                    onTap: () => Navigator.pop(context),
                  ),
                  const Divider(height: 30),
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      '近期对话',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<Conversation>>(
                      future: _conversationsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('加载失败: ${snapshot.error}'));
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                '暂无对话记录\n点击"发起新对话"开始咨询',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }
                        final conversations = snapshot.data!;
                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: conversations.length,
                          itemBuilder: (context, index) {
                            final conversation = conversations[index];
                            return ListTile(
                              leading: conversation.isPinned
                                  ? const Icon(
                                      Icons.star,
                                      size: 20,
                                      color: Colors.amber,
                                    )
                                  : null,
                              title: Text(
                                conversation.title,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () => _showConversationOptions(
                                    context, conversation),
                              ),
                              onTap: () {
                                debugPrint("🔘 点击历史对话: ${conversation.title}");
                                Navigator.pop(context);
                                if (widget.onConversationSelected != null) {
                                  widget.onConversationSelected!(conversation);
                                }
                              },
                            );
                          },
                        );
                      },
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
}

// =======================================================================
// AI "正在输入中"的动画组件
// =======================================================================

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _wagController;
  late AnimationController _bubbleController;
  Timer? _sloganTimer;
  int _sloganIndex = 0;
  static const List<String> _slogans = [
    '狗狗努力思考中...',
    '本汪正在组织语言...',
    '鼻子嗅到关键线索了...',
    '让我再确认一下症状...',
  ];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _wagController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..repeat(reverse: true);
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _sloganTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() {
        _sloganIndex = (_sloganIndex + 1) % _slogans.length;
      });
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _wagController.dispose();
    _bubbleController.dispose();
    _sloganTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
        [_floatController, _wagController, _bubbleController],
      ),
      builder: (context, _) {
        final floatY = math.sin(_floatController.value * math.pi) * 3.0;
        final tailAngle = (_wagController.value - 0.5) * 0.9;
        return Transform.translate(
          offset: Offset(0, -floatY),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBubble(0.0, 7),
                  const SizedBox(width: 3),
                  _buildBubble(0.25, 5),
                  const SizedBox(width: 3),
                  _buildBubble(0.5, 4),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Transform.rotate(
                    angle: tailAngle,
                    child: Container(
                      width: 11,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC78E5E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9C88A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        top: -5,
                        child: Transform.rotate(
                          angle: -0.25,
                          child: Container(
                            width: 10,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC78E5E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: -5,
                        child: Transform.rotate(
                          angle: 0.25,
                          child: Container(
                            width: 10,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC78E5E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 12,
                        top: 12,
                        child: Icon(Icons.circle, size: 3.5, color: Colors.black87),
                      ),
                      const Positioned(
                        right: 12,
                        top: 12,
                        child: Icon(Icons.circle, size: 3.5, color: Colors.black87),
                      ),
                      const Positioned(
                        left: 19,
                        top: 17,
                        child: Icon(Icons.circle, size: 4, color: Color(0xFF8D5A3C)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 5),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Text(
                  _slogans[_sloganIndex],
                  key: ValueKey(_sloganIndex),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBubble(double shift, double size) {
    final t = (_bubbleController.value + shift) % 1.0;
    final opacity = (0.35 + 0.65 * math.sin(t * math.pi)).clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, -2 * math.sin(t * math.pi)),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFAEDCFF),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

// =======================================================================
// 消息气泡组件（增强交互）
// =======================================================================
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String? consultationPetName;
  // 流式打字阶段：从外部覆盖要展示的文本，避免依赖 message.text 的高频 setState
  final String? overrideText;
  final bool isLoading;
  final bool isResponseComplete;
  final VoidCallback onLikePressed;
  final VoidCallback onDislikePressed;
  final VoidCallback onRegeneratePressed;
  final VoidCallback onCopyPressed;
  final VoidCallback onMoreOptionsPressed;

  const _MessageBubble({
    required this.message,
    this.consultationPetName,
    this.overrideText,
    this.isLoading = false,
    this.isResponseComplete = false,
    required this.onLikePressed,
    required this.onDislikePressed,
    required this.onRegeneratePressed,
    required this.onCopyPressed,
    required this.onMoreOptionsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);
    final renderText = overrideText ?? message.text;
    final bubbleDecoration = isUser
        ? BoxDecoration(
            color: theme.primaryColor,
            borderRadius: BorderRadius.circular(_UIConstants.borderRadius),
          )
        : BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_UIConstants.borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
              ),
            ],
          );
    final markdownStyleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: TextStyle(
        color: isUser ? Colors.white : Colors.black87,
        fontSize: 16,
        height: 1.5,
      ),
      strong: TextStyle(
        color: isUser ? Colors.white : Colors.black,
        fontWeight: FontWeight.bold,
      ),
    );
    final showLoadingIndicator = isLoading && renderText.isEmpty;
    final isStreaming = isLoading && !isResponseComplete && !isUser;

    // ✅ 优先渲染推荐卡片
    if (message.recommendationData != null) {
      return RecommendationCard(
        data: message.recommendationData!,
        onAdopt: () {
          HapticFeedback.mediumImpact();
          // 模拟加载
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("正在为您自动加购..."),
              duration: Duration(milliseconds: 800),
              behavior: SnackBarBehavior.floating,
            ),
          );

          Future.delayed(const Duration(milliseconds: 800), () {
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CartPage(
                  autoAddedItem: {
                    'name': message.recommendationData!.productName,
                    'price': 528.00, // 假设价格
                    'quantity': 1,
                    'spec': '10kg / 袋',
                  },
                ),
              ),
            );
          });
        },
      );
    }

    // Check if message is JSON report or recommendation
    Widget messageContent;
    bool isCustomCard = false;

    // 增强的检测逻辑：如果消息以 { 开头，或者包含 "type": "recommendation"，则视为协议消息
    // 这样可以避免在流式传输初期显示原始 JSON 文本
    bool isProtocolMessage = !isUser &&
        !isStreaming &&
        (renderText.trimLeft().startsWith('{') ||
            renderText.contains('"type": "recommendation"') ||
            renderText.contains('"type": "report"'));

    if (isProtocolMessage) {
      try {
        // Find the JSON part if there is any text before/after
        final startIndex = message.text.indexOf('{');
        final endIndex = message.text.lastIndexOf('}');
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          final jsonString = message.text.substring(startIndex, endIndex + 1);
          final jsonMap = jsonDecode(jsonString);

          if (jsonMap['type'] == 'report') {
            final data = (jsonMap['data'] as Map?)?.cast<String, dynamic>() ??
                <String, dynamic>{};
            final petName = consultationPetName?.trim();
            if (petName != null && petName.isNotEmpty) {
              data['pet_name'] = petName;
            }
            messageContent = DiagnosticReportCard(data: data);
            isCustomCard = true;
          } else if (jsonMap['type'] == 'recommendation') {
            // ✅ 动态解析推荐数据
            final data = jsonMap['data'];
            final priceStr = data['price']?.toString() ?? "299.00";
            final price = double.tryParse(priceStr) ?? 299.00;

            messageContent = RecommendationCard(
              data: RecommendationData(
                reason: data['reason'] ?? "AI 智能推荐",
                productName: data['productName'] ?? "推荐商品",
                rating: data['rating'] ?? "5.0",
                safetyCheck: data['safetyCheck'] ?? "安全检核通过",
                reasoningSteps: List<String>.from(data['reasoningSteps'] ?? []),
                price: priceStr,
              ),
              onAdopt: () {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("正在为您自动加购..."),
                    duration: Duration(milliseconds: 800),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                Future.delayed(const Duration(milliseconds: 800), () {
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CartPage(
                        autoAddedItem: {
                          'name': data['productName'],
                          'price': price,
                          'quantity': 1,
                          'spec': '默认规格',
                        },
                      ),
                    ),
                  );
                });
              },
            );
            isCustomCard = true;
          } else {
            messageContent = MarkdownBody(
              data: message.text,
              selectable: true,
              styleSheet: markdownStyleSheet,
            );
          }
        } else {
          // JSON 结构不完整（例如正在流式传输中）
          if (!isResponseComplete) {
            // 尝试提取已生成的思考步骤
            List<String> steps = [];
            try {
              final stepsStartIndex = message.text.indexOf('"reasoningSteps"');
              if (stepsStartIndex != -1) {
                final arrayOpenIndex =
                    message.text.indexOf('[', stepsStartIndex);
                if (arrayOpenIndex != -1) {
                  // 截取数组开始后的内容
                  String content = message.text.substring(arrayOpenIndex + 1);

                  // 如果数组已经闭合，只取闭合前的内容
                  final arrayCloseIndex = content.indexOf(']');
                  if (arrayCloseIndex != -1) {
                    content = content.substring(0, arrayCloseIndex);
                  }

                  // 正则匹配：匹配完整字符串 "..." 或 未闭合的字符串 "..."
                  // 1. " 开启
                  // 2. ((?:[^"\\]|\\.)*) 内容：非引号或转义字符
                  // 3. (?:"|$) 结束：引号或字符串结尾
                  final matches =
                      RegExp(r'"((?:[^"\\]|\\.)*)(?:"|$)').allMatches(content);

                  for (final m in matches) {
                    if (m.group(1) != null) {
                      steps.add(m.group(1)!);
                    }
                  }
                }
              }
            } catch (e) {
              // Ignore parsing errors during streaming
            }

            messageContent = Container(
              margin: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(
                    left: BorderSide(color: Colors.grey.shade300, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Thinking...",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Monaco', // 尝试使用等宽字体增加极客感
                        ),
                      ),
                    ],
                  ),
                  if (steps.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...steps.map((step) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            step,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              height: 1.4,
                            ),
                          ),
                        )),
                  ],
                ],
              ),
            );
          } else {
            messageContent = MarkdownBody(
              data: message.text,
              selectable: true,
              styleSheet: markdownStyleSheet,
            );
          }
        }
      } catch (e) {
        // Fallback if JSON parsing fails
        if (!isResponseComplete) {
          messageContent = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF5D5FEF),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "正在生成决策方案...",
                style: TextStyle(
                  color: Color(0xFF5D5FEF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        } else {
          messageContent = MarkdownBody(
            data: message.text,
            selectable: true,
            styleSheet: markdownStyleSheet,
          );
        }
      }
    } else {
      // 流式阶段不走 Markdown/JSON 解析，直接展示纯文本以降低每帧开销
      if (isStreaming) {
        messageContent = SelectableText(
          renderText.isEmpty ? "思考中..." : renderText,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 16,
            height: 1.5,
          ),
        );
      } else {
        messageContent = MarkdownBody(
          data: renderText.isEmpty && !isUser ? "思考中..." : renderText,
          selectable: true,
          styleSheet: markdownStyleSheet,
        );
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6DD5FA), // Light Blue
                    Color(0xFF2980B9), // Deep Blue
                    Color(0xFFFF6B9D), // Pink
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pets, color: Colors.white, size: 20),
            ),
          if (!isUser) const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: isCustomCard
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 11.0,
                        ),
                  decoration: isCustomCard ? null : bubbleDecoration,
                  child: showLoadingIndicator
                      ? const _TypingIndicator()
                      : messageContent,
                ),
                if (!isUser && isResponseComplete && message.text.isNotEmpty)
                  _buildActionBar(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 4.0, right: 4.0),
      child: Wrap(
        spacing: 4.0,
        runSpacing: 4.0,
        children: [
          _buildActionButton(
            message.isLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
            onLikePressed,
            color: message.isLiked ? theme.primaryColor : null,
            tooltip: message.isLiked ? '取消点赞' : '点赞',
          ),
          _buildActionButton(
            CupertinoIcons.arrow_2_circlepath,
            onRegeneratePressed,
            tooltip: '重新生成',
          ),
          _buildActionButton(Icons.share_outlined, () {}, tooltip: '分享'),
          _buildActionButton(Icons.copy_outlined, onCopyPressed, tooltip: '复制'),
          _buildActionButton(
            Icons.more_horiz_outlined,
            onMoreOptionsPressed,
            tooltip: '更多选项',
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    VoidCallback onPressed, {
    Color? color,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20.0),
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Icon(icon, size: 20.0, color: color ?? Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}

// =======================================================================
// Kimi 风格精灵小球组件
// =======================================================================
class _KimiBall extends StatefulWidget {
  const _KimiBall();

  @override
  State<_KimiBall> createState() => _KimiBallState();
}

class _KimiBallState extends State<_KimiBall> with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _bounceController;
  late AnimationController _lookController;
  late AnimationController _breathController;
  Timer? _blinkTimer;
  Timer? _lookTimer;

  @override
  void initState() {
    super.initState();
    // 眨眼动画控制器
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // 点击跳动动画控制器
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    // 视线移动控制器
    _lookController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // 呼吸动画控制器
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _startBlinking();
    _startLooking();
  }

  void _startBlinking() {
    // 随机眨眼间隔 (2-6秒)
    _blinkTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        // 偶尔眨两次眼
        if (math.Random().nextBool()) {
          _blinkController.forward().then((_) {
            _blinkController.reverse().then((_) {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  _blinkController
                      .forward()
                      .then((_) => _blinkController.reverse());
                }
              });
            });
          });
        } else {
          _blinkController.forward().then((_) => _blinkController.reverse());
        }
      }
    });
  }

  void _startLooking() {
    // 随机看向右上角
    _lookTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_lookController.isAnimating && math.Random().nextBool()) {
        // 30% 概率看向右上角
        _lookController.forward().then((_) {
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) _lookController.reverse();
          });
        });
      }
    });
  }

  void _onTap() {
    if (!_bounceController.isAnimating) {
      HapticFeedback.mediumImpact();
      _bounceController.forward().then((_) => _bounceController.reverse());
      // 点击时也眨眼
      _blinkController.forward().then((_) => _blinkController.reverse());
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _bounceController.dispose();
    _lookController.dispose();
    _breathController.dispose();
    _blinkTimer?.cancel();
    _lookTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bounceController, _breathController]),
        builder: (context, child) {
          // 模拟果冻弹跳效果
          double bounceScale = 1.0;
          double translateY = 0.0;

          if (_bounceController.value <= 0.5) {
            // 下压阶段
            bounceScale = 1.0 - (_bounceController.value * 0.2);
            translateY = _bounceController.value * 10;
          } else {
            // 回弹阶段
            bounceScale = 0.9 + ((_bounceController.value - 0.5) * 0.2);
            translateY = (1.0 - _bounceController.value) * 10;
          }

          // 呼吸效果 (轻微缩放)
          double breathScale = 1.0 + (_breathController.value * 0.03);

          return Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(
              scale: bounceScale * breathScale,
              child: child,
            ),
          );
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4facfe), // 亮蓝
                Color(0xFF00f2fe), // 青蓝
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4facfe).withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 左眼
              Align(
                alignment: const Alignment(-0.35, -0.2),
                child: _buildEye(),
              ),
              // 右眼
              Align(
                alignment: const Alignment(0.35, -0.2),
                child: _buildEye(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEye() {
    return AnimatedBuilder(
      animation: Listenable.merge([_blinkController, _lookController]),
      builder: (context, child) {
        // 眨眼时高度变小
        final height = 10.0 * (1.0 - _blinkController.value);

        // 看向右上角逻辑 (x: +6, y: -4)
        final lookProgress = Curves.easeInOut.transform(_lookController.value);
        final lookOffset = Offset(4.0 * lookProgress, -3.0 * lookProgress);

        return Transform.translate(
          offset: lookOffset,
          child: Container(
            width: 6,
            height: height > 1.5 ? height : 1.5, // 最小高度1.5
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      },
    );
  }
}

// =======================================================================
// Agent 模式欢迎页 (带入场动画)
// =======================================================================
class _AgentWelcomeView extends StatefulWidget {
  const _AgentWelcomeView({super.key});

  @override
  State<_AgentWelcomeView> createState() => _AgentWelcomeViewState();
}

class _AgentWelcomeViewState extends State<_AgentWelcomeView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconOpacity;
  late Animation<Offset> _iconSlide;
  late Animation<double> _text1Opacity;
  late Animation<Offset> _text1Slide;
  late Animation<double> _text2Opacity;
  late Animation<Offset> _text2Slide;
  late Animation<double> _statusOpacity;
  late Animation<Offset> _statusSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    // Staggered animations
    _iconOpacity = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));
    _iconSlide = Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(
        CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));

    _text1Opacity = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut)));
    _text1Slide = Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(
        CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.6, curve: Curves.easeOut)));

    _text2Opacity = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOut)));
    _text2Slide = Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(
        CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.4, 0.8, curve: Curves.easeOut)));

    _statusOpacity = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut)));
    _statusSlide = Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(
        CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.6, 1.0, curve: Curves.easeOut)));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
                opacity: _iconOpacity,
                child: SlideTransition(
                    position: _iconSlide,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5D5FEF).withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.psychology,
                          color: Color(0xFF5D5FEF), size: 48),
                    ))),
            const SizedBox(height: 60),
            FadeTransition(
                opacity: _text1Opacity,
                child: SlideTransition(
                    position: _text1Slide,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF9CA3AF), Color(0xFF4B5563)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(bounds),
                      child: const Text(
                        "因为爱有时盲目",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          letterSpacing: 6,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ))),
            const SizedBox(height: 16),
            FadeTransition(
                opacity: _text2Opacity,
                child: SlideTransition(
                    position: _text2Slide,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF374151), Color(0xFF111827)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(bounds),
                      child: const Text(
                        "所以数据必须清醒",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 3,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ))),
            const SizedBox(height: 60),
            FadeTransition(
                opacity: _statusOpacity,
                child: SlideTransition(
                    position: _statusSlide,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome,
                              size: 16, color: Color(0xFF5D5FEF)),
                          const SizedBox(width: 8),
                          Text(
                            "Agent 模式已就绪，请描述您的需求",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ))),
          ],
        ),
      ),
    );
  }
}
