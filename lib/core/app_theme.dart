import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

export '../theme/app_colors.dart';
export '../theme/app_spacing.dart';
export '../theme/app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme;
    final googleSansTheme = GoogleFonts.googleSansTextTheme(baseTextTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.neutral0,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary4,
        onPrimary: AppColors.neutral12,
        secondary: AppColors.secondary5,
        onSecondary: AppColors.neutral12,
        surface: AppColors.neutral2,
        onSurface: AppColors.neutral12,
        surfaceContainerLowest: AppColors.neutral0,
        surfaceContainerLow: AppColors.neutral1,
        surfaceContainer: AppColors.neutral2,
        surfaceContainerHigh: AppColors.neutral3,
        surfaceContainerHighest: AppColors.neutral4,
        outline: AppColors.neutral4,
        outlineVariant: AppColors.neutral3,
        error: AppColors.error,
        onError: AppColors.neutral12,
      ),
      textTheme: googleSansTheme,
      cardTheme: CardThemeData(
        color: AppColors.neutral2,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xl),
          side: const BorderSide(color: AppColors.neutral3, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.neutral3,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.neutral0,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.neutral12),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.neutral1,
        indicatorColor: AppColors.primary4.withValues(alpha: 0.15),
        selectedIconTheme: const IconThemeData(color: AppColors.primary4),
        unselectedIconTheme: const IconThemeData(color: AppColors.neutral9),
        selectedLabelTextStyle: AppTypography.tagline.copyWith(
          color: AppColors.primary4,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelTextStyle: AppTypography.tagline.copyWith(
          color: AppColors.neutral9,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutral2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          borderSide: const BorderSide(color: AppColors.neutral4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          borderSide: const BorderSide(color: AppColors.neutral4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          borderSide: const BorderSide(color: AppColors.primary4, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary4,
          foregroundColor: AppColors.primary12,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: AppTypography.label.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.neutral11,
          side: const BorderSide(color: AppColors.neutral4),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: AppTypography.label.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary4,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.neutral2,
        shape: ContinuousRectangleBorder(
          side: const BorderSide(color: AppColors.neutral4),
          borderRadius: BorderRadius.circular(AppSpacing.xxl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.neutral3,
        contentTextStyle: AppTypography.body.copyWith(
          color: AppColors.neutral12,
        ),
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          side: const BorderSide(color: AppColors.neutral4),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.neutral3,
          borderRadius: BorderRadius.circular(AppSpacing.xxs),
          border: Border.all(color: AppColors.neutral5),
        ),
        textStyle: AppTypography.caption.copyWith(color: AppColors.neutral12),
      ),
    );
  }
}
