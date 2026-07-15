import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../screens/profile_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/connection_status.dart';
import '../common/aura_brand_logo.dart';

/// Barra superior reutilizable: logo AURA, badge de rol y estado de conexión
class AuraTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String role; // "Ganadero", "Veterinario", etc.

  const AuraTopBar({super.key, this.role = 'Ganadero'});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const AuraBrandLogo(size: 42),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AURA Agro AI',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primaryGreenDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(role, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
      actions: [
        const ConnectionStatus(),
        const SizedBox(width: 4),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.user,
              size: 18,
              color: AppColors.primaryGreen,
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}
