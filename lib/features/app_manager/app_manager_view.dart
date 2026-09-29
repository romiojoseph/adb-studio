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
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state_view.dart';
import 'permission_dictionary.dart';

class AppManagerView extends StatefulWidget {
  const AppManagerView({super.key});

  @override
  State<AppManagerView> createState() => _AppManagerViewState();
}

class _AppManagerViewState extends State<AppManagerView> {
  bool _onlyThirdParty = true;
  List<String> _packages = [];
  String _searchQuery = '';
  String? _selectedPackage;
  bool _isLoadingList = false;

  // Selected App Details
  bool _isLoadingDetails = false;
  String _appVersion = '';
  String _installPath = '';
  List<AppPermission> _permissions = [];
  bool _allowBackup = false;
  bool _isBmgrEnrolled = false;
  String _permSearchQuery = '';
  String _permFilterMode = 'all'; // 'all', 'granted', 'not_granted'
  String? _lastLoadedSerial;

  int get _grantedCount => _permissions.where((p) => p.isGranted).length;
  int get _notGrantedCount => _permissions.length - _grantedCount;

  final _searchController = TextEditingController();
  final _permSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    PermissionDictionary.instance.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _permSearchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AdbController.of(context);
    final currentSerial = controller.selectedDevice?.serial;
    if (currentSerial != null &&
        (currentSerial != _lastLoadedSerial || _packages.isEmpty) &&
        !_isLoadingList) {
      _loadPackages();
    }
  }

  Future<void> _loadPackages() async {
    final controller = AdbController.of(context);
    final serial = controller.selectedDevice?.serial;
    if (serial == null) return;
    _lastLoadedSerial = serial;

    setState(() => _isLoadingList = true);
    try {
      final list = _onlyThirdParty
          ? await controller.service.listThirdPartyApps(serial)
          : await controller.service.listAllApps(serial);

      if (mounted) {
        setState(() {
          _packages = list;
          if (_selectedPackage != null && !list.contains(_selectedPackage)) {
            _selectedPackage = null;
            _appVersion = '';
            _installPath = '';
            _permissions = [];
            _allowBackup = false;
            _isBmgrEnrolled = false;
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  Future<void> _loadAppDetails(String package) async {
    final controller = AdbController.of(context);
    final serial = controller.selectedDevice?.serial;
    if (serial == null) return;

    setState(() {
      _selectedPackage = package;
      _isLoadingDetails = true;
      _appVersion = '';
      _installPath = '';
      _permissions = [];
      _allowBackup = false;
      _isBmgrEnrolled = false;
      _permSearchQuery = '';
      _permFilterMode = 'all';
      _permSearchController.clear();
    });

    try {
      final details = await controller.service.getAppFullDetails(
        serial,
        package,
      );

      if (mounted && _selectedPackage == package) {
        final rawPerms = details['permissions'] as List<dynamic>? ?? [];
        final parsedPerms = <AppPermission>[];
        for (final item in rawPerms) {
          if (item is Map<String, dynamic>) {
            parsedPerms.add(AppPermission.fromMap(item));
          } else if (item is String) {
            parsedPerms.add(AppPermission(permission: item, isGranted: true));
          }
        }

        setState(() {
          _appVersion = details['version'] as String? ?? 'Unknown';
          _installPath = details['installPath'] as String? ?? 'Unknown';
          _permissions = parsedPerms;
          _allowBackup = details['allowBackup'] as bool? ?? false;
          _isBmgrEnrolled = details['isBmgrEnrolled'] as bool? ?? false;
        });
      }
    } catch (_) {
    } finally {
      if (mounted && _selectedPackage == package) {
        setState(() => _isLoadingDetails = false);
      }
    }
  }

  Future<void> _handleInstallApk() async {
    final controller = AdbController.of(context);
    final serial = controller.selectedDevice?.serial;
    if (serial == null) return;

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['apk'],
      dialogTitle: 'Select APK file to install',
    );
    if (file == null || file.path == null) return;
    if (!mounted) return;

    final apkPath = file.path!;
    final fileName = file.name;

    final confirm = await ConfirmDialog.show(
      context,
      title: 'Install Application',
      message: 'Do you want to install $fileName onto the device?',
      confirmLabel: 'Install APK',
    );
    if (!confirm) return;
    if (!mounted) return;

    // Show persistent install progress modal
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ApkInstallProgressModal(
        fileName: fileName,
        apkPath: apkPath,
        serial: serial,
        controller: controller,
        onFinished: () {
          if (mounted) {
            _loadPackages();
          }
        },
      ),
    );
  }

  Future<void> _handleExportAppList() async {
    final controller = AdbController.of(context);
    final serial = controller.selectedDevice?.serial;
    if (serial == null) return;

    final folder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select folder to save packages list',
    );
    if (folder == null) return;

    final dest =
        '$folder\\installed_packages_${DateTime.now().millisecondsSinceEpoch}.txt';
    try {
      final record = await controller.service.exportAppList(serial, dest);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record.isSuccess
                  ? 'Package list exported to $dest'
                  : 'Failed: ${record.stderr}',
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

  Future<void> _handleLaunchApp() async {
    if (_selectedPackage == null) return;
    final controller = AdbController.of(context);
    final serial = controller.selectedDevice?.serial;
    if (serial == null) return;

    try {
      final record = await controller.service.launchApp(
        serial,
        _selectedPackage!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record.isSuccess
                  ? 'Launched $_selectedPackage'
                  : 'Launch failed: ${record.stderr}',
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

  Future<void> _handleOpenAppInfo() async {
    if (_selectedPackage == null) return;
    final controller = AdbController.of(context);
    final serial = controller.selectedDevice?.serial;
    if (serial == null) return;

    try {
      final record = await controller.service.openAppInfo(
        serial,
        _selectedPackage!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record.isSuccess
                  ? 'Opened Settings on phone for $_selectedPackage'
                  : 'Failed: ${record.stderr}',
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

  Future<void> _handleForceStop() async {
    if (_selectedPackage == null) return;
    final controller = AdbController.of(context);
    final serial = controller.selectedDevice?.serial;
    if (serial == null) return;

    final confirm = await ConfirmDialog.show(
      context,
      title: 'Force Stop App',
      message: 'Are you sure you want to force-stop $_selectedPackage?',
      confirmLabel: 'Force Stop',
    );
    if (!confirm) return;

    try {
      final record = await controller.service.forceStopApp(
        serial,
        _selectedPackage!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record.isSuccess
                  ? 'Force stopped $_selectedPackage'
                  : 'Failed: ${record.stderr}',
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

  @override
  Widget build(BuildContext context) {
    final controller = AdbController.of(context);
    final device = controller.selectedDevice;

    if (device == null) {
      return const EmptyStateView(
        iconAsset: AppIcons.circlesFour,
        title: 'No Device Selected',
        description:
            'Connect and select a device to inspect and manage packages.',
      );
    }

    final filtered = _packages
        .where((pkg) => pkg.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Package List & Controls
          Expanded(
            flex: 5,
            child: Column(
              children: [
                Container(
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
                  child: Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _searchController,
                          hint: 'Search packages...',
                          prefixIcon: const AppSvgIcon(
                            AppIcons.magnifyingGlass,
                            size: 18,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? AppIconButton(
                                  iconAsset: AppIcons.x,
                                  size: AppIconButtonSize.sm,
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          ),
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        decoration: ShapeDecoration(
                          color: AppColors.neutral1,
                          shape: ContinuousRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.sm),
                            side: const BorderSide(
                              color: AppColors.neutral3,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildScopeTab(true, '3rd-Party'),
                            _buildScopeTab(false, 'All Apps'),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppButton.secondary(
                        text: 'Export',
                        icon: const AppSvgIcon(AppIcons.fileText, size: 20),
                        size: AppButtonSize.md,
                        onPressed: _handleExportAppList,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      AppButton(
                        text: 'Install APK',
                        icon: const AppSvgIcon(AppIcons.plus, size: 20),
                        size: AppButtonSize.md,
                        onPressed: _handleInstallApk,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      AppIconButton.secondary(
                        iconAsset: AppIcons.arrowClockwise,
                        tooltip: 'Refresh packages',
                        size: AppIconButtonSize.md,
                        onPressed: _loadPackages,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
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
                    child: _isLoadingList
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No matching packages found.',
                              style: AppTypography.body.copyWith(
                                color: AppColors.neutral8,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final pkg = filtered[index];
                              final isSelected = pkg == _selectedPackage;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                  vertical: AppSpacing.xxxs,
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
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: AppSpacing.xxs,
                                    ),
                                    leading: AppSvgIcon(
                                      AppIcons.circlesFour,
                                      color: isSelected
                                          ? AppColors.primary4
                                          : AppColors.neutral7,
                                      size: 20,
                                    ),
                                    title: Text(
                                      pkg,
                                      style: AppTypography.body.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? AppColors.neutral9
                                            : AppColors.neutral7,
                                      ),
                                    ),
                                    onTap: () => _loadAppDetails(pkg),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),

          // Right: Package Details & Actions
          Expanded(
            flex: 4,
            child: _selectedPackage == null
                ? Container(
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
                    child: const EmptyStateView(
                      iconAsset: AppIcons.play,
                      title: 'No App Selected',
                      description:
                          'Select an application package from the list to inspect its version, install path, backup flags, and declared permissions.',
                    ),
                  )
                : Container(
                    padding: AppSpacing.paddingLg,
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            AppSvgIcon(
                              AppIcons.circlesFour,
                              color: AppColors.neutral7,
                              size: 44,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SelectableText(
                                          _selectedPackage!,
                                          style: AppTypography.subtitle
                                              .copyWith(
                                                color: AppColors.neutral9,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      if (!_isLoadingDetails) ...[
                                        AppBadge(
                                          label: _allowBackup
                                              ? 'ALLOW_BACKUP'
                                              : 'NO_BACKUP',
                                          tone: _allowBackup
                                              ? AppBadgeTone.success
                                              : AppBadgeTone.neutral,
                                          size: AppBadgeSize.sm,
                                        ),
                                        if (_isBmgrEnrolled) ...[
                                          const SizedBox(width: AppSpacing.xs),
                                          const AppBadge(
                                            label: 'BMGR ENROLLED',
                                            tone: AppBadgeTone.info,
                                            size: AppBadgeSize.sm,
                                          ),
                                        ],
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Version: ${_isLoadingDetails ? "..." : _appVersion}',
                                    style: AppTypography.label.copyWith(
                                      color: AppColors.neutral7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Divider(height: 2, color: AppColors.neutral3),
                        const SizedBox(height: AppSpacing.md),

                        // Action Buttons Row (Launch, Force-Stop, App Info)
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            AppButton(
                              text: 'Launch',
                              icon: const AppSvgIcon(AppIcons.play, size: 20),
                              size: AppButtonSize.md,
                              onPressed: _handleLaunchApp,
                            ),
                            AppButton.secondary(
                              text: 'Force Stop',
                              icon: const AppSvgIcon(AppIcons.x, size: 20),
                              size: AppButtonSize.md,
                              onPressed: _handleForceStop,
                            ),
                            AppButton.secondary(
                              text: 'App Info (Phone)',
                              icon: const AppSvgIcon(AppIcons.pencil, size: 20),
                              size: AppButtonSize.md,
                              onPressed: _handleOpenAppInfo,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        Text(
                          'Install Path:',
                          style: AppTypography.body.copyWith(
                            color: AppColors.neutral8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          _isLoadingDetails ? '...' : _installPath,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: AppColors.neutral7,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        Text(
                          'Google Cloud Backup:',
                          style: AppTypography.body.copyWith(
                            color: AppColors.neutral8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isLoadingDetails
                              ? '...'
                              : _allowBackup
                              ? (_isBmgrEnrolled
                                    ? 'Allowed by manifest and currently enrolled in Android Backup Manager (bmgr).'
                                    : 'Allowed in manifest (allowBackup="true"), eligible for cloud and device backup.')
                              : 'Disabled by application manifest (allowBackup="false"). Excluded from cloud backups.',
                          style: AppTypography.label.copyWith(
                            color: _allowBackup
                                ? AppColors.success
                                : AppColors.neutral7,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Permissions Section with Classification & Search Filter
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Permissions (${_permissions.length}):',
                                  style: AppTypography.body.copyWith(
                                    color: AppColors.neutral8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_permissions.isNotEmpty) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  AppBadge(
                                    label: '$_grantedCount GRANTED',
                                    tone: AppBadgeTone.success,
                                    size: AppBadgeSize.sm,
                                  ),
                                  const SizedBox(width: 4),
                                  AppBadge(
                                    label: '$_notGrantedCount REQUESTED',
                                    tone: AppBadgeTone.warning,
                                    size: AppBadgeSize.sm,
                                  ),
                                ],
                              ],
                            ),
                            if (_permissions.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Row(
                                children: [
                                  Container(
                                    decoration: ShapeDecoration(
                                      color: AppColors.neutral1,
                                      shape: ContinuousRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.sm,
                                        ),
                                        side: const BorderSide(
                                          color: AppColors.neutral3,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildPermFilterTab(
                                          'all',
                                          'All (${_permissions.length})',
                                        ),
                                        _buildPermFilterTab(
                                          'granted',
                                          'Granted ($_grantedCount)',
                                        ),
                                        _buildPermFilterTab(
                                          'not_granted',
                                          'Requested ($_notGrantedCount)',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: AppTextField(
                                      controller: _permSearchController,
                                      hint: 'Filter permissions...',
                                      prefixIcon: const AppSvgIcon(
                                        AppIcons.magnifyingGlass,
                                        size: 14,
                                        color: AppColors.neutral8,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.xs,
                                            vertical: AppSpacing.xs,
                                          ),
                                      onChanged: (val) => setState(
                                        () => _permSearchQuery = val
                                            .trim()
                                            .toLowerCase(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Expanded(
                          child: Container(
                            padding: AppSpacing.paddingSm,
                            decoration: ShapeDecoration(
                              color: AppColors.neutral1,
                              shape: ContinuousRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.sm,
                                ),
                                side: const BorderSide(
                                  color: AppColors.neutral3,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: _isLoadingDetails
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _permissions.isEmpty
                                ? Center(
                                    child: Text(
                                      'No declared permissions or system package',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.neutral8,
                                      ),
                                    ),
                                  )
                                : Builder(
                                    builder: (context) {
                                      final filtered = _permissions.where((
                                        permItem,
                                      ) {
                                        if (_permFilterMode == 'granted' &&
                                            !permItem.isGranted) {
                                          return false;
                                        }
                                        if (_permFilterMode == 'not_granted' &&
                                            permItem.isGranted) {
                                          return false;
                                        }

                                        if (_permSearchQuery.isEmpty) {
                                          return true;
                                        }
                                        final info = PermissionDictionary
                                            .instance
                                            .getInfo(permItem.permission);
                                        return permItem.permission
                                                .toLowerCase()
                                                .contains(_permSearchQuery) ||
                                            info.name.toLowerCase().contains(
                                              _permSearchQuery,
                                            ) ||
                                            info.description
                                                .toLowerCase()
                                                .contains(_permSearchQuery) ||
                                            (info.group != null &&
                                                info.group!
                                                    .toLowerCase()
                                                    .contains(
                                                      _permSearchQuery,
                                                    ));
                                      }).toList();

                                      if (filtered.isEmpty) {
                                        return Center(
                                          child: Text(
                                            _permSearchQuery.isNotEmpty
                                                ? 'No permissions match "$_permSearchQuery"'
                                                : 'No ${_permFilterMode == 'granted' ? 'granted' : 'requested-only'} permissions found',
                                            style: AppTypography.caption
                                                .copyWith(
                                                  color: AppColors.neutral8,
                                                ),
                                          ),
                                        );
                                      }

                                      return Column(
                                        children: [
                                          // Informative Banner
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.sm,
                                              vertical: 6,
                                            ),
                                            margin: const EdgeInsets.only(
                                              bottom: AppSpacing.xs,
                                            ),
                                            decoration: ShapeDecoration(
                                              color: AppColors.neutral2,
                                              shape: ContinuousRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppSpacing.sm,
                                                    ),
                                                side: const BorderSide(
                                                  color: AppColors.neutral3,
                                                  width: 1,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const AppSvgIcon(
                                                  AppIcons.info,
                                                  size: 14,
                                                  color: AppColors.info,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Requested = Declared in manifest • Granted = Active & authorized by user/system',
                                                    style: AppTypography.label
                                                        .copyWith(
                                                          color: AppColors
                                                              .neutral7,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: ListView.separated(
                                              itemCount: filtered.length,
                                              separatorBuilder: (_, _) =>
                                                  const SizedBox(
                                                    height: AppSpacing.xxs,
                                                  ),
                                              itemBuilder: (context, index) {
                                                final permItem =
                                                    filtered[index];
                                                final perm =
                                                    permItem.permission;
                                                final info =
                                                    PermissionDictionary
                                                        .instance
                                                        .getInfo(perm);

                                                return Container(
                                                  padding: AppSpacing.paddingMd,
                                                  decoration: ShapeDecoration(
                                                    color: AppColors.neutral2,
                                                    shape: ContinuousRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            AppSpacing.sm,
                                                          ),
                                                      side: const BorderSide(
                                                        color:
                                                            AppColors.neutral3,
                                                        width: 1,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          AppSvgIcon(
                                                            permItem.isGranted
                                                                ? AppIcons
                                                                      .checkCircle
                                                                : AppIcons
                                                                      .minus,
                                                            size: 16,
                                                            color:
                                                                permItem
                                                                    .isGranted
                                                                ? AppColors
                                                                      .success
                                                                : AppColors
                                                                      .warning,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              info.name,
                                                              style: AppTypography
                                                                  .body
                                                                  .copyWith(
                                                                    color: AppColors
                                                                        .neutral8,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                            ),
                                                          ),
                                                          AppBadge(
                                                            label:
                                                                permItem
                                                                    .isGranted
                                                                ? 'GRANTED'
                                                                : 'REQUESTED',
                                                            tone:
                                                                permItem
                                                                    .isGranted
                                                                ? AppBadgeTone
                                                                      .success
                                                                : AppBadgeTone
                                                                      .warning,
                                                            size:
                                                                AppBadgeSize.sm,
                                                          ),
                                                          if (info.group !=
                                                              null) ...[
                                                            const SizedBox(
                                                              width:
                                                                  AppSpacing.xs,
                                                            ),
                                                            AppBadge(
                                                              label: info.group!
                                                                  .toUpperCase(),
                                                              tone: AppBadgeTone
                                                                  .info,
                                                              size: AppBadgeSize
                                                                  .sm,
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        info.description,
                                                        style: AppTypography
                                                            .label
                                                            .copyWith(
                                                              color: AppColors
                                                                  .neutral7,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: SelectableText(
                                                              perm,
                                                              style: const TextStyle(
                                                                fontFamily:
                                                                    'monospace',
                                                                fontSize: 11,
                                                                color: AppColors
                                                                    .neutral7,
                                                              ),
                                                            ),
                                                          ),
                                                          Text(
                                                            permItem.isGranted
                                                                ? 'Declared in manifest • Active'
                                                                : 'Declared in manifest • Not granted',
                                                            style: AppTypography
                                                                .caption
                                                                .copyWith(
                                                                  color:
                                                                      permItem
                                                                          .isGranted
                                                                      ? AppColors
                                                                            .success
                                                                      : AppColors
                                                                            .neutral7,
                                                                  fontStyle:
                                                                      FontStyle
                                                                          .italic,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeTab(bool isThirdParty, String label) {
    final isSelected = _onlyThirdParty == isThirdParty;
    return InkWell(
      onTap: () {
        setState(() => _onlyThirdParty = isThirdParty);
        _loadPackages();
      },
      borderRadius: BorderRadius.circular(AppSpacing.xxs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neutral3 : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.xxs),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            color: isSelected ? AppColors.neutral8 : AppColors.neutral6,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildPermFilterTab(String mode, String label) {
    final isSelected = _permFilterMode == mode;
    return InkWell(
      onTap: () => setState(() => _permFilterMode = mode),
      borderRadius: BorderRadius.circular(AppSpacing.xxs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neutral3 : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.xxs),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            color: isSelected ? AppColors.neutral8 : AppColors.neutral6,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ApkInstallProgressModal extends StatefulWidget {
  final String fileName;
  final String apkPath;
  final String serial;
  final AdbController controller;
  final VoidCallback onFinished;

  const _ApkInstallProgressModal({
    required this.fileName,
    required this.apkPath,
    required this.serial,
    required this.controller,
    required this.onFinished,
  });

  @override
  State<_ApkInstallProgressModal> createState() =>
      _ApkInstallProgressModalState();
}

class _ApkInstallProgressModalState extends State<_ApkInstallProgressModal> {
  bool _isInstalling = true;
  bool _isSuccess = false;
  String _statusMessage = 'Streaming and installing APK...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startInstall();
  }

  Future<void> _startInstall() async {
    try {
      final record = await widget.controller.service.installApk(
        widget.serial,
        widget.apkPath,
      );
      if (!mounted) return;

      setState(() {
        _isInstalling = false;
        if (record.isSuccess) {
          _isSuccess = true;
          _statusMessage = 'Successfully installed ${widget.fileName}';
        } else {
          _isSuccess = false;
          _statusMessage = 'Installation failed';
          _errorMessage = record.stderr.isNotEmpty
              ? record.stderr
              : (record.stdout.isNotEmpty ? record.stdout : 'Unknown error');
        }
      });
      widget.onFinished();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInstalling = false;
        _isSuccess = false;
        _statusMessage = 'Installation failed';
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppModal(
      title: _isInstalling
          ? 'Installing APK'
          : (_isSuccess ? 'Installation Complete' : 'Installation Failed'),
      maxWidth: 480,
      showCloseButton: !_isInstalling,
      contentPadding: const EdgeInsets.all(AppSpacing.xl),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (_isInstalling) ...[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.md),
              ] else if (_isSuccess) ...[
                const AppSvgIcon(
                  AppIcons.checkCircle,
                  color: AppColors.success,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.md),
              ] else ...[
                const AppSvgIcon(AppIcons.x, color: AppColors.error, size: 24),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.fileName,
                      style: AppTypography.subtitle.copyWith(
                        color: AppColors.neutral9,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusMessage,
                      style: AppTypography.caption.copyWith(
                        color: _isSuccess
                            ? AppColors.success
                            : (_isInstalling
                                  ? AppColors.neutral7
                                  : AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: AppSpacing.paddingSm,
              decoration: ShapeDecoration(
                color: AppColors.neutral2,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  side: const BorderSide(color: AppColors.neutral3, width: 1),
                ),
              ),
              child: SelectableText(
                _errorMessage!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: AppTypography.captionSize,
                  color: AppColors.error,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!_isInstalling)
          AppButton(
            onPressed: () => Navigator.of(context).pop(),
            text: 'Close',
            size: AppButtonSize.md,
          ),
      ],
    );
  }
}
