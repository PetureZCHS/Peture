import 'package:flutter/material.dart';

import '../../../shared/design_system/peture_design_system.dart';
import 'account_deactivate_page.dart';
import 'change_password_page.dart';

/// 账号安全：修改密码、注销等（与主流 App 分组一致）。
class AccountSecurityPage extends StatelessWidget {
  const AccountSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PeturePageScaffold(
      title: '账号安全',
      child: ListView(
        children: [
          const PetureSectionHeader(
            title: '安全',
            subtitle: '密码管理与账号风险操作',
          ),
          PetureCard(
            padding: const EdgeInsets.symmetric(
              horizontal: PetureSpacing.sm,
              vertical: PetureSpacing.sm,
            ),
            child: Column(
              children: [
                _securityEntry(
                  context: context,
                  title: '修改密码',
                  subtitle: '更新登录密码',
                  icon: Icons.lock_outline_rounded,
                  iconColor: PetureColors.primary,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: PetureSpacing.sm),
                _securityEntry(
                  context: context,
                  title: '账号注销',
                  subtitle: '删除账号及全部数据，不可恢复（非退出登录）',
                  icon: Icons.no_accounts_outlined,
                  iconColor: PetureColors.danger,
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

  Widget _securityEntry({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(PetureRadius.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PetureSpacing.sm,
          vertical: PetureSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(PetureRadius.sm),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: PetureSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: PetureTextStyles.bodyStrong),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: PetureTextStyles.caption.copyWith(
                      color: PetureColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: PetureColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
