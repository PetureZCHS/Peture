import 'package:flutter/material.dart';

class SnackbarUtils {
  static get fadeSnackbar => null;

  static void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        duration: Duration(seconds: 2),
        showCloseIcon: true,
        closeIconColor: Colors.white,
      ),
    );
  }

  static void showSnackBarWithFade(BuildContext context, String message) {
    // fadeSnackbar.show(context: context, message: message);
  }
}
