import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'app_svg_icon.dart';

/// Unified reusable Modal/Dialog component adhering to the design system.
/// Features a titlebar with title, optional subtitle,
/// top-right close icon button, custom body content, and optional bottom action bar.
class AppModal extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final double maxWidth;
  final double? maxHeight;
  final bool showCloseButton;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry contentPadding;

  const AppModal({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.actions,
    this.maxWidth = 540,
    this.maxHeight,
    this.showCloseButton = true,
    this.onClose,
    this.contentPadding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.md,
      AppSpacing.xl,
      AppSpacing.xl,
    ),
  });

  /// Displays the modal using the Flutter [showDialog] API.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Widget body,
    List<Widget>? actions,
    double maxWidth = 540,
    double? maxHeight,
    bool showCloseButton = true,
    bool barrierDismissible = true,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.md,
      AppSpacing.xl,
      AppSpacing.xl,
    ),
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => AppModal(
        title: title,
        subtitle: subtitle,
        body: body,
        actions: actions,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        showCloseButton: showCloseButton,
        contentPadding: contentPadding,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.neutral2,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xl,
      ),
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.xxl),
        side: const BorderSide(color: AppColors.neutral3, width: 1),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header with Top-Right Close Icon Button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTypography.heading6.copyWith(
                            color: AppColors.neutral9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.neutral7,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showCloseButton)
                    AppIconButton(
                      iconAsset: AppIcons.x,
                      size: AppIconButtonSize.sm,
                      color: AppColors.neutral8,
                      tooltip: 'Close',
                      onPressed: onClose ?? () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),
            const Divider(color: AppColors.neutral3, height: 1),

            // Modal Body
            Flexible(
              child: Padding(padding: contentPadding, child: body),
            ),

            // Bottom Actions Bar
            if (actions != null && actions!.isNotEmpty) ...[
              const Divider(color: AppColors.neutral3, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (int i = 0; i < actions!.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      actions![i],
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
