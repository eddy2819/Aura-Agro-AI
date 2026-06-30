import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/data_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../ganado/production_register_sheet.dart';

/// Grid 2x2 con los indicadores rápidos: Total Ganado, Producción, Peso, Score Salud
class QuickStatsGrid extends StatelessWidget {
  final void Function(int navIndex)? onNavigate;

  const QuickStatsGrid({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DataProvider>(context);
    final animals = provider.animals;
    final totalGanado = animals.length;

    // Calcular peso promedio
    final avgWeight = totalGanado > 0
        ? (animals.map((a) => a.weightKg).reduce((a, b) => a + b) / totalGanado)
        : 0.0;

    // Calcular score promedio
    final avgScore = totalGanado > 0
        ? (animals.map((a) => a.score).reduce((a, b) => a + b) / totalGanado).round()
        : 0;

    // Calcular producción hoy y ayer en base a registros de BD reales
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final yesterdayStr = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T')[0];

    final todayRecords = provider.productionRecords.where((r) => r.date.startsWith(todayStr)).toList();
    final yesterdayRecords = provider.productionRecords.where((r) => r.date.startsWith(yesterdayStr)).toList();

    double totalProductionToday = todayRecords.fold(0.0, (sum, r) => sum + r.liters);
    double totalProductionYesterday = yesterdayRecords.fold(0.0, (sum, r) => sum + r.liters);

    double variationPercent = 0.0;
    if (totalProductionYesterday > 0) {
      variationPercent = ((totalProductionToday - totalProductionYesterday) / totalProductionYesterday) * 100;
    }

    final hasTodayRecord = todayRecords.isNotEmpty;

    final stats = [
      (
        icon: LucideIcons.beef,
        label: 'Total Ganado',
        value: '$totalGanado',
        sub: totalGanado > 5 ? '+${totalGanado - 5} este mes' : 'Estable',
        color: AppColors.primaryGreen,
      ),
      (
        icon: LucideIcons.milk,
        label: 'Producción Hoy',
        value: hasTodayRecord ? '${totalProductionToday.toStringAsFixed(1)} L' : 'Sin registro hoy',
        sub: totalProductionYesterday > 0
            ? '${variationPercent >= 0 ? '+' : ''}${variationPercent.toStringAsFixed(1)}% vs ayer'
            : 'Estable',
        color: const Color(0xFF1E88E5),
      ),
      (
        icon: LucideIcons.scale,
        label: 'Peso Promedio',
        value: '${avgWeight.toStringAsFixed(0)} kg',
        sub: 'Óptimo',
        color: AppColors.earthBrown,
      ),
      (
        icon: LucideIcons.heartPulse,
        label: 'Score IA Salud',
        value: '$avgScore%',
        sub: avgScore >= 90 ? 'Excelente' : (avgScore >= 75 ? 'Bueno' : 'Cuidado'),
        color: AppColors.primaryGreenDark,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.22,
      ),
      itemBuilder: (context, index) {
        final s = stats[index];

        if (index == 1) {
          // Tarjeta de producción con acceso rápido y animaciones
          final subColor = variationPercent >= 0 ? AppColors.primaryGreen : AppColors.alertOrange;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: !hasTodayRecord ? AppColors.primaryGreen.withOpacity(0.3) : AppColors.border,
                width: !hasTodayRecord ? 1.5 : 1.0,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: s.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(s.icon, size: 18, color: s.color),
                    ),
                    const Spacer(),
                    Text(
                      s.value,
                      style: hasTodayRecord
                          ? AppTextStyles.h2
                          : AppTextStyles.h3.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(s.label, style: AppTextStyles.caption),
                    const SizedBox(height: 2),
                    Text(
                      s.sub,
                      style: AppTextStyles.caption.copyWith(
                        color: subColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                // Botón "+"
                Positioned(
                  top: 0,
                  right: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) {
                            return ProductionRegisterSheet(onNavigate: onNavigate);
                          },
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: !hasTodayRecord
                          ? Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.greenSurface,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.plus,
                                color: AppColors.primaryGreen,
                                size: 22,
                              ),
                            )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.25, 1.25), duration: 800.ms, curve: Curves.easeInOut)
                              .then()
                              .boxShadow(
                                begin: const BoxShadow(color: Colors.transparent, blurRadius: 0),
                                end: BoxShadow(color: AppColors.primaryGreen.withOpacity(0.2), blurRadius: 6.0),
                              )
                          : Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(
                                LucideIcons.plus,
                                color: AppColors.textSecondary,
                                size: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: s.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(s.icon, size: 18, color: s.color),
              ),
              const Spacer(),
              Text(s.value, style: AppTextStyles.h2),
              Text(s.label, style: AppTextStyles.caption),
              const SizedBox(height: 2),
              Text(
                s.sub,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
