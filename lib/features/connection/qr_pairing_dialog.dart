import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/adb_controller.dart';
import '../../core/mdns_service_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_svg_icon.dart';

class QrPairingDialog extends StatefulWidget {
  final AdbController controller;

  const QrPairingDialog({
    super.key,
    required this.controller,
  });

  static Future<void> show(BuildContext context, AdbController controller) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => QrPairingDialog(controller: controller),
    );
  }

  @override
  State<QrPairingDialog> createState() => _QrPairingDialogState();
}

class _QrPairingDialogState extends State<QrPairingDialog> {
  late String _serviceName;
  late String _pairingCode;
  Timer? _mdnsTimer;
  bool _isAutoPairing = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _regenerateCredentials();
    _startMdnsMonitoring();
  }

  @override
  void dispose() {
    _mdnsTimer?.cancel();
    super.dispose();
  }

  void _regenerateCredentials() {
    final rand = Random();
    final randomSuffix = (1000 + rand.nextInt(9000)).toString();
    _serviceName = 'adb-studio-$randomSuffix';
    _pairingCode = (100000 + rand.nextInt(900000)).toString();
    _statusMessage = 'Waiting for Android device to scan...';
    _isSuccess = false;
    if (mounted) setState(() {});
  }

  String get _qrPayload => 'WIFI:T:ADB;S:$_serviceName;P:$_pairingCode;;';

  void _startMdnsMonitoring() {
    _mdnsTimer?.cancel();
    _mdnsTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted || _isAutoPairing || _isSuccess) return;
      await _checkAndPairDiscoveredServices();
    });
  }

  Future<void> _checkAndPairDiscoveredServices() async {
    try {
      final services = await widget.controller.service.getMdnsServices();
      final target = services.firstWhere(
        (s) => s.isPairing && s.serviceName.contains(_serviceName),
        orElse: () => const AdbMdnsService(serviceName: '', serviceType: '', ipPort: ''),
      );

      if (target.isValid && !_isAutoPairing && !_isSuccess) {
        setState(() {
          _isAutoPairing = true;
          _statusMessage = 'Device detected (${target.ipPort})! Auto-pairing...';
        });

        final result = await widget.controller.service.wirelessPair(
          target.ipPort,
          _pairingCode,
        );

        if (!mounted) return;

        if (result.isSuccess) {
          setState(() {
            _isSuccess = true;
            _statusMessage = 'Successfully paired with ${target.ipPort}!';
          });
          await widget.controller.refreshDevices();
        } else {
          setState(() {
            _isAutoPairing = false;
            _statusMessage = 'Device detected (${target.ipPort}). Waiting for handshake...';
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AppModal(
      title: 'Pair Device via QR Code',
      subtitle: 'Wireless Debugging (Android 11+)',
      maxWidth: 820,
      contentPadding: const EdgeInsets.all(AppSpacing.xl),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // QR Code Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.xl),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 280,
                  height: 280,
                  child: QrImageView(
                    data: _qrPayload,
                    version: QrVersions.auto,
                    size: 280.0,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PIN: $_pairingCode',
                      style: AppTypography.caption.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _pairingCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pairing PIN copied')),
                        );
                      },
                      child: const AppSvgIcon(
                        AppIcons.copy,
                        size: 16,
                        color: AppColors.neutral5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xl),

          // Instructions & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'How to Pair',
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.neutral12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildStep(1, 'Connect your PC & phone to the same Wi-Fi network.'),
                _buildStep(2, 'On phone: Settings > Developer options > Wireless debugging.'),
                _buildStep(3, 'Enable Wireless debugging and tap "Pair device with QR code".'),
                _buildStep(4, 'Scan this QR code with your phone camera.'),
                const SizedBox(height: AppSpacing.lg),

                // Status Banner
                Container(
                  padding: AppSpacing.paddingSm,
                  decoration: ShapeDecoration(
                    color: _isSuccess
                        ? AppColors.success.withValues(alpha: 0.12)
                        : _isAutoPairing
                            ? AppColors.info.withValues(alpha: 0.12)
                            : AppColors.neutral1,
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                      side: BorderSide(
                        color: _isSuccess
                            ? AppColors.success.withValues(alpha: 0.35)
                            : _isAutoPairing
                                ? AppColors.info.withValues(alpha: 0.35)
                                : AppColors.neutral3,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isSuccess)
                        const AppSvgIcon(AppIcons.checkCircle, color: AppColors.success, size: 18)
                      else if (_isAutoPairing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const AppSvgIcon(AppIcons.scan, color: AppColors.primary4, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _statusMessage ?? '',
                          style: AppTypography.caption.copyWith(
                            color: _isSuccess
                                ? AppColors.success
                                : AppColors.neutral11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        AppButton.outlined(
          onPressed: _regenerateCredentials,
          icon: const AppSvgIcon(AppIcons.arrowClockwise, size: 16),
          text: 'New QR Code',
          size: AppButtonSize.md,
        ),
        AppButton(
          onPressed: () => Navigator.of(context).pop(),
          text: _isSuccess ? 'Done' : 'Close',
          size: AppButtonSize.md,
        ),
      ],
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.neutral3,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: AppTypography.caption.copyWith(
                color: AppColors.primary4,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.caption.copyWith(color: AppColors.neutral8),
            ),
          ),
        ],
      ),
    );
  }
}
