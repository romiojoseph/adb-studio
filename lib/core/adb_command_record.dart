class AdbCommandRecord {
  final String id;
  final DateTime timestamp;
  final List<String> args;
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;

  const AdbCommandRecord({
    required this.id,
    required this.timestamp,
    required this.args,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
  });

  bool get isSuccess => exitCode == 0;

  String get displayCommand => 'adb ${args.map(_escapeArg).join(' ')}';

  static String _escapeArg(String arg) {
    if (arg.contains(' ') || arg.contains('"')) {
      return '"${arg.replaceAll('"', r'\"')}"';
    }
    return arg;
  }
}
