import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math';
import 'dart:ui';
import 'package:confetti/confetti.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../invitation/presentation/invitation_code_page.dart';
import '../../invitation/presentation/my_invitation_code_page.dart';
import '../../auth/presentation/login_page.dart';
import 'account_settings_page.dart';
import 'change_password_page.dart';
import '../../../shared/utils/ui_helpers.dart';

// ==========================================
// 1. 主设置页面框架 (SettingsPage)
// ==========================================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.background.withOpacity(0.85),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
          ).createShader(bounds),
          child: const Text(
            '设置',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 8,
                  color: Color(0x405A8EFA),
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1D1D1F),
              size: 18,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
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

class _AppSettingsState extends State<AppSettings>
    with SingleTickerProviderStateMixin {
  bool _notificationsEnabled = true;
  late AnimationController _shimmerController;

  // --- 样式常量 ---
  static const Color _logoutButtonTextColor = Color(0xFFE53935);

  // 图标渐变配置
  static const List<LinearGradient> _iconGradients = [
    LinearGradient(
      colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFFEC407A), Color(0xFFAB47BC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight - 20;
    return ListView(
      padding: EdgeInsets.only(left: 20.0, right: 20.0, top: topPadding),
      children: [

        // ==============================================
        // [入口] 高级会员订阅入口
        // ==============================================
        _buildSubscriptionCard(),

        const SizedBox(height: 16),

        // ==============================================
        // [入口] 我的邀请码（仅对 739319163@qq.com 开放）
        // ==============================================
        _buildMyInvitationCard(),

        const SizedBox(height: 12),

        // ==============================================
        // [入口] 输入邀请码（兑换终身会员）
        // ==============================================
        _buildEnterInvitationCard(),

        // === 账户区域 ===
        _buildSectionHeader('账户', Icons.person_outline),
        _buildGlassCard(
          children: [
            _buildPremiumSettingsTile(
              icon: Icons.person_outline,
              gradientIndex: 0,
              title: '编辑个人资料',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AccountSettingsPage(),
                  ),
                );
              },
            ),
            _buildPremiumDivider(),
            _buildPremiumSettingsTile(
              icon: Icons.lock_outline,
              gradientIndex: 0,
              title: '修改密码',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ChangePasswordPage(),
                  ),
                );
              },
            ),
          ],
        ),

        // === 通用区域 ===
        _buildSectionHeader('通用', Icons.settings_outlined),
        _buildGlassCard(
          children: [
            _buildPremiumSettingsTile(
              icon: Icons.notifications_none_outlined,
              gradientIndex: 1,
              title: '通知设置',
              onTap: null,
              trailing: _buildCustomSwitch(
                value: _notificationsEnabled,
                onChanged: (bool value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                },
              ),
            ),
            _buildPremiumDivider(),
            _buildPremiumSettingsTile(
              icon: Icons.palette_outlined,
              gradientIndex: 2,
              title: '外观',
              subtitle: '跟随系统',
              onTap: () async {
                // Navigator.push...
              },
            ),
          ],
        ),

        // === 退出登录按钮 ===
        const SizedBox(height: 40),
        _buildPremiumLogoutButton(context),
        const SizedBox(height: 48),
      ],
    );
  }

  // ==========================================
  // 订阅卡片 - 带闪光动画效果
  // ==========================================
  Widget _buildSubscriptionCard() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => const SubscriptionPage(),
          ),
        );
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 100),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5A8EFA).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // 装饰性圆形
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -40,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              // 闪光动画层
              AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, child) {
                  return Positioned.fill(
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        final gradient = LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.08),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          transform: _SlideGradientTransform(
                            percent: _shimmerController.value,
                          ),
                        );
                        return gradient.createShader(bounds);
                      },
                      blendMode: BlendMode.srcATop,
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  );
                },
              ),
              // 内容
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.2),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.diamond_rounded,
                        color: Colors.white,
                        size: 28,
                        shadows: [
                          Shadow(
                            color: Color(0x40000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "升级到 Pro 版",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                  color: Color(0x66000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "解锁无限 AI 问诊与多宠物档案",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xD9FFFFFF),
                              fontSize: MediaQuery.of(context).size.width < 380 ? 11.5 : 13,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  color: Color(0x66000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          shadows: [
                            Shadow(
                              color: Color(0x66000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 我的邀请码卡片 - 玻璃拟态风格
  // ==========================================
  Widget _buildMyInvitationCard() {
    return GestureDetector(
      onTap: () async {
        final email = Supabase.instance.client.auth.currentUser?.email
                ?.trim()
                .toLowerCase() ??
            '';
        if (email == '739319163@qq.com') {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (context) => const MyInvitationCodePage()),
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFFF8E1).withOpacity(0.7),
              const Color(0xFFFFECB3).withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFFFFB300).withOpacity(0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB300).withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB300).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "我的邀请码",
                          style: TextStyle(
                            color: Color(0xFF8B6914),
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "一人一码，分享好友兑换终身会员",
                          style: TextStyle(
                            color: Color(0xFFB8860B),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF8B6914),
                      size: 14,
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

  // ==========================================
  // 输入邀请码卡片 - 玻璃拟态风格
  // ==========================================
  Widget _buildEnterInvitationCard() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (context) => const InvitationCodePage()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              const Color(0xFFE3F2FD).withOpacity(0.7),
              const Color(0xFFBBDEFB).withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFF5A8EFA).withOpacity(0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5A8EFA).withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5A8EFA).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.keyboard_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "输入邀请码",
                          style: TextStyle(
                            color: Color(0xFF1D1D1F),
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "兑换终身会员权益",
                          style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A8EFA).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF5A8EFA),
                      size: 14,
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

  // ==========================================
  // 玻璃拟态卡片容器
  // ==========================================
  Widget _buildGlassCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.65),
            Colors.white.withOpacity(0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
            ),
            child: Column(children: children),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 高级设置项 - 带渐变图标
  // ==========================================
  Widget _buildPremiumSettingsTile({
    required IconData icon,
    required int gradientIndex,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xFF5A8EFA).withOpacity(0.1),
        highlightColor: const Color(0xFF5A8EFA).withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              // 渐变图标容器
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: _iconGradients[gradientIndex % _iconGradients.length],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _getGradientColor(gradientIndex).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF1D1D1F),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing
              else if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: const Color(0xFF8E8E93).withOpacity(0.4),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getGradientColor(int index) {
    switch (index % 4) {
      case 0:
        return const Color(0xFF5A8EFA);
      case 1:
        return const Color(0xFF43E97B);
      case 2:
        return const Color(0xFFFFA726);
      case 3:
        return const Color(0xFFEC407A);
      default:
        return const Color(0xFF5A8EFA);
    }
  }

  // ==========================================
  // 自定义开关 - 使用主题色
  // ==========================================
  Widget _buildCustomSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF5A8EFA),
        trackColor: Colors.grey.withOpacity(0.3),
      ),
    );
  }

  // ==========================================
  // 分隔线
  // ==========================================
  Widget _buildPremiumDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 70.0),
      child: Container(
        height: 0.5,
        color: Colors.grey.withOpacity(0.1),
      ),
    );
  }

  // ==========================================
  // 区域标题 - 带图标和装饰
  // ==========================================
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4.0, 28.0, 4.0, 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF5A8EFA),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF5A8EFA).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 高级退出登录按钮 - 玻璃拟态胶囊
  // ==========================================
  Widget _buildPremiumLogoutButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _signOut(context),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.5),
              Colors.white.withOpacity(0.4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: _logoutButtonTextColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _logoutButtonTextColor.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    color: _logoutButtonTextColor.withOpacity(0.9),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '退出登录',
                    style: TextStyle(
                      color: _logoutButtonTextColor.withOpacity(0.9),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
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

  /// 退出登录
  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFE53935)),
            SizedBox(width: 10),
            Text('确认退出'),
          ],
        ),
        content: const Text('您确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
}

// ==========================================
// 闪光动画变换器
// ==========================================
class _SlideGradientTransform extends GradientTransform {
  final double percent;

  const _SlideGradientTransform({required this.percent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * 2 * (percent - 0.5),
      0,
      0,
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
            Text(message,
                style: const TextStyle(
                    fontSize: 16, color: Color(0xFF8B4545), height: 1.4),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pinkDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
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
  bool _isLoading = false;

  // 礼花控制器
  late ConfettiController _confettiController;

  // 品牌色
  final Color brandColor = const Color(0xFF6C5DD3);
  final Color brandLightColor = const Color(0xFF6C5DD3).withOpacity(0.1);

  @override
  void initState() {
    super.initState();
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
      _isLoading = true;
    });
    final supabase = Supabase.instance.client;
    await supabase.functions.invoke('recharge-test', body: {'amount': 1});
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    _confettiController.play();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                      Navigator.of(context).pop();
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
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
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
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
                      onPressed: _isLoading ? null : _handlePurchase,
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
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              colors: const [
                Color(0xFF6C5DD3),
                Color(0xFFFFCF5C),
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