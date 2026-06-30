import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Chips de filtro: Todos, Vacas, Toros, Terneros, Con Alertas
class FilterChips extends StatefulWidget {
  final ValueChanged<String>? onFilterChanged;
  final int alertsCount;

  const FilterChips({
    super.key, 
    this.onFilterChanged, 
    this.alertsCount = 0,
  });

  @override
  State<FilterChips> createState() => _FilterChipsState();
}

class _FilterChipsState extends State<FilterChips> {
  String _selected = 'Todos';

  List<MapEntry<String, int?>> get _filters => [
    const MapEntry('Todos', null),
    const MapEntry('Vacas', null),
    const MapEntry('Toros', null),
    const MapEntry('Terneros', null),
    MapEntry('Con Alertas', widget.alertsCount > 0 ? widget.alertsCount : null),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((f) {
          final label = f.key;
          final badge = f.value;
          final isSelected = _selected == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              labelPadding: EdgeInsets.zero,
              label: badge != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : AppColors.alertOrange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$badge',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text(label),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selected = label);
                widget.onFilterChanged?.call(label);
              },
              labelStyle: AppTextStyles.caption.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: BorderSide(
                  color: isSelected ? AppColors.primaryGreen : AppColors.border,
                ),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}
