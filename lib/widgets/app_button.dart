import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_svg_icon.dart';

enum AppButtonVariant { filled, secondary, outlined, ghost, text, danger }

enum AppButtonSize { sm, md, lg }

/// A unified button component supporting filled, secondary, outlined, ghost, text,
/// and danger variants with continuous squircle borders, hover, active, and loading states.
class AppButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String? text;
  final Widget? icon;
  final Widget? trailingIcon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool isFullWidth;
  final String? tooltip;

  const AppButton({
    super.key,
    required this.onPressed,
    this.text,
    this.icon,
    this.trailingIcon,
    this.variant = AppButtonVariant.filled,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.isFullWidth = false,
    this.tooltip,
  });

  const AppButton.text({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.trailingIcon,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.isFullWidth = false,
    this.tooltip,
  }) : variant = AppButtonVariant.text;

  const AppButton.secondary({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.trailingIcon,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.isFullWidth = false,
    this.tooltip,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outlined({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.trailingIcon,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.isFullWidth = false,
    this.tooltip,
  }) : variant = AppButtonVariant.outlined;

  const AppButton.ghost({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.trailingIcon,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.isFullWidth = false,
    this.tooltip,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.danger({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.trailingIcon,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.isFullWidth = false,
    this.tooltip,
  }) : variant = AppButtonVariant.danger;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  EdgeInsets _getPadding() {
    switch (widget.size) {
      case AppButtonSize.sm:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        );
      case AppButtonSize.md:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        );
      case AppButtonSize.lg:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        );
    }
  }

  double _getFontSize() {
    switch (widget.size) {
      case AppButtonSize.sm:
        return AppTypography.labelSize;
      case AppButtonSize.md:
        return AppTypography.captionSize;
      case AppButtonSize.lg:
        return AppTypography.bodySize;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case AppButtonSize.sm:
        return 14;
      case AppButtonSize.md:
        return 16;
      case AppButtonSize.lg:
        return 18;
    }
  }

  double _getBorderRadius() {
    switch (widget.size) {
      case AppButtonSize.sm:
        return 16;
      case AppButtonSize.md:
        return 18;
      case AppButtonSize.lg:
        return 24;
    }
  }

  Color _getBackgroundColor() {
    if (!_isEnabled) {
      if (widget.variant == AppButtonVariant.text ||
          widget.variant == AppButtonVariant.ghost ||
          widget.variant == AppButtonVariant.outlined) {
        return Colors.transparent;
      }
      return AppColors.neutral3;
    }

    switch (widget.variant) {
      case AppButtonVariant.filled:
        if (_isPressed) return AppColors.primary8;
        if (_isHovered) return AppColors.primary6;
        return AppColors.primary4;

      case AppButtonVariant.secondary:
        if (_isPressed) return AppColors.neutral5;
        if (_isHovered) return AppColors.neutral4;
        return AppColors.neutral3;

      case AppButtonVariant.danger:
        if (_isPressed) return AppColors.danger8;
        if (_isHovered) return AppColors.danger6;
        return AppColors.danger6;

      case AppButtonVariant.outlined:
        if (_isPressed) return AppColors.neutral4.withValues(alpha: 0.3);
        if (_isHovered) return AppColors.neutral3;
        return Colors.transparent;

      case AppButtonVariant.ghost:
      case AppButtonVariant.text:
        if (_isPressed) return AppColors.neutral4.withValues(alpha: 0.25);
        if (_isHovered) return AppColors.neutral3.withValues(alpha: 0.6);
        return Colors.transparent;
    }
  }

  Color _getForegroundColor() {
    if (!_isEnabled) {
      return AppColors.neutral6;
    }

    switch (widget.variant) {
      case AppButtonVariant.filled:
        return AppColors.primary12;

      case AppButtonVariant.danger:
        return AppColors.neutral12;

      case AppButtonVariant.secondary:
        if (_isHovered || _isPressed) return AppColors.neutral12;
        return AppColors.neutral8;

      case AppButtonVariant.outlined:
        if (_isHovered || _isPressed) return AppColors.neutral9;
        return AppColors.neutral10;

      case AppButtonVariant.ghost:
        if (_isHovered || _isPressed) return AppColors.primary7;
        return AppColors.primary9;

      case AppButtonVariant.text:
        if (_isHovered || _isPressed) return AppColors.neutral9;
        return AppColors.neutral7;
    }
  }

  Border? _getBorder() {
    if (widget.variant == AppButtonVariant.outlined) {
      final borderColor = !_isEnabled
          ? AppColors.neutral4
          : (_isHovered || _isPressed
                ? AppColors.neutral6
                : AppColors.neutral5);
      return Border.all(color: borderColor, width: 1);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor();
    final fgColor = _getForegroundColor();
    final border = _getBorder();
    final padding = _getPadding();
    final fontSize = _getFontSize();
    final iconSize = _getIconSize();
    final borderRadius = _getBorderRadius();

    Widget content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          if (widget.text != null) const SizedBox(width: AppSpacing.xs),
        ] else if (widget.icon != null) ...[
          IconTheme(
            data: IconThemeData(color: fgColor, size: iconSize),
            child: widget.icon!,
          ),
          if (widget.text != null) const SizedBox(width: AppSpacing.xs - 2),
        ],
        if (widget.text != null)
          Text(
            widget.text!,
            style: AppTypography.label.copyWith(
              color: fgColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (widget.trailingIcon != null && !widget.isLoading) ...[
          const SizedBox(width: AppSpacing.xs),
          IconTheme(
            data: IconThemeData(color: fgColor, size: iconSize),
            child: widget.trailingIcon!,
          ),
        ],
      ],
    );

    Widget button = MouseRegion(
      cursor: _isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (_isEnabled && mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (_isEnabled && mounted) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (mounted) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (mounted) setState(() => _isPressed = false);
        },
        onTap: _isEnabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeInOut,
          padding: padding,
          decoration: ShapeDecoration(
            color: bgColor,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              side: border?.top ?? BorderSide.none,
            ),
          ),
          child: content,
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}

enum AppIconButtonVariant { ghost, secondary, filled, outlined, danger }

enum AppIconButtonSize { sm, md, lg }

/// An icon-only button component supporting variants, asset paths, and continuous squircle styling.
class AppIconButton extends StatefulWidget {
  final IconData? icon;
  final String? iconAsset;
  final Widget? iconWidget;
  final VoidCallback? onPressed;
  final String? tooltip;
  final AppIconButtonVariant variant;
  final AppIconButtonSize size;
  final Color? color;
  final bool isLoading;

  const AppIconButton({
    super.key,
    this.icon,
    this.iconAsset,
    this.iconWidget,
    required this.onPressed,
    this.tooltip,
    this.variant = AppIconButtonVariant.ghost,
    this.size = AppIconButtonSize.md,
    this.color,
    this.isLoading = false,
  }) : assert(
         icon != null || iconWidget != null || iconAsset != null,
         'Either icon, iconAsset, or iconWidget must be provided',
       );

  const AppIconButton.danger({
    super.key,
    this.icon,
    this.iconAsset,
    this.iconWidget,
    required this.onPressed,
    this.tooltip,
    this.size = AppIconButtonSize.md,
    this.isLoading = false,
  }) : variant = AppIconButtonVariant.danger,
       color = AppColors.error,
       assert(
         icon != null || iconWidget != null || iconAsset != null,
         'Either icon, iconAsset, or iconWidget must be provided',
       );

  const AppIconButton.secondary({
    super.key,
    this.icon,
    this.iconAsset,
    this.iconWidget,
    required this.onPressed,
    this.tooltip,
    this.size = AppIconButtonSize.md,
    this.color,
    this.isLoading = false,
  }) : variant = AppIconButtonVariant.secondary,
       assert(
         icon != null || iconWidget != null || iconAsset != null,
         'Either icon, iconAsset, or iconWidget must be provided',
       );

  const AppIconButton.outlined({
    super.key,
    this.icon,
    this.iconAsset,
    this.iconWidget,
    required this.onPressed,
    this.tooltip,
    this.size = AppIconButtonSize.md,
    this.color,
    this.isLoading = false,
  }) : variant = AppIconButtonVariant.outlined,
       assert(
         icon != null || iconWidget != null || iconAsset != null,
         'Either icon, iconAsset, or iconWidget must be provided',
       );

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  double _getContainerSize() {
    switch (widget.size) {
      case AppIconButtonSize.sm:
        return 30;
      case AppIconButtonSize.md:
        return 38;
      case AppIconButtonSize.lg:
        return 46;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case AppIconButtonSize.sm:
        return 16;
      case AppIconButtonSize.md:
        return 20;
      case AppIconButtonSize.lg:
        return 24;
    }
  }

  double _getBorderRadius() {
    switch (widget.size) {
      case AppIconButtonSize.sm:
        return 16;
      case AppIconButtonSize.md:
        return 18;
      case AppIconButtonSize.lg:
        return 24;
    }
  }

  Color _getBackgroundColor() {
    if (!_isEnabled) {
      return Colors.transparent;
    }

    switch (widget.variant) {
      case AppIconButtonVariant.filled:
        if (_isPressed) return AppColors.primary10;
        if (_isHovered) return AppColors.primary8;
        return AppColors.primary4;

      case AppIconButtonVariant.secondary:
        if (_isPressed) return AppColors.neutral5;
        if (_isHovered) return AppColors.neutral4;
        return AppColors.neutral3;

      case AppIconButtonVariant.danger:
        if (_isPressed) return AppColors.danger7;
        if (_isHovered) return AppColors.danger8;
        return Colors.transparent;

      case AppIconButtonVariant.outlined:
        if (_isPressed) return AppColors.neutral4.withValues(alpha: 0.3);
        if (_isHovered) return AppColors.neutral3;
        return Colors.transparent;

      case AppIconButtonVariant.ghost:
        if (_isPressed) return AppColors.neutral4.withValues(alpha: 0.4);
        if (_isHovered) return AppColors.neutral3;
        return Colors.transparent;
    }
  }

  Color _getForegroundColor() {
    if (!_isEnabled) {
      return AppColors.neutral6;
    }

    if (widget.color != null) {
      if (_isHovered || _isPressed) {
        return widget.color!;
      }
      return widget.color!.withValues(alpha: 0.85);
    }

    switch (widget.variant) {
      case AppIconButtonVariant.filled:
        return AppColors.primary12;

      case AppIconButtonVariant.danger:
        return AppColors.error;

      case AppIconButtonVariant.secondary:
      case AppIconButtonVariant.outlined:
      case AppIconButtonVariant.ghost:
        if (_isHovered || _isPressed) return AppColors.neutral12;
        return AppColors.neutral10;
    }
  }

  Border? _getBorder() {
    if (widget.variant == AppIconButtonVariant.outlined) {
      final borderColor = !_isEnabled
          ? AppColors.neutral4
          : (_isHovered || _isPressed
                ? AppColors.neutral6
                : AppColors.neutral5);
      return Border.all(color: borderColor, width: 1);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final containerSize = _getContainerSize();
    final iconSize = _getIconSize();
    final bgColor = _getBackgroundColor();
    final fgColor = _getForegroundColor();
    final border = _getBorder();
    final borderRadius = _getBorderRadius();

    Widget button = MouseRegion(
      cursor: _isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (_isEnabled && mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (_isEnabled && mounted) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (mounted) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (mounted) setState(() => _isPressed = false);
        },
        onTap: _isEnabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeInOut,
          width: containerSize,
          height: containerSize,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: bgColor,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              side: border?.top ?? BorderSide.none,
            ),
          ),
          child: widget.isLoading
              ? SizedBox(
                  width: iconSize - 2,
                  height: iconSize - 2,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                  ),
                )
              : widget.iconAsset != null
              ? AppSvgIcon(widget.iconAsset!, size: iconSize, color: fgColor)
              : widget.iconWidget != null
              ? IconTheme(
                  data: IconThemeData(color: fgColor, size: iconSize),
                  child: widget.iconWidget!,
                )
              : Icon(widget.icon, size: iconSize, color: fgColor),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}

/// A unified Floating Action Button component with continuous rectangle borders and theme tokens.
class AppFab extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final Color backgroundColor;
  final Color foregroundColor;
  final double elevation;

  const AppFab({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.backgroundColor = AppColors.primary4,
    this.foregroundColor = AppColors.primary12,
    this.elevation = 4,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: null,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(32)),
      tooltip: tooltip,
      onPressed: onPressed,
      child: icon,
    );
  }
}
