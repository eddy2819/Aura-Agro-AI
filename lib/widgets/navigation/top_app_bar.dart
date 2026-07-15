import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../screens/profile_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/connection_status.dart';

/// Barra superior reutilizable: logo AURA, badge de rol y estado de conexión
class AuraTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String role; // "Ganadero", "Veterinario", etc.

  const AuraTopBar({super.key, this.role = 'Ganadero'});

  @override
  Size get preferredSize => const Size.fromHeight(74);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 74,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.asset(
              'assets/icon/logotipo.png',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: AppColors.greenSurface,
                child: Icon(LucideIcons.leaf, color: AppColors.primaryGreen),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AURA Agro AI',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primaryGreenDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
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
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
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

/// Cabecera coherente para pantallas internas que necesitan botón Atrás.
class AuraPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;
  final bool showBack;
  final bool showProfile;
  final bool showConnection;

  const AuraPageAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.showBack = true,
    this.showProfile = true,
    this.showConnection = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(74);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 74,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      leading: showBack
          ? IconButton(
              tooltip: 'Volver',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(
                LucideIcons.arrowLeft,
                color: AppColors.primaryGreenDark,
              ),
            )
          : null,
      titleSpacing: showBack ? 0 : 16,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.asset(
              'assets/icon/logotipo.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: AppColors.greenSurface,
                child: Icon(LucideIcons.leaf, color: AppColors.primaryGreen),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h3.copyWith(
                color: AppColors.primaryGreenDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (showConnection) const ConnectionStatus(),
        ...actions,
        if (showProfile)
          IconButton(
            tooltip: 'Mi perfil',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: AppColors.greenSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.user,
                size: 18,
                color: AppColors.primaryGreenDark,
              ),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}
