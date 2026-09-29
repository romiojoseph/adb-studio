import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/network_adapter_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_svg_icon.dart';

class NetworkAdaptersCard extends StatefulWidget {
  final void Function(String subnetPrefix)? onSelectSubnet;

  const NetworkAdaptersCard({super.key, this.onSelectSubnet});

  @override
  State<NetworkAdaptersCard> createState() => _NetworkAdaptersCardState();
}

class _NetworkAdaptersCardState extends State<NetworkAdaptersCard> {
  List<NetworkAdapterInfo>? _adapters;
  String _rawOutput = '';
  bool _isLoading = false;
  bool _isExpanded = false;
  bool _showRaw = false;

  Future<void> _fetchIpconfig() async {
    setState(() {
      _isLoading = true;
      _isExpanded = true;
    });

    try {
      final res = await Process.run(
        'ipconfig',
        [],
        runInShell: false,
        stdoutEncoding: utf8,
      );
      final raw = res.stdout.toString();
      final parsed = NetworkAdapterInfo.parseIpconfig(raw);

      if (mounted) {
        setState(() {
          _rawOutput = raw;
          _adapters = parsed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _rawOutput = 'Error running ipconfig: $e';
          _adapters = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Expanded(
                child: Text(
                  'Network Configuration (ipconfig)',
                  style: AppTypography.heading6.copyWith(
                    color: AppColors.neutral12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_adapters != null && _adapters!.isNotEmpty)
                AppButton.secondary(
                  onPressed: () => setState(() => _showRaw = !_showRaw),
                  icon: AppSvgIcon(
                    _showRaw ? AppIcons.cards : AppIcons.terminalWindow,
                    size: 16,
                  ),
                  text: _showRaw ? 'Structured View' : 'Raw Output',
                  size: AppButtonSize.sm,
                ),
              const SizedBox(width: AppSpacing.xs),
              AppButton(
                onPressed: _isLoading ? null : _fetchIpconfig,
                isLoading: _isLoading,
                icon: const AppSvgIcon(AppIcons.arrowClockwise, size: 16),
                text: _adapters == null ? 'Run ipconfig' : 'Refresh',
                size: AppButtonSize.sm,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Inspect host IPv4/IPv6 network adapters, Wi-Fi subnets, and gateways for wireless pairing.',
            style: AppTypography.caption.copyWith(color: AppColors.neutral7),
          ),

          if (_isExpanded && _adapters != null) ...[
            const SizedBox(height: AppSpacing.md),
            if (_showRaw)
              Container(
                width: double.infinity,
                padding: AppSpacing.paddingMd,
                decoration: ShapeDecoration(
                  color: AppColors.neutral1,
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                    side: const BorderSide(color: AppColors.neutral3, width: 1),
                  ),
                ),
                child: SelectableText(
                  _rawOutput,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.neutral11,
                  ),
                ),
              )
            else if (_adapters!.isEmpty)
              Container(
                padding: AppSpacing.paddingMd,
                decoration: ShapeDecoration(
                  color: AppColors.neutral1,
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                    side: const BorderSide(color: AppColors.neutral3, width: 1),
                  ),
                ),
                child: Text(
                  'No network adapters found.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral8,
                  ),
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
        ],
      ),
    );
  }

  Widget _buildAdapterCard(NetworkAdapterInfo adapter) {
    final isConnected = !adapter.isDisconnected && adapter.ipv4 != null;

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: ShapeDecoration(
        color: AppColors.neutral1,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          side: BorderSide(
            color: isConnected ? AppColors.neutral4 : AppColors.neutral3,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Adapter Title + Status Badge
          Row(
            children: [
              AppSvgIcon(
                adapter.name.toLowerCase().contains('wi-fi') ||
                        adapter.name.toLowerCase().contains('wireless')
                    ? AppIcons.cellTower
                    : adapter.name.toLowerCase().contains('ethernet')
                    ? AppIcons.hardDrives
                    : AppIcons.devices,
                size: 18,
                color: isConnected ? AppColors.primary4 : AppColors.neutral7,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  adapter.name,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isConnected)
                const AppBadge.success(label: 'Connected')
              else
                const AppBadge.paused(label: 'Disconnected'),
            ],
          ),

          if (isConnected) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(color: AppColors.neutral3, height: 1),
            const SizedBox(height: AppSpacing.sm),

            // Fields Table
            _buildFieldRow(
              label: 'IPv4 Address',
              value: adapter.ipv4!,
              isPrimary: true,
              trailingAction: widget.onSelectSubnet != null
                  ? AppButton.outlined(
                      size: AppButtonSize.sm,
                      onPressed: () =>
                          widget.onSelectSubnet!(adapter.subnetPrefix),
                      icon: const AppSvgIcon(AppIcons.arrowSquareOut, size: 12),
                      text: 'Use ${adapter.subnetPrefix}',
                    )
                  : null,
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
            width: 130,
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.neutral7,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                SelectableText(
                  value,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
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
                    size: 12,
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
