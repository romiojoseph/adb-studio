import 'dart:io';
import 'package:path/path.dart' as p;

class AdbPathResolver {
  String? _cachedPath;
  String? _customPath;

  String? get resolvedPath => _cachedPath;
  String? get customPath => _customPath;

  static List<String> get standardSearchPaths {
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
    final userProfile = Platform.environment['USERPROFILE'] ?? '';
    final programFiles = Platform.environment['ProgramFiles'] ?? '';

    return [
      r'C:\platform-tools\adb.exe',
      r'C:\Android-SDK\platform-tools\adb.exe',
      if (localAppData.isNotEmpty)
        p.join(localAppData, 'Android', 'Sdk', 'platform-tools', 'adb.exe'),
      if (userProfile.isNotEmpty) ...[
        p.join(userProfile, 'platform-tools', 'adb.exe'),
        p.join(userProfile, 'AppData', 'Local', 'Android', 'Sdk', 'platform-tools', 'adb.exe'),
      ],
      if (programFiles.isNotEmpty)
        p.join(programFiles, 'Android', 'platform-tools', 'adb.exe'),
    ];
  }

  void setCustomPath(String? path) {
    _customPath = path;
    _cachedPath = null;
  }

  Future<String?> resolve() async {
    // 1. User-specified path
    if (_customPath != null && _customPath!.trim().isNotEmpty) {
      final custom = _customPath!.trim();
      if (await isValidAdbExecutable(custom)) {
        _cachedPath = custom;
        return custom;
      }
    }

    if (_cachedPath != null && await isValidAdbExecutable(_cachedPath!)) {
      return _cachedPath;
    }

    // 2. System PATH via 'where adb'
    try {
      final whereResult = await Process.run('where', ['adb']);
      if (whereResult.exitCode == 0) {
        final lines = (whereResult.stdout as String)
            .split(RegExp(r'\r?\n'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);
        for (final line in lines) {
          if (await isValidAdbExecutable(line)) {
            _cachedPath = line;
            return line;
          }
        }
      }
    } catch (_) {}

    // 3. Check standard Android SDK & platform-tools directories
    for (final candidate in standardSearchPaths) {
      if (await isValidAdbExecutable(candidate)) {
        _cachedPath = candidate;
        return candidate;
      }
    }

    // 4. Default command name if executable in current env PATH
    if (await isValidAdbExecutable('adb')) {
      _cachedPath = 'adb';
      return 'adb';
    }

    return null;
  }

  Future<bool> isValidAdbExecutable(String executablePath) async {
    final trimmed = executablePath.trim();
    if (trimmed.isEmpty) return false;

    final baseName = p.basename(trimmed).toLowerCase();
    if (baseName != 'adb.exe' && baseName != 'adb') {
      return false;
    }

    try {
      final result = await Process.run(trimmed, ['version'], runInShell: false);
      return result.exitCode == 0 &&
          (result.stdout as String).contains('Android Debug Bridge');
    } catch (_) {
      return false;
    }
  }

  Future<String?> getVersion() async {
    final adb = await resolve();
    if (adb == null) return null;
    try {
      final result = await Process.run(adb, ['version'], runInShell: false);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split(RegExp(r'\r?\n'));
        return lines.isNotEmpty ? lines.first.trim() : 'ADB installed';
      }
    } catch (_) {}
    return null;
  }
}
