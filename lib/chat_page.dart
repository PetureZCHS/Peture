// lib/chat_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';
// ✅ 使用新的 Supabase Edge Function 服务
import 'services/supabase_edge_service.dart';
// ================== 所有必需的导入 ==================
import 'models/conversation.dart';
import 'database/database_helper.dart';
// ===============================================

// =======================================================================
// ChatMessage 类
// =======================================================================
class ChatMessage {
  final String text;
  final bool isUser;
  bool isLiked;
  bool isDisliked;
  // bool isFavorited; // ✅ 已注释：不再使用收藏功能

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isLiked = false,
    this.isDisliked = false,
    // this.isFavorited = false, // ✅ 已注释
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
  final String _userId = "flutter_test_user_123";
  bool _hasStartedChat = false;
  bool _isComposing = false;
  final Random _random = Random();
  List<String> _currentSuggestions = [];
  String? _conversationId;

  // 打字机效果相关
  String _currentTypingText = '';
  Timer? _typingTimer;
  final List<String> _pendingChunks = [];
  bool _isTyping = false;
  bool _shouldAutoScroll = true;
  bool _isStreamDone = false;
  bool _userScrolledUp = false;

  // ✅ 使用新的 Supabase Edge Function 服务
  final SupabaseEdgeFunctionService _edgeService = SupabaseEdgeFunctionService();

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

  @override
  void initState() {
    super.initState();
    _suggestionFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _updateSuggestions();
    _textController.addListener(_onTextChange);
  }

  void _onTextChange() {
    if (mounted) {
      final isComposing = _textController.text.isNotEmpty;
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
    _suggestionFadeController.dispose();
    // ✅ Edge Function 服务不需要 dispose
    super.dispose();
  }

  Future<void> _saveConversation(String question, String answer) async {
    if (question.trim().isEmpty ||
        answer.trim().isEmpty ||
        answer.startsWith("出现错误")) {
      return;
    }
    final conversation = Conversation(
      question: question,
      answer: answer,
      timestamp: DateTime.now(),
    );
    await DatabaseHelper.instance.insertConversation(conversation);
    debugPrint("对话已保存: Q: $question");
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _textController.clear();
      _hasStartedChat = false;
      _isLoading = false;
      _conversationId = null;
      _typingTimer?.cancel();
      _pendingChunks.clear();
      _isTyping = false;
      _currentTypingText = '';
      _updateSuggestions();
    });
    debugPrint("新对话已开始, conversationId 已清空。");
  }

  // 添加这个新方法来加载历史对话
  void _loadConversation(Conversation conversation) {
    setState(() {
      _messages.clear();
      _textController.clear();
      _hasStartedChat = true;
      _isLoading = false;
      _conversationId = null;
      _typingTimer?.cancel();
      _pendingChunks.clear();
      _isTyping = false;
      _currentTypingText = '';
      // 添加用户问题
      _messages.add(ChatMessage(text: conversation.question, isUser: true));
      // 添加AI回答
      _messages.add(ChatMessage(text: conversation.answer, isUser: false));
    });
    debugPrint("已加载历史对话: ${conversation.question}");
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
        });
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
        if (mounted) {
          setState(() {
            _currentTypingText += characters[index];
            if (_messages.isNotEmpty && !_messages.last.isUser) {
              final lastMessage = _messages.last;
              _messages[_messages.length - 1] = ChatMessage(
                text: _currentTypingText,
                isUser: false,
                isLiked: lastMessage.isLiked,
                isDisliked: lastMessage.isDisliked,
                // isFavorited: lastMessage.isFavorited, // ✅ 已移除
              );
            }
          });
          if (index % 10 == 0 || characters[index] == '\n') {
            _smoothScrollToEnd();
          }
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

  void _sendMessage({String? text}) {
    if (_isLoading) return;
    final messageText = (text ?? _textController.text).trim();
    if (messageText.isEmpty) return;
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
      _pendingChunks.clear();
      _isTyping = false;
      _shouldAutoScroll = true;
      _isStreamDone = false;
      _userScrolledUp = false;
    });

    _saveMessageToDatabase(messageText, true);
    _scrollToBottom();

    // ✅ 使用 Supabase Edge Function 服务
    final stream = _edgeService.callDifyChat(
      query: messageText,
      user: _userId,
      conversationId: _conversationId,
    );
    
    stream.listen((event) {
      if (!mounted) return;
      switch (event) {
        case ContentEvent():
          _startTypewriterEffect(event.content);
          break;
          
        case DoneEvent():
          _isStreamDone = true;
          // ✅ 从 DoneEvent 获取 conversation_id
          if (event.conversationId != null && event.conversationId != _conversationId) {
            setState(() {
              _conversationId = event.conversationId;
            });
            debugPrint("✅ Conversation ID 已更新: $_conversationId");
          }
          _saveConversation(messageText, _currentTypingText);
          if (_pendingChunks.isEmpty && !_isTyping) {
            setState(() => _isLoading = false);
          }
          break;
          
        case ErrorEvent():
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

    // ✅ 使用 Supabase Edge Function 服务
    final stream = _edgeService.callDifyChat(
      query: lastUserMessage.text,
      user: _userId,
      conversationId: _conversationId,
    );
    
    stream.listen((event) {
      if (!mounted) return;
      switch (event) {
        case ContentEvent():
          _startTypewriterEffect(event.content);
          break;
          
        case DoneEvent():
          _isStreamDone = true;
          _saveConversation(lastUserMessage.text, _currentTypingText);
          if (_pendingChunks.isEmpty && !_isTyping) {
            setState(() => _isLoading = false);
          }
          break;
          
        case ErrorEvent():
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
    if (message.isDisliked) {
      _showFeedbackBottomSheet();
    }
  }

  // ✅ 已移除 _onFavoritePressed 方法

  void _onCopyPressed(ChatMessage message) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: message.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("已复制到剪贴板"),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
            // ✅ 已移除“收藏”选项
          ],
        );
      },
    );
  }

  void _showFeedbackBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "请告诉我们您不满意的原因（可选）：",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  "内容不相关",
                  "有事实错误",
                  "存在有害信息",
                  "其他",
                ].map(_buildFeedbackChip).toList(),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("提交"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedbackChip(String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        debugPrint("Feedback received: $label");
        Navigator.pop(context);
      },
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade300),
      ),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      endDrawer: drawer,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final offsetAnimation =
                      Tween<Offset>(
                        begin: const Offset(0.0, 1.0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOutCubic,
                        ),
                      );
                  return SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  );
                },
                child: _hasStartedChat
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
                  "智能问诊",
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
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: _UIConstants.horizontalPadding,
      ),
      children: [
        const SizedBox(height: 20), // 增加一些顶部间距
        _buildStepper(),
        const SizedBox(height: 20),
        _buildWelcomeCard(),
      ],
    );
  }

  Widget _buildStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStep("主诉分析", CupertinoIcons.search, isActive: true),
        _buildStep("症状推理", CupertinoIcons.lightbulb),
        _buildStep("病历采集", CupertinoIcons.doc_text),
        _buildStep("报告生成", CupertinoIcons.graph_square),
      ],
    );
  }

  Widget _buildStep(String title, IconData icon, {bool isActive = false}) {
    final color = isActive
        ? Theme.of(context).primaryColor
        : Colors.grey.shade300;
    final iconColor = isActive ? Colors.white : Colors.grey.shade600;
    final textColor = isActive
        ? Theme.of(context).primaryColor
        : Colors.grey.shade500;
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(color: textColor, fontSize: 13)),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        // 使用与聊天页面背景色一致的颜色，确保动画过程中背景无缝衔接
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Hi, 您好 👋",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            "我是您的 AI 宠物医生\n欢迎来到我们 AI 宠物诊所，请问我今天有什么可以帮助这位可爱的小家伙～",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "你可以试着问我",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton.icon(
                onPressed: _updateSuggestions,
                icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 18),
                label: const Text("换一换"),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FadeTransition(
            opacity: _suggestionFadeController,
            child: Column(
              children: _currentSuggestions
                  .map((text) => _buildSuggestionItem(text))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(String text) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _sendMessage(text: text),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea({bool enabled = true}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: enabled,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                hintText: '请输入您宠物遇到的问题',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.normal,
                  fontSize: 16,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: enabled ? (value) => _sendMessage() : null,
              style: const TextStyle(color: Colors.black87, fontSize: 16),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: _isComposing
                ? Semantics(
                    button: true,
                    child: IconButton(
                      key: const ValueKey('send_button'),
                      icon: Icon(
                        Icons.send,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: enabled ? () => _sendMessage() : null,
                      tooltip: '发送',
                    ),
                  )
                : Semantics(
                    button: true,
                    child: IconButton(
                      key: const ValueKey('mic_button'),
                      icon: Icon(
                        CupertinoIcons.mic,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: enabled ? () {} : null,
                      tooltip: '语音输入（暂未实现）',
                    ),
                  ),
          ),
        ],
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
              final isLastMessageLoading =
                  _isLoading &&
                  index == _messages.length - 1 &&
                  message.text.isEmpty;
              final isLastMessage = index == _messages.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLastMessage ? 80.0 : 0),
                child: _MessageBubble(
                  message: message,
                  isLoading: isLastMessageLoading,
                  isResponseComplete: !_isLoading && !message.isUser,
                  onLikePressed: () => _onLikePressed(message),
                  onDislikePressed: () => _onDislikePressed(message),
                  onRegeneratePressed: _regenerateResponse,
                  onCopyPressed: () => _onCopyPressed(message),
                  // onFavoritePressed: () => _onFavoritePressed(message), // ✅ 已移除
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

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  void _loadConversations() {
    setState(() {
      _conversationsFuture = DatabaseHelper.instance.getAllConversations().then(
        (data) {
          data.sort((a, b) {
            if (a.isPinned && !b.isPinned) return -1;
            if (!a.isPinned && b.isPinned) return 1;
            return b.timestamp.compareTo(a.timestamp);
          });
          return data;
        },
      );
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
                onTap: () {
                  Navigator.pop(context);
                  final String shareContent =
                      "Q: ${conversation.question}\nA: ${conversation.answer}";
                  Share.share(shareContent);
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
    await DatabaseHelper.instance.updateConversation(updated);
    _loadConversations();
  }

  void _renameConversation(
    BuildContext context,
    Conversation conversation,
  ) async {
    final controller = TextEditingController(text: conversation.question);
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
                    question: controller.text,
                  );
                  await DatabaseHelper.instance.updateConversation(updated);
                  _loadConversations();
                }
                Navigator.pop(context);
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
          content: Text("删除后无法恢复：\n\"${conversation.question}\""),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () async {
                if (conversation.id != null) {
                  await DatabaseHelper.instance.deleteConversation(
                    conversation.id!,
                  );
                  _loadConversations();
                }
                Navigator.pop(context);
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
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
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
                          conversation.question,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.grey,
                            size: 20,
                          ),
                          onPressed: () =>
                              _showConversationOptions(context, conversation),
                        ),
                        onTap: () {
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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return ScaleTransition(
            scale: Tween<double>(begin: 0.4, end: 1.0).animate(
              CurvedAnimation(
                parent: _controller,
                curve: Interval(
                  0.1 + index * 0.2,
                  0.4 + index * 0.2,
                  curve: Curves.easeInOut,
                ),
              ),
            ),
            child: CircleAvatar(
              radius: 4,
              backgroundColor: Colors.grey.shade400,
            ),
          );
        }),
      ),
    );
  }
}

// =======================================================================
// 消息气泡组件（增强交互）
// =======================================================================
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isLoading;
  final bool isResponseComplete;
  final VoidCallback onLikePressed;
  final VoidCallback onDislikePressed;
  final VoidCallback onRegeneratePressed;
  final VoidCallback onCopyPressed;
  // final VoidCallback onFavoritePressed; // ✅ 已移除
  final VoidCallback onMoreOptionsPressed;

  const _MessageBubble({
    required this.message,
    this.isLoading = false,
    this.isResponseComplete = false,
    required this.onLikePressed,
    required this.onDislikePressed,
    required this.onRegeneratePressed,
    required this.onCopyPressed,
    // required this.onFavoritePressed, // ✅ 已移除
    required this.onMoreOptionsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);
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
    final showLoadingIndicator = isLoading && message.text.isEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 11.0,
                  ),
                  decoration: bubbleDecoration,
                  child: showLoadingIndicator
                      ? const _TypingIndicator()
                      : MarkdownBody(
                          data: message.text.isEmpty && !isUser
                              ? "思考中..."
                              : message.text,
                          selectable: true,
                          styleSheet: markdownStyleSheet,
                        ),
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
            message.isDisliked
                ? Icons.thumb_down_alt
                : Icons.thumb_down_alt_outlined,
            onDislikePressed,
            color: message.isDisliked ? theme.colorScheme.error : null,
            tooltip: message.isDisliked ? '取消点踩' : '点踩',
          ),
          _buildActionButton(
            CupertinoIcons.arrow_2_circlepath,
            onRegeneratePressed,
            tooltip: '重新生成',
          ),
          // ✅ 已移除收藏按钮（星星图标）
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
