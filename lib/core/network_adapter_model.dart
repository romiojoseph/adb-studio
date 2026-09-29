class NetworkAdapterInfo {
  final String name;
  final bool isDisconnected;
  final String? ipv4;
  final String? ipv6;
  final String? subnetMask;
  final String? gateway;
  final Map<String, String> properties;

  const NetworkAdapterInfo({
    required this.name,
    this.isDisconnected = false,
    this.ipv4,
    this.ipv6,
    this.subnetMask,
    this.gateway,
    this.properties = const {},
  });

  String get subnetPrefix {
    if (ipv4 == null) return '192.168.';
    final parts = ipv4!.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.${parts[1]}.${parts[2]}.';
    }
    return '192.168.';
  }

  static List<NetworkAdapterInfo> parseIpconfig(String rawOutput) {
    final adapters = <NetworkAdapterInfo>[];
    final lines = rawOutput.split(RegExp(r'\r?\n'));

    String? currentName;
    bool currentDisconnected = false;
    final currentProps = <String, String>{};

    void commitCurrent() {
      if (currentName != null && currentName!.isNotEmpty) {
        String? ipv4;
        String? ipv6;
        String? subnetMask;
        String? gateway;

        for (final entry in currentProps.entries) {
          final k = entry.key.toLowerCase();
          final v = entry.value;
          if (k.contains('ipv4 address') || k.contains('ipv4-adresse') || k.contains('ipv4')) {
            // strip "(Preferred)" or other suffixes if any
            ipv4 = v.replaceAll(RegExp(r'\(.*?\)'), '').trim();
          } else if (k.contains('ipv6') && ipv6 == null) {
            ipv6 = v.trim();
          } else if (k.contains('subnet mask')) {
            subnetMask = v.trim();
          } else if (k.contains('default gateway') && gateway == null && v.isNotEmpty) {
            gateway = v.trim();
          }
        }

        adapters.add(NetworkAdapterInfo(
          name: currentName!,
          isDisconnected: currentDisconnected,
          ipv4: ipv4,
          ipv6: ipv6,
          subnetMask: subnetMask,
          gateway: gateway,
          properties: Map.unmodifiable(currentProps),
        ));
      }
      currentName = null;
      currentDisconnected = false;
      currentProps.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.isEmpty) continue;

      // Adapter header usually ends with a colon and does not start with whitespace
      if (!rawLine.startsWith(' ') && line.endsWith(':')) {
        commitCurrent();
        currentName = line.substring(0, line.length - 1).trim();
        continue;
      }

      // Check key-value line e.g. "   IPv4 Address. . . . . . . . . . . : 192.168.1.5"
      if (currentName != null && line.contains(':')) {
        final colonIdx = line.indexOf(':');
        final keyPart = line.substring(0, colonIdx).replaceAll('.', '').trim();
        final valPart = line.substring(colonIdx + 1).trim();

        if (keyPart.toLowerCase().contains('media state') &&
            valPart.toLowerCase().contains('disconnected')) {
          currentDisconnected = true;
        }

        if (keyPart.isNotEmpty) {
          currentProps[keyPart] = valPart;
        }
      }
    }

    commitCurrent();
    return adapters;
  }
}
