import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'app_modal.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AppModal(
      title: title,
      maxWidth: 460,
      contentPadding: const EdgeInsets.all(AppSpacing.xl),
      body: Text(
        message,
        style: AppTypography.body.copyWith(
          color: AppColors.neutral10,
          fontSize: 14,
        ),
      ),
      actions: [
        AppButton.secondary(
          onPressed: () => Navigator.of(context).pop(false),
          text: cancelLabel,
          size: AppButtonSize.md,
        ),
        if (isDestructive)
          AppButton.danger(
            onPressed: () => Navigator.of(context).pop(true),
            text: confirmLabel,
            size: AppButtonSize.md,
          )
        else
          AppButton(
            onPressed: () => Navigator.of(context).pop(true),
            text: confirmLabel,
            size: AppButtonSize.md,
          ),
      ],
    );
  }
}
