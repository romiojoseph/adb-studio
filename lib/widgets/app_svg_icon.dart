import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

export '../theme/app_icons.dart';

/// A clean, unified SVG icon widget that automatically adapts to the surrounding IconTheme.
class AppSvgIcon extends StatelessWidget {
  final String icon;
  final double? size;
  final Color? color;
  final BlendMode blendMode;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final String? semanticsLabel;

  const AppSvgIcon(
    this.icon, {
    super.key,
    this.size = 18.0,
    this.color,
    this.blendMode = BlendMode.srcIn,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final effectiveSize = size ?? iconTheme.size ?? 18.0;
    final effectiveColor = color ?? iconTheme.color;

    return SvgPicture.asset(
      icon,
      width: effectiveSize,
      height: effectiveSize,
      fit: fit,
      alignment: alignment,
      semanticsLabel: semanticsLabel,
      colorFilter: effectiveColor != null
          ? ColorFilter.mode(effectiveColor, blendMode)
          : null,
    );
  }
}
