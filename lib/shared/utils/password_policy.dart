import 'package:flutter/material.dart';

/// 与注册/设置密码页一致的密码强度档位。
enum PasswordStrength {
  weak,
  medium,
  strong,
}

/// 密码校验结果（展示与是否满足策略）。
class PasswordValidationResult {
  final PasswordStrength strength;
  final String message;
  final Color color;
  final bool isValid;

  const PasswordValidationResult({
    required this.strength,
    required this.message,
    required this.color,
    required this.isValid,
  });

  static PasswordValidationResult empty() => const PasswordValidationResult(
        strength: PasswordStrength.weak,
        message: '',
        color: Colors.grey,
        isValid: false,
      );
}

/// 与 [EmailPasswordSetupPage] 规则对齐：至少 8 位，且字符种类不为「弱」；
/// 并拒绝单一字符重复（如 `666666`、`aaaaaa`）。
PasswordValidationResult evaluateAppPassword(String password) {
  if (password.isEmpty) {
    return PasswordValidationResult.empty();
  }

  if (password.isNotEmpty &&
      password.split('').every((c) => c == password[0])) {
    return const PasswordValidationResult(
      strength: PasswordStrength.weak,
      message: '请勿使用完全相同的字符作为密码',
      color: Colors.red,
      isValid: false,
    );
  }

  final hasUpperCase = password.contains(RegExp(r'[A-Z]'));
  final hasLowerCase = password.contains(RegExp(r'[a-z]'));
  final hasDigit = password.contains(RegExp(r'[0-9]'));
  final hasSpecial = password.contains(RegExp(r'[^A-Za-z0-9]'));

  var typeCount = 0;
  if (hasUpperCase) typeCount++;
  if (hasLowerCase) typeCount++;
  if (hasDigit) typeCount++;
  if (hasSpecial) typeCount++;

  final PasswordStrength strength;
  String message;
  final Color color;

  if (typeCount <= 1) {
    strength = PasswordStrength.weak;
    message = '弱：建议同时包含字母、数字或符号中的至少两种';
    color = Colors.red;
  } else if (typeCount == 2) {
    strength = PasswordStrength.medium;
    message = '中：密码强度良好';
    color = Colors.orange;
  } else {
    strength = PasswordStrength.strong;
    message = '强：密码强度优秀';
    color = Colors.green;
  }

  var isValid = strength != PasswordStrength.weak && password.length >= 8;
  if (!isValid && password.length < 8) {
    message = '密码长度至少8位，建议混合使用字母、数字和符号';
  }

  return PasswordValidationResult(
    strength: strength,
    message: message,
    color: color,
    isValid: isValid,
  );
}

bool isAppPasswordValid(String password) =>
    evaluateAppPassword(password).isValid;
