import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'core/adb_controller.dart';
import 'core/adb_service.dart';
import 'core/app_theme.dart';
import 'features/app_manager/app_manager_view.dart';
import 'features/connection/connection_view.dart';
import 'features/device_info/device_info_view.dart';
import 'features/file_manager/file_manager_view.dart';
import 'features/screen_tools/screen_tools_view.dart';
import 'widgets/app_badge.dart';
import 'widgets/app_svg_icon.dart';
import 'widgets/command_bar.dart';
import 'widgets/window_buttons.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(1000, 650),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const AdbStudioApp());
}

class AdbStudioApp extends StatefulWidget {
  const AdbStudioApp({super.key});

  @override
  State<AdbStudioApp> createState() => _AdbStudioAppState();
}

class _AdbStudioAppState extends State<AdbStudioApp> {
  late final AdbService _adbService;
  late final AdbController _adbController;

  @override
  void initState() {
    super.initState();
    _adbService = AdbService();
    _adbController = AdbController(service: _adbService);
  }

  @override
  void dispose() {
    _adbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdbScope(
      controller: _adbController,
      child: MaterialApp(
        title: 'ADB Studio',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        theme: AppTheme.darkTheme,
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedTabIndex = 0;
  final Set<int> _visitedTabs = {0};

  static const _views = <Widget>[
    ConnectionView(),
    DeviceInfoView(),
    FileManagerView(),
    AppManagerView(),
    ScreenToolsView(),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = AdbController.of(context);
    final selectedDevice = controller.selectedDevice;

    return Scaffold(
      backgroundColor: AppColors.neutral0,
      body: Column(
        children: [
          // Top Navigation Header
          _buildHeader(context, controller, selectedDevice),
          const Divider(height: 1, color: AppColors.neutral3),

          // Body: Navigation Rail + Active View
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedTabIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedTabIndex = index;
                      _visitedTabs.add(index);
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: AppColors.neutral1,
                  indicatorColor: AppColors.primary4.withValues(alpha: 0.15),
                  selectedIconTheme: const IconThemeData(
                    color: AppColors.primary4,
                  ),
                  unselectedIconTheme: const IconThemeData(
                    color: AppColors.neutral9,
                  ),
                  selectedLabelTextStyle: AppTypography.tagline.copyWith(
                    color: AppColors.primary4,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelTextStyle: AppTypography.tagline.copyWith(
                    color: AppColors.neutral9,
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: AppSvgIcon(AppIcons.cellTower, size: 20),
                      selectedIcon: AppSvgIcon(
                        AppIcons.cellTower,
                        size: 20,
                        color: AppColors.primary4,
                      ),
                      label: Text('Connect'),
                    ),
                    NavigationRailDestination(
                      icon: AppSvgIcon(AppIcons.info, size: 20),
                      selectedIcon: AppSvgIcon(
                        AppIcons.info,
                        size: 20,
                        color: AppColors.primary4,
                      ),
                      label: Text('Device'),
                    ),
                    NavigationRailDestination(
                      icon: AppSvgIcon(AppIcons.folderSimple, size: 20),
                      selectedIcon: AppSvgIcon(
                        AppIcons.folder,
                        size: 20,
                        color: AppColors.primary4,
                      ),
                      label: Text('Files'),
                    ),
                    NavigationRailDestination(
                      icon: AppSvgIcon(AppIcons.circlesFour, size: 20),
                      selectedIcon: AppSvgIcon(
                        AppIcons.circlesFour,
                        size: 20,
                        color: AppColors.primary4,
                      ),
                      label: Text('Apps'),
                    ),

                    NavigationRailDestination(
                      icon: AppSvgIcon(AppIcons.deviceMobileCamera, size: 20),
                      selectedIcon: AppSvgIcon(
                        AppIcons.deviceMobileCamera,
                        size: 20,
                        color: AppColors.primary4,
                      ),
                      label: Text('Screen'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1, color: AppColors.neutral3),
                Expanded(
                  child: Container(
                    color: AppColors.neutral0,
                    child: IndexedStack(
                      index: _selectedTabIndex,
                      children: List.generate(_views.length, (i) {
                        return _visitedTabs.contains(i)
                            ? _views[i]
                            : const SizedBox.shrink();
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Command Status Bar
          const CommandBar(),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AdbController controller,
    selectedDevice,
  ) {
    return DragToMoveArea(
      child: Container(
        height: 50,
        padding: const EdgeInsets.only(left: AppSpacing.md),
        color: AppColors.neutral1,
        child: Row(
          children: [
            Text(
              'ADB Studio',
              style: AppTypography.heading6.copyWith(
                color: AppColors.neutral12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),

            // Target Device Selector
            if (controller.devices.isNotEmpty) ...[
              DropdownButtonHideUnderline(
                child: DropdownButton(
                  value: selectedDevice?.serial,
                  dropdownColor: AppColors.neutral2,
                  icon: const AppSvgIcon(
                    AppIcons.caretDown,
                    size: 14,
                    color: AppColors.neutral10,
                  ),
                  items: controller.devices.map((d) {
                    return DropdownMenuItem(
                      value: d.serial,
                      child: Row(
                        children: [
                          AppSvgIcon(
                            d.isWireless ? AppIcons.cellTower : AppIcons.usb,
                            size: 14,
                            color: d.isOnline
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            d.displayName,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.neutral12,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '(${d.serial})',
                            style: AppTypography.tagline.copyWith(
                              color: AppColors.neutral8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (serial) {
                    final found = controller.devices.where(
                      (d) => d.serial == serial,
                    );
                    if (found.isNotEmpty) {
                      controller.selectDevice(found.first);
                    }
                  },
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 5,
                ),
                decoration: ShapeDecoration(
                  color: AppColors.neutral2,
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.neutral3, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const AppSvgIcon(
                      AppIcons.linkBreak,
                      size: 14,
                      color: AppColors.neutral8,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'No Devices Attached',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.neutral8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),

            // System ADB status tag
            if (controller.resolvedAdbPath != null)
              const AppBadge.success(label: 'ADB Bridge Active')
            else
              const AppBadge.danger(label: 'ADB Missing'),
            const SizedBox(width: AppSpacing.sm),

            // Custom Frameless Window Controls (Minimize, Maximize, Close)
            const WindowControls(),
          ],
        ),
      ),
    );
  }
}
