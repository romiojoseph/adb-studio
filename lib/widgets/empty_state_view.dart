import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'app_svg_icon.dart';

class EmptyStateView extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final Widget? iconWidget;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateView({
    super.key,
    this.icon,
    this.iconAsset,
    this.iconWidget,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    Widget renderIcon() {
      if (iconAsset != null) {
        return AppSvgIcon(iconAsset!, size: 36, color: AppColors.neutral7);
      }
      if (iconWidget != null) {
        return IconTheme(
          data: const IconThemeData(color: AppColors.neutral7, size: 36),
          child: iconWidget!,
        );
      }
      if (icon != null) {
        return Icon(icon, size: 36, color: AppColors.neutral7);
      }
      return const AppSvgIcon(AppIcons.info, size: 36, color: AppColors.neutral7);
    }

    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: AppSpacing.paddingLg,
              decoration: BoxDecoration(
                color: AppColors.neutral1,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.neutral3, width: 1),
              ),
              child: renderIcon(),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.subtitle.copyWith(
                color: AppColors.neutral11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                description,
                style: AppTypography.caption.copyWith(color: AppColors.neutral7),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                onPressed: onAction,
                text: actionLabel,
                size: AppButtonSize.md,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
