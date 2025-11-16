import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

// 假设您有这些文件
import 'settings/about.dart';
import 'settings/theme.dart';
import 'utils/snackbar_utils.dart';
import 'login_page.dart'; // 导入登录页面
import 'account_settings_page.dart'; // 导入账户设置页面

// --- 主页面框架 ---
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 采用与内容一致的背景色，使过渡更自然
    return Scaffold(
      backgroundColor: _AppSettingsState._backgroundColor,
      appBar: AppBar(
        // iOS 风格的半透明 AppBar 背景
        backgroundColor: _AppSettingsState._backgroundColor.withOpacity(0.8),
        elevation: 0,
        centerTitle: true,
        title: const Text('设置', style: _AppSettingsState._appBarTextStyle),
        // 自定义返回按钮以匹配 iOS 风格
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

// --- 设置项内容 ---
class AppSettings extends StatefulWidget {
  const AppSettings({super.key});

  @override
  State<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings> {
  bool _notificationsEnabled = true;

  // --- 样式常量，便于统一管理和修改 ---
  static const Color _backgroundColor = Color(0xFFF2F2F7);
  static const Color _cardColor = Colors.white;
  static const Color _iconBlue = Color(0xFF0A84FF);
  static const Color _iconStar = Color(0xFFFFCC00); // 星星使用黄色
  static const Color _iconInfo = Color(0xFF5856D6); // 关于使用紫色
  static const Color _logoutButtonTextColor = Color(0xFFE53935); // 更鲜明的红色
  static const Color _logoutButtonBackgroundColor = Color(0xFFFFEBEE);

  static const TextStyle _appBarTextStyle = TextStyle(
    color: Colors.black,
    fontSize: 17,
    fontWeight: FontWeight.w600, // Semi-bold for iOS titles
  );

  static const TextStyle _sectionTitleStyle = TextStyle(
    color: Color(0xFF6D6D72), // iOS 系统灰色
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
    color: Color(0xFF8A8A8E), // iOS 系统副标题灰色
    fontWeight: FontWeight.w400,
  );

  static const TextStyle _logoutTextStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500, // Medium weight for emphasis
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        const SizedBox(height: 16), // 顶部留出更多空间
        // === 账户区域 ===
        _buildSectionTitle('账户'),
        _buildSettingsCard(
          children: [
            _buildSettingsTile(
              icon: Icons.person_outline,
              iconColor: _iconBlue,
              title: '编辑个人资料',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccountSettingsPage(),
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.lock_outline,
              iconColor: _iconBlue,
              title: '修改密码',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccountSettingsPage(),
                  ),
                );
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
              onTap: null, // 开关本身是可交互的，行不再响应点击
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
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Themes()),
                );
              },
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.language_outlined,
              iconColor: _iconBlue,
              title: '语言',
              subtitle: '中文',
              onTap: () => SnackbarUtils.showSnackBar(context, '建设中'),
            ),
          ],
        ),

        // === 关于区域 ===
        _buildSectionTitle('关于'),
        _buildSettingsCard(
          children: [
            _buildSettingsTile(
              icon: Icons.star_border,
              iconColor: _iconStar,
              title: '给个好评',
              onTap: () => SnackbarUtils.showSnackBar(context, '建设中'),
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.info_outline,
              iconColor: _iconInfo,
              title: '关于我们',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const About()),
                );
              },
            ),
          ],
        ),

        // === 退出登录按钮 ===
        const SizedBox(height: 32),
        _buildLogoutButton(context),
        const SizedBox(height: 20),
      ],
    );
  }

  // --- 辅助构建方法 ---

  /// 构建灰色的区域标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Text(title, style: _sectionTitleStyle),
    );
  }

  /// 构建白色圆角卡片容器
  Widget _buildSettingsCard({required List<Widget> children}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(children: children),
    );
  }

  /// 构建卡片内部分隔线 (带左边距)
  Widget _buildDivider() {
    // 16 (边距) + 32 (图标容器) + 16 (间隙) = 64
    return const Padding(
      padding: EdgeInsets.only(left: 64.0),
      child: Divider(height: 0.5, thickness: 0.5, color: Color(0xFFDCDCDC)),
    );
  }

  /// 构建退出登录按钮
  Widget _buildLogoutButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        _showLogoutConfirmDialog(context);
      },
      style: TextButton.styleFrom(
        backgroundColor: _logoutButtonBackgroundColor,
        foregroundColor: _logoutButtonTextColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('退出登录', style: _logoutTextStyle),
    );
  }

  /// 显示退出登录确认对话框
  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认退出'),
          content: const Text('您确定要退出登录吗？'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 关闭对话框
                _performLogout(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: _logoutButtonTextColor,
              ),
              child: const Text('退出'),
            ),
          ],
        );
      },
    );
  }

  /// 执行退出登录操作
  void _performLogout(BuildContext context) {
    // TODO: 这里可以添加清除用户数据的逻辑，比如：
    // - 清除本地存储的用户信息
    // - 清除认证令牌
    // - 清除缓存数据等

    // 导航到登录页面并清除所有之前的路由栈
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false, // 清除所有之前的路由
    );
  }

  /// 构建每一行的设置项
  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback? onTap,
  }) {
    // 使用 Material 和 InkWell 来实现点击效果
    return Material(
      color: _cardColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // --- 左侧图标 ---
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor, // 直接使用主题色作为背景
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),

              // --- 中间标题和副标题 ---
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

              // --- 右侧控件 (箭头或开关) ---
              if (trailing != null)
                trailing
              else if (onTap != null) // 只有可点击时才显示箭头
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
