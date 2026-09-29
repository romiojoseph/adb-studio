import 'package:flutter/material.dart';
import '../../core/adb_controller.dart';
import '../../core/mdns_service_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_svg_icon.dart';

class DiscoveredServicesCard extends StatefulWidget {
  final AdbController controller;
  final void Function(String ipPort)? onSelectPairIp;
  final void Function(String ipPort)? onSelectConnectIp;

  const DiscoveredServicesCard({
    super.key,
    required this.controller,
    this.onSelectPairIp,
    this.onSelectConnectIp,
  });

  @override
  State<DiscoveredServicesCard> createState() => _DiscoveredServicesCardState();
}

class _DiscoveredServicesCardState extends State<DiscoveredServicesCard> {
  List<AdbMdnsService> _services = [];
  bool _isLoading = false;
  String? _actionInProgressIp;

  @override
  void initState() {
    super.initState();
    _refreshServices();
  }

  Future<void> _refreshServices() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final services = await widget.controller.service.getMdnsServices();
      if (mounted) {
        setState(() => _services = services);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _services = []);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleConnect(String ipPort) async {
    setState(() => _actionInProgressIp = ipPort);
    try {
      final res = await widget.controller.service.wirelessConnect(ipPort);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.isSuccess ? 'Connected to $ipPort' : 'Connect failed: ${res.stdout}',
            ),
          ),
        );
        await widget.controller.refreshDevices();
        await _refreshServices();
      }
    } finally {
      if (mounted) setState(() => _actionInProgressIp = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: ShapeDecoration(
                  color: AppColors.primary4.withValues(alpha: 0.15),
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                  ),
                ),
                child: const AppSvgIcon(AppIcons.scan, color: AppColors.primary4, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Discovered Wireless Devices (mDNS)',
                  style: AppTypography.heading6.copyWith(
                    color: AppColors.neutral12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              AppIconButton(
                iconAsset: AppIcons.arrowClockwise,
                size: AppIconButtonSize.sm,
                isLoading: _isLoading,
                tooltip: 'Scan local network for ADB services',
                onPressed: _refreshServices,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Automatic discovery of Android devices advertising wireless debugging on the local Wi-Fi.',
            style: AppTypography.caption.copyWith(color: AppColors.neutral7),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_services.isEmpty)
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
                  const AppSvgIcon(AppIcons.info, color: AppColors.neutral7, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _isLoading
                          ? 'Scanning local Wi-Fi for wireless devices...'
                          : 'No wireless ADB services detected yet. Enable Wireless Debugging on your phone or scan with QR code.',
                      style: AppTypography.caption.copyWith(color: AppColors.neutral8),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _services.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final s = _services[index];
                final isBusy = _actionInProgressIp == s.ipPort;
                final isPairing = s.isPairing;
                final isAlreadyConnected = widget.controller.devices.any(
                  (d) => d.isOnline && (d.serial.contains(s.ipPort) || d.serial.startsWith(s.serviceName)),
                );

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: ShapeDecoration(
                    color: AppColors.neutral1,
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                      side: const BorderSide(color: AppColors.neutral3, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      AppSvgIcon(
                        isPairing ? AppIcons.deviceMobileCamera : AppIcons.cellTower,
                        color: isPairing ? AppColors.warning : AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.serviceName,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.neutral12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                if (isPairing)
                                  const AppBadge.warning(
                                    label: 'Ready to Pair',
                                    size: AppBadgeSize.md,
                                  )
                                else if (isAlreadyConnected)
                                  const AppBadge.success(
                                    label: 'Connected',
                                    size: AppBadgeSize.md,
                                  )
                                else
                                  const AppBadge.info(
                                    label: 'Available',
                                    size: AppBadgeSize.md,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.ipPort,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.neutral7,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isPairing)
                        AppButton(
                          onPressed: () {
                            if (widget.onSelectPairIp != null) {
                              widget.onSelectPairIp!(s.ipPort);
                            }
                          },
                          icon: const AppSvgIcon(AppIcons.key, size: 14),
                          text: 'Enter Code',
                          size: AppButtonSize.sm,
                        )
                      else if (isAlreadyConnected)
                        AppButton.outlined(
                          onPressed: null,
                          icon: const AppSvgIcon(AppIcons.checkCircle, size: 14, color: AppColors.success),
                          text: 'Connected',
                          size: AppButtonSize.sm,
                        )
                      else
                        AppButton(
                          onPressed: isBusy ? null : () => _handleConnect(s.ipPort),
                          isLoading: isBusy,
                          icon: const AppSvgIcon(AppIcons.plusCircle, size: 14),
                          text: 'Connect',
                          size: AppButtonSize.sm,
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
