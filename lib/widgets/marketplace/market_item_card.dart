import 'package:flutter/material.dart';

import '../../models/marketplace_item.dart';
import 'auto_carousel.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/score_badge.dart';

/// Tarjeta de publicación del marketplace - estilo "premium card"
class MarketItemCard extends StatelessWidget {
  final MarketplaceItem item;
  final VoidCallback? onTap;
  final VoidCallback? onContact;

  const MarketItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onContact,
  });

  String get _priceLabel {
    if (item.category == 'Leche')
      return '\$${item.price.toStringAsFixed(2)}/litro';
    if (item.category == 'Queso')
      return '\$${item.price.toStringAsFixed(1)}/lb';
    if (item.category == 'Ganado' && item.title.contains('Terneros')) {
      return '\$${item.price.toStringAsFixed(0)}/c.u.';
    }
    return '\$${item.price.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen / icono + badges superiores
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: AutoCarousel(
                    imagePaths: item.imagePaths,
                    height: 170,
                    category: item.category,
                    isZoomable: false,
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Row(
                    children: [
                      if (item.promoted)
                        _tag('Promocionado', AppColors.primaryGreenDark),
                      if (item.offerTag != null) ...[
                        if (item.promoted) const SizedBox(width: 6),
                        _tag(item.offerTag!, AppColors.alertOrange),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: CategoryBadge(label: item.badge),
                ),
                Positioned(
                  bottom: -22,
                  left: 14,
                  child: ScoreBadge(score: item.score, size: 46),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 28, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTextStyles.h3,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _priceLabel,
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.primaryGreenDark,
                        ),
                      ),
                      if (item.referencePrice != null) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '\$${item.referencePrice!.toStringAsFixed(0)}',
                            style: AppTextStyles.caption.copyWith(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                      if (item.negotiable) ...[
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Negociable',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.earthBrown,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (item.weight != null)
                        _infoChip(Icons.monitor_weight_rounded, item.weight!),
                      if (item.production != null)
                        _infoChip(Icons.local_drink_rounded, item.production!),
                      if (item.certified)
                        _infoChip(Icons.verified_user_rounded, 'Certificado'),
                      _infoChip(Icons.access_time_rounded, item.responseTime),
                    ],
                  ),
                  if (item.priceRange != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.psychology_rounded,
                            size: 14,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Buen precio · Rango: ${item.priceRange}',
                              style: AppTextStyles.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(item.location, style: AppTextStyles.caption),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: onContact,
                        icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                        label: const Text('Contactar'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryGreenDark,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
