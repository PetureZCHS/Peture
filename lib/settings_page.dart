import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math'; // 用于生成随机角度
import 'package:confetti/confetti.dart'; // 必须导入 confetti 包
import 'package:supabase_flutter/supabase_flutter.dart';

// 添加数据迁移页面导入
import 'pages/data_migration_page.dart';
import 'pages/invitation_code_page.dart';
import 'pages/my_invitation_code_page.dart';
import 'login_page.dart';

// ==========================================
// 1. 主设置页面框架 (SettingsPage)
// ==========================================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 假设 _AppSettingsState 中有这些变量，为了独立运行，这里直接取值
    // 您实际代码中保留原来的即可
    const Color backgroundColor = Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor.withOpacity(0.8),
        elevation: 0,
        centerTitle: true,
        title: const Text('设置',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const AppSettings(),
    );
  }
}

// ==========================================
// 2. 设置列表内容 (AppSettings)
// ==========================================
class AppSettings extends StatefulWidget {
  const AppSettings({super.key});

  @override
  State<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings> {
  bool _notificationsEnabled = true;

  // --- 样式常量 ---
  static const Color _cardColor = Colors.white;
  static const Color _iconBlue = Color(0xFF0A84FF);
  static const Color _logoutButtonTextColor = Color(0xFFE53935);
  static const Color _logoutButtonBackgroundColor = Color(0xFFFFEBEE);

  static const TextStyle _sectionTitleStyle = TextStyle(
    color: Color(0xFF6D6D72),
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle _tileTitleStyle = TextStyle(
    fontSize: 17,
    color: Colors.black,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle _tileSubtitleStyle = TextStyle(
    fontSize: 15,
    color: Color(0xFF8A8A8E),
    fontWeight: FontWeight.w400,
  );

  static const TextStyle _logoutTextStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        const SizedBox(height: 16),

        // ==============================================
        // [入口] 高级会员订阅入口
        // ==============================================
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (context) => const SubscriptionPage(),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5DD3), Color(0xFF8B80F8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5DD3).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.diamond_outlined,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "升级到 Pro 版",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "解锁无限AI问诊与多宠物档案",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),

        // ==============================================
        // [入口] 我的邀请码（仅对 739319163@qq.com 开放）
        // ==============================================
        GestureDetector(
          onTap: () async {
            final email = Supabase.instance.client.auth.currentUser?.email?.trim().toLowerCase() ?? '';
            if (email == '739319163@qq.com') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const MyInvitationCodePage()),
              );
            } else {
              if (!context.mounted) return;
              showDialog(
                context: context,
                builder: (ctx) => _WarmTipDialog(message: '该功能暂未对小主们开放'),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB6C1), Color(0xFFF8C4CC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB6C1).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "我的邀请码",
                        style: TextStyle(color: Color(0xFF8B4545), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "一人一码，分享好友兑换终身会员",
                        style: TextStyle(color: Color(0xFFB85C5C), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Color(0xFFB85C5C), size: 16),
              ],
            ),
          ),
        ),

        // ==============================================
        // [入口] 输入邀请码（兑换终身会员）
        // ==============================================
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const InvitationCodePage()),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFFF8C4CC), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB6C1).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFE8919E), size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "输入邀请码",
                        style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "兑换终身会员权益",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
              ],
            ),
          ),
        ),

        // === 账户区域 ===
        _buildSectionTitle('账户'),
        _buildSettingsCard(
          children: [
            _buildSettingsTile(
              icon: Icons.person_outline,
              iconColor: _iconBlue,
              title: '编辑个人资料',
              onTap: () {
                // Navigator.push...
              },
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.lock_outline,
              iconColor: _iconBlue,
              title: '修改密码',
              onTap: () {
                // Navigator.push...
              },
            ),
          ],
        ),

        // === 通用区域 ===
        _buildSectionTitle('通用'),
        _buildSettingsCard(
          children: [
            _buildSettingsTile(
              icon: Icons.notifications_none_outlined,
              iconColor: _iconBlue,
              title: '通知设置',
              onTap: null,
              trailing: CupertinoSwitch(
                value: _notificationsEnabled,
                onChanged: (bool value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                },
                activeColor: _iconBlue,
              ),
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.palette_outlined,
              iconColor: _iconBlue,
              title: '外观',
              subtitle: '跟随系统',
              onTap: () async {
                // Navigator.push...
              },
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.cloud_upload_outlined,
              iconColor: _iconBlue,
              title: '数据迁移',
              subtitle: '迁移数据到 Supabase 云端',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DataMigrationPage(),
                  ),
                );
              },
            ),
          ],
        ),

        // === 退出登录按钮 ===
        const SizedBox(height: 32),
        _buildLogoutButton(context),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- 辅助构建方法 ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Text(title, style: _sectionTitleStyle),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 64.0),
      child: Divider(height: 0.5, thickness: 0.5, color: Color(0xFFDCDCDC)),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return TextButton(
      onPressed: () => _signOut(context),
      style: TextButton.styleFrom(
        backgroundColor: _logoutButtonBackgroundColor,
        foregroundColor: _logoutButtonTextColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('退出登录', style: _logoutTextStyle),
    );
  }

  /// 退出登录
  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('您确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final supabase = Supabase.instance.client;
        await supabase.auth.signOut();

        if (context.mounted) {
          // 返回登录页面并清除所有路由栈
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('退出失败: $e')),
          );
        }
      }
    }
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: _cardColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: _tileTitleStyle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: _tileSubtitleStyle),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing
              else if (onTap != null)
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFFC7C7CC),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 温馨提示弹窗（画风与 invitation_banner 一致）
// ==========================================
class _WarmTipDialog extends StatelessWidget {
  final String message;

  const _WarmTipDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    const pinkDark = Color(0xFFE8919E);
    const yellow = Color(0xFFFFF8E7);
    const pinkBorder = Color(0xFFF8C4CC);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        decoration: BoxDecoration(
          color: yellow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: pinkBorder, width: 2),
          boxShadow: [
            BoxShadow(
              color: pinkDark.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded, size: 48, color: pinkDark),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: 16, color: Color(0xFF8B4545), height: 1.4), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pinkDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('好的'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. [包含礼花动画] 订阅页面 (SubscriptionPage)
// ==========================================
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  // 0 = 年度, 1 = 月度
  int _selectedPlanIndex = 0;
  bool _isLoading = false; // 控制支付中的加载状态

  // 礼花控制器
  late ConfettiController _confettiController;

  // 品牌色
  final Color brandColor = const Color(0xFF6C5DD3);
  final Color brandLightColor = const Color(0xFF6C5DD3).withOpacity(0.1);

  @override
  void initState() {
    super.initState();
    // 初始化礼花控制器，设置持续时间
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  // --- 模拟支付成功逻辑 ---
  Future<void> _handlePurchase() async {
    setState(() {
      _isLoading = true; // 开始加载
    });
    final supabase = Supabase.instance.client;
    final res =
        await supabase.functions.invoke('recharge-test', body: {'amount': 1});
    final data = res.data;
    // 1. 模拟网络请求延迟 (2秒)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _isLoading = false; // 结束加载
    });

    // 2. 播放礼花
    _confettiController.play();

    // 3. 显示成功弹窗
    showDialog(
      context: context,
      barrierDismissible: false, // 必须点击按钮才能关闭
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 动态缩放的成功图标
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.green, size: 40),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  "订阅成功！",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "您已成功解锁所有 Pro 功能。\n开始您的智能养宠之旅吧！",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // 关弹窗
                      // 安全检查，确保页面栈不为空再执行pop
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop(); // 关订阅页，回设置页
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("太棒了",
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 使用 Stack 确保礼花层 (ConfettiWidget) 在最上面
      body: Stack(
        alignment: Alignment.topCenter, // 礼花从顶部发射
        children: [
          // ---------------------------------------------------------
          // 1. 页面主要内容
          // ---------------------------------------------------------
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                      bottom: 120 + MediaQuery.of(context).padding.bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderImage(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              "解锁 AI 潜能\n让养宠变得前所未有的简单",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildFeatureItem("每日无限次 AI 医疗深度问诊"),
                            _buildFeatureItem("无限次一键生成 AI 宠物日记"),
                            _buildFeatureItem("定制专属生骨肉/鲜食营养方案"),
                            _buildFeatureItem("多个宠物档案管理、数据导出"),
                            _buildFeatureItem("云端无限同步，珍贵回忆不丢失"),
                            const SizedBox(height: 40),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPlanCard(
                                    index: 0,
                                    title: "每年",
                                    price: "¥16.5/月",
                                    subPrice: "按 ¥198/年 计费",
                                    badgeText: "省 76%",
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildPlanCard(
                                    index: 1,
                                    title: "每月",
                                    price: "¥28.0/月",
                                    subPrice: "按月灵活计费",
                                    badgeText: null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ---------------------------------------------------------
          // 2. 顶部关闭按钮
          // ---------------------------------------------------------
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),

          // ---------------------------------------------------------
          // 3. 底部悬浮按钮 (支付入口)
          // ---------------------------------------------------------
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    offset: const Offset(0, -4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handlePurchase, // 加载时禁用
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "立即开启 Pro",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      "恢复购买",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---------------------------------------------------------
          // 4. 礼花层 (Confetti Widget) - 放在 Stack 最上层
          // ---------------------------------------------------------
          // 放在这里，确保它能覆盖在页面所有内容之上
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2, // 向下发射 (pi/2)
              maxBlastForce: 5, // 最大速度
              minBlastForce: 2, // 最小速度
              emissionFrequency: 0.05, // 发射频率
              numberOfParticles: 20, // 粒子数量
              gravity: 0.1, // 重力
              colors: const [
                Color(0xFF6C5DD3), // 品牌紫
                Color(0xFFFFCF5C), // 品牌黄
                Colors.blue,
                Colors.pink,
                Colors.green,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 辅助组件保持不变 ---

  Widget _buildHeaderImage() {
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1548199973-03cce0bbc87b?auto=format&fit=crop&w=1400&q=80',
            fit: BoxFit.cover,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.0),
                  Colors.white.withOpacity(0.8),
                  Colors.white,
                ],
                stops: const [0.0, 0.6, 0.85, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: brandColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 12),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required int index,
    required String title,
    required String price,
    required String subPrice,
    String? badgeText,
  }) {
    final bool isSelected = _selectedPlanIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanIndex = index;
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected ? brandLightColor : Colors.white,
              border: Border.all(
                color: isSelected ? brandColor : Colors.grey.shade300,
                width: isSelected ? 2 : 1.5,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isSelected ? brandColor : Colors.black87,
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected ? brandColor : Colors.grey.shade400,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subPrice,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (badgeText != null)
            Positioned(
              top: -12,
              left: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B61FF),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    topRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7B61FF).withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
