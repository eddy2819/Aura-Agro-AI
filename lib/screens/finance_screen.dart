import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:uuid/uuid.dart';

import '../data/data_provider.dart';
import '../models/nutrition_plan.dart';
import '../services/pdf_export_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Alimentación';
  String? _selectedAnimalId;

  final List<String> _categories = [
    'Alimentación',
    'Medicina',
    'Vacunas',
    'Transporte',
    'Mano de obra',
    'Mantenimiento',
    'Compra de animales',
    'Servicios veterinarios',
    'Otros'
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showAddExpenseDialog() {
    _amountController.clear();
    _descriptionController.clear();
    _selectedCategory = 'Alimentación';
    _selectedAnimalId = null;

    final provider = Provider.of<DataProvider>(context, listen: false);
    final activeAnimals = provider.animals.where((a) => a.status.toLowerCase() == 'activo').toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Registrar Gasto Operativo', style: AppTextStyles.bodyBold),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Monto (\$)', hintText: 'Ej. 45.50'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Descripción / Nota', hintText: 'Ej. Compra de balanceado saco 40kg'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedAnimalId,
                  decoration: const InputDecoration(labelText: 'Asociar a Animal (Opcional)'),
                  hint: const Text('Ninguno'),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Ninguno')),
                    ...activeAnimals.map((a) => DropdownMenuItem<String>(
                          value: a.id,
                          child: Text('${a.name} (${a.tag})'),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedAnimalId = val;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final double? amt = double.tryParse(_amountController.text);
                if (amt == null || amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Ingresa un monto válido")),
                  );
                  return;
                }

                final expRow = {
                  'id': 'exp_${const Uuid().v4()}',
                  'category': _selectedCategory,
                  'amount': amt,
                  'date': DateTime.now().toIso8601String().split('T')[0],
                  'description': _descriptionController.text.trim().isNotEmpty
                      ? _descriptionController.text.trim()
                      : "Gasto en $_selectedCategory",
                  'animal_id': _selectedAnimalId ?? '',
                  'farm_id': provider.profile?['farm_name'] ?? 'Mi Finca',
                  'created_at': DateTime.now().toIso8601String(),
                  'synced': 0,
                };

                await provider.addOperatingExpense(expRow);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Gasto operativo registrado")),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
              child: const Text('Agregar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DataProvider>(context);
    final expenses = provider.operatingExpenses;

    // Calcular balances
    double totalExpenses = 0.0;
    double totalIncome = 0.0;

    for (var exp in expenses) {
      final double amt = (exp['amount'] as num?)?.toDouble() ?? 0.0;
      if (exp['category'] == 'Ventas de animales') {
        totalIncome += amt;
      } else {
        totalExpenses += amt;
      }
    }

    final double utility = totalIncome - totalExpenses;

    // Distribución por categoría
    final Map<String, double> categorySums = {};
    for (var exp in expenses) {
      if (exp['category'] == 'Ventas de animales') continue;
      final cat = exp['category'] as String? ?? 'Otros';
      final amt = (exp['amount'] as num?)?.toDouble() ?? 0.0;
      categorySums[cat] = (categorySums[cat] ?? 0.0) + amt;
    }

    final pieSections = categorySums.entries.map((entry) {
      final double percentage = totalExpenses > 0 ? (entry.value / totalExpenses) * 100 : 0.0;
      return PieChartSectionData(
        color: _getCategoryColor(entry.key),
        value: entry.value,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    // Costo alimentación vs producción láctea
    final activeMilkCows = provider.animals.where((a) => a.category == 'Vaca Lechera' && a.status.toLowerCase() == 'activo').toList();
    double totalDailyFeedCost = 0.0;
    double totalDailyMilkProduction = 0.0;

    for (var cow in activeMilkCows) {
      final plan = provider.nutritionPlans.cast<NutritionPlan?>().firstWhere(
        (p) => p != null && p.status == 'Activo' && (p.targetGroup == 'Todo el Hato' || p.targetGroup == cow.category || p.targetGroup == cow.id || p.targetGroup == cow.name),
        orElse: () => null,
      );
      
      double cowDailyFeedCost = 0.0;
      if (plan != null) {
        cowDailyFeedCost = plan.estimatedCostPerDay;
      }
      
      totalDailyFeedCost += cowDailyFeedCost;

      // Production liters
      double prodLiters = 0.0;
      if (cow.productionLiters != null) {
        try {
          prodLiters = double.tryParse(cow.productionLiters!.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        } catch (_) {}
      }
      totalDailyMilkProduction += prodLiters;
    }

    final double avgFeedCostPerCow = activeMilkCows.isNotEmpty ? totalDailyFeedCost / activeMilkCows.length : 0.0;
    final double avgMilkPerCow = activeMilkCows.isNotEmpty ? totalDailyMilkProduction / activeMilkCows.length : 0.0;
    // Assume liter price of $0.45
    final double milkIncomePerCow = avgMilkPerCow * 0.45;
    final double netMarginPerCow = milkIncomePerCow - avgFeedCostPerCow;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Control Financiero', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryGreenDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Export buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await PdfExportService.instance.exportFinancialReport(totalIncome, totalExpenses, expenses);
                  },
                  icon: const Icon(LucideIcons.fileText, size: 14),
                  label: const Text('Exportar PDF'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryGreen, side: const BorderSide(color: AppColors.primaryGreen)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await PdfExportService.instance.exportExpensesToCsv(expenses);
                  },
                  icon: const Icon(LucideIcons.fileSpreadsheet, size: 14),
                  label: const Text('Exportar CSV'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryGreen, side: const BorderSide(color: AppColors.primaryGreen)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Balances Row
            Row(
              children: [
                Expanded(
                  child: _buildBalanceCard(
                    title: 'Venta de Ganado',
                    amount: totalIncome,
                    color: AppColors.primaryGreen,
                    icon: LucideIcons.trendingUp,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildBalanceCard(
                    title: 'Gastos de Finca',
                    amount: totalExpenses,
                    color: AppColors.alertOrange,
                    icon: LucideIcons.trendingDown,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Utilidad Neta Estimada', style: AppTextStyles.caption),
                      const SizedBox(height: 2),
                      Text(
                        '\$${utility.toStringAsFixed(2)}',
                        style: AppTextStyles.h1.copyWith(
                          color: utility >= 0 ? AppColors.primaryGreenDark : AppColors.alertOrange,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    utility >= 0 ? LucideIcons.smile : LucideIcons.frown,
                    color: utility >= 0 ? AppColors.primaryGreen : AppColors.alertOrange,
                    size: 32,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Chart Distribution
            if (categorySums.isNotEmpty) ...[
              Text('Distribución de Gastos', style: AppTextStyles.bodyBold),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sections: pieSections,
                        centerSpaceRadius: 18,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: categorySums.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(width: 10, height: 10, color: _getCategoryColor(entry.key)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${entry.key}: \$${entry.value.toStringAsFixed(0)}',
                                  style: AppTextStyles.caption,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Cost vs Production Section
            Text('Eficiencia Nutricional (Lechería)', style: AppTextStyles.bodyBold),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEfficiencyMetric(
                    label: 'Costo diario promedio de alimentación por vaca:',
                    value: '\$${avgFeedCostPerCow.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _buildEfficiencyMetric(
                    label: 'Producción diaria promedio de leche por vaca:',
                    value: '${avgMilkPerCow.toStringAsFixed(1)} Litros',
                  ),
                  const SizedBox(height: 8),
                  _buildEfficiencyMetric(
                    label: 'Margen diario neto promedio por vaca (leche a \$0.45):',
                    value: '\$${netMarginPerCow.toStringAsFixed(2)}',
                    valueColor: netMarginPerCow >= 0 ? AppColors.primaryGreenDark : AppColors.alertOrange,
                  ),
                  const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        netMarginPerCow >= 0.20 ? LucideIcons.thumbsUp : LucideIcons.alertTriangle,
                        color: netMarginPerCow >= 0.20 ? AppColors.primaryGreen : AppColors.alertOrange,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          netMarginPerCow >= 0.20
                              ? '“Este animal produce más de lo que cuesta alimentarlo.”'
                              : '“La alimentación está alta frente a la producción registrada.”',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: netMarginPerCow >= 0.20 ? AppColors.primaryGreenDark : AppColors.alertOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Regional Market Prices (MAGAP Ecuador Mock feed)
            Text('Precios Ganaderos de Referencia (Regional)', style: AppTextStyles.bodyBold),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.greenSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildMarketPriceRow('Litro de Leche en Finca (MAGAP)', '\$0.42 - \$0.47', 'Semana Actual'),
                  const SizedBox(height: 6),
                  _buildMarketPriceRow('NovillaHolstein de Producción', '\$1,100 - \$1,400', 'Semana Actual'),
                  const SizedBox(height: 6),
                  _buildMarketPriceRow('Toro Brahman (Pie de Cría)', '\$1,800 - \$2,400', 'Semana Actual'),
                  const SizedBox(height: 6),
                  _buildMarketPriceRow('Mano de Obra Jornada Agro', '\$15.00 - \$20.00', 'Región Sur'),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: AppTextStyles.h2.copyWith(color: color, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildEfficiencyMetric({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: AppTextStyles.caption),
        ),
        Text(
          value,
          style: AppTextStyles.bodyBold.copyWith(color: valueColor ?? AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildMarketPriceRow(String label, String value, String region) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryGreenDark)),
              Text(region, style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Text(value, style: AppTextStyles.bodyBold),
      ],
    );
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'Alimentación':
        return Colors.green;
      case 'Medicina':
        return Colors.red;
      case 'Vacunas':
        return Colors.orange;
      case 'Transporte':
        return Colors.blue;
      case 'Mano de obra':
        return Colors.purple;
      case 'Mantenimiento':
        return Colors.brown;
      case 'Compra de animales':
        return Colors.teal;
      case 'Servicios veterinarios':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }
}
