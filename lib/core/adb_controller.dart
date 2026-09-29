import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_svg_icon.dart';
import 'adb_service.dart';
import 'device_model.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class AdbController extends ChangeNotifier {
  final AdbService service;

  List<AdbDevice> _devices = [];
  AdbDevice? _selectedDevice;
  bool _isLoadingDevices = false;
  String? _adbVersion;
  String? _resolvedAdbPath;
  String? _errorMessage;

  AdbController({required this.service}) {
    service.lastCommandNotifier.addListener(_onCommandExecuted);
    _init();
  }

  List<AdbDevice> get devices => _devices;
  AdbDevice? get selectedDevice => _selectedDevice;
  bool get isLoadingDevices => _isLoadingDevices;
  String? get adbVersion => _adbVersion;
  String? get resolvedAdbPath => _resolvedAdbPath;
  String? get errorMessage => _errorMessage;

  void _init() {
    refreshAdbInfo();
    refreshDevices();
  }

  void _onCommandExecuted() {
    final cmd = service.lastCommandNotifier.value;
    if (cmd == null) return;

    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          backgroundColor: cmd.isSuccess
              ? AppColors.success9
              : AppColors.danger9,
          content: Row(
            children: [
              AppSvgIcon(
                cmd.isSuccess ? AppIcons.checkCircle : AppIcons.x,
                color: cmd.isSuccess ? AppColors.success3 : AppColors.danger4,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cmd.displayCommand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${cmd.duration.inMilliseconds}ms',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }
    notifyListeners();
  }

  Future<void> refreshAdbInfo() async {
    _resolvedAdbPath = await service.resolver.resolve();
    _adbVersion = await service.resolver.getVersion();
    notifyListeners();
  }

  Future<void> refreshDevices() async {
    _isLoadingDevices = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final list = await service.listDevices();
      _devices = list;
      if (_selectedDevice == null || !_devices.any((d) => d.serial == _selectedDevice!.serial)) {
        _selectedDevice = _devices.isNotEmpty ? _devices.first : null;
      } else {
        // Update device instance
        _selectedDevice = _devices.firstWhere((d) => d.serial == _selectedDevice!.serial);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingDevices = false;
      notifyListeners();
    }
  }

  void selectDevice(AdbDevice? device) {
    _selectedDevice = device;
    notifyListeners();
  }

  static AdbController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AdbScope>();
    assert(scope != null, 'No AdbController found in context');
    return scope!.controller;
  }

  @override
  void dispose() {
    service.lastCommandNotifier.removeListener(_onCommandExecuted);
    super.dispose();
  }
}

class AdbScope extends InheritedNotifier<AdbController> {
  final AdbController controller;

  const AdbScope({
    super.key,
    required this.controller,
    required super.child,
  }) : super(notifier: controller);

  @override
  bool updateShouldNotify(covariant InheritedNotifier<AdbController> oldWidget) => true;
}
