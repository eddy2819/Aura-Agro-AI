import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/data_provider.dart';
import '../models/score_breakdown.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common/ai_recommendation_card.dart';
import '../widgets/common/section_title.dart';
import '../widgets/home/score_overview_card.dart';
import '../widgets/home/quick_stats_grid.dart';
import '../widgets/home/alerts_list.dart';
import '../widgets/home/sanitary_calendar.dart';
import '../widgets/home/quick_actions.dart';
import '../widgets/home/home_module_grid.dart';
import '../widgets/common/aura_brand_logo.dart';
import '../widgets/home/ganadero_home_dashboard.dart';
import '../widgets/navigation/top_app_bar.dart';
import 'sos_screen.dart';
import 'inventory_screen.dart';
import 'finance_screen.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int navIndex)? onNavigate;

  const HomeScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final role =
        Provider.of<DataProvider>(context).profile?['role'] ?? 'Ganadero';
    return Scaffold(
      appBar: AuraTopBar(role: role),
      body: Consumer<DataProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }

          final profile = provider.profile ?? {};
          final ownerName = profile['owner_name'] ?? 'Usuario';
          final farmName = profile['farm_name'] ?? 'Mi Finca';

          final animals = provider.animals;
          final alerts = provider.alerts;

          int overallScore = 87;
          int healthScore = 92;
          int nutritionScore = 85;
          int vaccinationScore = 88;
          int productivityScore = 83;

          final dynamicScore = ScoreBreakdown(
            overall: overallScore,
            trend: 3,
            health: healthScore,
            nutrition: nutritionScore,
            vaccination: vaccinationScore,
            productivity: productivityScore,
            zoneAverage: 72,
          );

          final hour = DateTime.now().hour;
          final greeting = (hour >= 5 && hour < 12)
              ? 'Buenos días'
              : (hour >= 12 && hour < 19)
              ? 'Buenas tardes'
              : 'Buenas noches';

          if (role == 'Ganadero') {
            return GanaderoHomeDashboard(
              provider: provider,
              greeting: greeting,
              ownerName: ownerName,
              farmName: farmName,
              onNavigate: onNavigate,
            );
          }

          final content = <Widget>[];

          content.add(
            Text(
              '$greeting, ${role == 'Veterinario' ? 'Dr. ' : ''}$ownerName',
              style: AppTextStyles.h1,
            ),
          );
          content.add(const SizedBox(height: 2));

          if (role == 'Veterinario') {
            content.add(
              Text(
                'Revisando el estado clínico de las fincas autorizadas',
                style: AppTextStyles.body,
              ),
            );
            content.add(const SizedBox(height: 16));

            final activeAuths = provider.farmAuthorizations
                .where((auth) => auth['status'] == 'active')
                .toList();
            final farmCount = activeAuths.length;
            final animalCount = animals.length;
            final alertCount = alerts.length;

            content.add(
              Row(
                children: [
                  Expanded(
                    child: _buildVetStatCard(
                      title: 'Fincas Activas',
                      value: '$farmCount',
                      icon: LucideIcons.home,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildVetStatCard(
                      title: 'Pacientes',
                      value: '$animalCount',
                      icon: LucideIcons.beef,
                      color: AppColors.primaryGreenDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildVetStatCard(
                      title: 'Alertas',
                      value: '$alertCount',
                      icon: LucideIcons.alertTriangle,
                      color: AppColors.alertOrange,
                    ),
                  ),
                ],
              ),
            );

            content.add(const SizedBox(height: 24));
            content.add(
              SectionTitle(
                title: 'Alertas Sanitarias de Fincas',
                actionLabel: 'Ver todas',
                onActionTap: () => onNavigate?.call(1),
              ),
            );
            content.add(const SizedBox(height: 12));
            if (alerts.isEmpty) {
              content.add(
                Card(
                  color: AppColors.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            LucideIcons.checkCircle,
                            color: AppColors.primaryGreen,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sin Alertas Sanitarias',
                            style: AppTextStyles.bodyBold,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No hay alertas pendientes en tus fincas autorizadas.',
                            style: AppTextStyles.caption,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            } else {
              content.add(AlertsList(alerts: alerts));
            }

            content.add(const SizedBox(height: 24));
            content.add(
              SectionTitle(
                title: 'Calendario Sanitario',
                actionLabel: 'Ver todo',
              ),
            );
            content.add(const SizedBox(height: 12));
            content.add(const SanitaryCalendar());
          } else if (role == 'Comprador') {
            content.add(
              Text(
                'Encuentra y adquiere el mejor ganado para tu negocio',
                style: AppTextStyles.body,
              ),
            );
            content.add(const SizedBox(height: 16));

            // Premium Glassmorphic / Gradient card for AURA trust score
            content.add(
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primaryGreen,
                      AppColors.primaryGreenDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.shieldCheck,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Score de Confianza AURA',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Compra con total seguridad. Todos los animales con score superior a 80 cuentan con historial sanitario validado por veterinarios certificados.',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
            content.add(const SizedBox(height: 20));

            // Categorías de Compra
            content.add(Text('Categorías de Compra', style: AppTextStyles.h2));
            content.add(const SizedBox(height: 12));
            content.add(
              Row(
                children: [
                  Expanded(
                    child: _buildBuyerCategoryCard(
                      title: 'Producción',
                      icon: LucideIcons.milk,
                      onTap: () => onNavigate?.call(1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBuyerCategoryCard(
                      title: 'Reproducción',
                      icon: LucideIcons.heart,
                      onTap: () => onNavigate?.call(1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBuyerCategoryCard(
                      title: 'Engorde',
                      icon: LucideIcons.trendingUp,
                      onTap: () => onNavigate?.call(1),
                    ),
                  ),
                ],
              ),
            );
            content.add(const SizedBox(height: 20));

            // Destacados AURA
            content.add(
              SectionTitle(
                title: 'Destacados AURA',
                actionLabel: 'Ver todo',
                onActionTap: () => onNavigate?.call(1),
              ),
            );
            content.add(const SizedBox(height: 12));

            content.add(
              Column(
                children: [
                  _buildFeaturedItemTile(
                    name: 'Novilla Holstein F1',
                    score: 94,
                    price: '\$1,200',
                    breed: 'Holstein',
                    farmName: 'Finca Taquil',
                  ),
                  _buildFeaturedItemTile(
                    name: 'Toro Brown Swiss',
                    score: 89,
                    price: '\$2,500',
                    breed: 'Brown Swiss',
                    farmName: 'Hacienda Loja',
                  ),
                ],
              ),
            );
          } else {
            // Ganadero / default
            content.add(
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF7FBF8), Color(0xFFEAF5EE)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primaryGreen.withValues(alpha: .16),
                  ),
                ),
                child: Row(
                  children: [
                    const AuraBrandLogo(size: 70),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AURA',
                            style: AppTextStyles.h2.copyWith(
                              color: AppColors.primaryGreenDark,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gestión ganadera inteligente, incluso sin conexión',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            farmName,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
            content.add(const SizedBox(height: 16));
            content.add(
              HomeModuleGrid(
                onNavigate: onNavigate,
                onShowAlerts: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Alertas preventivas', style: AppTextStyles.h2),
                          const SizedBox(height: 12),
                          if (alerts.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text('No hay alertas activas.'),
                              ),
                            )
                          else
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * .58,
                              child: SingleChildScrollView(
                                child: AlertsList(alerts: alerts),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            content.add(const SizedBox(height: 16));

            // BOTÓN CRÍTICO DE AURA SOS GANADERO
            content.add(
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SosScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.shade900.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.shieldAlert,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AURA SOS GANADERO',
                              style: AppTextStyles.bodyBold.copyWith(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Triaje médico de emergencias y contacto directo',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        LucideIcons.chevronRight,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
            content.add(const SizedBox(height: 16));

            content.add(
              AiRecommendationCard(
                title: 'Mejora la producción de leche',
                description:
                    'Basado en el análisis de tus vacas lecheras, agregar 200g de melaza al concentrado de la tarde puede aumentar la producción hasta un 8%.',
                savingLabel: 'Ahorro: \$45/semana',
                onViewPlan: () => onNavigate?.call(2),
              ),
            );
            content.add(const SizedBox(height: 16));

            content.add(ScoreOverviewCard(score: dynamicScore));
            content.add(const SizedBox(height: 16));

            content.add(QuickStatsGrid(onNavigate: onNavigate));
            content.add(const SizedBox(height: 16));

            // TARJETAS DE ACCESO A FINANZAS E INVENTARIO
            content.add(
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const FinanceScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              LucideIcons.wallet,
                              color: AppColors.primaryGreen,
                              size: 24,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Finanzas',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Costos y Ventas',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const InventoryScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              LucideIcons.package,
                              color: AppColors.primaryGreen,
                              size: 24,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Inventario',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Medicamentos',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
            content.add(const SizedBox(height: 20));

            content.add(
              SectionTitle(
                title: 'Alertas Activas',
                actionLabel: 'Ver todas',
                onActionTap: () => onNavigate?.call(3),
              ),
            );
            content.add(const SizedBox(height: 12));
            content.add(AlertsList(alerts: alerts));
            content.add(const SizedBox(height: 20));

            content.add(
              SectionTitle(
                title: 'Calendario Sanitario',
                actionLabel: 'Ver todo',
              ),
            );
            content.add(const SizedBox(height: 12));
            content.add(const SanitaryCalendar());
            content.add(const SizedBox(height: 20));

            content.add(Text('Acciones Rápidas', style: AppTextStyles.h3));
            content.add(const SizedBox(height: 12));
            content.add(QuickActions(onNavigate: onNavigate));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: content,
          );
        },
      ),
    );
  }

  Widget _buildVetStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(color: color, fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTextStyles.caption.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerCategoryCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryGreen, size: 24),
            const SizedBox(height: 8),
            Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedItemTile({
    required String name,
    required int score,
    required String price,
    required String breed,
    required String farmName,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.greenSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  '$score',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.primaryGreenDark,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'AURA',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreenDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.bodyBold),
                const SizedBox(height: 2),
                Text('$breed • $farmName', style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(
            price,
            style: AppTextStyles.h3.copyWith(color: AppColors.primaryGreen),
          ),
        ],
      ),
    );
  }
}
