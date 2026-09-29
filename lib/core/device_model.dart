class AdbDevice {
  final String serial;
  final String state;
  final String model;
  final String product;
  final String device;
  final String transportId;

  const AdbDevice({
    required this.serial,
    required this.state,
    this.model = '',
    this.product = '',
    this.device = '',
    this.transportId = '',
  });

  bool get isWireless => serial.contains(':') || serial.contains('._adb-tls-connect');
  bool get isOnline => state.toLowerCase() == 'device';

  String get displayName {
    if (model.isNotEmpty) {
      return model.replaceAll('_', ' ');
    }
    if (device.isNotEmpty) {
      return device;
    }
    return serial;
  }

  factory AdbDevice.fromLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('List of devices')) {
      return const AdbDevice(serial: '', state: 'unknown');
    }

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return const AdbDevice(serial: '', state: 'unknown');
    }

    const knownStates = {
      'device',
      'offline',
      'unauthorized',
      'recovery',
      'bootloader',
      'sideload',
      'authorizing',
      'connecting',
      'unknown',
    };

    int stateIndex = -1;
    for (int i = 1; i < parts.length; i++) {
      final token = parts[i].toLowerCase();
      if (knownStates.contains(token)) {
        stateIndex = i;
        break;
      }
    }

    String serial;
    String state;
    int propertiesStartIndex;

    if (stateIndex != -1) {
      serial = parts.sublist(0, stateIndex).join(' ');
      state = parts[stateIndex];
      propertiesStartIndex = stateIndex + 1;
    } else {
      serial = parts[0];
      state = parts.length > 1 ? parts[1] : 'unknown';
      propertiesStartIndex = 2;
    }

    var model = '';
    var product = '';
    var device = '';
    var transportId = '';

    for (int i = propertiesStartIndex; i < parts.length; i++) {
      final token = parts[i];
      if (token.startsWith('model:')) {
        model = token.substring('model:'.length);
      } else if (token.startsWith('product:')) {
        product = token.substring('product:'.length);
      } else if (token.startsWith('device:')) {
        device = token.substring('device:'.length);
      } else if (token.startsWith('transport_id:')) {
        transportId = token.substring('transport_id:'.length);
      }
    }

    return AdbDevice(
      serial: serial,
      state: state,
      model: model,
      product: product,
      device: device,
      transportId: transportId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdbDevice &&
          runtimeType == other.runtimeType &&
          serial == other.serial;

  @override
  int get hashCode => serial.hashCode;
}
