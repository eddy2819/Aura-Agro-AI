import 'package:flutter/material.dart';

import '../../models/animal.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Resumen del hato: Total, Vacas, Toros, Crías (Calculado dinámicamente)
class HerdSummary extends StatelessWidget {
  final List<Animal> animals;

  const HerdSummary({super.key, required this.animals});

  @override
  Widget build(BuildContext context) {
    final total = animals.length;
    final vacas = animals.where((a) => a.category.contains('Vaca') || a.category.contains('Vaquilla')).length;
    final toros = animals.where((a) => a.category.contains('Toro')).length;
    final crias = animals.where((a) => a.category.contains('Ternero') || a.category.contains('Cría')).length;

    final items = [
      (label: 'Total', value: '$total', color: AppColors.primaryGreenDark),
      (label: 'Vacas', value: '$vacas', color: AppColors.primaryGreen),
      (label: 'Toros', value: '$toros', color: AppColors.earthBrown),
      (label: 'Crías', value: '$crias', color: const Color(0xFF1E88E5)),
    ];

    return Row(
      children: items
          .map(
            (i) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        i.value,
                        style: AppTextStyles.h2.copyWith(color: i.color),
                      ),
                      Text(i.label, style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
