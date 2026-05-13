import 'package:flutter/material.dart';

import '../peture_text_styles.dart';
import '../peture_tokens.dart';

class PeturePrimaryButton extends StatelessWidget {
  const PeturePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return _PetureButtonBase(
      label: label,
      icon: icon,
      isLoading: isLoading,
      expand: expand,
      onPressed: onPressed,
      backgroundColor: PetureColors.primary,
      foregroundColor: PetureColors.surfacePure,
      pressedColor: PetureColors.primaryPressed,
      borderColor: Colors.transparent,
    );
  }
}

class PetureSecondaryButton extends StatelessWidget {
  const PetureSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return _PetureButtonBase(
      label: label,
      icon: icon,
      isLoading: isLoading,
      expand: expand,
      onPressed: onPressed,
      backgroundColor: PetureColors.surface,
      foregroundColor: PetureColors.textPrimary,
      pressedColor: PetureColors.surfaceMuted,
      borderColor: PetureColors.border,
    );
  }
}

class PetureDangerButton extends StatelessWidget {
  const PetureDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return _PetureButtonBase(
      label: label,
      icon: icon,
      isLoading: isLoading,
      expand: expand,
      onPressed: onPressed,
      backgroundColor: PetureColors.danger,
      foregroundColor: PetureColors.surfacePure,
      pressedColor: PetureColors.danger.withOpacity(0.86),
      borderColor: Colors.transparent,
    );
  }
}

class _PetureButtonBase extends StatefulWidget {
  const _PetureButtonBase({
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.pressedColor,
    required this.borderColor,
    required this.isLoading,
    required this.expand,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color pressedColor;
  final Color borderColor;
  final bool isLoading;
  final bool expand;
  final IconData? icon;

  @override
  State<_PetureButtonBase> createState() => _PetureButtonBaseState();
}

class _PetureButtonBaseState extends State<_PetureButtonBase> {
  bool _isPressed = false;

  bool get _isDisabled => widget.onPressed == null || widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: PetureMotion.fast,
      curve: PetureMotion.standard,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: PetureSpacing.xl),
      decoration: BoxDecoration(
        color: _isDisabled
            ? widget.backgroundColor.withOpacity(0.45)
            : _isPressed
                ? widget.pressedColor
                : widget.backgroundColor,
        borderRadius: BorderRadius.circular(PetureRadius.pill),
        border: Border.all(color: widget.borderColor),
      ),
      child: Center(
        child: widget.isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.foregroundColor,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 18, color: widget.foregroundColor),
                    const SizedBox(width: PetureSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PetureTextStyles.label.copyWith(
                        color: widget.foregroundColor,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );

    return GestureDetector(
      onTapDown: _isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapCancel:
          _isDisabled ? null : () => setState(() => _isPressed = false),
      onTapUp: _isDisabled ? null : (_) => setState(() => _isPressed = false),
      onTap: _isDisabled ? null : widget.onPressed,
      child: widget.expand
          ? SizedBox(width: double.infinity, child: content)
          : content,
    );
  }
}
