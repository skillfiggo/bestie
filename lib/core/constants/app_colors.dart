import 'package:flutter/material.dart';

/// YADA Color Theme - Green & Lime Accent Palette
class AppColors {
  AppColors._();

  // Primary Brand Colors
  static const Color primary = Color(0xFF6CC449);       // Main green
  static const Color primaryDark = Color(0xFF1E9A36);   // Deep green
  static const Color lime = Color(0xFFC5F96C);          // Lime accents
  static const Color limeSoft = Color(0xFFE8FF9A);      // Glow highlight

  // Background colors
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFF1A1A1A);
  static const Color cardBackground = Color(0xFFF9FFF1); // Soft cream
  static const Color surface = Color(0xFFF9FFF1);        // Soft cream (alias)
  static const Color surfaceDark = Color(0xFF2C2C2C);

  // Text colors
  static const Color textPrimary = Color(0xFF1A1A1A);    // Dark text
  static const Color textSecondary = Color(0xFF7E8A7D);  // Grey text
  static const Color textLight = Color(0xFFB2BEC3);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Badge/Status colors
  static const Color success = Color(0xFF00C853);        // Badge green
  static const Color error = Color(0xFFFF5252);          // Badge red
  static const Color warning = Color(0xFFFFD600);        // Badge yellow
  static const Color info = Color(0xFF74B9FF);
}
