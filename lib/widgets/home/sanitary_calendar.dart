import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Calendario sanitario con próximos eventos
class SanitaryCalendar extends StatelessWidget {
  const SanitaryCalendar({super.key});

  @override
  Widget build(BuildContext context) {
    final events = [
      (
        date: '28',
        month: 'May',
        title: 'Vacunación masiva',
        sub: '45 animales',
      ),
      (date: '01', month: 'Jun', title: 'Pesaje mensual', sub: '120 animales'),
      (
        date: '05',
        month: 'Jun',
        title: 'Visita veterinario',
        sub: '8 animales',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: events
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.greenSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            e.date,
                            style: AppTextStyles.bodyBold.copyWith(
                              color: AppColors.primaryGreenDark,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            e.month,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryGreen,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.title, style: AppTextStyles.bodyBold),
                          Text(e.sub, style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
