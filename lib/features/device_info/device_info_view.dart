import 'package:flutter/material.dart';
import '../../core/adb_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_svg_icon.dart';
import '../../widgets/empty_state_view.dart';

class DeviceInfoView extends StatefulWidget {
  const DeviceInfoView({super.key});

  @override
  State<DeviceInfoView> createState() => _DeviceInfoViewState();
}

class _DeviceInfoViewState extends State<DeviceInfoView> {
  bool _isLoading = false;
  String? _errorMessage;
  String? _loadedSerial;
  bool? _lastDeviceOnline;

  String _model = '';
  String _manufacturer = '';
  String _androidVersion = '';
  String _apiLevel = '';
  String _buildNumber = '';
  String _serialNumber = '';
  String _uptime = '';
  String _batteryRaw = '';
  String _storageRaw = '';
  String _ramRaw = '';
  String _screenSize = '';
  String _screenDensity = '';
  String _screenOffTimeout = '';
  String _cpuAbi = '';
  String _bluetoothStatus = '';
  Map<String, String> _networkInfo = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AdbController.of(context);
    final currentDevice = controller.selectedDevice;
    final currentSerial = currentDevice?.serial;
    final isOnline = currentDevice?.isOnline ?? false;

    if (currentSerial == null) {
      _loadedSerial = null;
      _lastDeviceOnline = null;
    } else if ((currentSerial != _loadedSerial ||
            isOnline != _lastDeviceOnline) &&
        !_isLoading) {
      _fetchDeviceInfo(currentSerial, controller);
    }
  }

  Future<void> _fetchDeviceInfo(String serial, AdbController controller) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadedSerial = serial;
      _lastDeviceOnline = controller.selectedDevice?.isOnline;
    });

    try {
      final s = controller.service;

      final results = await Future.wait([
        s.getAllProps(serial),
        s.getBattery(serial),
        s.getWifiRaw(serial),
        s.getBatchHardwareAndSettings(serial),
      ]);

      final props = results[0] as Map<String, String>;
      final batteryRaw = results[1] as String;
      final wifiRaw = results[2] as String;
      final batch = results[3] as Map<String, String>;

      if (mounted) {
        setState(() {
          _model = props['ro.product.model'] ?? '';
          _manufacturer = props['ro.product.manufacturer'] ?? '';
          _androidVersion = props['ro.build.version.release'] ?? '';
          _apiLevel = props['ro.build.version.sdk'] ?? '';
          _buildNumber = props['ro.build.display.id'] ?? '';
          _serialNumber =
              props['ro.serialno'] ?? props['ro.boot.serialno'] ?? serial;
          _cpuAbi = props['ro.product.cpu.abi'] ?? '';

          _batteryRaw = batteryRaw;
          _uptime = batch['uptime'] ?? '';
          _screenSize = batch['screenSize'] ?? '';
          _screenDensity = batch['screenDensity'] ?? '';
          _ramRaw = batch['meminfo'] ?? '';
          _storageRaw = batch['storage'] ?? '';

          final btRaw = batch['bluetooth'] ?? '';
          _bluetoothStatus = btRaw == '1'
              ? 'Enabled'
              : (btRaw == '0' ? 'Disabled' : 'N/A');
          _screenOffTimeout = _formatScreenOffTimeout(
            batch['screenOffTimeout'] ?? '',
          );

          _networkInfo = _parseNetworkInfo(
            ipRaw: batch['ipAddr'] ?? '',
            gateway: props['dhcp.wlan0.gateway'] ?? props['net.dns1'] ?? 'N/A',
            dns: props['net.dns1'] ?? 'N/A',
            wifiRaw: wifiRaw,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to retrieve all device specs: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatScreenOffTimeout(String raw) {
    final ms = int.tryParse(raw.trim());
    if (ms != null) {
      if (ms <= 0 || ms >= 2147483647) return 'Never';
      if (ms < 60000) return '${ms ~/ 1000} seconds';
      final minutes = ms ~/ 60000;
      final seconds = (ms % 60000) ~/ 1000;
      return seconds > 0 ? '$minutes min $seconds sec' : '$minutes min';
    }
    return raw.isNotEmpty ? raw : 'N/A';
  }

  Map<String, String> _parseNetworkInfo({
    required String ipRaw,
    required String gateway,
    required String dns,
    required String wifiRaw,
  }) {
    String ip = 'Not connected';
    String broadcast = 'N/A';

    for (final line in ipRaw.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.startsWith('inet ')) {
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 2) ip = parts[1];
        final brdIndex = parts.indexOf('brd');
        if (brdIndex != -1 && brdIndex + 1 < parts.length) {
          broadcast = parts[brdIndex + 1];
        }
      }
    }

    String ssid = 'Unknown';
    String bssid = 'N/A';
    String linkSpeed = 'N/A';
    String rssi = 'N/A';

    for (final line in wifiRaw.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.contains('SSID:') || trimmed.contains('mWifiInfo')) {
        final ssidMatch = RegExp(
          r'SSID:\s*"?([^",\r\n]+)"?',
        ).firstMatch(trimmed);
        if (ssidMatch != null &&
            (ssid == 'Unknown' || ssid == '<unknown ssid>')) {
          final val = ssidMatch.group(1)?.trim() ?? '';
          if (val.isNotEmpty && val != '<unknown ssid>') {
            ssid = val;
          }
        }
        final bssidMatch = RegExp(
          r'BSSID:\s*([0-9a-fA-F:]{17})',
        ).firstMatch(trimmed);
        if (bssidMatch != null && bssid == 'N/A') {
          bssid = bssidMatch.group(1)?.trim() ?? 'N/A';
        }
        final speedMatch = RegExp(
          r'(?:Link speed|txLinkSpeedMbps):\s*([0-9]+(?:\s*Mbps)?)',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (speedMatch != null && linkSpeed == 'N/A') {
          final spd = speedMatch.group(1)?.trim() ?? '';
          linkSpeed = spd.endsWith('Mbps') ? spd : '$spd Mbps';
        }
        final rssiMatch = RegExp(
          r'RSSI:\s*(-?[0-9]+)',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (rssiMatch != null && rssi == 'N/A') {
          rssi = '${rssiMatch.group(1)} dBm';
        }
      }
    }

    return {
      'ip': ip,
      'broadcast': broadcast,
      'gateway': gateway.isNotEmpty ? gateway : 'N/A',
      'dns': dns.isNotEmpty ? dns : 'N/A',
      'ssid': ssid,
      'bssid': bssid,
      'linkSpeed': linkSpeed,
      'rssi': rssi,
    };
  }

  // Parsers
  Map<String, String> _parseBattery(String raw) {
    final map = <String, String>{};
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final parts = line.split(':');
      if (parts.length >= 2) {
        map[parts[0].trim()] = parts[1].trim();
      }
    }

    // Friendly status
    final statusCode = map['status'] ?? '';
    String statusLabel = 'Unknown';
    if (statusCode == '2') statusLabel = 'Charging';
    if (statusCode == '3') statusLabel = 'Discharging';
    if (statusCode == '4') statusLabel = 'Not Charging';
    if (statusCode == '5') statusLabel = 'Full';

    // Friendly health
    final healthCode = map['health'] ?? '';
    String healthLabel = 'Unknown';
    if (healthCode == '2') healthLabel = 'Good';
    if (healthCode == '3') healthLabel = 'Overheat';
    if (healthCode == '4') healthLabel = 'Dead';
    if (healthCode == '5') healthLabel = 'Over Voltage';
    if (healthCode == '7') healthLabel = 'Cold';

    // Power source
    String powerSource = 'Battery (Unplugged)';
    if (map['AC powered'] == 'true') powerSource = 'AC Charger';
    if (map['USB powered'] == 'true') powerSource = 'USB Cable';
    if (map['Wireless powered'] == 'true') powerSource = 'Wireless Charging';

    // Voltage
    final rawVoltage = double.tryParse(map['voltage'] ?? '') ?? 0;
    final voltageStr = rawVoltage > 0
        ? '${rawVoltage.toInt()} mV (${(rawVoltage / 1000).toStringAsFixed(2)} V)'
        : 'N/A';

    // Temperature
    final rawTemp = double.tryParse(map['temperature'] ?? '') ?? 0;
    final tempC = rawTemp / 10;
    final tempF = (tempC * 9 / 5) + 32;
    final tempStr = rawTemp > 0
        ? '${tempC.toStringAsFixed(1)} °C (${tempF.toStringAsFixed(1)} °F)'
        : 'N/A';

    // Charge Counter
    final rawCharge = double.tryParse(map['Charge counter'] ?? '') ?? 0;
    final chargeStr = rawCharge > 0
        ? '${(rawCharge / 1000).toStringAsFixed(0)} mAh'
        : 'N/A';

    return {
      'level': '${map['level'] ?? 'N/A'}%',
      'status': statusLabel,
      'health': healthLabel,
      'powerSource': powerSource,
      'voltage': voltageStr,
      'temperature': tempStr,
      'technology': map['technology'] ?? 'N/A',
      'chargeCounter': chargeStr,
    };
  }

  Map<String, String> _parseStorage(String raw) {
    if (raw.trim().isEmpty) return {};
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (final line in lines) {
      if (line.toLowerCase().contains('filesystem') ||
          line.toLowerCase().contains('1k-blocks')) {
        continue;
      }
      final cols = line.split(RegExp(r'\s+'));
      if (cols.length >= 4) {
        final percentIndex = cols.indexWhere(
          (c) => RegExp(r'^\d+%$').hasMatch(c),
        );
        if (percentIndex >= 3) {
          return {
            'total': _formatStorageSize(cols[percentIndex - 3]),
            'used': _formatStorageSize(cols[percentIndex - 2]),
            'avail': _formatStorageSize(cols[percentIndex - 1]),
            'percent': cols[percentIndex],
          };
        } else if (cols.length >= 5) {
          return {
            'total': _formatStorageSize(cols[1]),
            'used': _formatStorageSize(cols[2]),
            'avail': _formatStorageSize(cols[3]),
            'percent': cols[4],
          };
        }
      }
    }

    final match = RegExp(
      r'(\d+(?:\.\d+)?\s*[KMGTP]?)\s+(\d+(?:\.\d+)?\s*[KMGTP]?)\s+(\d+(?:\.\d+)?\s*[KMGTP]?)\s+(\d+%)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match != null) {
      return {
        'total': _formatStorageSize(match.group(1)!),
        'used': _formatStorageSize(match.group(2)!),
        'avail': _formatStorageSize(match.group(3)!),
        'percent': match.group(4)!,
      };
    }

    return {};
  }

  String _formatStorageSize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('G') ||
        trimmed.endsWith('GB') ||
        trimmed.endsWith('M') ||
        trimmed.endsWith('MB')) {
      return trimmed;
    }
    final numVal = double.tryParse(trimmed);
    if (numVal != null) {
      if (numVal > 1024 * 1024) {
        return '${(numVal / 1024 / 1024).toStringAsFixed(1)} GB';
      } else if (numVal > 1024) {
        return '${(numVal / 1024).toStringAsFixed(1)} MB';
      }
      return '${numVal.toStringAsFixed(0)} KB';
    }
    return trimmed;
  }

  Map<String, String> _parseRam(String raw) {
    String total = 'Unknown';
    String available = 'Unknown';
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      if (line.startsWith('MemTotal:')) {
        final kb = double.tryParse(line.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        total = '${(kb / 1024 / 1024).toStringAsFixed(1)} GB';
      } else if (line.startsWith('MemAvailable:')) {
        final kb = double.tryParse(line.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        available = '${(kb / 1024 / 1024).toStringAsFixed(1)} GB';
      }
    }
    return {'total': total, 'available': available};
  }

  @override
  Widget build(BuildContext context) {
    final controller = AdbController.of(context);
    final device = controller.selectedDevice;

    if (device == null) {
      return const EmptyStateView(
        iconAsset: AppIcons.devices,
        title: 'No Device Selected',
        description:
            'Please select an active wireless device from the Connection tab to view its hardware, network, and battery specifications.',
      );
    }

    final battery = _parseBattery(_batteryRaw);
    final storage = _parseStorage(_storageRaw);
    final ram = _parseRam(_ramRaw);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        device.displayName,
                        style: AppTypography.heading6.copyWith(
                          color: AppColors.neutral8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppBadge(
                        label: device.isWireless ? 'WIRELESS' : 'USB',
                        tone: device.isWireless
                            ? AppBadgeTone.info
                            : AppBadgeTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Serial: ${device.serial} • Status: ${device.state.toUpperCase()}',
                    style: AppTypography.label.copyWith(
                      color: AppColors.neutral7,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              AppButton(
                text: 'Refresh Specs',
                icon: const AppSvgIcon(AppIcons.arrowClockwise, size: 20),
                size: AppButtonSize.md,
                isLoading: _isLoading,
                onPressed: () => _fetchDeviceInfo(device.serial, controller),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_errorMessage != null) ...[
            Container(
              padding: AppSpacing.paddingLg,
              decoration: ShapeDecoration(
                color: AppColors.neutral2,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.xl),
                  side: const BorderSide(color: AppColors.danger6, width: 1),
                ),
              ),
              child: Row(
                children: [
                  const AppSvgIcon(
                    AppIcons.info,
                    color: AppColors.danger6,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTypography.body.copyWith(
                        color: AppColors.danger4,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton.secondary(
                    text: 'Retry',
                    size: AppButtonSize.md,
                    onPressed: () =>
                        _fetchDeviceInfo(device.serial, controller),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            // Row 1: Identity & Software
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildSectionCard(
                      title: 'Device Identity',
                      iconAsset: AppIcons.deviceMobileCamera,
                      items: [
                        _InfoItem('Model', _model),
                        _InfoItem('Manufacturer', _manufacturer),
                        _InfoItem('Serial Number', _serialNumber),
                        _InfoItem(
                          'System Uptime',
                          _uptime.isNotEmpty ? _uptime : 'N/A',
                        ),
                        _InfoItem('Build Number', _buildNumber),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: _buildSectionCard(
                      title: 'Software & Platform',
                      iconAsset: AppIcons.circlesFour,
                      items: [
                        _InfoItem(
                          'Android Version',
                          'Android $_androidVersion',
                        ),
                        _InfoItem('API Level / SDK', 'API $_apiLevel'),
                        _InfoItem('CPU Architecture', _cpuAbi),
                        _InfoItem(
                          'Transport ID',
                          device.transportId.isEmpty
                              ? 'N/A'
                              : device.transportId,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Row 2: Real-Time Battery Stats & Network / Wi-Fi Inspector
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildSectionCard(
                      title: 'Real-Time Battery Stats',
                      iconAsset: AppIcons.graph,
                      items: [
                        _InfoItem('Battery Level', battery['level'] ?? 'N/A'),
                        _InfoItem('Charging State', battery['status'] ?? 'N/A'),
                        _InfoItem(
                          'Power Source',
                          battery['powerSource'] ?? 'N/A',
                        ),
                        _InfoItem('Battery Health', battery['health'] ?? 'N/A'),
                        _InfoItem('Voltage', battery['voltage'] ?? 'N/A'),
                        _InfoItem(
                          'Temperature',
                          battery['temperature'] ?? 'N/A',
                        ),
                        _InfoItem('Technology', battery['technology'] ?? 'N/A'),
                        _InfoItem(
                          'Charge Counter',
                          battery['chargeCounter'] ?? 'N/A',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: _buildSectionCard(
                      title: 'Network & Wi-Fi Inspector',
                      iconAsset: AppIcons.cellTower,
                      items: [
                        _InfoItem(
                          'Connected SSID',
                          _networkInfo['ssid'] ?? 'N/A',
                        ),
                        _InfoItem('BSSID', _networkInfo['bssid'] ?? 'N/A'),
                        _InfoItem(
                          'Link Speed',
                          _networkInfo['linkSpeed'] ?? 'N/A',
                        ),
                        _InfoItem(
                          'Signal (RSSI)',
                          _networkInfo['rssi'] ?? 'N/A',
                        ),
                        _InfoItem(
                          'Bluetooth',
                          _bluetoothStatus.isNotEmpty
                              ? _bluetoothStatus
                              : 'N/A',
                        ),
                        _InfoItem(
                          'Device Wi-Fi IP',
                          _networkInfo['ip'] ?? 'N/A',
                        ),
                        _InfoItem(
                          'Broadcast / Subnet',
                          _networkInfo['broadcast'] ?? 'N/A',
                        ),
                        _InfoItem(
                          'Gateway IP',
                          _networkInfo['gateway'] ?? 'N/A',
                        ),
                        _InfoItem('DNS Server', _networkInfo['dns'] ?? 'N/A'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Row 3: Hardware & Display Specs
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildSectionCard(
                      title: 'Memory & Storage',
                      iconAsset: AppIcons.hardDrives,
                      items: [
                        _InfoItem(
                          'Storage Used',
                          storage.isNotEmpty
                              ? '${storage['used']} of ${storage['total']} (${storage['percent']})'
                              : 'N/A',
                        ),
                        _InfoItem('Total RAM', ram['total'] ?? 'N/A'),
                        _InfoItem('Available RAM', ram['available'] ?? 'N/A'),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: _buildSectionCard(
                      title: 'Display & Density',
                      iconAsset: AppIcons.layout,
                      items: [
                        _InfoItem(
                          'Screen Resolution',
                          _screenSize.replaceAll('Physical size: ', ''),
                        ),
                        _InfoItem(
                          'Screen Density',
                          _screenDensity.replaceAll('Physical density: ', ''),
                        ),
                        _InfoItem(
                          'Screen Timeout',
                          _screenOffTimeout.isNotEmpty
                              ? _screenOffTimeout
                              : 'N/A',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String iconAsset,
    required List<_InfoItem> items,
  }) {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: ShapeDecoration(
        color: AppColors.neutral2,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xl),
          side: const BorderSide(color: AppColors.neutral3, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSvgIcon(iconAsset, color: AppColors.primary4, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.neutral8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 2, color: AppColors.neutral3),
          const SizedBox(height: AppSpacing.sm),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 180,
                    child: Text(
                      item.label,
                      style: AppTypography.body.copyWith(
                        color: AppColors.neutral7,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      item.value.isNotEmpty ? item.value : '—',
                      style: AppTypography.body.copyWith(
                        color: AppColors.neutral8,
                        fontWeight: FontWeight.w600,
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
}

class _InfoItem {
  final String label;
  final String value;
  _InfoItem(this.label, this.value);
}
