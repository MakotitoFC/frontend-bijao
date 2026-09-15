import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppButtonVariant { primary, outline }

// Botón base del sistema de diseño: relleno sólido (acción primaria) o
// outline/ghost (acción secundaria, por defecto). Se encoge levemente al
// presionar y oscurece un poco en hover (escritorio/web).
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool expand;
  final Color? backgroundColor;
  final Color? hoverColor;
  final double? radius;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.outline,
    this.isLoading = false,
    this.icon,
    this.expand = true,
    this.backgroundColor,
    this.hoverColor,
    this.radius,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final isPrimary = widget.variant == AppButtonVariant.primary;
    final baseColor = isPrimary
        ? (widget.backgroundColor ?? AppColors.primaryGreen)
        : Colors.transparent;
    final hoverColor = isPrimary
        ? (widget.hoverColor ?? AppColors.primaryGreenDark)
        : AppColors.primaryGreen.withValues(alpha: 0.06);
    final foreground = isPrimary ? Colors.white : AppColors.primaryGreen;

    final child = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading)
          SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 18, color: foreground),
            const SizedBox(width: 8),
          ],
          Text(
            widget.label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ],
    );

    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: _enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            width: widget.expand ? double.infinity : null,
            decoration: BoxDecoration(
              color: !_enabled
                  ? (isPrimary ? Colors.grey.shade300 : Colors.transparent)
                  : (_hovered ? hoverColor : baseColor),
              borderRadius: BorderRadius.circular(
                widget.radius ?? AppRadii.button,
              ),
              border: isPrimary
                  ? null
                  : Border.all(
                      color: _enabled
                          ? AppColors.primaryGreen
                          : Colors.grey.shade300,
                    ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
