import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_colors.dart';

import 'app_svg_icon.dart';

class WindowControls extends StatefulWidget {
  final Brightness? brightness;

  const WindowControls({super.key, this.brightness});

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.addListener(this);
      _checkMaximized();
    }
  }

  @override
  void dispose() {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    try {
      final max = await windowManager.isMaximized();
      if (mounted) setState(() => _isMaximized = max);
    } catch (_) {}
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb ||
        (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          iconWidget: const AppSvgIcon(
            AppIcons.minus,
            size: 14,
            color: AppColors.neutral9,
          ),
          tooltip: 'Minimize',
          onPressed: () => windowManager.minimize(),
        ),
        _WindowButton(
          iconWidget: AppSvgIcon(
            _isMaximized ? AppIcons.squaresBold : AppIcons.squareBold,
            size: 14,
            color: AppColors.neutral9,
          ),
          tooltip: _isMaximized ? 'Restore' : 'Maximize',
          onPressed: () async {
            if (_isMaximized) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        _WindowButton(
          iconWidget: const AppSvgIcon(
            AppIcons.x,
            size: 14,
            color: AppColors.neutral9,
          ),
          tooltip: 'Close',
          isClose: true,
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _WindowButton extends StatefulWidget {
  final Widget iconWidget;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isClose;

  const _WindowButton({
    required this.iconWidget,
    required this.tooltip,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color hoverColor = widget.isClose
        ? AppColors.danger6
        : AppColors.neutral4;
    final Color iconColor = _isHovered && widget.isClose
        ? Colors.white
        : AppColors.neutral11;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 46,
            height: 38,
            color: _isHovered ? hoverColor : Colors.transparent,
            alignment: Alignment.center,
            child: IconTheme(
              data: IconThemeData(color: iconColor, size: 14),
              child: widget.iconWidget,
            ),
          ),
        ),
      ),
    );
  }
}
