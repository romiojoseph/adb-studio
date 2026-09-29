import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A highly customizable, state-aware text field component respecting design tokens.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;

  // Custom styling properties
  final Color? fillColor;
  final Color? enabledBorderColor;
  final Color? focusedBorderColor;
  final Color? errorBorderColor;
  final Color? disabledBorderColor;
  final double borderRadius;
  final double borderWidth;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? style;
  final TextStyle? labelStyle;
  final TextStyle? hintStyle;

  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.prefix,
    this.suffix,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.validator,
    this.inputFormatters,
    this.fillColor,
    this.enabledBorderColor,
    this.focusedBorderColor,
    this.errorBorderColor,
    this.disabledBorderColor,
    this.borderRadius = AppSpacing.xs,
    this.borderWidth = 1.0,
    this.contentPadding,
    this.style,
    this.labelStyle,
    this.hintStyle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveFillColor =
        fillColor ?? (enabled ? AppColors.neutral2 : AppColors.neutral1);
    final effectiveEnabledBorder = enabledBorderColor ?? AppColors.neutral3;
    final effectiveFocusedBorder = focusedBorderColor ?? AppColors.neutral5;
    final effectiveErrorBorder = errorBorderColor ?? AppColors.error;
    final effectiveDisabledBorder = disabledBorderColor ?? AppColors.neutral3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: labelStyle ??
                AppTypography.label.copyWith(
                  color: enabled ? AppColors.neutral9 : AppColors.neutral5,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: AppSpacing.xs - 2),
        ],
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          focusNode: focusNode,
          obscureText: obscureText,
          readOnly: readOnly,
          enabled: enabled,
          autofocus: autofocus,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          onTap: onTap,
          validator: validator,
          inputFormatters: inputFormatters,
          style: style ??
              AppTypography.body.copyWith(
                color: enabled ? AppColors.neutral12 : AppColors.neutral6,
              ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: hintStyle ??
                AppTypography.caption.copyWith(color: AppColors.neutral7),
            errorText: null,
            isDense: true,
            prefixIcon: prefixIcon != null
                ? Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: prefixIcon,
                  )
                : null,
            prefixIconConstraints:
                const BoxConstraints(minWidth: 28, minHeight: 28),
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxs),
                    child: suffixIcon,
                  )
                : null,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 28, minHeight: 28),
            prefix: prefix,
            suffix: suffix,
            contentPadding: contentPadding ??
                const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
            filled: true,
            fillColor: effectiveFillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide:
                  BorderSide(color: effectiveEnabledBorder, width: borderWidth),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide:
                  BorderSide(color: effectiveEnabledBorder, width: borderWidth),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(
                  color: effectiveFocusedBorder, width: borderWidth + 0.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide:
                  BorderSide(color: effectiveErrorBorder, width: borderWidth),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(
                  color: effectiveErrorBorder, width: borderWidth + 1.0),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(
                  color: effectiveDisabledBorder, width: borderWidth),
            ),
          ),
        ),
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs + 2),
          Text(
            errorText!,
            style: AppTypography.tagline.copyWith(color: AppColors.error),
          ),
        ] else if (helperText != null && helperText!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs + 2),
          Text(
            helperText!,
            style: AppTypography.tagline.copyWith(color: AppColors.neutral7),
          ),
        ],
      ],
    );
  }
}
