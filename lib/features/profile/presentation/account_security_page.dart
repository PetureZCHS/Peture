import 'package:flutter/material.dart';

import '../../../shared/utils/ui_helpers.dart';
import 'account_deactivate_page.dart';
import 'change_password_page.dart';

/// 账号安全：修改密码、注销等（与主流 App 分组一致）。
class AccountSecurityPage extends StatelessWidget {
  const AccountSecurityPage({super.key});

  static const Color _iconBlue = Color(0xFF0A84FF);
  static const Color _cardColor = Colors.white;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background.withOpacity(0.92),
        elevation: 0,
        centerTitle: true,
        title: Text(
          '账号安全',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textDark,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('安全', style: _sectionTitleStyle),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                _tile(
                  context,
                  icon: Icons.lock_outline_rounded,
                  iconColor: _iconBlue,
                  title: '修改密码',
                  subtitle: '更新登录密码',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordPage(),
                      ),
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 64),
                  child: Divider(
                    height: 0.5,
                    thickness: 0.5,
                    color: Color(0xFFDCDCDC),
                  ),
                ),
                _tile(
                  context,
                  icon: Icons.no_accounts_outlined,
                  iconColor: Colors.red,
                  title: '用户注销',
                  subtitle: '永久删除账号及业务数据，不可恢复',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AccountDeactivatePage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _cardColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  children: [
                    Text(title, style: _tileTitleStyle),
                    const SizedBox(height: 2),
                    Text(subtitle, style: _tileSubtitleStyle),
                  ],
                ),
              ),
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
