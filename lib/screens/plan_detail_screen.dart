import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/data_provider.dart';
import '../models/nutrition_plan.dart';
import '../models/animal.dart';
import '../services/nutrition_ai_service.dart';
import 'premium_result_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Pantalla de detalle de un plan nutricional guardado
class PlanDetailScreen extends StatelessWidget {
  final NutritionPlan plan;
  final Function(String)? onPrefillPlan;

  const PlanDetailScreen({
    super.key,
    required this.plan,
    this.onPrefillPlan,
  });

  String _formatDateTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final months = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
      ];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day $month $year, $hour:$minute';
    } catch (_) {}
    return dateStr;
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'Activo':
        color = AppColors.primaryGreen;
        break;
      case 'Completado':
        color = AppColors.textSecondary;
        break;
      case 'Descartado':
        color = AppColors.alertRed;
        break;
      default:
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: AppTextStyles.badge.copyWith(color: color, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (plan.rawResponse != null && plan.rawResponse!.isNotEmpty) {
      try {
        final decoded = jsonDecode(plan.rawResponse!);
        final result = NutritionPlanResult.fromMap(decoded);
        return PremiumResultScreen(
          result: result,
          targetGroup: plan.targetGroup,
          animalCount: 1,
          targetAnimals: const [],
          confirmedResources: const [],
          isFromHistory: true,
          historicalPlan: plan,
        );
      } catch (e) {
        debugPrint("Error parsing rawResponse for premium view: $e");
      }
    }

    final provider = Provider.of<DataProvider>(context, listen: false);

    // Buscar animal representativo
    Animal? representativeAnimal;
    try {
      representativeAnimal = provider.animals.firstWhere(
        (a) => a.category == plan.targetGroup || a.id == plan.targetGroup || a.name == plan.targetGroup,
      );
    } catch (_) {
      if (provider.animals.isNotEmpty) {
        representativeAnimal = provider.animals.first;
      }
    }

    // Calcular comparación
    double projected = 8.0;
    double real = 0.0;
    bool hasRealData = false;
    String complianceNote = "Sin datos reales registrados para evaluar este plan.";

    if (representativeAnimal != null) {
      final analysis = PlanHistoryAnalyzer.analyze(
        representativeAnimal,
        provider.nutritionPlans,
        provider.weightRecords,
        provider.productionRecords,
      );

      final isLechera = representativeAnimal.category == 'Vaca Lechera';

      // Parsear proyectado
      final regExp = RegExp(r'\+?(\d+(?:\.\d+)?)\s*%');
      final match = regExp.firstMatch(plan.projectedImprovement);
      if (match != null) {
        projected = double.tryParse(match.group(1) ?? '8.0') ?? 8.0;
      } else {
        projected = isLechera ? 8.0 : 12.0;
      }

      if (!analysis.feedbackNote.contains("No se encontraron") && 
          !analysis.feedbackNote.contains("sin registros")) {
        hasRealData = true;
        real = projected * analysis.complianceScore;
        complianceNote = analysis.feedbackNote;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Plan Nutricional'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        plan.targetGroup,
                        style: AppTextStyles.h1.copyWith(color: AppColors.primaryGreenDark),
                      ),
                    ),
                    _statusBadge(plan.status),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _formatDateTime(plan.createdAt),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                const Divider(height: 24),
                
                // Atributos clave
                _detailRow(Icons.grass_rounded, 'Dieta sugerida', plan.suggestedDiet),
                const SizedBox(height: 10),
                _detailRow(Icons.attach_money_rounded, 'Costo diario', '\$${plan.estimatedCostPerDay.toStringAsFixed(2)} / animal / día'),
                const SizedBox(height: 10),
                _detailRow(Icons.savings_rounded, 'Ahorro semanal proyectado', '\$${plan.projectedSavings.toStringAsFixed(0)}'),
                const SizedBox(height: 10),
                _detailRow(Icons.trending_up_rounded, 'Mejora proyectada', plan.projectedImprovement),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Gráfico de Rendimiento
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Text('Evolución de Producción / Peso', style: AppTextStyles.h2),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  complianceNote,
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 24),
                
                // Gráfico de Barras Custom
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildBar('Proyectado', projected, AppColors.primaryGreen, true),
                    _buildBar(
                      'Real Logrado', 
                      real, 
                      real >= projected ? AppColors.primaryGreenLight : AppColors.alertOrange, 
                      hasRealData,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Explicación
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: AppColors.alertOrange),
                    const SizedBox(width: 8),
                    Text('Explicación y Recomendación', style: AppTextStyles.h2),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  plan.explanation,
                  style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botón pre-llenar
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                if (onPrefillPlan != null) {
                  onPrefillPlan!(plan.targetGroup);
                }
                Navigator.pop(context);
              },
              icon: const Icon(Icons.auto_awesome_motion_rounded, color: Colors.white),
              label: Text(
                'Generar nuevo plan basado en este',
                style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String title, String val) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primaryGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(val, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBar(String label, double val, Color color, bool hasData) {
    const maxHeight = 160.0;
    // Escalar asumiendo que un 20% es el 100% de la barra
    final scaleVal = (val / 20.0).clamp(0.01, 1.0);
    final height = scaleVal * maxHeight;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          hasData ? '+${val.toStringAsFixed(1)}%' : 'N/D',
          style: AppTextStyles.bodyBold.copyWith(
            color: hasData ? color : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 50,
          height: hasData ? height : 12.0,
          decoration: BoxDecoration(
            color: hasData ? color : AppColors.border,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            gradient: hasData 
                ? LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [color, color.withOpacity(0.7)],
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
