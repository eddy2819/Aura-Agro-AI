import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../data/data_provider.dart';
import '../models/nutrition_plan.dart';
import '../services/nutrition_ai_service.dart';
import '../models/animal.dart';
import '../models/nutrition_resource.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class PremiumResultScreen extends StatefulWidget {
  final NutritionPlanResult result;
  final String targetGroup;
  final int animalCount;
  final List<Animal> targetAnimals;
  final List<NutritionResource> confirmedResources;
  final bool isFromHistory;
  final NutritionPlan? historicalPlan;

  const PremiumResultScreen({
    super.key,
    required this.result,
    required this.targetGroup,
    required this.animalCount,
    required this.targetAnimals,
    required this.confirmedResources,
    this.isFromHistory = false,
    this.historicalPlan,
  });

  @override
  State<PremiumResultScreen> createState() => _PremiumResultScreenState();
}

class _PremiumResultScreenState extends State<PremiumResultScreen> {
  bool _isSaved = false;
  late List<bool> _todayChecks;
  late List<bool> _weekChecks;
  late List<bool> _monitorChecks;

  // Comentarios del veterinario
  final List<String> _comments = [];
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isSaved = widget.isFromHistory;
    _todayChecks = List.filled(widget.result.taskToday.length, false);
    _weekChecks = List.filled(widget.result.taskWeek.length, false);
    _monitorChecks = List.filled(widget.result.taskMonitor.length, false);

    // Mock initial comment if history
    if (widget.isFromHistory) {
      _comments.add("Revisado por Veterinario Autorizado: Plan balanceado. Mantener monitoreo de peso quincenal.");
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _savePlan(DataProvider provider) async {
    if (_isSaved) return;

    await provider.addNutritionPlan(
      targetGroup: widget.targetGroup,
      suggestedDiet: widget.result.suggestedDiet,
      estimatedCostPerDay: widget.result.estimatedCostPerDay,
      projectedSavings: widget.result.projectedSavings,
      projectedImprovement: widget.result.projectedImprovement,
      explanation: widget.result.explanation,
      rawResponse: widget.result.rawJson,
    );

    setState(() {
      _isSaved = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¡Plan nutricional guardado con éxito!',
          style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _compareScenarios() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final eco = widget.result.scenarios['economico'] ?? {};
        final eq = widget.result.scenarios['equilibrado'] ?? {};
        final high = widget.result.scenarios['rendimiento'] ?? {};

        // Validar si faltan datos
        final bool hasMissingData = widget.targetAnimals.any((a) => a.weightKg <= 0);

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Comparar Escenarios AURA', style: AppTextStyles.h1),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Analiza alternativas de ración basadas en costos y rendimiento.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 16),
              if (hasMissingData)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.alertOrangeSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.alertOrange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Advertencia: Faltan registros de peso en algunos animales. Los cálculos pueden no ser exactos.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.alertOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildScenarioCard('Económico 💰', eco, AppColors.sandBeige),
                    const SizedBox(height: 16),
                    _buildScenarioCard('Equilibrado ⚖️ (Recomendado)', eq, AppColors.greenSurface, isBest: true),
                    const SizedBox(height: 16),
                    _buildScenarioCard('Máximo Rendimiento 🚀', high, AppColors.sandBeige),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScenarioCard(String title, Map<dynamic, dynamic> data, Color bgColor, {bool isBest = false}) {
    if (data.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBest ? AppColors.primaryGreen : AppColors.border,
          width: isBest ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTextStyles.h2.copyWith(color: AppColors.primaryGreenDark)),
              Text(
                '\$${(data['cost_per_day'] ?? 0.0).toStringAsFixed(2)} / día',
                style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreen, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _scenarioDetail('Ración:', data['resources'] ?? ''),
          _scenarioDetail('Beneficios:', data['benefits'] ?? ''),
          _scenarioDetail('Riesgos:', data['risks'] ?? ''),
          const Divider(height: 20),
          Text(
            'Recomendación AURA:',
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          Text(
            data['recommendation'] ?? '',
            style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _scenarioDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            TextSpan(
              text: value,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }

  void _shareWithVeterinarian(DataProvider provider) {
    // Buscar veterinarios autorizados
    final authorizedVets = provider.farmAuthorizations
        .where((auth) => auth['status'] == 'active')
        .toList();

    if (authorizedVets.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Sin Veterinario Autorizado', style: AppTextStyles.h2),
          content: Text(
            'No tienes veterinarios autorizados vinculados a tu cuenta. '
            'Pide a tu veterinario que se registre en AURA Agro y solicite acceso a tu finca.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido', style: TextStyle(color: AppColors.primaryGreen)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Enviar a Veterinario', style: AppTextStyles.h2),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Selecciona el veterinario autorizado para validar el plan:',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 12),
              ...authorizedVets.map((vet) {
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.greenSurface,
                    child: Icon(Icons.person, color: AppColors.primaryGreen),
                  ),
                  title: Text(vet['veterinario_name'] ?? 'Veterinario', style: AppTextStyles.bodyBold),
                  subtitle: Text('Reg: ${vet['license_number'] ?? "N/A"}', style: AppTextStyles.caption),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Plan compartido con ${vet['veterinario_name']} exitosamente.',
                          style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
                        ),
                        backgroundColor: AppColors.primaryGreen,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _addComment() {
    if (_commentController.text.trim().isEmpty) return;
    setState(() {
      _comments.add(_commentController.text.trim());
      _commentController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DataProvider>(context);
    final userRole = provider.profile?['role'] ?? 'Ganadero';
    final isVeterinario = userRole == 'Veterinario';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Nutricional AURA'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          // 1. Viability Score & General Info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.targetGroup, style: AppTextStyles.h1.copyWith(color: AppColors.primaryGreenDark)),
                      const SizedBox(height: 4),
                      Text(
                        'Alcance: ${widget.animalCount == 1 ? "Individual" : "Grupo - " + widget.targetGroup}',
                        style: AppTextStyles.caption,
                      ),
                      Text(
                        'Animales cubiertos: ${widget.animalCount}',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Insumo limitante: ${widget.result.limitingResource}',
                        style: AppTextStyles.bodyBold.copyWith(color: AppColors.alertOrange, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Radial Score
                Container(
                  width: 90,
                  height: 90,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: widget.result.viabilityScore / 100,
                          strokeWidth: 8,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${widget.result.viabilityScore}',
                            style: AppTextStyles.h2.copyWith(color: AppColors.primaryGreenDark),
                          ),
                          Text(
                            'Viabilidad',
                            style: AppTextStyles.caption.copyWith(fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().scale(delay: 200.ms, duration: 500.ms, curve: Curves.easeOutBack),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Photo & Body Condition (if Individual & visualAnalysis exists)
          if (widget.result.visualAnalysis != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.greenSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primaryGreen.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.camera_alt_rounded, color: AppColors.primaryGreen),
                      const SizedBox(width: 8),
                      Text('Evaluación Visual de Imagen', style: AppTextStyles.h2.copyWith(color: AppColors.primaryGreenDark)),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Condición Corporal Estimada:', style: AppTextStyles.bodyBold),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          (widget.result.visualAnalysis!['body_condition_estimated'] ?? 'Adecuada').toString().toUpperCase(),
                          style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreenDark, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.result.visualAnalysis!['observations'] ?? '',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recomendación visual: ${widget.result.visualAnalysis!['nutritional_improvements'] ?? ""}',
                    style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Confianza: ${widget.result.visualAnalysis!['confidence_level'] ?? "Media"}',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '⚠️ ${widget.result.visualAnalysis!['disclaimer'] ?? ""}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.alertOrange, fontSize: 10, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 3. Ración Diaria
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant_rounded, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Text('Ración Diaria Recomendada', style: AppTextStyles.h2),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.result.suggestedDiet,
                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreenDark, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _metricBox(
                        Icons.attach_money_rounded,
                        'Costo animal/día',
                        '\$${widget.result.estimatedCostPerDay.toStringAsFixed(2)}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metricBox(
                        Icons.savings_rounded,
                        'Ahorro semanal',
                        '\$${widget.result.projectedSavings.toStringAsFixed(0)}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Tabla de Insumos
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tabla de Recursos Requeridos', style: AppTextStyles.h2),
                const SizedBox(height: 12),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1.2),
                    2: FlexColumnWidth(1.2),
                    3: FlexColumnWidth(1.2),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5))),
                      children: [
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Alimento', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Diario', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Total Mes', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Costo/kg', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    ...widget.result.resourcesTable.map((r) {
                      return TableRow(
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5))),
                        children: [
                          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(r['name'] ?? '', style: AppTextStyles.bodyBold.copyWith(fontSize: 12))),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${r['daily_amount']} ${r['unit']}', style: AppTextStyles.caption)),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${r['total_amount']} ${r['unit']}', style: AppTextStyles.caption)),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('\$${(r['cost'] ?? 0.0).toStringAsFixed(2)}', style: AppTextStyles.caption)),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. Alertas
          if (widget.result.alerts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.alertRed),
                      const SizedBox(width: 8),
                      Text('Alertas de Nutrición', style: AppTextStyles.h2),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...widget.result.alerts.map((a) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.circle, size: 8, color: AppColors.alertRed),
                          const SizedBox(width: 8),
                          Expanded(child: Text(a, style: AppTextStyles.caption.copyWith(color: AppColors.alertRed))),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 6. Proyecciones (fl_chart)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.trending_up_rounded, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      widget.targetGroup.contains('Lechera') ? 'Proyección de Producción (L)' : 'Proyección de Peso (kg)',
                      style: AppTextStyles.h2,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true, drawVerticalLine: false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final text = value == 0
                                  ? 'Inicio'
                                  : 'Sem ${value.toInt()}';
                              return Text(text, style: AppTextStyles.caption.copyWith(fontSize: 9));
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(widget.result.projectionData.length, (index) {
                            return FlSpot(index.toDouble(), widget.result.projectionData[index]);
                          }),
                          isCurved: true,
                          color: AppColors.primaryGreen,
                          barWidth: 4,
                          dotData: FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Nota: Estas proyecciones son orientativas basadas en modelos biológicos ideales y no representan una garantía de rendimiento.',
                  style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 7. Tareas Priorizadas
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tareas Nutricionales Recomendadas', style: AppTextStyles.h2),
                const Divider(height: 24),
                _taskListSection('Haz hoy 🔴', widget.result.taskToday, _todayChecks),
                const SizedBox(height: 14),
                _taskListSection('Esta semana 🟡', widget.result.taskWeek, _weekChecks),
                const SizedBox(height: 14),
                _taskListSection('Monitorear 🟢', widget.result.taskMonitor, _monitorChecks),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 8. Sección de Comentarios
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Validación del Veterinario', style: AppTextStyles.h2),
                const SizedBox(height: 12),
                if (_comments.isEmpty)
                  Text('Aún no hay comentarios ni validaciones de un veterinario.', style: AppTextStyles.body)
                else
                  ..._comments.map((comment) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.sandBeige,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(comment, style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary)),
                    );
                  }),
                if (isVeterinario) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Añadir recomendación veterinaria...',
                            hintStyle: AppTextStyles.caption,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          style: AppTextStyles.body,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: AppColors.primaryGreen),
                        onPressed: _addComment,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 9. Botones de Acción
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _compareScenarios,
                  icon: const Icon(Icons.compare_arrows_rounded),
                  label: const Text('Comparar escenarios'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sandBeige,
                    foregroundColor: AppColors.primaryGreenDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (userRole == 'Ganadero')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _shareWithVeterinarian(provider),
                    icon: const Icon(Icons.send_to_mobile_rounded),
                    label: const Text('Enviar a Vet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen.withOpacity(0.12),
                      foregroundColor: AppColors.primaryGreenDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSaved ? null : () => _savePlan(provider),
              icon: Icon(
                _isSaved ? Icons.check_circle_rounded : Icons.save_rounded,
                color: Colors.white,
              ),
              label: Text(
                _isSaved ? 'Plan Guardado' : 'Guardar Plan',
                style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskListSection(String title, List<String> tasks, List<bool> checks) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.bodyBold),
        const SizedBox(height: 6),
        ...List.generate(tasks.length, (index) {
          return CheckboxListTile(
            value: checks[index],
            onChanged: (val) {
              setState(() {
                checks[index] = val ?? false;
              });
            },
            title: Text(tasks[index], style: AppTextStyles.caption),
            activeColor: AppColors.primaryGreen,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          );
        }),
      ],
    );
  }

  Widget _metricBox(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sandBeige,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 16)),
              Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
