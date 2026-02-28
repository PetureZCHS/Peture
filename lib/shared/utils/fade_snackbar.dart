import 'package:flutter/material.dart';

class SnackbarUtils {
  static void showSnackBar({
    required BuildContext context,
    required String message,
  }) {
    // 使用 ScaffoldMessenger.of(context) 是显示 SnackBar 的官方推荐方式
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.transparent, // 确保 SnackBar 自身背景透明，以显示自定义容器
        behavior: SnackBarBehavior.floating, // 浮动效果
        elevation: 0, // 移除 SnackBar 自身的阴影，使用自定义容器的阴影
      ),
    );
  }
}
