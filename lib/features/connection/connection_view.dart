import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/adb_controller.dart';
import '../../core/mdns_service_model.dart';
import '../../core/network_adapter_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_svg_icon.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/confirm_dialog.dart';
import 'qr_pairing_dialog.dart';

class ConnectionView extends StatefulWidget {
  const ConnectionView({super.key});

  @override
  State<ConnectionView> createState() => _ConnectionViewState();
}

class _ConnectionViewState extends State<ConnectionView> {
  final _pairIpController = TextEditingController();
  final _pairPortController = TextEditingController();
  final _pairCodeController = TextEditingController();
  final _connectIpController = TextEditingController();
  final _connectPortController = TextEditingController();
  final _customPathController = TextEditingController();

  bool _isPairing = false;
  bool _isConnecting = false;
  bool _isServerOp = false;

  // Discovered mDNS services state
  List<AdbMdnsService> _discoveredServices = [];
  bool _isLoadingDiscoveredServices = false;
  String? _mdnsActionInProgressIp;

  // Environment & Network Diagnostics state
  String? _envRunningCommand;
  String _envOutput = '';
  bool _showEnvRaw = false;

  List<NetworkAdapterInfo>? _adapters;
  String _rawIpconfigOutput = '';
  bool _isLoadingIpconfig = false;
  bool _showIpconfigRaw = false;

  @override
  void initState() {
    super.initState();
    _prefillSubnetPrefix();
  }

  Future<void> _fetchIpconfig() async {
    setState(() => _isLoadingIpconfig = true);
    try {
      final res = await Process.run('ipconfig', [], runInShell: false);
      final raw = res.stdout.toString();
      final parsed = NetworkAdapterInfo.parseIpconfig(raw);

      if (mounted) {
        setState(() {
          _rawIpconfigOutput = raw;
          _adapters = parsed;
          _isLoadingIpconfig = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _rawIpconfigOutput = 'Error running ipconfig: $e';
          _adapters = [];
          _isLoadingIpconfig = false;
        });
      }
    }
  }

  Future<void> _refreshDiscoveredServices(AdbController controller) async {
    if (!mounted) return;
    setState(() => _isLoadingDiscoveredServices = true);
    try {
      final services = await controller.service.getMdnsServices();
      if (mounted) {
        setState(() => _discoveredServices = services);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _discoveredServices = []);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDiscoveredServices = false);
      }
    }
  }

  Future<void> _handleMdnsConnect(
    AdbController controller,
    String ipPort,
  ) async {
    setState(() => _mdnsActionInProgressIp = ipPort);
    try {
      final res = await controller.service.wirelessConnect(ipPort);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.isSuccess
                  ? 'Connected to $ipPort'
                  : 'Connect failed: ${res.stdout}',
            ),
          ),
        );
        await controller.refreshDevices();
        await _refreshDiscoveredServices(controller);
      }
    } finally {
      if (mounted) setState(() => _mdnsActionInProgressIp = null);
    }
  }

  Future<void> _prefillSubnetPrefix() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final candidateIps = <String>[];

      for (final iface in interfaces) {
        final nameLower = iface.name.toLowerCase();
        // Ignore virtual adapters (WSL, Hyper-V, VirtualBox, VMware, Docker)
        if (nameLower.contains('vethernet') ||
            nameLower.contains('wsl') ||
            nameLower.contains('virtual') ||
            nameLower.contains('vmware') ||
            nameLower.contains('docker') ||
            nameLower.contains('loopback')) {
          continue;
        }

        for (final addr in iface.addresses) {
          candidateIps.add(addr.address);
        }
      }

      // Prioritize standard Wi-Fi/LAN (192.168.x.x), then 10.x.x.x
      String? selectedIp = candidateIps.cast<String?>().firstWhere(
        (ip) => ip!.startsWith('192.168.'),
        orElse: () => candidateIps.cast<String?>().firstWhere(
          (ip) => ip!.startsWith('10.'),
          orElse: () => null,
        ),
      );

      String prefix = '192.168.';
      if (selectedIp != null) {
        final segments = selectedIp.split('.');
        if (segments.length == 4) {
          prefix = '${segments[0]}.${segments[1]}.${segments[2]}.';
        }
      }

      if (mounted) {
        if (_pairIpController.text.isEmpty ||
            _pairIpController.text.startsWith('172.')) {
          _pairIpController.text = prefix;
        }
        if (_connectIpController.text.isEmpty ||
            _connectIpController.text.startsWith('172.')) {
          _connectIpController.text = prefix;
        }
      }
    } catch (_) {
      if (mounted) {
        if (_pairIpController.text.isEmpty) {
          _pairIpController.text = '192.168.';
        }
        if (_connectIpController.text.isEmpty) {
          _connectIpController.text = '192.168.';
        }
      }
    }
  }

  @override
  void dispose() {
    _pairIpController.dispose();
    _pairPortController.dispose();
    _pairCodeController.dispose();
    _connectIpController.dispose();
    _connectPortController.dispose();
    _customPathController.dispose();
    super.dispose();
  }

  Future<void> _handleWirelessPair(AdbController controller) async {
    final ip = _pairIpController.text.trim();
    final port = _pairPortController.text.trim();
    final code = _pairCodeController.text.trim();

    if (ip.isEmpty || port.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter IP address, Port, and Pairing code'),
        ),
      );
      return;
    }

    final ipPort = '$ip:$port';

    setState(() => _isPairing = true);
    try {
      final res = await controller.service.wirelessPair(ipPort, code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.isSuccess
                  ? 'Pairing successful'
                  : 'Pairing failed: ${res.stderr}',
            ),
          ),
        );
        if (res.isSuccess) {
          _pairCodeController.clear();
          await controller.refreshDevices();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPairing = false);
    }
  }

  Future<void> _handleWirelessConnect(AdbController controller) async {
    final ip = _connectIpController.text.trim();
    final port = _connectPortController.text.trim();

    if (ip.isEmpty || port.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter IP address and Port')),
      );
      return;
    }

    final ipPort = '$ip:$port';

    setState(() => _isConnecting = true);
    try {
      final res = await controller.service.wirelessConnect(ipPort);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.isSuccess
                  ? 'Connected to $ipPort'
                  : 'Connect failed: ${res.stdout}',
            ),
          ),
        );
        await controller.refreshDevices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _handleWirelessDisconnect(
    AdbController controller,
    String ipPort,
  ) async {
    final confirm = await ConfirmDialog.show(
      context,
      title: 'Disconnect Device',
      message: 'Are you sure you want to disconnect $ipPort?',
      confirmLabel: 'Disconnect',
    );
    if (!confirm) return;

    try {
      await controller.service.wirelessDisconnect(ipPort);
      await controller.refreshDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handleKillServer(AdbController controller) async {
    final confirm = await ConfirmDialog.show(
      context,
      title: 'Kill ADB Server',
      message:
          'This will terminate the background adb daemon. It will automatically restart on the next command.',
      confirmLabel: 'Kill Server',
      isDestructive: true,
    );
    if (!confirm) return;

    setState(() => _isServerOp = true);
    try {
      await controller.service.killServer();
      await controller.refreshDevices();
    } finally {
      if (mounted) setState(() => _isServerOp = false);
    }
  }

  Future<void> _handleStartServer(AdbController controller) async {
    setState(() => _isServerOp = true);
    try {
      await controller.service.startServer();
      await controller.refreshDevices();
    } finally {
      if (mounted) setState(() => _isServerOp = false);
    }
  }

  Future<void> _handleRestartServer(AdbController controller) async {
    setState(() => _isServerOp = true);
    try {
      final res = await controller.service.restartServer();
      await controller.refreshAdbInfo();
      await controller.refreshDevices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.isSuccess
                  ? 'ADB Server restarted successfully'
                  : 'Failed to restart server: ${res.stderr}',
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
    } finally {
      if (mounted) setState(() => _isServerOp = false);
    }
  }

  Future<void> _handleCleanStaleConnections(AdbController controller) async {
    setState(() => _isServerOp = true);
    try {
      final staleDevices =
          controller.devices.where((d) => !d.isOnline).toList();

      int cleanedCount = 0;
      for (final dev in staleDevices) {
        if (dev.isWireless) {
          await controller.service.wirelessDisconnect(dev.serial);
          cleanedCount++;
        }
      }

      await controller.service.reconnectOffline();
      await controller.refreshDevices();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cleanedCount > 0
                  ? 'Cleaned $cleanedCount stale / offline connection(s)'
                  : 'No stale devices found. Active devices preserved.',
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
    } finally {
      if (mounted) setState(() => _isServerOp = false);
    }
  }

  Future<void> _handleOpenDeveloperOptions(AdbController controller) async {
    final serial = controller.selectedDevice?.serial;
    if (serial == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an active device first')),
      );
      return;
    }
    try {
      final record = await controller.service.openDeveloperOptions(serial);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record.isSuccess
                  ? 'Opened Developer Options on device'
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

  Future<void> _runEnvCheck(
    String label,
    String command,
    List<String> args,
  ) async {
    const allowedCommands = {'flutter'};
    if (!allowedCommands.contains(command)) {
      setState(() {
        _envOutput =
            'Execution of command "$command" is blocked by safety policy.';
        _envRunningCommand = null;
      });
      return;
    }

    setState(() {
      _envRunningCommand = label;
      _envOutput = 'Running $command ${args.join(' ')}...\n';
    });

    try {
      final res = await Process.run(command, args, runInShell: false);

      final combined = StringBuffer();
      if (res.stdout.toString().trim().isNotEmpty) {
        combined.writeln(res.stdout.toString().trim());
      }
      if (res.stderr.toString().trim().isNotEmpty) {
        if (combined.isNotEmpty) combined.writeln();
        combined.writeln('STDERR:');
        combined.writeln(res.stderr.toString().trim());
      }
      if (combined.isEmpty) {
        combined.writeln(
          'Completed with exit code ${res.exitCode} (no output)',
        );
      }

      if (mounted) {
        setState(() {
          _envOutput = combined.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _envOutput =
              'Error executing $command: $e\nEnsure Flutter SDK is installed and added to system PATH.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _envRunningCommand = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AdbController.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ADB Status & Path Card
          _buildAdbStatusCard(controller),
          const SizedBox(height: AppSpacing.lg),

          // Connected & Discovered Devices Card
          _buildDevicesCard(controller),
          const SizedBox(height: AppSpacing.lg),

          // Wireless Pair & Connect Card
          _buildWirelessSetupCard(controller),
          const SizedBox(height: AppSpacing.lg),

          // Network Configuration & Environment Diagnostics Card
          _buildNetworkAndEnvironmentCard(),
        ],
      ),
    );
  }

  Widget _buildAdbStatusCard(AdbController controller) {
    final isAdbReady = controller.resolvedAdbPath != null;

    return Row(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Opacity(
            opacity: isAdbReady ? 1.0 : 0.35,
            child: ColorFiltered(
              colorFilter: isAdbReady
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                  : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
              child: Image.asset('assets/AppIcon.png', fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAdbReady ? 'ADB Bridge Connected' : 'ADB Bridge Not Found',
                style: AppTypography.heading6.copyWith(
                  color: AppColors.neutral8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                controller.resolvedAdbPath ??
                    'Install Android platform-tools in C:\\platform-tools or system PATH',
                style: AppTypography.label.copyWith(color: AppColors.neutral7),
                overflow: TextOverflow.ellipsis,
              ),
              if (controller.adbVersion != null) ...[
                const SizedBox(height: 4),
                Text(
                  controller.adbVersion!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral8,
                  ),
                ),
              ],
            ],
          ),
        ),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            AppButton.secondary(
              size: AppButtonSize.md,
              onPressed: () async {
                final file = await FilePicker.pickFile(
                  dialogTitle: 'Select adb.exe',
                  type: FileType.custom,
                  allowedExtensions: ['exe'],
                );
                if (file?.path != null) {
                  controller.service.resolver.setCustomPath(file!.path);
                  await controller.refreshAdbInfo();
                  await controller.refreshDevices();
                }
              },
              icon: const AppSvgIcon(AppIcons.folderOpen, size: 20),
              text: 'Browse...',
            ),
            AppButton.secondary(
              size: AppButtonSize.md,
              onPressed: () => controller.refreshAdbInfo(),
              icon: const AppSvgIcon(AppIcons.magnifyingGlass, size: 20),
              text: 'Re-detect',
            ),
            if (isAdbReady)
              AppButton.secondary(
                size: AppButtonSize.md,
                onPressed: _isServerOp
                    ? null
                    : () => _handleRestartServer(controller),
                icon: const AppSvgIcon(AppIcons.arrowClockwise, size: 20),
                text: 'Restart Server',
              )
            else
              AppButton.secondary(
                size: AppButtonSize.md,
                onPressed: _isServerOp
                    ? null
                    : () => _handleStartServer(controller),
                icon: const AppSvgIcon(AppIcons.play, size: 20),
                text: 'Start Server',
              ),
            if (isAdbReady)
              AppButton.danger(
                size: AppButtonSize.md,
                onPressed: _isServerOp
                    ? null
                    : () => _handleKillServer(controller),
                icon: const AppSvgIcon(AppIcons.x, size: 20),
                text: 'Kill Server',
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDevicesCard(AdbController controller) {
    return AppCard(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Text(
                'Connected Devices (${controller.devices.length})',
                style: AppTypography.heading6.copyWith(
                  color: AppColors.neutral8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (controller.selectedDevice != null) ...[
                AppButton.secondary(
                  size: AppButtonSize.md,
                  onPressed: () => _handleOpenDeveloperOptions(controller),
                  icon: const AppSvgIcon(AppIcons.terminalWindow, size: 20),
                  text: 'Open Dev Options on Phone',
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              AppButton.secondary(
                size: AppButtonSize.md,
                onPressed: _isServerOp
                    ? null
                    : () => _handleCleanStaleConnections(controller),
                icon: const AppSvgIcon(AppIcons.broom, size: 20),
                text: 'Clean Ghost Devices',
              ),
              const SizedBox(width: AppSpacing.xs),
              AppButton.secondary(
                size: AppButtonSize.md,
                isLoading: controller.isLoadingDevices,
                onPressed: controller.isLoadingDevices
                    ? null
                    : () {
                        controller.refreshDevices();
                        _refreshDiscoveredServices(controller);
                      },
                icon: const AppSvgIcon(AppIcons.arrowClockwise, size: 20),
                text: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (controller.devices.isEmpty)
            Container(
              width: double.infinity,
              padding: AppSpacing.paddingXl,
              child: Column(
                children: [
                  const AppSvgIcon(
                    AppIcons.linkBreak,
                    size: 36,
                    color: AppColors.neutral7,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'No Android devices attached',
                    style: AppTypography.body.copyWith(
                      color: AppColors.neutral8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Connect via USB with USB Debugging enabled, or pair via Wi-Fi below.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral7,
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = AppSpacing.sm;
                const columns = 3;
                final totalSpacing = spacing * (columns - 1);
                final itemWidth =
                    ((constraints.maxWidth - totalSpacing) / columns)
                        .floorToDouble();

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: controller.devices.map((dev) {
                    final isSelected =
                        controller.selectedDevice?.serial == dev.serial;

                    return SizedBox(
                      width: itemWidth,
                      child: Container(
                        padding: AppSpacing.paddingLg,
                        decoration: ShapeDecoration(
                          color: AppColors.neutral2,
                          shape: ContinuousRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.xl),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary4
                                  : AppColors.neutral3,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Device icon, name & badges
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppSvgIcon(
                                  dev.isWireless
                                      ? AppIcons.deviceMobileCamera
                                      : AppIcons.usb,
                                  color: dev.isOnline
                                      ? AppColors.primary4
                                      : AppColors.neutral7,
                                  size: 32,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              dev.displayName,
                                              style: AppTypography.subtitle
                                                  .copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.neutral9,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(
                                              width: AppSpacing.xs,
                                            ),
                                            const AppSvgIcon(
                                              AppIcons.checkCircle,
                                              color: AppColors.primary4,
                                              size: 20,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Wrap(
                                        spacing: AppSpacing.xs,
                                        runSpacing: 2,
                                        children: [
                                          if (dev.isOnline)
                                            const AppBadge.success(
                                              label: 'ONLINE',
                                            )
                                          else
                                            AppBadge.warning(
                                              label: dev.state.toUpperCase(),
                                            ),
                                          if (dev.isWireless)
                                            const AppBadge.info(
                                              label: 'WIRELESS',
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Serial: ${dev.serial}',
                              style: AppTypography.body.copyWith(
                                color: AppColors.neutral8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Product: ${dev.product.isEmpty ? "N/A" : dev.product}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.neutral7,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!isSelected || dev.isWireless) ...[
                              const SizedBox(height: AppSpacing.md),
                              const Divider(
                                color: AppColors.neutral3,
                                height: 1,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              // Actions below details
                              Row(
                                children: [
                                  if (dev.isWireless) ...[
                                    AppButton.outlined(
                                      size: AppButtonSize.md,
                                      icon: const AppSvgIcon(
                                        AppIcons.linkBreak,
                                        size: 20,
                                      ),
                                      text: 'Unlink',
                                      tooltip: 'Disconnect wireless device',
                                      onPressed: () =>
                                          _handleWirelessDisconnect(
                                            controller,
                                            dev.serial,
                                          ),
                                    ),
                                    if (!isSelected)
                                      const SizedBox(width: AppSpacing.xs),
                                  ],
                                  if (!isSelected)
                                    Expanded(
                                      child: AppButton(
                                        size: AppButtonSize.md,
                                        icon: const AppSvgIcon(
                                          AppIcons.checkCircleDuotone,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            controller.selectDevice(dev),
                                        text: 'Select',
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

          // Discovered Wireless Devices (mDNS) Section
          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.neutral3, height: 2),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text(
                'Discovered on Local Wi-Fi (mDNS)',
                style: AppTypography.body.copyWith(
                  color: AppColors.neutral8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              AppIconButton(
                iconAsset: AppIcons.arrowClockwise,
                size: AppIconButtonSize.md,
                isLoading: _isLoadingDiscoveredServices,
                tooltip: 'Scan local network for ADB services',
                onPressed: () => _refreshDiscoveredServices(controller),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Devices advertising wireless debugging on the local network.',
            style: AppTypography.label.copyWith(color: AppColors.neutral7),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_discoveredServices.isEmpty)
            Container(
              padding: AppSpacing.paddingMd,
              decoration: ShapeDecoration(
                color: AppColors.neutral1,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  side: const BorderSide(color: AppColors.neutral3, width: 1),
                ),
              ),
              child: Row(
                children: [
                  const AppSvgIcon(
                    AppIcons.info,
                    color: AppColors.neutral7,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _isLoadingDiscoveredServices
                          ? 'Scanning local Wi-Fi for wireless devices...'
                          : 'No wireless ADB services detected yet. Enable Wireless Debugging on your phone.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.neutral8,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = AppSpacing.sm;
                const columns = 3;
                final totalSpacing = spacing * (columns - 1);
                final itemWidth =
                    ((constraints.maxWidth - totalSpacing) / columns)
                        .floorToDouble();

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _discoveredServices.map((s) {
                    final isBusy = _mdnsActionInProgressIp == s.ipPort;
                    final isPairing = s.isPairing;
                    final isAlreadyConnected = controller.devices.any(
                      (d) =>
                          d.isOnline &&
                          (d.serial.contains(s.ipPort) ||
                              d.serial.startsWith(s.serviceName)),
                    );

                    return SizedBox(
                      width: itemWidth,
                      child: Container(
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppSvgIcon(
                                  isPairing
                                      ? AppIcons.deviceMobileCamera
                                      : AppIcons.cellTower,
                                  color: isPairing
                                      ? AppColors.warning
                                      : AppColors.success,
                                  size: 32,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.serviceName,
                                        style: AppTypography.subtitle.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.neutral9,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Wrap(
                                        spacing: AppSpacing.xs,
                                        runSpacing: 2,
                                        children: [
                                          if (isPairing)
                                            const AppBadge.warning(
                                              label: 'READY TO PAIR',
                                            )
                                          else if (isAlreadyConnected)
                                            const AppBadge.success(
                                              label: 'CONNECTED',
                                            )
                                          else
                                            const AppBadge.info(
                                              label: 'AVAILABLE',
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'IP:Port: ${s.ipPort}',
                              style: AppTypography.body.copyWith(
                                color: AppColors.neutral8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Type: ${isPairing ? "Pairing Service" : "Connect Service"}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.neutral7,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const Divider(color: AppColors.neutral3, height: 1),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: isPairing
                                      ? AppButton(
                                          size: AppButtonSize.md,
                                          onPressed: () {
                                            setState(() {
                                              final parts = s.ipPort.split(':');
                                              if (parts.length == 2) {
                                                _pairIpController.text =
                                                    parts[0];
                                                _pairPortController.text =
                                                    parts[1];
                                              } else {
                                                _pairIpController.text =
                                                    s.ipPort;
                                              }
                                            });
                                          },
                                          icon: const AppSvgIcon(
                                            AppIcons.key,
                                            size: 20,
                                          ),
                                          text: 'Use for Pair',
                                        )
                                      : isAlreadyConnected
                                      ? const AppButton.outlined(
                                          size: AppButtonSize.md,
                                          onPressed: null,
                                          icon: AppSvgIcon(
                                            AppIcons.checkCircle,
                                            size: 14,
                                            color: AppColors.success,
                                          ),
                                          text: 'Connected',
                                        )
                                      : AppButton(
                                          size: AppButtonSize.md,
                                          onPressed: isBusy
                                              ? null
                                              : () => _handleMdnsConnect(
                                                  controller,
                                                  s.ipPort,
                                                ),
                                          isLoading: isBusy,
                                          icon: const AppSvgIcon(
                                            AppIcons.broadcast,
                                            size: 20,
                                          ),
                                          text: 'Connect',
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildWirelessSetupCard(AdbController controller) {
    return AppCard(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Wireless Debugging (Pair & Connect)',
                  style: AppTypography.heading6.copyWith(
                    color: AppColors.neutral8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AppButton.secondary(
                onPressed: () => QrPairingDialog.show(context, controller),
                icon: const AppSvgIcon(AppIcons.qrCode, size: 20),
                text: 'Pair via QR',
                size: AppButtonSize.md,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Pair a new device with Wi-Fi pairing code (Android 11+) or connect directly to an existing ADB port.',
            style: AppTypography.caption.copyWith(color: AppColors.neutral7),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Wireless Pair
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pair with Pairing Code',
                      style: AppTypography.body.copyWith(
                        color: AppColors.neutral8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Developer Options > Wireless Debugging > Pair with pairing code',
                      style: AppTypography.label.copyWith(
                        color: AppColors.neutral7,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: AppTextField(
                            controller: _pairIpController,
                            label: 'IP Address',
                            hint: 'e.g. 192.168.1.50',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            controller: _pairPortController,
                            label: 'Port',
                            hint: 'e.g. 37123',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _pairCodeController,
                      label: 'Pairing Code',
                      hint: '6-digit Wi-Fi pairing code',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerRight,
                      child: AppButton(
                        onPressed: _isPairing
                            ? null
                            : () => _handleWirelessPair(controller),
                        isLoading: _isPairing,
                        icon: const AppSvgIcon(AppIcons.link, size: 20),
                        text: 'Pair Device',
                        size: AppButtonSize.md,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              // Right Column: Wireless Connect
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direct Connect',
                      style: AppTypography.body.copyWith(
                        color: AppColors.neutral8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Connect directly after pairing, or for fixed ADB port (5555)',
                      style: AppTypography.label.copyWith(
                        color: AppColors.neutral7,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: AppTextField(
                            controller: _connectIpController,
                            label: 'IP Address',
                            hint: 'e.g. 192.168.1.50',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            controller: _connectPortController,
                            label: 'Port',
                            hint: '12345',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm + 48),
                    Align(
                      alignment: Alignment.centerRight,
                      child: AppButton(
                        onPressed: _isConnecting
                            ? null
                            : () => _handleWirelessConnect(controller),
                        isLoading: _isConnecting,
                        icon: const AppSvgIcon(AppIcons.link, size: 20),
                        text: 'Connect',
                        size: AppButtonSize.md,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkAndEnvironmentCard() {
    final isRunning = _envRunningCommand != null;

    return AppCard(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Host Network Adapters (ipconfig) Section
          Row(
            children: [
              Expanded(
                child: Text(
                  'Host Network Configuration (ipconfig)',
                  style: AppTypography.heading6.copyWith(
                    color: AppColors.neutral8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_adapters != null && _adapters!.isNotEmpty)
                AppButton.secondary(
                  onPressed: () =>
                      setState(() => _showIpconfigRaw = !_showIpconfigRaw),
                  icon: AppSvgIcon(
                    _showIpconfigRaw ? AppIcons.cards : AppIcons.terminalWindow,
                    size: 20,
                  ),
                  text: _showIpconfigRaw ? 'Structured View' : 'Raw Output',
                  size: AppButtonSize.md,
                ),
              const SizedBox(width: AppSpacing.xs),
              AppButton(
                onPressed: _isLoadingIpconfig ? null : _fetchIpconfig,
                isLoading: _isLoadingIpconfig,
                icon: const AppSvgIcon(AppIcons.arrowClockwise, size: 20),
                text: _adapters == null ? 'Run ipconfig' : 'Refresh',
                size: AppButtonSize.md,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Inspect host IPv4/IPv6 network adapters, Wi-Fi subnets, and gateways for wireless pairing.',
            style: AppTypography.label.copyWith(color: AppColors.neutral7),
          ),
          if (_adapters != null) ...[
            const SizedBox(height: AppSpacing.md),
            if (_showIpconfigRaw)
              Container(
                width: double.infinity,
                padding: AppSpacing.paddingLg,
                decoration: ShapeDecoration(
                  color: AppColors.neutral2,
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.xl),
                    side: const BorderSide(color: AppColors.neutral3, width: 1),
                  ),
                ),
                child: SelectableText(
                  _rawIpconfigOutput,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.neutral11,
                  ),
                ),
              )
            else if (_adapters!.isEmpty)
              Container(
                padding: AppSpacing.paddingLg,
                decoration: ShapeDecoration(
                  color: AppColors.neutral2,
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.xl),
                    side: const BorderSide(color: AppColors.neutral3, width: 1),
                  ),
                ),
                child: Text(
                  'No network adapters found.',
                  style: AppTypography.body.copyWith(color: AppColors.neutral8),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _adapters!.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final adapter = _adapters![index];
                  return _buildAdapterCard(adapter);
                },
              ),
          ],

          // Divider between Network and Environment
          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.neutral3, height: 2),
          const SizedBox(height: AppSpacing.lg),

          // 2. Flutter & Toolchain Diagnostics Section
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flutter & Toolchain Diagnostics',
                      style: AppTypography.body.copyWith(
                        color: AppColors.neutral8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Verify Flutter device recognition, toolchain health, and detected ADB path.',
                      style: AppTypography.label.copyWith(
                        color: AppColors.neutral7,
                      ),
                    ),
                  ],
                ),
              ),
              if (_envOutput.isNotEmpty)
                AppButton.secondary(
                  onPressed: () => setState(() => _showEnvRaw = !_showEnvRaw),
                  icon: AppSvgIcon(
                    _showEnvRaw ? AppIcons.cards : AppIcons.terminalWindow,
                    size: 20,
                  ),
                  text: _showEnvRaw ? 'Structured View' : 'Raw Output',
                  size: AppButtonSize.md,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton.secondary(
                size: AppButtonSize.md,
                onPressed: isRunning
                    ? null
                    : () => _runEnvCheck('flutter devices', 'flutter', [
                        'devices',
                      ]),
                isLoading: isRunning && _envRunningCommand == 'flutter devices',
                icon: const AppSvgIcon(AppIcons.devices, size: 20),
                text: 'flutter devices',
              ),
              AppButton.secondary(
                size: AppButtonSize.md,
                onPressed: isRunning
                    ? null
                    : () =>
                          _runEnvCheck('flutter doctor', 'flutter', ['doctor']),
                isLoading: isRunning && _envRunningCommand == 'flutter doctor',
                icon: const AppSvgIcon(AppIcons.info, size: 20),
                text: 'flutter doctor',
              ),
              AppButton.secondary(
                size: AppButtonSize.md,
                onPressed: isRunning
                    ? null
                    : () => _runEnvCheck('flutter doctor -v', 'flutter', [
                        'doctor',
                        '-v',
                      ]),
                isLoading:
                    isRunning && _envRunningCommand == 'flutter doctor -v',
                icon: const AppSvgIcon(AppIcons.terminalWindow, size: 20),
                text: 'flutter doctor -v',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 340),
            padding: AppSpacing.paddingLg,
            decoration: ShapeDecoration(
              color: AppColors.neutral2,
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.xl),
                side: const BorderSide(color: AppColors.neutral3, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      _envRunningCommand != null
                          ? 'RUNNING: $_envRunningCommand'
                          : 'DIAGNOSTIC OUTPUT',
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: AppTypography.bodySize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neutral8,
                      ),
                    ),
                    const Spacer(),
                    if (_envOutput.isNotEmpty) ...[
                      AppIconButton(
                        iconAsset: AppIcons.copy,
                        size: AppIconButtonSize.md,
                        tooltip: 'Copy Output',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _envOutput));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Diagnostic output copied to clipboard',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      AppIconButton(
                        iconAsset: AppIcons.x,
                        size: AppIconButtonSize.md,
                        tooltip: 'Clear Output',
                        onPressed: () => setState(() => _envOutput = ''),
                      ),
                    ],
                  ],
                ),
                const Divider(color: AppColors.neutral3, height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: _envOutput.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Text(
                              'Click any diagnostic button above to run checks against your local Flutter environment.',
                              style: AppTypography.label.copyWith(
                                color: AppColors.neutral7,
                              ),
                            ),
                          )
                        : _showEnvRaw
                        ? SelectableText(
                            _envOutput,
                            style: const TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 12,
                              color: AppColors.neutral11,
                              height: 1.4,
                            ),
                          )
                        : _buildStructuredEnvOutput(_envOutput),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStructuredEnvOutput(String output) {
    final lines = output.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return const SizedBox(height: 4);

        if (trimmed.startsWith('[√]') ||
            trimmed.startsWith('[v]') ||
            trimmed.startsWith('• [√]')) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSvgIcon(
                  AppIcons.checkCircle,
                  color: AppColors.success,
                  size: 14,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (trimmed.startsWith('[!]') || trimmed.startsWith('!')) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSvgIcon(
                  AppIcons.info,
                  color: AppColors.warning,
                  size: 14,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (trimmed.startsWith('[✗]') ||
            trimmed.startsWith('[x]') ||
            trimmed.startsWith('✗')) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSvgIcon(
                  AppIcons.x,
                  color: AppColors.danger4,
                  size: 14,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      color: AppColors.danger4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(
            line,
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: AppTypography.bodySize,
              color: AppColors.neutral7,
              height: 1.5,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAdapterCard(NetworkAdapterInfo adapter) {
    final isConnected = !adapter.isDisconnected && adapter.ipv4 != null;

    return Container(
      padding: AppSpacing.paddingLg,
      decoration: ShapeDecoration(
        color: AppColors.neutral2,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xl),
          side: BorderSide(
            color: isConnected ? AppColors.neutral4 : AppColors.neutral3,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSvgIcon(
                adapter.name.toLowerCase().contains('wi-fi') ||
                        adapter.name.toLowerCase().contains('wireless')
                    ? AppIcons.cellTower
                    : adapter.name.toLowerCase().contains('ethernet')
                    ? AppIcons.hardDrives
                    : AppIcons.devices,
                size: 32,
                color: isConnected ? AppColors.primary4 : AppColors.neutral7,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  adapter.name,
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.neutral9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isConnected)
                const AppBadge.success(label: 'CONNECTED')
              else
                const AppBadge.paused(label: 'DISCONNECTED'),
            ],
          ),
          if (isConnected) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(color: AppColors.neutral3, height: 1),
            const SizedBox(height: AppSpacing.sm),
            _buildFieldRow(
              label: 'IPv4 Address',
              value: adapter.ipv4!,
              isPrimary: true,
              trailingAction: AppButton.outlined(
                size: AppButtonSize.md,
                onPressed: () {
                  setState(() {
                    _pairIpController.text = adapter.subnetPrefix;
                    _connectIpController.text = adapter.subnetPrefix;
                  });
                },
                icon: const AppSvgIcon(AppIcons.arrowSquareOut, size: 20),
                text: 'Use ${adapter.subnetPrefix}',
              ),
            ),
            if (adapter.subnetMask != null)
              _buildFieldRow(label: 'Subnet Mask', value: adapter.subnetMask!),
            if (adapter.gateway != null && adapter.gateway!.isNotEmpty)
              _buildFieldRow(label: 'Default Gateway', value: adapter.gateway!),
            if (adapter.ipv6 != null)
              _buildFieldRow(label: 'IPv6 Address', value: adapter.ipv6!),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldRow({
    required String label,
    required String value,
    bool isPrimary = false,
    Widget? trailingAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: AppTypography.body.copyWith(color: AppColors.neutral7),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                SelectableText(
                  value,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppTypography.bodySize,
                    fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
                    color: isPrimary ? AppColors.primary4 : AppColors.neutral10,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied $value to clipboard')),
                    );
                  },
                  child: const AppSvgIcon(
                    AppIcons.copy,
                    size: 16,
                    color: AppColors.neutral6,
                  ),
                ),
              ],
            ),
          ),
          ?trailingAction,
        ],
      ),
    );
  }
}
