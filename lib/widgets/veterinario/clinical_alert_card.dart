import 'package:flutter/material.dart';

import '../../models/alert_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Tarjeta de alerta clínica detallada con score de riesgo,
/// síntomas y recomendación de la IA
class ClinicalAlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback? onRegisterTreatment;

  const ClinicalAlertCard({
    super.key,
    required this.alert,
    this.onRegisterTreatment,
  });

  @override
  Widget build(BuildContext context) {
    final risk = alert.riskScore ?? 0;
    final riskColor = risk >= 90
        ? AppColors.alertRed
        : risk >= 70
        ? AppColors.alertOrange
        : AppColors.alertYellow;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.animalName, style: AppTextStyles.h3),
                    if (alert.farm != null)
                      Text(alert.farm!, style: AppTextStyles.caption),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      '$risk%',
                      style: AppTextStyles.h3.copyWith(color: riskColor),
                    ),
                    Text(
                      'Riesgo',
                      style: AppTextStyles.caption.copyWith(
                        color: riskColor,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.monitor_heart_rounded, size: 16, color: riskColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  alert.title,
                  style: AppTextStyles.bodyBold.copyWith(color: riskColor),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Text(
              'Detectado: ${alert.detectedAgo}',
              style: AppTextStyles.caption,
            ),
          ),
          if (alert.symptoms.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Síntomas detectados:',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: alert.symptoms
                  .map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        s,
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (alert.aiRecommendation != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.greenSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: AppColors.primaryGreenDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recomendación IA: ${alert.aiRecommendation}',
                      style: AppTextStyles.body.copyWith(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRegisterTreatment,
              icon: const Icon(Icons.assignment_add, size: 16),
              label: const Text('Registrar Tratamiento'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreenDark,
                side: BorderSide(color: AppColors.primaryGreen),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: AppTextStyles.bodyBold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
