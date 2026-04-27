import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';
// ✅ 使用新的 Supabase Dify 服务
import '../../../services/supabase_edge_service.dart';
import '../../../services/supabase_service.dart'; 
import '../../../shared/models/pet.dart'; 
// ================== 所有必需的导入 ==================
import '../../../shared/models/conversation.dart';
import '../../../shared/utils/ui_helpers.dart';
import '../../../shared/widgets/diagnostic_report_card.dart';
import '../../../shared/widgets/recommendation_card.dart'; 
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
  final String _userId = "flutter_test_user_123";
  bool _hasStartedChat = false;
  bool _isComposing = false;
  final math.Random _random = math.Random();
  List<String> _currentSuggestions = [];
  String? _conversationId; // Dify 的 conversation_id
  String? _supabaseConversationId; // Supabase 的 conversation ID

  // 打字机效果相关
  String _currentTypingText = '';
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

  // ✅ 使用新的 Supabase Edge Function 服务
  final SupabaseEdgeFunctionService _difyService =
      SupabaseEdgeFunctionService();
  final SupabaseService _supabaseService = SupabaseService();
  static const String _agentSystemPrompt = """
# System Prompt for Peture AI (Agent Mode)

## Role
你现在是 Peture AI 的高级智能购物决策 Agent。你的核心能力不仅仅是推荐，而是像一位经验丰富的采购专家一样，通过多维度的数据分析，为用户做出最优的购买决策。

## Workflow (思考与执行流程)
在生成推荐之前，你必须在后台模拟执行以下复杂的决策逻辑，并在 `reasoningSteps` 中体现出来：

1.  **用户意图深度解析**：分析用户的显性需求（如“性价比高”）和隐性需求（如“长期健康”、“适口性”）。
2.  **宠物档案调阅 (Simulated)**：假装你正在读取用户的云端宠物健康档案。
    *   *Action*: "正在读取 '旺财' 的健康档案... 发现历史过敏源：鸡肉..."
    *   *Action*: "分析最近一次体检报告... 关注指标：体重偏胖，需低脂..."
3.  **全网比价与库存检索 (Simulated)**：假装你正在实时连接淘宝、京东、亚马逊的 API 进行比价。
    *   *Action*: "正在检索京东自营库存... 状态：有货"
    *   *Action*: "对比淘宝旗舰店价格... 发现优惠券..."
    *   *Action*: "扫描全网历史价格波动... 当前为近 90 天低价..."
4.  **成分与安全审计**：对候选商品进行成分分析。
    *   *Action*: "正在比对 FDA 召回数据库... 安全无记录"
    *   *Action*: "分析配料表前五位... 蛋白质含量 > 30%..."
5.  **最终决策锁定**：综合以上信息，选出唯一最优解。

## Constraints (核心规则)
1.  **专业性**：用词要精确、专业。使用“检索中”、“审计通过”、“加权评分”等术语。
2.  **决策优先**：不要给模棱两可的选项，直接给出“最佳选择”。
3.  **思考过程可视化**：在 JSON 的 `reasoningSteps` 字段中，必须包含 6-10 个详细的步骤，展示你从“读取档案”到“全网比价”再到“安全审计”的全过程。

## Output Format (输出格式)
这是一个状态机逻辑：

**状态 A：需求确认中**
如果用户需求不明确，进行简短追问。
示例："请问狗狗多大了？平时吃什么牌子的粮？"

**状态 B：生成推荐**
当你锁定推荐商品时，**必须** 输出以下 JSON 格式的数据块。
**重要**：请确保 JSON 格式合法，不要使用 Markdown 代码块包裹，直接输出 JSON 字符串即可。

{
  "type": "recommendation",
  "data": {
    "reason": "综合全网比价与成分分析，这款粮在同价位中蛋白质含量最高，且完美避开您宠物的过敏源。",
    "productName": "这里填写完整的商品名称",
    "price": "299.00",
    "rating": "4.9",
    "safetyCheck": "FDA/AAFCO 双重认证通过",
    "reasoningSteps": [
      "正在解析用户需求：目标为【高性价比】且【适合金毛】...",
      "正在调阅宠物档案... 识别对象：7岁金毛，体重30kg，需关注关节健康...",
      "正在连接京东/淘宝数据库进行全网比价...",
      "已过滤掉 12 款溢价过高的进口品牌...",
      "正在进行成分安全审计... 排除 3 款含诱食剂产品...",
      "检测到目标商品在京东自营有【限时 8.8 折】优惠...",
      "最终决策：锁定性价比最高的【伯纳天纯/网易严选/或其他真实品牌】..."
    ]
  }
}
""";

  static const String _systemPrompt = """
# System Prompt for Peture AI (Doctor Mode)

## Role
你现在是 Peture AI 的首席兽医专家。你的目标是通过多轮对话，收集患病宠物的详细信息，并最终给出一份结构化的诊断报告。

## Constraints (核心规则)
1. **循序渐进**：用户第一次描述病情时，**绝对不要**直接给结论。
2. **单步追问**：每次回复 **只问 1 个** 最需要厘清的问题（例如：先问频率，再问颜色，最后问精神状态）。禁止一次性抛出多个问题。
3. **语气风格**：温暖、治愈、专业。使用中文。
4. **决策时刻**：当你收集了足够的信息（通常在 3-5 轮对话后），或者发现情况危急（如呼吸困难、吞食异物），请立即停止追问，生成诊断单。

## Output Format (输出格式)
这是一个状态机逻辑：

**状态 A：问诊中**
直接输出纯文本对话。
示例："哎呀，听起来宝宝很难受。请问它最后一次进食是什么时候？"

**状态 B：生成诊断**
当你决定结束问诊时，**仅输出** 以下 JSON 格式的数据，不要包含 Markdown 标记或其他废话：

{
  "type": "report",
  "data": {
    "diagnosis": "这里填写初步判断，如：急性肠胃炎",
    "urgency_level": 3,  // 1-5的整数，5最紧急
    "urgency_color": "yellow", // green/yellow/red
    "possible_causes": ["这里填写原因1", "这里填写原因2"],
    "advice_summary": "这里填写简短的行动建议，如：禁食禁水12小时，观察..."
  }
}
""";
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

  Future<void> _sendMessage({String? text}) async {
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

    // ✅ 使用 Supabase Dify 服务
    String queryToSend = messageText;

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

      // 将宠物信息拼接到 Prompt 中 (作为上下文)
      // 注意：如果是第一条消息，我们会下面统一组合 System Prompt
      // 如果不是第一条，我们直接附带在 User Message 后
      if (_conversationId != null) {
        queryToSend += petInfoBuffer.toString();
        debugPrint("📎 已向现有对话注入宠物信息");
      } else {
        // 如果是新对话，我们将 petInfoBuffer 暂存，拼接到 SystemPrompt 后面
        // 下面的 _isDoctorMode 判断逻辑会处理
      }

      // Hack: 无论是否新对话，都追加到 messageText 后面给 AI 看，或者是追加到 System Prompt?
      // Dify通常接收 query。
      // 为了确保 AI 既然看到 System Prompt 也能看到这个 Context，我们把它放在 query 里。
      // 但是如果在 System Prompt 里放会更稳定。

      // 策略：直接追加到 User Query 后面。
      queryToSend += petInfoBuffer.toString();
    }

    if (_conversationId == null) {
      if (_isAgentMode) {
        // Agent 模式：注入购物决策 Prompt
        // 注意：如果在 Agent 模式下选了宠物，也会带上宠物信息
        queryToSend =
            "$_agentSystemPrompt\n\n用户问题：$queryToSend"; // queryToSend 已经包含了宠物信息
        debugPrint("🧠 已注入系统提示词 (Agent Mode)");
      } else if (_isDoctorMode) {
        // 医生模式：注入问诊 Prompt
        queryToSend = "$_systemPrompt\n\n用户问题：$queryToSend";
        debugPrint("💉 已注入系统提示词 (Doctor Mode)");
      }
    }

    final stream = _difyService.callDifyChat(
      query: messageText,
      user: _userId,
      conversationId: _conversationId,
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
                  isActive: false,
                  onTap: () {}, // 占位功能
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
                  onPressed: enabled ? () {} : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
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
                          onPressed: enabled ? () {} : null,
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
  final VoidCallback onMoreOptionsPressed;

  const _MessageBubble({
    required this.message,
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
        (message.text.trimLeft().startsWith('{') ||
            message.text.contains('"type": "recommendation"') ||
            message.text.contains('"type": "report"'));

    if (isProtocolMessage) {
      try {
        // Find the JSON part if there is any text before/after
        final startIndex = message.text.indexOf('{');
        final endIndex = message.text.lastIndexOf('}');
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          final jsonString = message.text.substring(startIndex, endIndex + 1);
          final jsonMap = jsonDecode(jsonString);

          if (jsonMap['type'] == 'report') {
            messageContent = DiagnosticReportCard(data: jsonMap['data']);
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
      messageContent = MarkdownBody(
        data: message.text.isEmpty && !isUser ? "思考中..." : message.text,
        selectable: true,
        styleSheet: markdownStyleSheet,
      );
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
