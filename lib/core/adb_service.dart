import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'adb_command_record.dart';
import 'adb_path_resolver.dart';
import 'device_model.dart';
import 'mdns_service_model.dart';

class AdbSecurityException implements Exception {
  final String message;
  AdbSecurityException(this.message);

  @override
  String toString() => 'AdbSecurityException: $message';
}

class AdbService {
  final AdbPathResolver _resolver;
  final ValueNotifier<AdbCommandRecord?> lastCommandNotifier = ValueNotifier(null);
  final ListQueue<AdbCommandRecord> _history = ListQueue(200);
  int _counter = 0;

  AdbService({AdbPathResolver? resolver}) : _resolver = resolver ?? AdbPathResolver();

  AdbPathResolver get resolver => _resolver;
  List<AdbCommandRecord> get commandHistory => List.unmodifiable(_history.toList());

  // Guardrail: Validate package name format
  void validatePackageName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || !RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(trimmed)) {
      throw AdbSecurityException('Invalid package name format. Denied: $name');
    }
  }

  // Guardrail: Validate local filesystem path
  void validateLocalPath(String path, {bool mustExist = false}) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      throw AdbSecurityException('Local path cannot be empty.');
    }
    final forbiddenChars = [';', '&', '|', '`', '\n', '\r'];
    for (final char in forbiddenChars) {
      if (trimmed.contains(char)) {
        throw AdbSecurityException('Illegal characters in local path. Denied: $path');
      }
    }
    if (mustExist && !File(trimmed).existsSync() && !Directory(trimmed).existsSync()) {
      throw AdbSecurityException('Local path does not exist: $path');
    }
  }

  // Guardrail: Validate path is strictly within /sdcard and has no directory traversal
  void validateSdcardPath(String path) {
    final normalized = path.trim().replaceAll('\\', '/');
    if (!normalized.startsWith('/sdcard')) {
      throw AdbSecurityException('Path must be inside /sdcard. Denied: $path');
    }
    final segments = normalized.split('/');
    if (segments.contains('..') || segments.contains('%2e%2e') || segments.contains('%2E%2E')) {
      throw AdbSecurityException('Path traversal is forbidden. Denied: $path');
    }
    // Block command injection characters
    final forbiddenChars = [';', '&', '|', '`', '\n', '\r', '\$', '(', ')'];
    for (final char in forbiddenChars) {
      if (normalized.contains(char)) {
        throw AdbSecurityException('Illegal characters in path. Denied: $path');
      }
    }
  }


  // Guardrail: Block forbidden system-altering or destructive commands
  void validateSafeCommand(List<String> args) {
    final joined = args.join(' ').toLowerCase();
    const forbiddenSubstrings = [
      'fastboot',
      'root',
      'remount',
      'settings put',
      'settings delete',
      'reboot bootloader',
      'reboot recovery',
      'reboot-bootloader',
      'pm uninstall',
      'pm clear',
      'pm disable',
      'pm hide',
      'pm suspend',
      'rm ',
      'rm -',
      'rmdir',
      'erase',
      'format',
      'delete',
      'setprop',
      'dd if=',
      'mkfs',
      'wipe',
      'fstrim',
      'bmgr restore',
      'bmgr wipe',
    ];

    for (final forbidden in forbiddenSubstrings) {
      if (joined.contains(forbidden)) {
        throw AdbSecurityException('Command is blocked by safety policy: $forbidden');
      }
    }

    // Guard against dangerous sub-commands inside composite scripts
    for (final arg in args) {
      final lower = arg.toLowerCase();
      if (lower.contains(';') || lower.contains('\n')) {
        final subLines = lower.split(RegExp(r'[;\n]'));
        for (final sub in subLines) {
          final trimmedSub = sub.trim();
          for (final forbidden in forbiddenSubstrings) {
            if (trimmedSub.contains(forbidden)) {
              throw AdbSecurityException('Command script is blocked by safety policy: $forbidden');
            }
          }
        }
      }
    }
  }

  static const Set<String> _allowedTempCleanupFiles = {
    '/sdcard/screenshot.png',
    '/sdcard/recording.mp4',
  };

  // Safe internal cleanup restricted only to known temporary media files
  Future<AdbCommandRecord> _cleanupDeviceTempFile(String serial, String remoteTempPath) async {
    final trimmed = remoteTempPath.trim();
    if (!_allowedTempCleanupFiles.contains(trimmed)) {
      throw AdbSecurityException('Unauthorized temp file cleanup target. Denied: $trimmed');
    }
    return _runCommandInternal(
      _target(serial, ['shell', 'rm', trimmed]),
      validateSafety: false,
    );
  }

  Future<AdbCommandRecord> runCommand(
    List<String> args, {
    Duration timeout = const Duration(seconds: 45),
    bool recordHistory = true,
  }) => _runCommandInternal(
        args,
        timeout: timeout,
        recordHistory: recordHistory,
        validateSafety: true,
      );

  Future<AdbCommandRecord> _runCommandInternal(
    List<String> args, {
    Duration timeout = const Duration(seconds: 45),
    bool recordHistory = true,
    bool validateSafety = true,
  }) async {
    if (validateSafety) {
      validateSafeCommand(args);
    }

    final adbExecutable = await _resolver.resolve();
    if (adbExecutable == null) {
      throw Exception('ADB executable could not be found or resolved.');
    }

    final stopwatch = Stopwatch()..start();
    final startTime = DateTime.now();
    int exitCode = -1;
    String stdoutStr = '';
    String stderrStr = '';

    try {
      final result = await Process.run(
        adbExecutable,
        args,
        runInShell: false,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(timeout);

      stopwatch.stop();
      exitCode = result.exitCode;
      stdoutStr = (result.stdout as String).trim();
      stderrStr = (result.stderr as String).trim();
    } on TimeoutException {
      stopwatch.stop();
      exitCode = -1;
      stderrStr = 'Command timed out after ${timeout.inSeconds} seconds.';
    } catch (e) {
      stopwatch.stop();
      exitCode = -1;
      stderrStr = e.toString();
    }

    final record = AdbCommandRecord(
      id: 'cmd_${++_counter}_${startTime.millisecondsSinceEpoch}',
      timestamp: startTime,
      args: args,
      exitCode: exitCode,
      stdout: stdoutStr,
      stderr: stderrStr,
      duration: stopwatch.elapsed,
    );

    if (recordHistory) {
      _history.addFirst(record);
      if (_history.length > 200) {
        _history.removeLast();
      }
      lastCommandNotifier.value = record;
    }

    return record;
  }

  Future<Process> startProcess(List<String> args) async {
    validateSafeCommand(args);

    final adbExecutable = await _resolver.resolve();
    if (adbExecutable == null) {
      throw Exception('ADB executable could not be found or resolved.');
    }

    final record = AdbCommandRecord(
      id: 'proc_${++_counter}_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      args: args,
      exitCode: 0,
      stdout: 'Process started',
      stderr: '',
      duration: Duration.zero,
    );

    _history.addFirst(record);
    if (_history.length > 200) {
      _history.removeLast();
    }
    lastCommandNotifier.value = record;

    return await Process.start(adbExecutable, args, runInShell: false);
  }

  // 1. Connection Commands
  Future<List<AdbDevice>> listDevices() async {
    final result = await runCommand(['devices', '-l']);
    final lines = result.stdout.split(RegExp(r'\r?\n'));
    final devices = <AdbDevice>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('List of devices')) {
        continue;
      }
      final device = AdbDevice.fromLine(trimmed);
      if (device.serial.isNotEmpty) {
        devices.add(device);
      }
    }
    return devices;
  }

  Future<AdbCommandRecord> wirelessPair(String ipPort, String code) {
    return runCommand(['pair', ipPort.trim(), code.trim()]);
  }

  Future<AdbCommandRecord> wirelessConnect(String ipPort) {
    return runCommand(['connect', ipPort.trim()]);
  }

  Future<AdbCommandRecord> wirelessDisconnect(String ipPort) {
    return runCommand(['disconnect', ipPort.trim()]);
  }

  Future<AdbCommandRecord> disconnectAll() {
    return runCommand(['disconnect']);
  }

  Future<AdbCommandRecord> reconnectOffline() {
    return runCommand(['reconnect', 'offline']);
  }

  Future<AdbCommandRecord> checkMdns() {
    return runCommand(['mdns', 'check']);
  }

  Future<List<AdbMdnsService>> getMdnsServices({bool recordHistory = false}) async {
    final res = await runCommand(['mdns', 'services'], recordHistory: recordHistory);
    if (!res.isSuccess) return [];

    final list = <AdbMdnsService>[];
    for (final line in res.stdout.split(RegExp(r'\r?\n'))) {
      final s = AdbMdnsService.fromLine(line);
      if (s.isValid) {
        list.add(s);
      }
    }
    return list;
  }

  Future<AdbCommandRecord> startServer() {
    return runCommand(['start-server']);
  }

  Future<AdbCommandRecord> killServer() {
    return runCommand(['kill-server']);
  }

  Future<AdbCommandRecord> restartServer() async {
    await killServer();
    return startServer();
  }

  // Helper for targeted device calls
  List<String> _target(String serial, List<String> args) => ['-s', serial, ...args];

  // 2. Device Info Dashboard Commands
  Future<String> getProp(String serial, String prop) async {
    final res = await runCommand(_target(serial, ['shell', 'getprop', prop]));
    return res.stdout;
  }

  Future<Map<String, String>> getAllProps(String serial) async {
    final res = await runCommand(_target(serial, ['shell', 'getprop']));
    final props = <String, String>{};
    for (final line in res.stdout.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.startsWith('[') && trimmed.contains(']: [')) {
        final match = RegExp(r'^\[([^\]]+)\]:\s*\[([^\]]*)\]').firstMatch(trimmed);
        if (match != null) {
          props[match.group(1)!] = match.group(2)!;
        }
      }
    }
    return props;
  }

  Future<Map<String, String>> getBatchHardwareAndSettings(String serial) async {
    const delimiter = '___ADB_SEC___';
    final script = [
      'uptime',
      'echo "$delimiter"',
      'wm size',
      'echo "$delimiter"',
      'wm density',
      'echo "$delimiter"',
      'cat /proc/meminfo',
      'echo "$delimiter"',
      'df /sdcard',
      'echo "$delimiter"',
      'ip -f inet addr show wlan0',
      'echo "$delimiter"',
      'settings get global bluetooth_on',
      'echo "$delimiter"',
      'settings get system screen_off_timeout',
    ].join(' ; ');

    final res = await runCommand(_target(serial, ['shell', script]));
    final sections = res.stdout.split(delimiter);
    return {
      'uptime': sections.isNotEmpty ? sections[0].trim() : '',
      'screenSize': sections.length > 1 ? sections[1].trim() : '',
      'screenDensity': sections.length > 2 ? sections[2].trim() : '',
      'meminfo': sections.length > 3 ? sections[3].trim() : '',
      'storage': sections.length > 4 ? sections[4].trim() : '',
      'ipAddr': sections.length > 5 ? sections[5].trim() : '',
      'bluetooth': sections.length > 6 ? sections[6].trim() : '',
      'screenOffTimeout': sections.length > 7 ? sections[7].trim() : '',
    };
  }

  Future<String> getSerialNo(String serial) async {
    final res = await runCommand(_target(serial, ['get-serialno']));
    return res.stdout;
  }

  Future<String> getBattery(String serial) async {
    final res = await runCommand(_target(serial, ['shell', 'dumpsys', 'battery']));
    return res.stdout;
  }

  Future<String> getWifiRaw(String serial) async {
    final res = await runCommand(_target(serial, ['shell', 'dumpsys', 'wifi']));
    return res.stdout;
  }

  Future<String> getStorage(String serial) async {
    final res = await runCommand(_target(serial, ['shell', 'df', '/sdcard']));
    return res.stdout;
  }

  Future<String> getRam(String serial) async {
    final res = await runCommand(_target(serial, ['shell', 'cat', '/proc/meminfo']));
    return res.stdout;
  }

  Future<String> getScreenSize(String serial) async {
    final res = await runCommand(_target(serial, ['shell', 'wm', 'size']));
    return res.stdout;
  }

  Future<String> getScreenDensity(String serial) async {
    final res = await runCommand(_target(serial, ['shell', 'wm', 'density']));
    return res.stdout;
  }

  Future<String> getUptime(String serial) async {
    final res = await runCommand(_target(serial, ['shell', 'uptime']));
    return res.stdout.trim();
  }

  Future<String> getBluetoothStatus(String serial) async {
    final res = await runCommand(_target(serial, ['shell', 'settings', 'get', 'global', 'bluetooth_on']));
    final out = res.stdout.trim();
    if (out == '1') return 'Enabled';
    if (out == '0') return 'Disabled';
    return out.isNotEmpty ? out : 'N/A';
  }

  Future<String> getScreenOffTimeout(String serial) async {
    final res = await runCommand(_target(serial, ['shell', 'settings', 'get', 'system', 'screen_off_timeout']));
    final out = res.stdout.trim();
    final ms = int.tryParse(out);
    if (ms != null) {
      if (ms <= 0 || ms >= 2147483647) return 'Never';
      if (ms < 60000) return '${ms ~/ 1000} seconds';
      final minutes = ms ~/ 60000;
      final seconds = (ms % 60000) ~/ 1000;
      return seconds > 0 ? '$minutes min $seconds sec' : '$minutes min';
    }
    return out.isNotEmpty ? out : 'N/A';
  }

  // 3. File Manager Commands (strictly scoped to /sdcard)
  Future<String> listDirectory(String serial, String remotePath) async {
    validateSdcardPath(remotePath);
    final target = remotePath.endsWith('/') ? remotePath : '$remotePath/';
    final res = await runCommand(_target(serial, ['shell', 'ls', '-la', target]));
    return res.stdout;
  }

  Future<AdbCommandRecord> pushFile(String serial, String localPath, String remotePath) {
    validateLocalPath(localPath, mustExist: true);
    validateSdcardPath(remotePath);
    return runCommand(_target(serial, ['push', localPath, remotePath]));
  }

  Future<AdbCommandRecord> pullFile(String serial, String remotePath, String localPath) {
    validateSdcardPath(remotePath);
    validateLocalPath(localPath, mustExist: false);
    return runCommand(_target(serial, ['pull', remotePath, localPath]));
  }

  Future<AdbCommandRecord> makeDirectory(String serial, String remotePath) {
    validateSdcardPath(remotePath);
    final sanitized = remotePath.replaceAll('"', r'\"');
    return runCommand(_target(serial, ['shell', 'mkdir', '-p', '"$sanitized"']));
  }

  Future<String> statPath(String serial, String remotePath) async {
    validateSdcardPath(remotePath);
    final sanitized = remotePath.replaceAll('"', r'\"');
    final res = await runCommand(_target(serial, ['shell', 'stat', '"$sanitized"']));
    return res.stdout;
  }

  // Note: No delete commands provided as requested.

  // 4. App Manager Commands
  Future<List<String>> listThirdPartyApps(String serial) async {
    final res = await runCommand(_target(serial, ['shell', 'pm', 'list', 'packages', '-3']));
    return _parsePackageList(res.stdout);
  }

  Future<List<String>> listAllApps(String serial) async {
    final res = await runCommand(_target(serial, ['shell', 'pm', 'list', 'packages']));
    return _parsePackageList(res.stdout);
  }

  List<String> _parsePackageList(String output) {
    return output
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.startsWith('package:'))
        .map((l) => l.replaceFirst('package:', ''))
        .where((l) => l.isNotEmpty)
        .toList()..sort();
  }

  Future<Map<String, dynamic>> getAppFullDetails(String serial, String packageName) async {
    validatePackageName(packageName);
    const delimiter = '___ADB_APP_DELIM___';
    final script = [
      'dumpsys package $packageName',
      'echo "$delimiter"',
      'pm path $packageName',
      'echo "$delimiter"',
      'bmgr list packages',
    ].join('\n');

    final res = await runCommand(_target(serial, ['shell', script]));
    final parts = res.stdout.split(delimiter);

    final dumpsysOutput = parts.isNotEmpty ? parts[0] : '';
    final pathOutput = parts.length > 1 ? parts[1] : '';
    final bmgrOutput = parts.length > 2 ? parts[2] : '';

    // 1. Version
    final vMatch = RegExp(r'versionName=([^\s]+)').firstMatch(dumpsysOutput);
    final versionName = vMatch?.group(1) ?? 'Unknown';

    // 2. Install Path
    final installPath = pathOutput.replaceAll('package:', '').trim();

    // 3. Permissions (Requested vs Granted)
    final lines = dumpsysOutput.split(RegExp(r'\r?\n'));
    final requestedPermissions = <String>[];
    final grantedSet = <String>{};
    final deniedSet = <String>{};

    bool inRequested = false;
    bool inLegacyGranted = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('requested permissions:')) {
        inRequested = true;
        inLegacyGranted = false;
        continue;
      } else if (trimmed.startsWith('grantedPermissions:')) {
        inLegacyGranted = true;
        inRequested = false;
        continue;
      }

      if (inRequested) {
        if (trimmed.endsWith(':') && !trimmed.contains('.')) {
          inRequested = false;
        } else if (line.length - line.trimLeft().length <= 4 && !line.startsWith('      ')) {
          if (!trimmed.startsWith('android.permission.') && !trimmed.contains('.')) {
            inRequested = false;
          }
        }
      }

      if (inLegacyGranted) {
        if (trimmed.endsWith(':') && !trimmed.contains('.')) {
          inLegacyGranted = false;
        }
      }

      if (inRequested) {
        final permName = trimmed.split(':').first.trim();
        if (permName.isNotEmpty && (permName.contains('.') || permName.startsWith('android.'))) {
          if (!requestedPermissions.contains(permName)) {
            requestedPermissions.add(permName);
          }
        }
      }

      if (inLegacyGranted) {
        final permName = trimmed.split(':').first.trim();
        if (permName.isNotEmpty && permName.contains('.')) {
          grantedSet.add(permName);
        }
      }

      if (trimmed.contains('granted=true')) {
        final permName = trimmed.split(':').first.trim();
        if (permName.contains('.')) {
          grantedSet.add(permName);
        }
      } else if (trimmed.contains('granted=false')) {
        final permName = trimmed.split(':').first.trim();
        if (permName.contains('.')) {
          deniedSet.add(permName);
        }
      }
    }

    final allPerms = requestedPermissions.isNotEmpty
        ? requestedPermissions
        : {...grantedSet, ...deniedSet}.toList();

    final permissionItems = <Map<String, dynamic>>[];
    for (final perm in allPerms) {
      final isGranted = grantedSet.contains(perm);
      permissionItems.add({
        'permission': perm,
        'isGranted': isGranted,
      });
    }

    // 4. Backup Flags & bmgr
    final allowBackup = dumpsysOutput.contains('ALLOW_BACKUP');
    final bmgrLines = bmgrOutput.split(RegExp(r'\r?\n')).map((l) => l.trim()).toList();
    final isBmgrEnrolled = bmgrLines.contains(packageName) || bmgrLines.any((l) => l.endsWith(packageName));

    return {
      'version': versionName,
      'installPath': installPath,
      'permissions': permissionItems,
      'allowBackup': allowBackup,
      'isBmgrEnrolled': isBmgrEnrolled,
    };
  }

  Future<void> openWirelessDebuggingSettings(String serial) async {
    await runCommand(_target(serial, [
      'shell',
      'am',
      'start',
      '-a',
      'com.android.settings.APPLICATION_DEVELOPMENT_SETTINGS',
    ]));
  }

  Future<AdbCommandRecord> installApk(String serial, String localApkPath) {
    validateLocalPath(localApkPath, mustExist: true);
    return runCommand(_target(serial, ['install', '-r', localApkPath]), timeout: const Duration(minutes: 5));
  }

  Future<AdbCommandRecord> forceStopApp(String serial, String packageName) {
    validatePackageName(packageName);
    return runCommand(_target(serial, ['shell', 'am', 'force-stop', packageName]));
  }

  Future<AdbCommandRecord> launchApp(String serial, String packageName) async {
    validatePackageName(packageName);
    // 1. Try monkey first
    final monkeyRecord = await runCommand(_target(serial, [
      'shell',
      'monkey',
      '-p',
      packageName,
      '-c',
      'android.intent.category.LAUNCHER',
      '1',
    ]));

    if (monkeyRecord.isSuccess && !monkeyRecord.stdout.contains('No activities found')) {
      return monkeyRecord;
    }

    // 2. Fallback: resolve launchable activity via cmd package
    final resolveRecord = await runCommand(_target(serial, [
      'shell',
      'cmd',
      'package',
      'resolve-activity',
      '--brief',
      packageName,
    ]));

    final lines = resolveRecord.stdout.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final targetActivity = lines.firstWhere(
      (l) => l.contains('/') && !l.startsWith('priority=') && !l.startsWith('match='),
      orElse: () => '',
    );

    if (targetActivity.isNotEmpty && targetActivity != 'null') {
      return runCommand(_target(serial, [
        'shell',
        'am',
        'start',
        '-n',
        targetActivity,
      ]));
    }

    // 3. Fallback: am start with LAUNCHER category
    return runCommand(_target(serial, [
      'shell',
      'am',
      'start',
      '-a',
      'android.intent.action.MAIN',
      '-c',
      'android.intent.category.LAUNCHER',
      '-p',
      packageName,
    ]));
  }

  Future<AdbCommandRecord> openAppInfo(String serial, String packageName) {
    validatePackageName(packageName);
    return runCommand(_target(serial, [
      'shell',
      'am',
      'start',
      '-a',
      'android.settings.APPLICATION_DETAILS_SETTINGS',
      '-d',
      'package:$packageName',
    ]));
  }

  Future<AdbCommandRecord> openDeveloperOptions(String serial) {
    return runCommand(_target(serial, [
      'shell',
      'am',
      'start',
      '-a',
      'com.android.settings.APPLICATION_DEVELOPMENT_SETTINGS',
    ]));
  }

  Future<Map<String, String>> getNetworkInfo(String serial) async {
    const delimiter = '___ADB_NET_DELIM___';
    final script = [
      'ip -f inet addr show wlan0',
      'echo "$delimiter"',
      'getprop dhcp.wlan0.gateway',
      'echo "$delimiter"',
      'getprop net.dns1',
      'echo "$delimiter"',
      'dumpsys wifi',
    ].join('\n');

    final res = await runCommand(_target(serial, ['shell', script]));
    final parts = res.stdout.split(delimiter);

    final ipOutput = parts.isNotEmpty ? parts[0] : '';
    final gwOutput = parts.length > 1 ? parts[1].trim() : '';
    final dnsOutput = parts.length > 2 ? parts[2].trim() : '';
    final wifiOutput = parts.length > 3 ? parts[3] : '';

    String ip = 'Not connected';
    String broadcast = 'N/A';
    for (final line in ipOutput.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.startsWith('inet ')) {
        final lineParts = trimmed.split(RegExp(r'\s+'));
        if (lineParts.length >= 2) ip = lineParts[1];
        final brdIndex = lineParts.indexOf('brd');
        if (brdIndex != -1 && brdIndex + 1 < lineParts.length) {
          broadcast = lineParts[brdIndex + 1];
        }
      }
    }

    String ssid = 'Unknown';
    String bssid = 'N/A';
    String linkSpeed = 'N/A';
    String rssi = 'N/A';

    for (final line in wifiOutput.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.contains('SSID:') || trimmed.contains('mWifiInfo')) {
        final ssidMatch = RegExp(r'SSID:\s*"?([^",\r\n]+)"?').firstMatch(trimmed);
        if (ssidMatch != null && (ssid == 'Unknown' || ssid == '<unknown ssid>')) {
          final val = ssidMatch.group(1)?.trim() ?? '';
          if (val.isNotEmpty && val != '<unknown ssid>') {
            ssid = val;
          }
        }
        final bssidMatch = RegExp(r'BSSID:\s*([0-9a-fA-F:]{17})').firstMatch(trimmed);
        if (bssidMatch != null && bssid == 'N/A') {
          bssid = bssidMatch.group(1)?.trim() ?? 'N/A';
        }
        final speedMatch = RegExp(r'(?:Link speed|txLinkSpeedMbps):\s*([0-9]+(?:\s*Mbps)?)', caseSensitive: false).firstMatch(trimmed);
        if (speedMatch != null && linkSpeed == 'N/A') {
          final spd = speedMatch.group(1)?.trim() ?? '';
          linkSpeed = spd.endsWith('Mbps') ? spd : '$spd Mbps';
        }
        final rssiMatch = RegExp(r'RSSI:\s*(-?[0-9]+)', caseSensitive: false).firstMatch(trimmed);
        if (rssiMatch != null && rssi == 'N/A') {
          rssi = '${rssiMatch.group(1)} dBm';
        }
      }
    }

    return {
      'ip': ip,
      'broadcast': broadcast,
      'gateway': gwOutput.isNotEmpty ? gwOutput : 'N/A',
      'dns': dnsOutput.isNotEmpty ? dnsOutput : 'N/A',
      'ssid': ssid,
      'bssid': bssid,
      'linkSpeed': linkSpeed,
      'rssi': rssi,
    };
  }

  // 5. Screen Tools
  Future<File> takeScreenshot(String serial, String localSavePath) async {
    validateLocalPath(localSavePath, mustExist: false);
    const remoteTemp = '/sdcard/screenshot.png';
    // 1. Screencap
    await runCommand(_target(serial, ['shell', 'screencap', '-p', remoteTemp]));
    // 2. Pull
    await runCommand(_target(serial, ['pull', remoteTemp, localSavePath]));
    // 3. Safe temporary cleanup on device
    await _cleanupDeviceTempFile(serial, remoteTemp);
    return File(localSavePath);
  }

  Future<Process> startScreenRecord(String serial, {int timeLimitSeconds = 180}) async {
    return startProcess(_target(serial, [
      'shell',
      'screenrecord',
      '--time-limit',
      timeLimitSeconds.toString(),
      '/sdcard/recording.mp4',
    ]));
  }

  Future<File> pullScreenRecord(String serial, String localSavePath) async {
    validateLocalPath(localSavePath, mustExist: false);
    const remoteTemp = '/sdcard/recording.mp4';
    await runCommand(_target(serial, ['pull', remoteTemp, localSavePath]));
    await _cleanupDeviceTempFile(serial, remoteTemp);
    return File(localSavePath);
  }

  // Package Export Command
  Future<AdbCommandRecord> exportAppList(String serial, String localFilePath) async {
    validateLocalPath(localFilePath, mustExist: false);
    final res = await runCommand(_target(serial, ['shell', 'pm', 'list', 'packages', '-3']));
    final file = File(localFilePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(res.stdout);
    return res;
  }
}
