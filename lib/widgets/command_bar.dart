import 'package:flutter/material.dart';
import '../core/adb_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_svg_icon.dart';
import 'command_history_dialog.dart';

class CommandBar extends StatelessWidget {
  const CommandBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AdbController.of(context);
    final history = controller.service.commandHistory;
    final lastCmd = history.isNotEmpty ? history.first : null;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.neutral1,
        border: Border(top: BorderSide(color: AppColors.neutral3, width: 1)),
      ),
      child: Row(
        children: [
          const AppSvgIcon(AppIcons.terminalWindow, size: 15, color: AppColors.primary4),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'LAST COMMAND:',
            style: AppTypography.tagline.copyWith(
              color: AppColors.neutral7,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: lastCmd == null
                ? Text(
                    'Ready. No commands executed.',
                    style: AppTypography.caption.copyWith(color: AppColors.neutral6),
                  )
                : Row(
                    children: [
                      AppSvgIcon(
                        lastCmd.isSuccess ? AppIcons.checkCircle : AppIcons.x,
                        size: 14,
                        color: lastCmd.isSuccess ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          lastCmd.displayCommand,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: AppColors.neutral11,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '(${lastCmd.duration.inMilliseconds}ms)',
                        style: AppTypography.tagline.copyWith(color: AppColors.neutral8),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => CommandHistoryDialog.show(context, controller.service.commandHistory),
              borderRadius: BorderRadius.circular(AppSpacing.xs),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                child: Row(
                  children: [
                    const AppSvgIcon(AppIcons.clockCounterClockwise, size: 14, color: AppColors.neutral10),
                    const SizedBox(width: 4),
                    Text(
                      'History (${history.length})',
                      style: AppTypography.caption.copyWith(color: AppColors.neutral10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
