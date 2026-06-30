import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/alert_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Lista de alertas activas (usada en el Dashboard)
class AlertsList extends StatelessWidget {
  final List<AlertModel> alerts;

  const AlertsList({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: alerts
          .map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AlertTile(alert: a),
            ),
          )
          .toList(),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AlertModel alert;

  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.alertOrangeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.alertOrange.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.alertOrange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.alertTriangle,
              color: AppColors.alertOrange,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.animalName, style: AppTextStyles.bodyBold),
                Text(alert.title, style: AppTextStyles.body),
              ],
            ),
          ),
          Text(
            alert.detectedAgo,
            style: AppTextStyles.caption.copyWith(color: AppColors.alertOrange),
          ),
        ],
      ),
    );
  }
}
