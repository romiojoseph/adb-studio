class AdbMdnsService {
  final String serviceName;
  final String serviceType;
  final String ipPort;

  const AdbMdnsService({
    required this.serviceName,
    required this.serviceType,
    required this.ipPort,
  });

  bool get isPairing => serviceType.contains('_adb-tls-pairing');
  bool get isConnect => serviceType.contains('_adb-tls-connect');
  bool get isValid => serviceName.isNotEmpty && ipPort.isNotEmpty;

  factory AdbMdnsService.fromLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('List of discovered')) {
      return const AdbMdnsService(serviceName: '', serviceType: '', ipPort: '');
    }

    final parts = trimmed.split(RegExp(r'\t+|\s{2,}'));
    if (parts.length >= 3) {
      return AdbMdnsService(
        serviceName: parts[0].trim(),
        serviceType: parts[1].trim(),
        ipPort: parts[2].trim(),
      );
    }

    final spaceParts = trimmed.split(RegExp(r'\s+'));
    if (spaceParts.length >= 3) {
      final ipPort = spaceParts.last;
      final serviceType = spaceParts[spaceParts.length - 2];
      final serviceName = spaceParts.sublist(0, spaceParts.length - 2).join(' ');
      return AdbMdnsService(
        serviceName: serviceName,
        serviceType: serviceType,
        ipPort: ipPort,
      );
    }

    return const AdbMdnsService(serviceName: '', serviceType: '', ipPort: '');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdbMdnsService &&
          runtimeType == other.runtimeType &&
          serviceName == other.serviceName &&
          ipPort == other.ipPort;

  @override
  int get hashCode => Object.hash(serviceName, ipPort);
}
