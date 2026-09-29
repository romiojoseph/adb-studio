import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/adb_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_svg_icon.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state_view.dart';

class FileItem {
  final String name;
  final bool isDirectory;
  final String permissions;
  final String size;
  final String date;

  const FileItem({
    required this.name,
    required this.isDirectory,
    required this.permissions,
    required this.size,
    required this.date,
  });

  factory FileItem.fromLsLine(String line) {
    // Example: drwxrwx--x 4 root sdcard_rw 4096 2026-09-01 12:00 Download
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 8) {
      String name = parts.isNotEmpty ? parts.last : '';
      if (name.contains(' -> ')) name = name.split(' -> ').first;
      return FileItem(
        name: name,
        isDirectory: line.startsWith('d') || line.startsWith('l'),
        permissions: parts.isNotEmpty ? parts[0] : '',
        size: '',
        date: '',
      );
    }
    final isDir = parts[0].startsWith('d') || parts[0].startsWith('l');
    final perms = parts[0];
    final size = parts[4];
    final date = '${parts[5]} ${parts[6]}';
    String name = parts.sublist(7).join(' ');
    if (name.contains(' -> ')) {
      name = name.split(' -> ').first;
    }

    return FileItem(
      name: name,
      isDirectory: isDir,
      permissions: perms,
      size: size,
      date: date,
    );
  }
}

class FileManagerView extends StatefulWidget {
  const FileManagerView({super.key});

  @override
  State<FileManagerView> createState() => _FileManagerViewState();
}

class _FileManagerViewState extends State<FileManagerView> {
  String _currentPath = '/sdcard';
  List<FileItem> _items = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _lastLoadedSerial;

  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AdbController.of(context);
    final currentSerial = controller.selectedDevice?.serial;
    if (currentSerial != null && !_isLoading) {
      if (currentSerial != _lastLoadedSerial) {
        _lastLoadedSerial = currentSerial;
        _currentPath = '/sdcard';
        _loadDirectory(_currentPath);
      }
    } else if (currentSerial == null) {
      _lastLoadedSerial = null;
    }
  }

  Future<void> _loadDirectory(String path) async {
    final controller = AdbController.of(context);
    final serial = controller.selectedDevice?.serial;
    if (serial == null) return;
    _lastLoadedSerial = serial;

    // Strict guardrail check
    if (!path.startsWith('/sdcard') || path.contains('..')) {
      setState(() => _error = 'Path outside /sdcard is strictly restricted.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final output = await controller.service.listDirectory(serial, path);
      final lines = output.split(RegExp(r'\r?\n'));
      final list = <FileItem>[];

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('total ')) continue;
        final item = FileItem.fromLsLine(trimmed);
        if (item.name == '.' || item.name == '..') continue;
        list.add(item);
      }

      // Sort directories first, then alphabetical
      list.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (mounted) {
        setState(() {
          _currentPath = path;
          _items = list;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateInto(String folderName) {
    final newPath = _currentPath == '/sdcard'
        ? '/sdcard/$folderName'
        : '$_currentPath/$folderName';
    _loadDirectory(newPath);
  }

  void _navigateUp() {
    if (_currentPath == '/sdcard') return;
    final lastSlash = _currentPath.lastIndexOf('/');
    if (lastSlash <= '/sdcard'.length) {
      _loadDirectory('/sdcard');
    } else {
      _loadDirectory(_currentPath.substring(0, lastSlash));
    }
  }

  Future<void> _handlePushFile() async {
    final controller = AdbController.of(context);
    final serial = controller.selectedDevice?.serial;
    if (serial == null) return;

    final file = await FilePicker.pickFile();
    if (file == null || file.path == null) return;

    final localPath = file.path!;
    final fileName = file.name;
    final remoteDest = '$_currentPath/$fileName';

    try {
      final record = await controller.service.pushFile(
        serial,
        localPath,
        remoteDest,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record.isSuccess
                  ? 'Pushed $fileName successfully'
                  : 'Push failed: ${record.stderr}',
            ),
          ),
        );
        _loadDirectory(_currentPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handlePullFile(FileItem item) async {
    final controller = AdbController.of(context);
    final serial = controller.selectedDevice?.serial;
    if (serial == null) return;

    final outputDir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select destination folder to save ${item.name}',
    );
    if (outputDir == null) return;

    final remoteSource = '$_currentPath/${item.name}';
    final localTarget = '$outputDir\\${item.name}';

    try {
      final record = await controller.service.pullFile(
        serial,
        remoteSource,
        localTarget,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record.isSuccess
                  ? 'Pulled ${item.name} to $outputDir'
                  : 'Pull failed: ${record.stderr}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handleMakeDirectory() async {
    final controller = AdbController.of(context);
    final serial = controller.selectedDevice?.serial;
    if (serial == null) return;

    final dirNameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AppModal(
        title: 'New Directory',
        maxWidth: 440,
        body: AppTextField(
          controller: dirNameController,
          autofocus: true,
          label: 'Folder Name',
          hint: 'Enter directory name',
          onFieldSubmitted: (val) {
            final trimmed = val.trim();
            if (trimmed.isNotEmpty) {
              Navigator.of(ctx).pop(trimmed);
            }
          },
        ),
        actions: [
          AppButton.secondary(
            onPressed: () => Navigator.of(ctx).pop(null),
            text: 'Cancel',
            size: AppButtonSize.md,
          ),
          AppButton(
            onPressed: () =>
                Navigator.of(ctx).pop(dirNameController.text.trim()),
            text: 'Create',
            size: AppButtonSize.md,
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    final remotePath = '$_currentPath/$name';

    try {
      final record = await controller.service.makeDirectory(serial, remotePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record.isSuccess
                  ? 'Created folder $name'
                  : 'Failed: ${record.stderr}',
            ),
          ),
        );
        _loadDirectory(_currentPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handleStat(FileItem item) async {
    final controller = AdbController.of(context);
    final serial = controller.selectedDevice?.serial;
    if (serial == null) return;

    final remotePath = '$_currentPath/${item.name}';
    final stat = await controller.service.statPath(serial, remotePath);

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AppModal(
          title: 'File Info: ${item.name}',
          maxWidth: 580,
          body: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: ShapeDecoration(
              color: AppColors.neutral1,
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                side: const BorderSide(color: AppColors.neutral3),
              ),
            ),
            child: SelectableText(
              stat,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: AppColors.neutral11,
              ),
            ),
          ),
          actions: [
            AppButton(
              onPressed: () => Navigator.of(ctx).pop(),
              text: 'Close',
              size: AppButtonSize.md,
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AdbController.of(context);
    final device = controller.selectedDevice;

    if (device == null) {
      return const EmptyStateView(
        iconAsset: AppIcons.folderOpen,
        title: 'No Device Selected',
        description:
            'Connect and select a device to browse internal storage (/sdcard).',
      );
    }

    final canGoUp = _currentPath != '/sdcard';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Navigation & Action Bar
          Container(
            padding: AppSpacing.paddingMd,
            decoration: ShapeDecoration(
              color: AppColors.neutral1,
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.xl),
                side: const BorderSide(color: AppColors.neutral3, width: 1),
              ),
            ),
            child: Row(
              children: [
                AppIconButton(
                  iconAsset: AppIcons.caretUp,
                  tooltip: 'Up one level',
                  color: AppColors.neutral8,
                  size: AppIconButtonSize.md,
                  onPressed: canGoUp ? _navigateUp : null,
                ),
                const SizedBox(width: AppSpacing.xs),
                AppIconButton(
                  iconAsset: AppIcons.folder,
                  tooltip: 'Home (/sdcard)',
                  color: AppColors.neutral8,
                  size: AppIconButtonSize.md,
                  onPressed: canGoUp ? () => _loadDirectory('/sdcard') : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md - 2,
                    ),
                    decoration: ShapeDecoration(
                      color: AppColors.neutral1,
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                        side: const BorderSide(color: AppColors.neutral3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const AppSvgIcon(
                          AppIcons.folderSimple,
                          size: 18,
                          color: AppColors.primary4,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            _currentPath,
                            style: AppTypography.body.copyWith(
                              fontFamily: 'monospace',
                              color: AppColors.neutral8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 220,
                  child: AppTextField(
                    controller: _searchController,
                    hint: 'Filter files...',
                    prefixIcon: const AppSvgIcon(
                      AppIcons.magnifyingGlass,
                      size: 18,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton.secondary(
                  onPressed: _handleMakeDirectory,
                  icon: const AppSvgIcon(AppIcons.plusCircle, size: 20),
                  text: 'New Folder',
                  size: AppButtonSize.lg,
                ),
                const SizedBox(width: AppSpacing.xs),
                AppButton(
                  onPressed: _handlePushFile,
                  icon: const AppSvgIcon(AppIcons.arrowSquareUp, size: 20),
                  text: 'Push File',
                  size: AppButtonSize.lg,
                ),
                const SizedBox(width: AppSpacing.xs),
                AppIconButton(
                  iconAsset: AppIcons.arrowClockwise,
                  tooltip: 'Refresh',
                  size: AppIconButtonSize.lg,
                  onPressed: () => _loadDirectory(_currentPath),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // File List Table Container
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              decoration: ShapeDecoration(
                color: AppColors.neutral2,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.xl),
                  side: const BorderSide(color: AppColors.neutral3, width: 1),
                ),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppSvgIcon(
                              AppIcons.info,
                              size: 36,
                              color: AppColors.danger4,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _error!,
                              style: AppTypography.body.copyWith(
                                color: AppColors.neutral11,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppButton(
                              onPressed: () => _loadDirectory('/sdcard'),
                              text: 'Return to /sdcard',
                              size: AppButtonSize.md,
                            ),
                          ],
                        ),
                      ),
                    )
                  : _items.isEmpty
                  ? const Center(
                      child: EmptyStateView(
                        iconAsset: AppIcons.folderOpen,
                        title: 'Folder is Empty',
                        description:
                            'There are no files or subdirectories in this directory.',
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final filtered = _items.where((i) {
                          if (_searchQuery.isEmpty) return true;
                          return i.name.toLowerCase().contains(_searchQuery);
                        }).toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Text(
                              'No files match "$_searchQuery"',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.neutral8,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: AppSpacing.xxs,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            color: AppColors.neutral3,
                          ),
                          itemBuilder: (context, index) {
                            final item = filtered[index];

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xxs,
                                vertical: 2,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                shape: ContinuousRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.sm,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  dense: true,
                                  leading: Container(
                                    padding: const EdgeInsets.all(AppSpacing.xs),
                                    decoration: ShapeDecoration(
                                      color: item.isDirectory
                                          ? AppColors.neutral3
                                          : AppColors.neutral4,
                                      shape: ContinuousRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.xs,
                                        ),
                                      ),
                                    ),
                                    child: AppSvgIcon(
                                      item.isDirectory
                                          ? AppIcons.folder
                                          : AppIcons.fileText,
                                      color: item.isDirectory
                                          ? AppColors.neutral8
                                          : AppColors.neutral11,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    item.name,
                                    style: AppTypography.body.copyWith(
                                      fontWeight: item.isDirectory
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                      color: AppColors.neutral8,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${item.permissions} • ${item.date}',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.neutral7,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!item.isDirectory &&
                                          item.size.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: AppSpacing.sm,
                                          ),
                                          child: AppBadge(
                                            label: _formatFileSize(item.size),
                                            tone: AppBadgeTone.neutral,
                                          ),
                                        ),
                                      AppIconButton(
                                        iconAsset: AppIcons.info,
                                        tooltip: 'File Info',
                                        size: AppIconButtonSize.sm,
                                        onPressed: () => _handleStat(item),
                                      ),
                                      const SizedBox(width: AppSpacing.xxs),
                                      AppIconButton(
                                        iconAsset: AppIcons.export,
                                        tooltip: 'Pull to PC',
                                        size: AppIconButtonSize.sm,
                                        onPressed: () => _handlePullFile(item),
                                      ),
                                    ],
                                  ),
                                  onTap: item.isDirectory
                                      ? () => _navigateInto(item.name)
                                      : null,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(String raw) {
    final bytes = int.tryParse(raw);
    if (bytes == null) return raw;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
