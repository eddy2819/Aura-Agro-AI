import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/data_provider.dart';
import '../../screens/sos_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class GanaderoHomeDashboard extends StatelessWidget {
  static const logoPath = 'assets/icon/logotipo.png';
  static const botPath = 'assets/icon/bot.png';

  final DataProvider provider;
  final String greeting;
  final String ownerName;
  final String farmName;
  final void Function(int index)? onNavigate;

  const GanaderoHomeDashboard({
    super.key,
    required this.provider,
    required this.greeting,
    required this.ownerName,
    required this.farmName,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final animals = provider.animals;
    final alerts = provider.alerts;
    final avgWeight = animals.isEmpty
        ? 0.0
        : animals.fold<double>(0, (sum, animal) => sum + animal.weightKg) /
              animals.length;
    final avgHealth = animals.isEmpty
        ? 0
        : (animals.fold<int>(0, (sum, animal) => sum + animal.score) /
                  animals.length)
              .round();
    final production = animals.fold<double>(
      0,
      (sum, animal) => sum + _numberFromText(animal.productionLiters),
    );
    final firstName = ownerName.trim().split(' ').first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 120),
      children: [
        Text(
          '$greeting, $firstName',
          style: AppTextStyles.h1.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Así va tu hato hoy.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        _generalPanel(animals.length, production, avgWeight, avgHealth),
        const SizedBox(height: 16),
        _recommendationCard(),
        const SizedBox(height: 20),
        _sectionTitle(
          'Salud del hato',
          'Ver ganado',
          () => onNavigate?.call(1),
        ),
        const SizedBox(height: 10),
        _healthGrid(avgHealth),
        const SizedBox(height: 20),
        _sectionTitle(
          'Alertas y recordatorios',
          'Ver todas',
          () => _showAlerts(context),
        ),
        const SizedBox(height: 10),
        _alertsStrip(alerts),
        const SizedBox(height: 20),
        _agendaAndTasks(context),
        const SizedBox(height: 18),
        _sosButton(context),
      ],
    );
  }

  Widget _generalPanel(
    int count,
    double production,
    double weight,
    int health,
  ) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Panel general', style: AppTextStyles.h3),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                color: AppColors.greenSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.warehouse,
                color: AppColors.primaryGreen,
                size: 43,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    farmName,
                    style: AppTextStyles.h2.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 4),
                  Text('Hato ganadero', style: AppTextStyles.body),
                  const SizedBox(height: 7),
                  const Row(
                    children: [
                      Icon(
                        LucideIcons.shieldCheck,
                        color: AppColors.primaryGreen,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Todo bajo control',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 26),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metric(LucideIcons.beef, '$count', 'Animales'),
            _metric(
              LucideIcons.milk,
              production > 0
                  ? '${production.toStringAsFixed(1)} L'
                  : 'Sin registro',
              'Producción hoy',
            ),
            _metric(
              LucideIcons.weight,
              '${weight.toStringAsFixed(0)} kg',
              'Peso promedio',
            ),
            _metric(LucideIcons.heartPulse, '$health%', 'Salud del hato'),
          ],
        ),
      ],
    ),
  );

  Widget _metric(IconData icon, String value, String label) => SizedBox(
    width: 145,
    child: Row(
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: AppColors.greenSurface,
          child: Icon(icon, color: AppColors.primaryGreen, size: 19),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyBold,
              ),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _recommendationCard() => Container(
    height: 260,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF258C43), Color(0xFF075C2B)],
      ),
      borderRadius: BorderRadius.circular(26),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33075C2B),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -28,
          bottom: -26,
          child: Container(
            width: 238,
            height: 238,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              botPath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      LucideIcons.sparkles,
                      color: Color(0xFFD7F3BE),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Recomendación IA del día',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'Optimiza la nutrición de tu hato',
                  style: AppTextStyles.h2.copyWith(
                    color: Colors.white,
                    fontSize: 23,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ajustar la ración puede ayudar a mejorar la producción esta semana.',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withValues(alpha: .9),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => onNavigate?.call(2),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryGreenDark,
                  ),
                  child: const Text('Ver plan  →'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _healthGrid(int health) {
    final scores = [
      (LucideIcons.heartPulse, health, 'Salud', const Color(0xFF188B43)),
      (LucideIcons.leaf, 85, 'Nutrición', const Color(0xFF188B43)),
      (LucideIcons.shieldCheck, 88, 'Vacunación', const Color(0xFF1976C9)),
      (LucideIcons.milk, 83, 'Producción', const Color(0xFF7B3FD0)),
    ];
    return Row(
      children: scores
          .map(
            (score) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: score.$4.withValues(alpha: .1),
                      child: Icon(score.$1, color: score.$4),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${score.$2}',
                      style: AppTextStyles.h2.copyWith(color: score.$4),
                    ),
                    Text(
                      score.$3,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _alertsStrip(List<dynamic> alerts) {
    final visible = alerts.take(3).toList();
    if (visible.isEmpty)
      return _card(
        child: const ListTile(
          leading: Icon(LucideIcons.circleCheck, color: AppColors.primaryGreen),
          title: Text('No hay alertas activas'),
        ),
      );
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (_, i) {
          final alert = visible[i];
          return Container(
            width: 245,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F3),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF3CCB4)),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.triangleAlert,
                  color: AppColors.alertOrange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyBold,
                      ),
                      Text(
                        alert.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _agendaAndTasks(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final cards = [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Calendario sanitario', style: AppTextStyles.bodyBold),
              const Divider(),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  LucideIcons.calendarDays,
                  color: AppColors.primaryGreen,
                ),
                title: Text('Próxima revisión'),
                subtitle: Text('Consulta tus recordatorios'),
              ),
            ],
          ),
        ),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pendientes de hoy', style: AppTextStyles.bodyBold),
              const Divider(),
              _check('Revisar animales enfermos'),
              _check('Registrar producción'),
              _check('Verificar nivel de agua'),
            ],
          ),
        ),
      ];
      return constraints.maxWidth > 650
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            )
          : Column(children: [cards[0], const SizedBox(height: 12), cards[1]]);
    },
  );

  Widget _check(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primaryGreen, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppTextStyles.caption)),
      ],
    ),
  );

  Widget _sosButton(BuildContext context) => FilledButton.icon(
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SosScreen()),
    ),
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF9D1919),
      padding: const EdgeInsets.symmetric(vertical: 16),
    ),
    icon: const Icon(LucideIcons.shieldAlert),
    label: const Text('AURA SOS · Emergencia ganadera'),
  );

  Widget _sectionTitle(String title, String action, VoidCallback tap) => Row(
    children: [
      Expanded(child: Text(title, style: AppTextStyles.h3)),
      TextButton(onPressed: tap, child: Text(action)),
    ],
  );
  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );

  void _showAlerts(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text('Alertas activas', style: AppTextStyles.h2),
            const SizedBox(height: 12),
            ...provider.alerts.map(
              (alert) => ListTile(
                leading: const Icon(
                  LucideIcons.triangleAlert,
                  color: AppColors.alertOrange,
                ),
                title: Text(alert.title),
                subtitle: Text(alert.description),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  double _numberFromText(String? value) {
    if (value == null) return 0;
    final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(value);
    return double.tryParse(match?.group(0)?.replaceAll(',', '.') ?? '') ?? 0;
  }
}
