import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_svg_icon.dart';

enum AppBadgeTone { success, warning, danger, info, paused, neutral }

enum AppBadgeStyle { pill, dotOnly, count }

enum AppBadgeSize { sm, md, lg }

/// A unified badge and status pill component supporting tones, styles, and sizes.
class AppBadge extends StatelessWidget {
  final String? label;
  final AppBadgeTone tone;
  final AppBadgeStyle style;
  final AppBadgeSize size;
  final Color? customColor;
  final IconData? icon;
  final String? iconAsset;
  final Widget? iconWidget;

  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.neutral,
    this.style = AppBadgeStyle.pill,
    this.size = AppBadgeSize.md,
    this.customColor,
    this.icon,
    this.iconAsset,
    this.iconWidget,
  });

  const AppBadge.success({
    super.key,
    required this.label,
    this.icon,
    this.iconAsset,
    this.iconWidget,
    this.style = AppBadgeStyle.pill,
    this.size = AppBadgeSize.md,
  }) : tone = AppBadgeTone.success,
       customColor = null;

  const AppBadge.warning({
    super.key,
    required this.label,
    this.icon,
    this.iconAsset,
    this.iconWidget,
    this.style = AppBadgeStyle.pill,
    this.size = AppBadgeSize.md,
  }) : tone = AppBadgeTone.warning,
       customColor = null;

  const AppBadge.danger({
    super.key,
    required this.label,
    this.icon,
    this.iconAsset,
    this.iconWidget,
    this.style = AppBadgeStyle.pill,
    this.size = AppBadgeSize.md,
  }) : tone = AppBadgeTone.danger,
       customColor = null;

  const AppBadge.info({
    super.key,
    required this.label,
    this.icon,
    this.iconAsset,
    this.iconWidget,
    this.style = AppBadgeStyle.pill,
    this.size = AppBadgeSize.md,
  }) : tone = AppBadgeTone.info,
       customColor = null;

  const AppBadge.paused({
    super.key,
    required this.label,
    this.icon,
    this.iconAsset,
    this.iconWidget,
    this.style = AppBadgeStyle.pill,
    this.size = AppBadgeSize.md,
  }) : tone = AppBadgeTone.paused,
       customColor = null;

  const AppBadge.count({
    super.key,
    required int count,
    this.tone = AppBadgeTone.neutral,
    this.size = AppBadgeSize.md,
    this.customColor,
  }) : label = '$count',
       style = AppBadgeStyle.count,
       icon = null,
       iconAsset = null,
       iconWidget = null;

  const AppBadge.dot({
    super.key,
    this.tone = AppBadgeTone.success,
    this.size = AppBadgeSize.md,
    this.customColor,
  }) : label = null,
       style = AppBadgeStyle.dotOnly,
       icon = null,
       iconAsset = null,
       iconWidget = null;

  Color _getColor() {
    if (customColor != null) return customColor!;
    switch (tone) {
      case AppBadgeTone.success:
        return AppColors.success;
      case AppBadgeTone.warning:
        return AppColors.warning;
      case AppBadgeTone.danger:
        return AppColors.error;
      case AppBadgeTone.info:
        return AppColors.primary4;
      case AppBadgeTone.paused:
        return AppColors.neutral7;
      case AppBadgeTone.neutral:
        return AppColors.neutral9;
    }
  }

  Color _getBackgroundColor(Color color) {
    if (style == AppBadgeStyle.dotOnly) return Colors.transparent;
    return color.withValues(alpha: 0.12);
  }

  Border _getBorder(Color color) {
    return Border.all(color: color.withValues(alpha: 0.25), width: 1);
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case AppBadgeSize.sm:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs + 2,
          vertical: 4,
        );
      case AppBadgeSize.md:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        );
      case AppBadgeSize.lg:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        );
    }
  }

  double _getFontSize() {
    switch (size) {
      case AppBadgeSize.sm:
        return 10;
      case AppBadgeSize.md:
        return 12;
      case AppBadgeSize.lg:
        return 14;
    }
  }

  double _getIconSize() {
    switch (size) {
      case AppBadgeSize.sm:
        return 10;
      case AppBadgeSize.md:
        return 12;
      case AppBadgeSize.lg:
        return 14;
    }
  }

  double _getDotSize() {
    switch (size) {
      case AppBadgeSize.sm:
        return 5;
      case AppBadgeSize.md:
        return 7;
      case AppBadgeSize.lg:
        return 9;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final bgColor = _getBackgroundColor(color);
    final border = _getBorder(color);
    final iconSize = _getIconSize();
    final dotSize = _getDotSize();
    final fontSize = _getFontSize();

    if (style == AppBadgeStyle.dotOnly) {
      final standaloneDotSize = size == AppBadgeSize.sm
          ? 8.0
          : (size == AppBadgeSize.md ? 12.0 : 16.0);
      return Container(
        width: standaloneDotSize,
        height: standaloneDotSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.6),
              blurRadius: 4,
              spreadRadius: 2,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: _getPadding(),
      decoration: ShapeDecoration(
        color: bgColor,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: border.top,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (iconAsset != null) ...[
            AppSvgIcon(iconAsset!, size: iconSize, color: color),
            const SizedBox(width: AppSpacing.xxs),
          ] else if (iconWidget != null) ...[
            IconTheme(
              data: IconThemeData(color: color, size: iconSize),
              child: iconWidget!,
            ),
            const SizedBox(width: AppSpacing.xxs),
          ] else if (icon != null) ...[
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: AppSpacing.xxs),
          ] else ...[
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 3,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (label != null)
            Text(
              label!,
              style: AppTypography.label.copyWith(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                height: 1.0,
              ),
            ),
        ],
      ),
    );
  }
}
