import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/data_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/navigation/liquid_glass_bottom_nav.dart';
import 'ganado_screen.dart';
import 'home_screen.dart';
import 'nutricion_screen.dart';
import 'veterinario_screen.dart';
import 'marketplace_screen.dart';
import 'pending_vet_screen.dart';
import 'admin_panel_screen.dart';

/// Contenedor principal: maneja el índice activo y muestra
/// la pantalla correspondiente + el bottom nav "liquid glass".
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _onNavigate(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DataProvider>(context);
    final profile = provider.profile ?? {};
    final role = profile['role'] ?? 'Ganadero';
    final status = profile['status'] ?? 'active';

    // 1. Redirigir si el veterinario está pendiente de aprobación
    if (role == 'Veterinario' && status == 'pending') {
      return const PendingVetScreen();
    }

    // 2. Redirigir si es administrador
    if (role == 'Admin') {
      return const AdminPanelScreen();
    }

    final screens = <Widget>[];
    final navItems = <NavItem>[];

    // Todos los roles autorizados ven Inicio
    screens.add(HomeScreen(onNavigate: _onNavigate));
    navItems.add(const NavItem(
      icon: LucideIcons.home,
      activeIcon: LucideIcons.home,
      label: 'Inicio',
    ));

    if (role == 'Veterinario') {
      screens.add(const VeterinarioScreen());
      navItems.add(const NavItem(
        icon: LucideIcons.stethoscope,
        activeIcon: LucideIcons.stethoscope,
        label: 'Veterinario',
      ));
      // Sin acceso comercial: no se agrega MarketplaceScreen para Veterinario
    } else if (role == 'Comprador') {
      // Comprador solo ve Inicio y Mercado
      screens.add(const MarketplaceScreen());
      navItems.add(const NavItem(
        icon: LucideIcons.store,
        activeIcon: LucideIcons.store,
        label: 'Mercado',
      ));
    } else {
      // Ganadero / default: tiene acceso completo tradicional
      screens.add(GanadoScreen(onNavigate: _onNavigate));
      navItems.add(const NavItem(
        icon: LucideIcons.beef,
        activeIcon: LucideIcons.beef,
        label: 'Ganado',
      ));

      screens.add(const NutricionScreen());
      navItems.add(const NavItem(
        icon: LucideIcons.brainCircuit,
        activeIcon: LucideIcons.brainCircuit,
        label: 'IA Nutrición',
      ));

      screens.add(const MarketplaceScreen());
      navItems.add(const NavItem(
        icon: LucideIcons.store,
        activeIcon: LucideIcons.store,
        label: 'Mercado',
      ));
    }

    // Ajustar el índice para no salir de los límites si el rol cambia en caliente
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true, // permite que el contenido pase detrás del nav glass
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: LiquidGlassBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavigate,
        items: navItems,
      ),
    );
  }
}
