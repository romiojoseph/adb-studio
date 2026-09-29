import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum AppCardVariant {
  elevated,
  outlined,
  flat,
}

/// A unified styled card wrapper enforcing design system borders, padding, and continuous squircle geometry.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final AppCardVariant variant;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.variant = AppCardVariant.elevated,
    this.onTap,
    this.backgroundColor,
  });

  const AppCard.outlined({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
  }) : variant = AppCardVariant.outlined;

  const AppCard.flat({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
  }) : variant = AppCardVariant.flat;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? AppSpacing.paddingMd;
    final bgColor = backgroundColor ??
        (variant == AppCardVariant.flat
            ? AppColors.neutral2
            : AppColors.neutral1);

    BorderSide side;
    switch (variant) {
      case AppCardVariant.elevated:
        side = const BorderSide(color: AppColors.neutral2, width: 2);
        break;
      case AppCardVariant.outlined:
        side = const BorderSide(color: AppColors.neutral3, width: 2);
        break;
      case AppCardVariant.flat:
        side = BorderSide.none;
        break;
    }

    final shape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.xl),
      side: side,
    );

    Widget content = Padding(
      padding: effectivePadding,
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: bgColor,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: content,
        ),
      );
    }

    return Material(
      color: bgColor,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}
