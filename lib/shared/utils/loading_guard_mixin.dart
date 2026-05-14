import 'package:flutter/widgets.dart';

mixin LoadingGuardMixin<T extends StatefulWidget> on State<T> {
  Future<void> runWithLoadingFlag({
    required bool isLoading,
    required void Function(bool value) assign,
    required Future<void> Function() action,
  }) async {
    if (isLoading || !mounted) return;

    setState(() => assign(true));
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => assign(false));
      }
    }
  }
}

