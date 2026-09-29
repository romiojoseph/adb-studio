import 'dart:convert';
import 'package:flutter/services.dart';

class PermissionInfo {
  final String name;
  final String description;
  final String? group;

  const PermissionInfo({
    required this.name,
    required this.description,
    this.group,
  });
}

class AppPermission {
  final String permission;
  final bool isGranted;

  const AppPermission({
    required this.permission,
    required this.isGranted,
  });

  factory AppPermission.fromMap(Map<String, dynamic> map) {
    return AppPermission(
      permission: map['permission'] as String? ?? '',
      isGranted: map['isGranted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'permission': permission,
    'isGranted': isGranted,
  };
}

class PermissionDictionary {
  PermissionDictionary._();
  static final PermissionDictionary instance = PermissionDictionary._();

  final Map<String, String> _permissions = {};
  final Map<String, String> _groups = {};
  bool _isLoaded = false;

  Future<void> load() async {
    if (_isLoaded) return;

    try {
      final permJsonStr = await rootBundle.loadString('assets/data/permission.json');
      final List<dynamic> permList = json.decode(permJsonStr);
      for (final item in permList) {
        if (item is Map<String, dynamic>) {
          final name = item['name'] as String?;
          final desc = item['description'] as String?;
          if (name != null && desc != null) {
            _permissions[name.trim().toUpperCase()] = _cleanHtml(desc.trim());
          }
        }
      }
    } catch (_) {}

    try {
      final groupJsonStr = await rootBundle.loadString('assets/data/permission_group.json');
      final List<dynamic> groupList = json.decode(groupJsonStr);
      for (final item in groupList) {
        if (item is Map<String, dynamic>) {
          final name = item['name'] as String?;
          final desc = item['description'] as String?;
          if (name != null && desc != null) {
            _groups[name.trim().toUpperCase()] = _cleanHtml(desc.trim());
          }
        }
      }
    } catch (_) {}

    _isLoaded = true;
  }

  PermissionInfo getInfo(String rawPermission) {
    final clean = rawPermission.trim();
    // e.g. "android.permission.CAMERA" -> "CAMERA"
    final shortName = clean.contains('.')
        ? clean.split('.').last.toUpperCase()
        : clean.toUpperCase();

    final desc = _permissions[shortName];
    final groupDesc = _groups[shortName];

    String? matchedGroup;
    for (final grp in _groups.keys) {
      if (shortName == grp || shortName.startsWith('${grp}_') || shortName.endsWith('_$grp')) {
        matchedGroup = grp;
        break;
      }
    }

    return PermissionInfo(
      name: shortName,
      description: desc ?? groupDesc ?? 'Standard or application-specific permission.',
      group: matchedGroup,
    );
  }

  static String _cleanHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}
