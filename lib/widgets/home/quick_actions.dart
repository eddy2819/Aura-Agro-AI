import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

import 'package:provider/provider.dart';
import '../../data/data_provider.dart';

/// Botones de acciones rápidas: Registrar Animal, Nueva Vacuna, Consultar IA, Ir al Mercado
class QuickActions extends StatelessWidget {
  final void Function(int navIndex)? onNavigate;

  const QuickActions({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (icon: LucideIcons.plusCircle, label: 'Registrar\nAnimal', nav: 1),
      (icon: LucideIcons.syringe, label: 'Nueva\nVacuna', nav: 3),
      (icon: LucideIcons.brainCircuit, label: 'Consultar\nIA', nav: 2),
      (icon: LucideIcons.store, label: 'Ir al\nMercado', nav: 4),
    ];

    return Row(
      children: actions
          .map(
            (a) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () {
                    if (a.nav == 3) {
                      Provider.of<DataProvider>(context, listen: false).setActiveVetTab(2);
                    }
                    onNavigate?.call(a.nav);
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(a.icon, color: AppColors.primaryGreen, size: 22),
                        const SizedBox(height: 6),
                        Text(
                          a.label,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
