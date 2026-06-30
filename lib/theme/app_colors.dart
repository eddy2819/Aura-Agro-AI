import 'package:flutter/material.dart';

/// Paleta de colores AURA Agro AI
/// Verde agro, tonos tierra y acentos naranja para alertas.
class AppColors {
  AppColors._();

  // Verdes principales
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color primaryGreenDark = Color(0xFF1B5E20);
  static const Color primaryGreenLight = Color(0xFF66BB6A);
  static const Color greenSurface = Color(0xFFE8F5E9);

  // Tonos tierra / beige
  static const Color earthBrown = Color(0xFF8D6E63);
  static const Color sandBeige = Color(0xFFF5F0E8);

  // Naranja / alertas
  static const Color alertOrange = Color(0xFFEF6C00);
  static const Color alertOrangeSurface = Color(0xFFFFF3E0);
  static const Color alertRed = Color(0xFFD32F2F);
  static const Color alertYellow = Color(0xFFFBC02D);

  // Neutros
  static const Color background = Color(0xFFF7F8F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1B1B1B);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  // Score colors (semáforo)
  static Color scoreColor(int score) {
    if (score >= 90) return primaryGreen;
    if (score >= 75) return const Color(0xFF7CB342);
    if (score >= 60) return alertYellow;
    return alertRed;
  }

  // Glass effect colors (para liquid glass nav)
  static Color glassFill = Colors.white.withOpacity(0.55);
  static Color glassBorder = Colors.white.withOpacity(0.35);
  static Color glassShadow = Colors.black.withOpacity(0.08);

  // Gradiente principal (usado en headers / score cards)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGreen, primaryGreenDark],
  );
}
