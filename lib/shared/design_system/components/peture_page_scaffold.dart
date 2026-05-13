import 'package:flutter/material.dart';

import '../peture_tokens.dart';

class PeturePageScaffold extends StatelessWidget {
  const PeturePageScaffold({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.padding = const EdgeInsets.all(PetureSpacing.lg),
    this.backgroundColor = PetureColors.background,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.safeArea = true,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: padding,
      child: child,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: title == null
          ? null
          : AppBar(
              title: Text(title!),
              actions: actions,
            ),
      body: safeArea ? SafeArea(child: body) : body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
