import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../screens/inventory_screen.dart';
import '../../screens/my_veterinarian_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class HomeModuleGrid extends StatelessWidget {
  final void Function(int index)? onNavigate;
  final VoidCallback onShowAlerts;

  const HomeModuleGrid({
    super.key,
    this.onNavigate,
    required this.onShowAlerts,
  });

  @override
  Widget build(BuildContext context) {
    final modules =
        <({IconData icon, String label, Color color, VoidCallback tap})>[
          (
            icon: LucideIcons.radioTower,
            label: 'Alertas\npreventivas',
            color: const Color(0xFF18A67A),
            tap: onShowAlerts,
          ),
          (
            icon: LucideIcons.heartPulse,
            label: 'Historial\nclínico',
            color: const Color(0xFF397A67),
            tap: () => onNavigate?.call(1),
          ),
          (
            icon: LucideIcons.briefcaseMedical,
            label: 'Inventario de\nmedicamentos',
            color: const Color(0xFF268E69),
            tap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InventoryScreen()),
            ),
          ),
          (
            icon: LucideIcons.scanQrCode,
            label: 'Trazabilidad\ncon QR',
            color: const Color(0xFF167A56),
            tap: () => onNavigate?.call(1),
          ),
          (
            icon: LucideIcons.store,
            label: 'Marketplace\nganadero',
            color: const Color(0xFF329769),
            tap: () => onNavigate?.call(4),
          ),
          (
            icon: LucideIcons.stethoscope,
            label: 'Mi\nveterinario',
            color: const Color(0xFF4E9876),
            tap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyVeterinarianScreen()),
            ),
          ),
        ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modules.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: .92,
      ),
      itemBuilder: (_, index) {
        final module = modules[index];
        return Material(
          color: AppColors.surface,
          elevation: 1,
          shadowColor: Colors.black12,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: module.tap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: module.color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(module.icon, color: module.color, size: 25),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    module.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
