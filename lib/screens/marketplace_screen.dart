import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/data_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/marketplace/market_filters.dart';
import '../widgets/marketplace/market_item_card.dart';
import '../widgets/marketplace/premium_banner.dart';
import '../widgets/navigation/top_app_bar.dart';
import 'market_item_detail_screen.dart';
import 'publish_wizard_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String _category = 'Todo';
  int _activeTab = 0; // 0 = Comprar, 1 = Vender (Solo Ganadero)

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DataProvider>(context);
    final role = provider.profile?['role'] ?? 'Ganadero';
    final isGanadero = role == 'Ganadero';

    final items = _category == 'Todo'
        ? provider.marketplaceItems
        : provider.marketplaceItems
              .where((i) => i.category == _category)
              .toList();

    return Scaffold(
      appBar: AuraTopBar(role: role),
      floatingActionButton: isGanadero && _activeTab == 1
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PublishWizardScreen()),
                );
              },
              backgroundColor: AppColors.primaryGreen,
              icon: const Icon(Icons.sell_rounded, color: Colors.white),
              label: Text(
                'Publicar',
                style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Text('Marketplace', style: AppTextStyles.h1),
          Text(
            'Comercio directo con trazabilidad certificada',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),

          // Renderizar pestañas superiores si es Ganadero
          if (isGanadero) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.sandBeige,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _activeTab == 0 ? AppColors.primaryGreen : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Comprar',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: _activeTab == 0 ? Colors.white : AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _activeTab == 1 ? AppColors.primaryGreen : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Vender / Mis Anuncios',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: _activeTab == 1 ? Colors.white : AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Contenido de la pestaña activa o vista única
          if (!isGanadero || _activeTab == 0) ...[
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    icon: Icons.storefront_rounded,
                    value: '${provider.marketplaceItems.length}',
                    label: 'Publicaciones activas',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    icon: Icons.attach_money_rounded,
                    value: '\$1,450',
                    label: 'Precio promedio',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            PremiumBanner(onActivate: () {}),
            const SizedBox(height: 14),

            MarketFilters(
              onCategoryChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 16),

            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No hay publicaciones en esta categoría',
                    style: AppTextStyles.body,
                  ),
                ),
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: MarketItemCard(
                    item: item,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MarketItemDetailScreen(item: item),
                        ),
                      );
                    },
                    onContact: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MarketItemDetailScreen(item: item),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ] else ...[
            // VISTA VENDER / MIS PUBLICACIONES (Solo para Ganadero)
            if (provider.myPublications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: AppColors.greenSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.primaryGreen,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '¿Quieres vender en el Marketplace?',
                      style: AppTextStyles.h2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Publica tus animales con trazabilidad garantizada por IA y conecta directo con compradores.',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PublishWizardScreen()),
                          );
                        },
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                        label: Text(
                          'Publicar tu primer anuncio',
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
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      icon: Icons.storefront_rounded,
                      value: '${provider.myPublications.length}',
                      label: 'Tus anuncios activos',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...provider.myPublications.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: MarketItemCard(
                    item: item,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MarketItemDetailScreen(item: item),
                        ),
                      );
                    },
                    onContact: () {},
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.greenSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryGreenDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTextStyles.h3),
                Text(
                  label,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
