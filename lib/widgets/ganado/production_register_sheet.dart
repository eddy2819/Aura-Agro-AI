import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/data_provider.dart';
import '../../models/animal.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/keyboard_aware_padding.dart';

/// Modal bottom sheet para el registro rápido de la producción de leche (ordeño).
/// Soporta dos modos: "hato completo" y "vaca individual".
class ProductionRegisterSheet extends StatefulWidget {
  final Animal? animal; // Nulo si es modo "hato completo"
  final Function(int)? onNavigate; // Redireccionar a otras pestañas

  const ProductionRegisterSheet({super.key, this.animal, this.onNavigate});

  @override
  State<ProductionRegisterSheet> createState() =>
      _ProductionRegisterSheetState();
}

class _ProductionRegisterSheetState extends State<ProductionRegisterSheet> {
  final litersController = TextEditingController();
  final obsController = TextEditingController();
  final ValueNotifier<double?> _enteredLiters = ValueNotifier<double?>(null);
  String selectedTurn = 'Mañana'; // Mañana, Tarde, Total del día
  bool showSuccessCheck = false;
  bool isSaving = false;

  @override
  void dispose() {
    litersController.dispose();
    obsController.dispose();
    _enteredLiters.dispose();
    super.dispose();
  }

  String _formatTodayDate() {
    final now = DateTime.now();
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${now.day} ${months[now.month - 1]}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DataProvider>(context);
    final isVacaMode = widget.animal != null;

    final yesterdayStr = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .split('T')[0];

    // Cálculos de subtexto (Ayer y Promedio 7 días)
    double yesterdayValue = 0.0;
    double avg7DaysValue = 0.0;

    if (isVacaMode) {
      // MODO VACA INDIVIDUAL
      final cow = widget.animal!;
      // Ayer
      yesterdayValue = provider.productionRecords
          .where((r) => r.animalId == cow.id && r.date.startsWith(yesterdayStr))
          .fold(0.0, (sum, r) => sum + r.liters);
      if (yesterdayValue == 0.0) {
        yesterdayValue = 12.5; // Valor estático por defecto si no hay registros
      }

      // Promedio 7 días
      double sum7Days = 0.0;
      int activeDays = 0;
      for (int i = 1; i <= 7; i++) {
        final dateStr = DateTime.now()
            .subtract(Duration(days: i))
            .toIso8601String()
            .split('T')[0];
        final daySum = provider.productionRecords
            .where((r) => r.animalId == cow.id && r.date.startsWith(dateStr))
            .fold(0.0, (sum, r) => sum + r.liters);
        if (daySum > 0) {
          sum7Days += daySum;
          activeDays++;
        }
      }
      avg7DaysValue = activeDays > 0 ? sum7Days / activeDays : 12.1;
    } else {
      // MODO HATO COMPLETO
      // Ayer
      yesterdayValue = provider.productionRecords
          .where((r) => r.date.startsWith(yesterdayStr))
          .fold(0.0, (sum, r) => sum + r.liters);
      if (yesterdayValue == 0.0) {
        yesterdayValue =
            308.0; // Valor estático por defecto si no hay registros
      }

      // Promedio 7 días
      double sum7Days = 0.0;
      int activeDays = 0;
      for (int i = 1; i <= 7; i++) {
        final dateStr = DateTime.now()
            .subtract(Duration(days: i))
            .toIso8601String()
            .split('T')[0];
        final daySum = provider.productionRecords
            .where((r) => r.date.startsWith(dateStr))
            .fold(0.0, (sum, r) => sum + r.liters);
        if (daySum > 0) {
          sum7Days += daySum;
          activeDays++;
        }
      }
      avg7DaysValue = activeDays > 0 ? sum7Days / activeDays : 305.0;
    }

    final title = isVacaMode
        ? 'Registrar Ordeño — ${widget.animal!.name}'
        : 'Ordeño del día — ${_formatTodayDate()}';

    final subtext = isVacaMode
        ? 'Ayer: ${yesterdayValue.toStringAsFixed(1)} L  ·  Su promedio: ${avg7DaysValue.toStringAsFixed(1)} L'
        : 'Ayer: ${yesterdayValue.toStringAsFixed(0)} L  ·  Promedio 7 días: ${avg7DaysValue.toStringAsFixed(0)} L';

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          KeyboardAwarePadding(
            basePadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle superior
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Encabezado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.h2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Contenido principal
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Input gigante
                        Center(
                          child: Container(
                            width: 220,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.border,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 140,
                                  child: TextFormField(
                                    controller: litersController,
                                    autofocus: true,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0.0',
                                      hintStyle: GoogleFonts.poppins(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary
                                            .withOpacity(0.3),
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    onChanged: (val) => _enteredLiters.value =
                                        double.tryParse(val),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'L',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtexto con comparativas estables
                        Center(
                          child: Text(
                            subtext,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Solo esta sección cambia mientras se escribe.
                        ValueListenableBuilder<double?>(
                          valueListenable: _enteredLiters,
                          builder: (context, enteredLiters, child) {
                            if (enteredLiters == null || enteredLiters <= 0) {
                              return const SizedBox.shrink();
                            }
                            final variationPercent = yesterdayValue > 0
                                ? ((enteredLiters - yesterdayValue) /
                                          yesterdayValue) *
                                      100
                                : 0.0;
                            final variationColor = variationPercent >= 0
                                ? AppColors.primaryGreen
                                : variationPercent > -10
                                ? AppColors.alertOrange
                                : AppColors.alertRed;
                            final variationIcon = variationPercent >= 0
                                ? LucideIcons.trendingUp
                                : LucideIcons.trendingDown;
                            return Center(
                              child:
                                  Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: variationColor.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: variationColor.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              variationIcon,
                                              color: variationColor,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${variationPercent >= 0 ? '+' : ''}${variationPercent.toStringAsFixed(1)}% vs ayer',
                                              style: AppTextStyles.bodyBold
                                                  .copyWith(
                                                    color: variationColor,
                                                    fontSize: 13,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .animate()
                                      .fadeIn(duration: 250.ms)
                                      .scale(
                                        begin: const Offset(0.95, 0.95),
                                        end: const Offset(1.0, 1.0),
                                        duration: 250.ms,
                                      ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Campo de turno
                        Text(
                          'Jornada / Turno del Ordeño',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['Mañana', 'Tarde', 'Total del día'].map((
                              turn,
                            ) {
                              final isSelected = selectedTurn == turn;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(
                                    turn,
                                    style: AppTextStyles.caption.copyWith(
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.primaryGreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppColors.primaryGreen,
                                  backgroundColor: AppColors.greenSurface,
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => selectedTurn = turn);
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Observación opcional
                        TextFormField(
                          controller: obsController,
                          maxLines: 1,
                          style: AppTextStyles.bodyBold,
                          decoration: InputDecoration(
                            labelText: 'Observación (Opcional)',
                            labelStyle: AppTextStyles.caption,
                            prefixIcon: const Icon(
                              LucideIcons.clipboard,
                              size: 20,
                              color: AppColors.primaryGreen,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryGreen,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Botón de guardar
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ValueListenableBuilder<double?>(
                    valueListenable: _enteredLiters,
                    builder: (context, enteredLiters, child) => ElevatedButton(
                      onPressed:
                          (isSaving ||
                              enteredLiters == null ||
                              enteredLiters <= 0)
                          ? null
                          : () => _handleSave(enteredLiters, provider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        disabledBackgroundColor: AppColors.primaryGreen
                            .withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Guardar ordeño',
                              style: AppTextStyles.bodyBold.copyWith(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Animación de éxito
          if (showSuccessCheck)
            Container(
              color: Colors.white.withOpacity(0.95),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                          LucideIcons.checkCircle,
                          color: AppColors.primaryGreen,
                          size: 100,
                        )
                        .animate()
                        .scale(duration: 400.ms, curve: Curves.easeOutBack)
                        .then()
                        .fadeOut(delay: 500.ms, duration: 200.ms),
                    const SizedBox(height: 16),
                    Text(
                      'Ordeño guardado',
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.primaryGreen,
                      ),
                    ).animate().fadeIn(duration: 400.ms),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleSave(double liters, DataProvider provider) async {
    setState(() => isSaving = true);

    final isVacaMode = widget.animal != null;

    if (isVacaMode) {
      // MODO VACA INDIVIDUAL
      await provider.addProductionRecord(
        animalId: widget.animal!.id,
        liters: liters,
        turn: selectedTurn,
        observation: obsController.text.trim().isEmpty
            ? null
            : obsController.text.trim(),
      );
    } else {
      // MODO HATO COMPLETO
      // Distribuir de forma equitativa entre todas las lecheras
      final lecheras = provider.animals
          .where(
            (a) => a.category == 'Vaca Lechera' || a.category == 'Vaca Seca',
          )
          .toList();

      if (lecheras.isNotEmpty) {
        final share = liters / lecheras.length;
        for (var cow in lecheras) {
          await provider.addProductionRecord(
            animalId: cow.id,
            liters: share,
            turn: selectedTurn,
            observation: obsController.text.trim().isEmpty
                ? null
                : obsController.text.trim(),
          );
        }
      } else {
        // Fallback: guardar bajo una id genérica si no hay vacas registradas
        await provider.addProductionRecord(
          animalId: 'Generico',
          liters: liters,
          turn: selectedTurn,
          observation: obsController.text.trim().isEmpty
              ? null
              : obsController.text.trim(),
        );
      }
    }

    setState(() => showSuccessCheck = true);

    await Future.delayed(const Duration(milliseconds: 1100));

    if (mounted) {
      Navigator.pop(context); // Cerrar modal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Ordeño registrado — ${liters.toStringAsFixed(1)} L',
            style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}
