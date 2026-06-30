import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/animal.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/score_badge.dart';

/// Tarjeta moderna para cada animal del hato
class AnimalCard extends StatelessWidget {
  final Animal animal;
  final VoidCallback? onTap;
  final VoidCallback? onWeightTap;
  final double? nutritionCompliance;

  const AnimalCard({
    super.key,
    required this.animal,
    this.onTap,
    this.onWeightTap,
    this.nutritionCompliance,
  });

  IconData get _categoryIcon {
    if (animal.category.contains('Lechera')) return LucideIcons.milk;
    if (animal.category.contains('Toro')) return LucideIcons.flame;
    return LucideIcons.heart;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: animal.hasAlert
                ? AppColors.alertOrange.withOpacity(0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            // Avatar / foto de perfil
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.greenSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: animal.imagePath != null && animal.imagePath!.isNotEmpty
                    ? _buildAnimalImage(animal.imagePath!)
                    : Icon(
                        _categoryIcon,
                        color: AppColors.primaryGreenDark,
                        size: 26,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            // Info principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(animal.name, style: AppTextStyles.h3),
                      const SizedBox(width: 6),
                      Text(
                        animal.tag,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(animal.category, style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                  Text(
                    animal.description,
                    style: AppTextStyles.body.copyWith(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (nutritionCompliance != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.leaf,
                          size: 14,
                          color: _getComplianceColor(nutritionCompliance!),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Plan nutricional activo — cumplimiento: ${nutritionCompliance!.toStringAsFixed(0)}%',
                            style: AppTextStyles.caption.copyWith(
                              color: _getComplianceColor(nutritionCompliance!),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _InfoChip(
                        icon: LucideIcons.scale,
                        label: '${animal.weightKg.toStringAsFixed(0)} kg',
                      ),
                      if (animal.productionLiters != null)
                        _InfoChip(
                          icon: LucideIcons.milk,
                          label: animal.productionLiters!,
                        ),
                      if (animal.vaccineStatus != null)
                        _InfoChip(
                          icon: LucideIcons.syringe,
                          label: 'Vacuna: ${animal.vaccineStatus}',
                          alert: animal.vaccineStatus == 'Vencida',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Score y botón de Pesar
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ScoreBadge(score: animal.score, size: 50),
                if (onWeightTap != null) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: AppColors.greenSurface,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: onWeightTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.scale,
                              color: AppColors.primaryGreen,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Pesar',
                              style: AppTextStyles.bodyBold.copyWith(
                                color: AppColors.primaryGreen,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
  Color _getComplianceColor(double compliance) {
    if (compliance >= 90) return AppColors.primaryGreen;
    if (compliance >= 75) return const Color(0xFF7CB342);
    return AppColors.alertOrange;
  }

  Widget _buildAnimalImage(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: 56,
        height: 56,
        errorBuilder: (context, error, stackTrace) => Icon(
          _categoryIcon,
          color: AppColors.primaryGreenDark,
          size: 26,
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryGreen,
              ),
            ),
          );
        },
      );
    } else {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: 56,
        height: 56,
        errorBuilder: (context, error, stackTrace) => Icon(
          _categoryIcon,
          color: AppColors.primaryGreenDark,
          size: 26,
        ),
      );
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool alert;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.alert = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = alert ? AppColors.alertOrange : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: alert ? AppColors.alertOrangeSurface : AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
