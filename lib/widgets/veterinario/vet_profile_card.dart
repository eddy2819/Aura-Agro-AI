import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Tarjeta de perfil del veterinario + indicadores rápidos
class VetProfileCard extends StatelessWidget {
  const VetProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. Carlos Ruiz',
                      style: AppTextStyles.h2.copyWith(color: Colors.white),
                    ),
                    Text(
                      'Veterinario Certificado',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    Text(
                      'Reg. MAG-2024-1234',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatTile(value: '3', label: 'Fincas'),
            const SizedBox(width: 8),
            _StatTile(value: '3', label: 'Alertas', alert: true),
            const SizedBox(width: 8),
            _StatTile(value: '422', label: 'Animales'),
            const SizedBox(width: 8),
            _StatTile(value: '45', label: 'Vacunas Pend.'),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final bool alert;

  const _StatTile({
    required this.value,
    required this.label,
    this.alert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: alert ? AppColors.alertOrangeSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: alert
                ? AppColors.alertOrange.withOpacity(0.3)
                : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.h2.copyWith(
                color: alert ? AppColors.alertOrange : AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
