import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/adb_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_svg_icon.dart';
import '../../widgets/empty_state_view.dart';

class CapturedMedia {
  final String path;
  final bool isVideo;
  final DateTime timestamp;

  CapturedMedia({
    required this.path,
    required this.isVideo,
    required this.timestamp,
  });
}

class ScreenToolsView extends StatefulWidget {
  const ScreenToolsView({super.key});

  @override
  State<ScreenToolsView> createState() => _ScreenToolsViewState();
}

class _ScreenToolsViewState extends State<ScreenToolsView> {
  bool _isTakingScreenshot = false;
  bool _isRecording = false;
  Process? _recordProcess;
  Timer? _recordTimer;
  int _recordSecondsElapsed = 0;
  final List<CapturedMedia> _gallery = [];
  CapturedMedia? _selectedMedia;

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recordProcess?.kill();
    super.dispose();
  }

  Future<String> _getStorageDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}\\ADB_Studio_Media');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<void> _handleTakeScreenshot() async {
    final controller = AdbController.of(context);
    final serial = controller.selectedDevice?.serial;
    if (serial == null) return;

    setState(() => _isTakingScreenshot = true);
    try {
      final baseDir = await _getStorageDir();
      final timeStr = DateTime.now().millisecondsSinceEpoch;
      final localFile = '$baseDir\\screenshot_$timeStr.png';

      final file = await controller.service.takeScreenshot(serial, localFile);

      if (await file.exists()) {
        final item = CapturedMedia(
          path: file.path,
          isVideo: false,
          timestamp: DateTime.now(),
        );
        setState(() {
          _gallery.insert(0, item);
          _selectedMedia = item;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Screenshot saved: ${file.path}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Screenshot error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isTakingScreenshot = false);
    }
  }

  Future<void> _handleStartRecord() async {
    final controller = AdbController.of(context);
    final serial = controller.selectedDevice?.serial;
    if (serial == null) return;

    setState(() {
      _isRecording = true;
      _recordSecondsElapsed = 0;
    });

    try {
      _recordProcess = await controller.service.startScreenRecord(
        serial,
        timeLimitSeconds: 180,
      );
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _recordSecondsElapsed++);
        if (_recordSecondsElapsed >= 180) {
          _handleStopRecord();
        }
      });
    } catch (e) {
      _recordTimer?.cancel();
      setState(() => _isRecording = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Record start error: $e')));
      }
    }
  }

  Future<void> _handleStopRecord() async {
    final controller = AdbController.of(context);
    final serial = controller.selectedDevice?.serial;
    if (serial == null) return;

    _recordTimer?.cancel();
    _recordTimer = null;

    // Terminate the screenrecord process
    _recordProcess?.kill(ProcessSignal.sigint);
    _recordProcess = null;

    // Small pause to allow device to flush MP4 file container
    await Future.delayed(const Duration(seconds: 1));

    try {
      final baseDir = await _getStorageDir();
      final timeStr = DateTime.now().millisecondsSinceEpoch;
      final localFile = '$baseDir\\recording_$timeStr.mp4';

      final file = await controller.service.pullScreenRecord(serial, localFile);

      if (await file.exists()) {
        final item = CapturedMedia(
          path: file.path,
          isVideo: true,
          timestamp: DateTime.now(),
        );
        setState(() {
          _gallery.insert(0, item);
          _selectedMedia = item;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recording saved: ${file.path}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Pull recording error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _saveAs(CapturedMedia media) async {
    final ext = media.isVideo ? 'mp4' : 'png';
    final folder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select folder to save media',
    );
    if (folder == null) return;
    final dest =
        '$folder\\capture_${media.timestamp.millisecondsSinceEpoch}.$ext';

    await File(media.path).copy(dest);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved to $dest')));
    }
  }

  void _openInExplorer(String path) {
    if (File(path).existsSync() || Directory(path).existsSync()) {
      Process.run('explorer.exe', ['/select,', path], runInShell: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AdbController.of(context);
    final device = controller.selectedDevice;

    if (device == null) {
      return const EmptyStateView(
        iconAsset: AppIcons.deviceMobileCamera,
        title: 'No Device Selected',
        description:
            'Select a device to take screenshots or record screen video.',
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Control Actions Card
          Container(
            padding: AppSpacing.paddingMd,
            decoration: ShapeDecoration(
              color: AppColors.neutral2,
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.xl),
                side: const BorderSide(color: AppColors.neutral3, width: 1),
              ),
            ),
            child: Row(
              children: [
                AppButton(
                  onPressed: _isTakingScreenshot || _isRecording
                      ? null
                      : _handleTakeScreenshot,
                  icon: const AppSvgIcon(AppIcons.deviceMobileCamera, size: 20),
                  text: 'Capture Screenshot',
                  isLoading: _isTakingScreenshot,
                  size: AppButtonSize.md,
                ),
                const SizedBox(width: AppSpacing.md),
                if (!_isRecording)
                  AppButton(
                    onPressed: _isTakingScreenshot ? null : _handleStartRecord,
                    icon: const AppSvgIcon(AppIcons.plusCircle, size: 20),
                    text: 'Start Screen Recording',
                    variant: AppButtonVariant.danger,
                    size: AppButtonSize.md,
                  )
                else
                  AppButton(
                    onPressed: _handleStopRecord,
                    icon: const AppSvgIcon(AppIcons.minus, size: 20),
                    text: 'Stop & Pull (${_recordSecondsElapsed}s)',
                    variant: AppButtonVariant.danger,
                    size: AppButtonSize.md,
                  ),
                const Spacer(),
                if (_gallery.isNotEmpty)
                  AppButton.secondary(
                    onPressed: () async {
                      final dir = await _getStorageDir();
                      if (Directory(dir).existsSync()) {
                        Process.run('explorer.exe', [dir], runInShell: false);
                      }
                    },
                    icon: const AppSvgIcon(AppIcons.folderOpen, size: 20),
                    text: 'Open Captures Folder',
                    size: AppButtonSize.md,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Main Split: Preview + Gallery
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Preview Area
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: AppSpacing.paddingMd,
                    decoration: ShapeDecoration(
                      color: AppColors.neutral2,
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.xl),
                        side: const BorderSide(
                          color: AppColors.neutral3,
                          width: 1,
                        ),
                      ),
                    ),
                    child: _selectedMedia == null
                        ? const Center(
                            child: EmptyStateView(
                              iconAsset: AppIcons.layout,
                              title: 'No Media Selected',
                              description:
                                  'Capture a screenshot or select a file from gallery to preview.',
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  AppSvgIcon(
                                    _selectedMedia!.isVideo
                                        ? AppIcons.play
                                        : AppIcons.folder,
                                    size: 20,
                                    color: AppColors.neutral7,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: SelectableText(
                                      _selectedMedia!.path,
                                      style: TextStyle(
                                        fontSize:
                                            AppTypography.caption.fontSize,
                                        color: AppColors.neutral8,
                                      ),
                                    ),
                                  ),
                                  AppIconButton(
                                    iconAsset: AppIcons.folderOpen,
                                    tooltip: 'Show in Explorer',
                                    color: AppColors.neutral8,
                                    size: AppIconButtonSize.md,
                                    onPressed: () =>
                                        _openInExplorer(_selectedMedia!.path),
                                  ),
                                  const SizedBox(width: AppSpacing.xxs),
                                  AppIconButton(
                                    iconAsset: AppIcons.export,
                                    tooltip: 'Save As...',
                                    color: AppColors.neutral8,
                                    size: AppIconButtonSize.md,
                                    onPressed: () => _saveAs(_selectedMedia!),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              const Divider(
                                height: 1,
                                color: AppColors.neutral3,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Expanded(
                                child: Container(
                                  decoration: ShapeDecoration(
                                    color: AppColors.neutral1,
                                    shape: ContinuousRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.sm,
                                      ),
                                      side: const BorderSide(
                                        color: AppColors.neutral3,
                                      ),
                                    ),
                                  ),
                                  child: Center(
                                    child: _selectedMedia!.isVideo
                                        ? Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const AppSvgIcon(
                                                AppIcons.play,
                                                size: 36,
                                                color: AppColors.primary4,
                                              ),
                                              const SizedBox(
                                                height: AppSpacing.sm,
                                              ),
                                              Text(
                                                'Video Recording Saved',
                                                style: AppTypography.subtitle
                                                    .copyWith(
                                                      color: AppColors.neutral8,
                                                    ),
                                              ),
                                              const SizedBox(
                                                height: AppSpacing.sm,
                                              ),
                                              AppButton(
                                                onPressed: () =>
                                                    _openInExplorer(
                                                      _selectedMedia!.path,
                                                    ),
                                                icon: const AppSvgIcon(
                                                  AppIcons.arrowSquareOut,
                                                  size: 20,
                                                ),
                                                text: 'Open Video File',
                                                size: AppButtonSize.md,
                                              ),
                                            ],
                                          )
                                        : ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              AppSpacing.xs,
                                            ),
                                            child: Image.file(
                                              File(_selectedMedia!.path),
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Gallery List
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: AppSpacing.paddingMd,
                    decoration: ShapeDecoration(
                      color: AppColors.neutral2,
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.xl),
                        side: const BorderSide(
                          color: AppColors.neutral3,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Session Gallery',
                              style: AppTypography.heading6.copyWith(
                                color: AppColors.neutral8,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '${_gallery.length}',
                              style: AppTypography.heading6.copyWith(
                                color: AppColors.neutral9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Divider(height: 1, color: AppColors.neutral3),
                        const SizedBox(height: AppSpacing.xs),
                        Expanded(
                          child: _gallery.isEmpty
                              ? const Center(
                                  child: EmptyStateView(
                                    iconAsset: AppIcons.cards,
                                    title: 'No Captures',
                                    description:
                                        'No captures in this session yet.',
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _gallery.length,
                                  itemBuilder: (context, index) {
                                    final item = _gallery[index];
                                    final isSelected = item == _selectedMedia;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Material(
                                        color: isSelected
                                            ? AppColors.neutral0
                                            : Colors.transparent,
                                        shape: ContinuousRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSpacing.xl,
                                          ),
                                          side: isSelected
                                              ? const BorderSide(
                                                  color: AppColors.neutral5,
                                                  width: 2,
                                                )
                                              : BorderSide.none,
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: ListTile(
                                          dense: true,
                                          leading: Container(
                                            padding: const EdgeInsets.all(
                                              AppSpacing.xs,
                                            ),
                                            decoration: ShapeDecoration(
                                              color: item.isVideo
                                                  ? AppColors.neutral5
                                                  : AppColors.neutral3,
                                              shape: ContinuousRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppSpacing.xl,
                                                    ),
                                              ),
                                            ),
                                            child: AppSvgIcon(
                                              item.isVideo
                                                  ? AppIcons.play
                                                  : AppIcons.layout,
                                              color: item.isVideo
                                                  ? AppColors.neutral8
                                                  : AppColors.neutral8,
                                              size: 18,
                                            ),
                                          ),
                                          title: Text(
                                            item.isVideo
                                                ? 'Screen Recording'
                                                : 'Screenshot',
                                            style: AppTypography.body.copyWith(
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              color: AppColors.neutral8,
                                            ),
                                          ),
                                          subtitle: Text(
                                            item.timestamp
                                                .toIso8601String()
                                                .substring(11, 19),
                                            style: AppTypography.caption
                                                .copyWith(
                                                  color: AppColors.neutral7,
                                                ),
                                          ),
                                          onTap: () => setState(
                                            () => _selectedMedia = item,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
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
