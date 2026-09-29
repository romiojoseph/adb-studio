import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/adb_command_record.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'app_modal.dart';
import 'app_svg_icon.dart';

class CommandHistoryDialog extends StatelessWidget {
  final List<AdbCommandRecord> history;

  const CommandHistoryDialog({super.key, required this.history});

  static void show(BuildContext context, List<AdbCommandRecord> history) {
    showDialog(
      context: context,
      builder: (ctx) => CommandHistoryDialog(history: history),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppModal(
      title: 'ADB Command History (${history.length})',
      maxWidth: 900,
      maxHeight: 650,
      contentPadding: EdgeInsets.zero,
      body: history.isEmpty
          ? Center(
              child: Text(
                'No commands executed yet.',
                style: AppTypography.body.copyWith(color: AppColors.neutral7),
              ),
            )
          : ListView.separated(
              padding: AppSpacing.paddingMd,
              itemCount: history.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final item = history[index];
                return _CommandHistoryItem(item: item);
              },
            ),
    );
  }
}

class _CommandHistoryItem extends StatefulWidget {
  final AdbCommandRecord item;

  const _CommandHistoryItem({required this.item});

  @override
  State<_CommandHistoryItem> createState() => _CommandHistoryItemState();
}

class _CommandHistoryItemState extends State<_CommandHistoryItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Material(
      color: AppColors.neutral1,
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.xl),
        side: BorderSide(
          color: item.isSuccess
              ? AppColors.neutral4
              : AppColors.error.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AppSvgIcon(
                      item.isSuccess ? AppIcons.checkCircle : AppIcons.x,
                      color: item.isSuccess
                          ? AppColors.success
                          : AppColors.error,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayCommand,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.neutral7,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.timestamp.toIso8601String().substring(11, 19)} • ${item.duration.inMilliseconds}ms • Exit: ${item.exitCode}',
                          style: AppTypography.label.copyWith(
                            color: AppColors.neutral6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppIconButton(
                    iconAsset: AppIcons.copy,
                    size: AppIconButtonSize.sm,
                    tooltip: 'Copy command',
                    color: AppColors.neutral8,
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: item.displayCommand),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Command copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              decoration: ShapeDecoration(
                color: AppColors.neutral2,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                  side: const BorderSide(color: AppColors.neutral3, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.xs,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.stderr.isNotEmpty && item.stdout.isEmpty
                              ? 'ERROR OUTPUT'
                              : 'COMMAND OUTPUT',
                          style: AppTypography.tagline.copyWith(
                            color: item.stderr.isNotEmpty && item.stdout.isEmpty
                                ? AppColors.error
                                : AppColors.neutral7,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.stdout.isNotEmpty || item.stderr.isNotEmpty)
                          AppIconButton(
                            iconAsset: AppIcons.copy,
                            size: AppIconButtonSize.sm,
                            tooltip: 'Copy output',
                            color: AppColors.neutral7,
                            onPressed: () {
                              final text = item.stdout.isNotEmpty
                                  ? item.stdout
                                  : item.stderr;
                              Clipboard.setData(ClipboardData(text: text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Output copied to clipboard'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.neutral3, height: 1),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SelectableText(
                      item.stdout.isNotEmpty
                          ? item.stdout
                          : (item.stderr.isNotEmpty
                                ? item.stderr
                                : '(no output)'),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: item.stderr.isNotEmpty && item.stdout.isEmpty
                            ? AppColors.error
                            : AppColors.neutral8,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
