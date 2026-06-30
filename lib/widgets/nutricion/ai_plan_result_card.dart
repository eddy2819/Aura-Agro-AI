import 'package:flutter/material.dart';

import '../../services/nutrition_ai_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Tarjeta de resultado del plan nutricional generado por IA
class AiPlanResultCard extends StatelessWidget {
  final NutritionPlanResult result;
  final String targetGroup;
  final int animalCount;
  final double? complianceHistory;
  final VoidCallback? onSavePlan;
  final bool isSaved;

  const AiPlanResultCard({
    super.key,
    required this.result,
    required this.targetGroup,
    required this.animalCount,
    this.complianceHistory,
    this.onSavePlan,
    this.isSaved = false,
  });

  Color _getComplianceColor(double compliance) {
    if (compliance >= 90) return Colors.greenAccent;
    if (compliance >= 75) return Colors.yellowAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final isLechera = targetGroup.contains('Lechera');
    final frequencyText = isLechera 
        ? '2 sesiones al día — mañana y tarde' 
        : '1 sesión al día — mañana';

    final isIndividual = animalCount == 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Icon(
                  isIndividual ? Icons.pets_rounded : Icons.groups_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIndividual ? 'Plan para $targetGroup' : 'Plan para: $targetGroup',
                      style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isIndividual ? 'Plan Nutricional IA' : 'Plan Nutricional IA ($animalCount animales)',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _row('Dieta sugerida', result.suggestedDiet),
          _row('Frecuencia', frequencyText),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  icon: Icons.attach_money_rounded,
                  label: 'Costo / animal / día',
                  value: '\$${result.estimatedCostPerDay.toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  icon: Icons.savings_rounded,
                  label: 'Ahorro semanal',
                  value: '\$${result.projectedSavings.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  icon: Icons.trending_up_rounded,
                  label: 'Mejora producción',
                  value: isLechera ? result.projectedImprovement : 'N/A',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  icon: Icons.monitor_heart_rounded,
                  label: 'Mejora de peso',
                  value: !isLechera ? result.projectedImprovement : '+2% / 4 sem',
                ),
              ),
            ],
          ),
          
          if (complianceHistory != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Basado en tu plan anterior',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getComplianceColor(complianceHistory!).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _getComplianceColor(complianceHistory!)),
                        ),
                        child: Text(
                          '${complianceHistory!.toStringAsFixed(0)}% cumpl.',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (complianceHistory! / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getComplianceColor(complianceHistory!),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              result.explanation,
              style: AppTextStyles.body.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),

          if (onSavePlan != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSaved ? null : onSavePlan,
                icon: Icon(
                  isSaved ? Icons.check_circle_outline_rounded : Icons.save_rounded,
                  color: isSaved ? AppColors.textSecondary : AppColors.primaryGreen,
                ),
                label: Text(
                  isSaved ? 'Plan Guardado' : 'Guardar este plan',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: isSaved ? AppColors.textSecondary : AppColors.primaryGreenDark,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSaved ? Colors.white.withOpacity(0.2) : Colors.white,
                  foregroundColor: isSaved ? Colors.white70 : AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: isSaved ? 0 : 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: AppTextStyles.bodyBold.copyWith(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
              ),
            ),
            TextSpan(
              text: value,
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBox({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.h3.copyWith(color: Colors.white)),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withOpacity(0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
