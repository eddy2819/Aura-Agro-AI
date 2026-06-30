import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Barra de categorías + filtros inteligentes del Marketplace
class MarketFilters extends StatefulWidget {
  final ValueChanged<String>? onCategoryChanged;

  const MarketFilters({super.key, this.onCategoryChanged});

  @override
  State<MarketFilters> createState() => _MarketFiltersState();
}

class _MarketFiltersState extends State<MarketFilters> {
  String _category = 'Todo';
  final _categories = const ['Todo', 'Ganado', 'Leche', 'Queso', 'Insumos'];

  final _quickFilters = const [
    (icon: Icons.verified_user_rounded, label: 'Verificados'),
    (icon: Icons.fact_check_rounded, label: 'Certificado Sanitario'),
    (icon: Icons.location_on_rounded, label: 'Cerca de mí'),
    (icon: Icons.handshake_rounded, label: 'Negociable'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((c) {
              final selected = _category == c;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _category = c);
                    widget.onCategoryChanged?.call(c);
                  },
                  selectedColor: AppColors.primaryGreen,
                  backgroundColor: AppColors.surface,
                  labelStyle: AppTextStyles.caption.copyWith(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: BorderSide(
                      color: selected
                          ? AppColors.primaryGreen
                          : AppColors.border,
                    ),
                  ),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _quickFilters
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(
                        f.icon,
                        size: 14,
                        color: AppColors.primaryGreenDark,
                      ),
                      label: Text(f.label),
                      onSelected: (_) {},
                      backgroundColor: AppColors.greenSurface,
                      labelStyle: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryGreenDark,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide.none,
                      ),
                      showCheckmark: false,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
