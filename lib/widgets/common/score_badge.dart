import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Badge circular que muestra el score IA (0-100) con color semáforo
class ScoreBadge extends StatelessWidget {
  final int score;
  final double size;

  const ScoreBadge({super.key, required this.score, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.scoreColor(score);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        color: color.withOpacity(0.08),
      ),
      alignment: Alignment.center,
      child: Text(
        '$score',
        style: AppTextStyles.bodyBold.copyWith(
          color: color,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Badge tipo "pill" para categorías: Elite, Premium, Verificado, Vendedor
class CategoryBadge extends StatelessWidget {
  final String label;

  const CategoryBadge({super.key, required this.label});

  Color get _color {
    switch (label.toLowerCase()) {
      case 'elite':
        return const Color(0xFF6A1B9A);
      case 'premium':
        return AppColors.primaryGreenDark;
      case 'verificado':
        return AppColors.primaryGreen;
      case 'vendedor':
        return AppColors.earthBrown;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label.toUpperCase(), style: AppTextStyles.badge),
    );
  }
}
