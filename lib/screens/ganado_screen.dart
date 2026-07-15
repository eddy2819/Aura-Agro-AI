import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/data_provider.dart';
import '../models/animal.dart';
import '../models/weight_record.dart';
import '../models/production_record.dart';
import '../models/alert_model.dart';
import '../services/nutrition_ai_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/ganado/animal_card.dart';
import '../widgets/ganado/filter_chips.dart';
import '../widgets/ganado/herd_summary.dart';
import '../widgets/navigation/top_app_bar.dart';
import '../widgets/ganado/production_register_sheet.dart';
import '../services/pdf_export_service.dart';

class GanadoScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const GanadoScreen({super.key, this.onNavigate});

  @override
  State<GanadoScreen> createState() => _GanadoScreenState();
}

class _GanadoScreenState extends State<GanadoScreen> {
  String _activeFilter = 'Todos';

  void _showAddAnimalDialog(BuildContext context, {Animal? animalToEdit}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: animalToEdit?.name);
    final tagController = TextEditingController(text: animalToEdit?.tag.replaceAll('#', ''));
    final weightController = TextEditingController(text: animalToEdit?.weightKg.toString());
    final prodController = TextEditingController(
      text: animalToEdit?.productionLiters?.replaceAll(' L/dia', ''),
    );
    final descController = TextEditingController(text: animalToEdit?.description);
    
    // Controladores adicionales
    final colorController = TextEditingController(text: animalToEdit?.color ?? 'Blanco con Negro');
    final birthDateController = TextEditingController(text: animalToEdit?.birthDate ?? '2024-01-01');
    final fatherController = TextEditingController(text: animalToEdit?.geneticFather);
    final motherController = TextEditingController(text: animalToEdit?.geneticMother);
    final geneticLineController = TextEditingController(text: animalToEdit?.geneticLine);
    final originController = TextEditingController(text: animalToEdit?.origin);
    final vetResponsibleController = TextEditingController(text: animalToEdit?.vetResponsible);
    final prevDiseasesController = TextEditingController(text: animalToEdit?.prevDiseases);
    final allergiesController = TextEditingController(text: animalToEdit?.allergies);
    final currentMedicationController = TextEditingController(text: animalToEdit?.currentMedication);
    final dailyConsumptionController = TextEditingController(text: animalToEdit?.dailyConsumption?.toString() ?? '12.0');
    final fincaController = TextEditingController(text: animalToEdit?.finca ?? 'Finca El Paraíso');
    final loteController = TextEditingController(text: animalToEdit?.lote ?? 'Lote A');
    final potreroController = TextEditingController(text: animalToEdit?.potrero ?? 'Potrero 1');
    final gpsCoordsController = TextEditingController(text: animalToEdit?.gpsCoords);
    final purchaseValueController = TextEditingController(text: animalToEdit?.purchaseValue?.toString());
    final purchaseDateController = TextEditingController(text: animalToEdit?.purchaseDate);
    final providerController = TextEditingController(text: animalToEdit?.provider);

    String selectedCategory = animalToEdit?.category ?? 'Vaca Lechera';
    String selectedBreed = animalToEdit?.breed ?? 'Holstein';
    String selectedSex = animalToEdit?.sex ?? 'Hembra';
    String selectedStatus = animalToEdit?.status ?? 'Activo';
    String selectedPurpose = animalToEdit?.purpose ?? 'Leche';
    String selectedStage = animalToEdit?.stage ?? 'Vaca';
    double bodyCondition = animalToEdit?.bodyCondition ?? 3.5;
    String selectedHealthStatus = animalToEdit?.healthStatus ?? 'Saludable';
    String selectedDietType = animalToEdit?.dietType ?? 'Pasto';
    String selectedProductionObjective = animalToEdit?.productionObjective ?? 'Producción láctea';
    bool grazing = animalToEdit?.grazing ?? true;
    bool balancedFeed = animalToEdit?.balancedFeed ?? false;
    bool supplements = animalToEdit?.supplements ?? false;
    bool availableForSale = animalToEdit?.availableForSale ?? false;
    
    String? selectedImagePath = animalToEdit?.imagePath;
    String? imageFrontPath = animalToEdit?.imageFrontPath;
    String? imageSidePath = animalToEdit?.imageSidePath;
    String? certSanitaryPath = animalToEdit?.certSanitaryPath;
    String? docPurchasePath = animalToEdit?.docPurchasePath;
    
    int activeTab = 0;
    bool iaAnalyzing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final isLechera = selectedCategory == 'Vaca Lechera';

            // Widgets de cada pestaña
            List<Widget> tabPages = [
              // PESTAÑA 0: BÁSICA
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Información Básica (Obligatoria)', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreen)),
                  const SizedBox(height: 12),
                  
                  // Selector de foto de perfil
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: AppColors.greenSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primaryGreen, width: 2),
                          ),
                          child: ClipOval(
                            child: selectedImagePath != null && selectedImagePath!.isNotEmpty
                                ? (selectedImagePath!.startsWith('http')
                                    ? Image.network(selectedImagePath!, fit: BoxFit.cover, width: 90, height: 90)
                                    : Image.file(File(selectedImagePath!), fit: BoxFit.cover, width: 90, height: 90))
                                : Center(
                                    child: Icon(
                                      selectedCategory.contains('Lechera')
                                          ? LucideIcons.milk
                                          : selectedCategory.contains('Toro')
                                              ? LucideIcons.flame
                                              : LucideIcons.heart,
                                      color: AppColors.primaryGreenDark,
                                      size: 36,
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Material(
                            color: AppColors.primaryGreen,
                            shape: const CircleBorder(),
                            elevation: 4,
                            child: InkWell(
                              onTap: () async {
                                final source = await showModalBottomSheet<ImageSource>(
                                  context: modalContext,
                                  backgroundColor: AppColors.surface,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(20),
                                    ),
                                  ),
                                  builder: (pickerContext) => Container(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Seleccionar origen de la foto', style: AppTextStyles.bodyBold),
                                        const SizedBox(height: 20),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Column(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(LucideIcons.camera, color: AppColors.primaryGreen, size: 32),
                                                  onPressed: () => Navigator.pop(pickerContext, ImageSource.camera),
                                                ),
                                                Text('Cámara', style: AppTextStyles.caption),
                                              ],
                                            ),
                                            Column(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(LucideIcons.image, color: AppColors.primaryGreen, size: 32),
                                                  onPressed: () => Navigator.pop(pickerContext, ImageSource.gallery),
                                                ),
                                                Text('Galería', style: AppTextStyles.caption),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    ),
                                  ),
                                );

                                if (source != null) {
                                  final picker = ImagePicker();
                                  try {
                                    final pickedFile = await picker.pickImage(source: source);
                                    if (pickedFile != null) {
                                      setModalState(() {
                                        selectedImagePath = pickedFile.path;
                                      });
                                    }
                                  } catch (e) {
                                    debugPrint("Error picking image: $e");
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(6.0),
                                child: Icon(LucideIcons.camera, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Analizar con IA
                  if (selectedImagePath != null) ...[
                    const SizedBox(height: 6),
                    Center(
                      child: iaAnalyzing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                            )
                          : TextButton.icon(
                              onPressed: () {
                                setModalState(() => iaAnalyzing = true);
                                Future.delayed(const Duration(seconds: 1500), () {
                                  setModalState(() {
                                    iaAnalyzing = false;
                                    selectedBreed = 'Holstein';
                                    colorController.text = 'Blanco con Negro';
                                  });
                                  ScaffoldMessenger.of(modalContext).showSnackBar(
                                    SnackBar(
                                      content: Text('IA: Detectada Raza Holstein, Color Blanco con Negro', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
                                      backgroundColor: AppColors.primaryGreen,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                });
                              },
                              icon: const Icon(LucideIcons.sparkles, size: 14, color: AppColors.primaryGreen),
                              label: Text('Analizar foto con IA', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreen, fontSize: 11)),
                            ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Arete / Tag
                  TextFormField(
                    controller: tagController,
                    style: AppTextStyles.bodyBold,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Número de Arete / Tag (Ej: 0456)',
                      labelStyle: AppTextStyles.caption,
                      prefixIcon: const Icon(LucideIcons.binary, size: 20, color: AppColors.primaryGreen),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Ingrese el número del arete';
                      if (RegExp(r'[^0-9]').hasMatch(value.trim())) return 'Ingrese solo números';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Nombre
                  TextFormField(
                    controller: nameController,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Nombre / Alias del Animal',
                      labelStyle: AppTextStyles.caption,
                      prefixIcon: const Icon(LucideIcons.tag, size: 20, color: AppColors.primaryGreen),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Ingrese un nombre' : null,
                  ),
                  const SizedBox(height: 12),

                  // Categoría (Dropdown)
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Categoría',
                      labelStyle: AppTextStyles.caption,
                      prefixIcon: const Icon(LucideIcons.beef, size: 20, color: AppColors.primaryGreen),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Vaca Lechera', child: Text('Vaca Lechera')),
                      DropdownMenuItem(value: 'Toro Reproductor', child: Text('Toro Reproductor')),
                      DropdownMenuItem(value: 'Ternero', child: Text('Ternero')),
                      DropdownMenuItem(value: 'Ternera', child: Text('Ternera')),
                      DropdownMenuItem(value: 'Vaca de cria', child: Text('Vaca de cria')),
                      DropdownMenuItem(value: 'Torete', child: Text('Torete')),
                      DropdownMenuItem(value: 'Toro Engorde', child: Text('Toro Engorde')),
                      DropdownMenuItem(value: 'Vaca de carne', child: Text('Vaca de carne')),
                      DropdownMenuItem(value: 'Vaquilla', child: Text('Vaquilla')),
                      DropdownMenuItem(value: 'Novillo', child: Text('Novillo')),
                      DropdownMenuItem(value: 'Novilla', child: Text('Novilla')),
                      DropdownMenuItem(value: 'Burro', child: Text('Burro')),
                      DropdownMenuItem(value: 'Caballo', child: Text('Caballo')),
                      DropdownMenuItem(value: 'Yegua', child: Text('Yegua')),
                      DropdownMenuItem(value: 'Mula', child: Text('Mula')),

                      
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedCategory = val;
                          if (val == 'Ternero') selectedStage = 'Ternero';
                          if (val == 'Toro Reproductor') selectedStage = 'Toro';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Raza
                  DropdownButtonFormField<String>(
                    value: selectedBreed,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Raza',
                      labelStyle: AppTextStyles.caption,
                      prefixIcon: const Icon(LucideIcons.award, size: 20, color: AppColors.primaryGreen),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Holstein', child: Text('Holstein')),
                      DropdownMenuItem(value: 'Brahman', child: Text('Brahman')),
                      DropdownMenuItem(value: 'Jersey', child: Text('Jersey')),
                      DropdownMenuItem(value: 'Gyr', child: Text('Gyr')),
                      DropdownMenuItem(value: 'Angus', child: Text('Angus')),
                      DropdownMenuItem(value: 'Pardo Suizo', child: Text('Pardo Suizo')),
                      DropdownMenuItem(value: 'Simental', child: Text('Simental')),
                      DropdownMenuItem(value: 'Mestizo', child: Text('Mestizo')),
                    ],
                    onChanged: (val) => setModalState(() => selectedBreed = val!),
                  ),
                  const SizedBox(height: 12),

                  // Sexo
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('Hembra', style: AppTextStyles.bodyBold),
                          value: 'Hembra',
                          groupValue: selectedSex,
                          activeColor: AppColors.primaryGreen,
                          onChanged: (val) => setModalState(() => selectedSex = val!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('Macho', style: AppTextStyles.bodyBold),
                          value: 'Macho',
                          groupValue: selectedSex,
                          activeColor: AppColors.primaryGreen,
                          onChanged: (val) => setModalState(() => selectedSex = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Fecha de nacimiento y edad calculada
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: birthDateController,
                          style: AppTextStyles.bodyBold,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'F. de Nacimiento',
                            labelStyle: AppTextStyles.caption,
                            prefixIcon: const Icon(LucideIcons.calendar, size: 20, color: AppColors.primaryGreen),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: modalContext,
                              initialDate: DateTime.tryParse(birthDateController.text) ?? DateTime.now(),
                              firstDate: DateTime(2010),
                              lastDate: DateTime.now(),
                            );
                            if (pickedDate != null) {
                              setModalState(() {
                                birthDateController.text = pickedDate.toIso8601String().split('T')[0];
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Edad estimada:', style: AppTextStyles.caption),
                              const SizedBox(height: 2),
                              Text(
                                _calculateAge(birthDateController.text),
                                style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreenDark),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Estado
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Estado General',
                      labelStyle: AppTextStyles.caption,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Activo', child: Text('Activo')),
                      DropdownMenuItem(value: 'Vendido', child: Text('Vendido')),
                      DropdownMenuItem(value: 'Fallecido', child: Text('Fallecido')),
                    ],
                    onChanged: (val) => setModalState(() => selectedStatus = val!),
                  ),
                ],
              ),

              // PESTAÑA 1: PRODUCTIVA
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('2. Información Productiva', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreen)),
                  const SizedBox(height: 16),

                  // Propósito
                  DropdownButtonFormField<String>(
                    value: selectedPurpose,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Propósito Productivo',
                      labelStyle: AppTextStyles.caption,
                      prefixIcon: const Icon(LucideIcons.target, size: 20, color: AppColors.primaryGreen),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Leche', child: Text('Leche')),
                      DropdownMenuItem(value: 'Carne', child: Text('Carne')),
                      DropdownMenuItem(value: 'Doble propósito', child: Text('Doble propósito')),
                    ],
                    onChanged: (val) => setModalState(() => selectedPurpose = val!),
                  ),
                  const SizedBox(height: 14),

                  // Etapa
                  DropdownButtonFormField<String>(
                    value: selectedStage,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Etapa Productiva',
                      labelStyle: AppTextStyles.caption,
                      prefixIcon: const Icon(LucideIcons.trendingUp, size: 20, color: AppColors.primaryGreen),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Ternero', child: Text('Ternero')),
                      DropdownMenuItem(value: 'Novillo', child: Text('Novillo')),
                      DropdownMenuItem(value: 'Vaca', child: Text('Vaca')),
                      DropdownMenuItem(value: 'Toro', child: Text('Toro')),
                      DropdownMenuItem(value: 'Gestación', child: Text('Gestación')),
                      DropdownMenuItem(value: 'Lactancia', child: Text('Lactancia')),
                    ],
                    onChanged: (val) => setModalState(() => selectedStage = val!),
                  ),
                  const SizedBox(height: 14),

                  // Peso
                  TextFormField(
                    controller: weightController,
                    style: AppTextStyles.bodyBold,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Peso Corporal Inicial (kg)',
                      labelStyle: AppTextStyles.caption,
                      prefixIcon: const Icon(LucideIcons.scale, size: 20, color: AppColors.primaryGreen),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Ingrese el peso';
                      if (double.tryParse(value) == null) return 'Ingrese un peso válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Producción de leche (solo si es lechera)
                  if (isLechera) ...[
                    TextFormField(
                      controller: prodController,
                      style: AppTextStyles.bodyBold,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Producción Diaria de Leche (Litros - Opcional)',
                        labelStyle: AppTextStyles.caption,
                        prefixIcon: const Icon(LucideIcons.milk, size: 20, color: AppColors.primaryGreen),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Condición Corporal slider (1-5)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Condición Corporal:', style: AppTextStyles.bodyBold),
                            Text(
                              bodyCondition.toStringAsFixed(1),
                              style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreen, fontSize: 18),
                            ),
                          ],
                        ),
                        Slider(
                          value: bodyCondition,
                          min: 1.0,
                          max: 5.0,
                          divisions: 8,
                          activeColor: AppColors.primaryGreen,
                          inactiveColor: AppColors.border,
                          onChanged: (val) => setModalState(() => bodyCondition = val),
                        ),
                        Text('1: Caquéctico, 3: Óptimo, 5: Obeso', style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Color
                  TextFormField(
                    controller: colorController,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Color / Patrón de Pelaje',
                      labelStyle: AppTextStyles.caption,
                      prefixIcon: const Icon(LucideIcons.palette, size: 20, color: AppColors.primaryGreen),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Observaciones
                  TextFormField(
                    controller: descController,
                    style: AppTextStyles.body,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Observaciones Físicas / Descripción',
                      labelStyle: AppTextStyles.caption,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),

              // PESTAÑA 2: GENÉTICA Y UBICACIÓN
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('3. Información Genética y Ubicación', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreen)),
                  const SizedBox(height: 16),

                  // Padre
                  TextFormField(
                    controller: fatherController,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Código del Padre (Arete / Registro)',
                      labelStyle: AppTextStyles.caption,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Madre
                  TextFormField(
                    controller: motherController,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Código de la Madre (Arete / Registro)',
                      labelStyle: AppTextStyles.caption,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Línea Genética
                  TextFormField(
                    controller: geneticLineController,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Línea o Cabaña Genética',
                      labelStyle: AppTextStyles.caption,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Origen
                  TextFormField(
                    controller: originController,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Origen / Finca Proveedora',
                      labelStyle: AppTextStyles.caption,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text('Ubicación Física', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreen)),
                  const SizedBox(height: 12),

                  // Finca
                  TextFormField(
                    controller: fincaController,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Finca',
                      labelStyle: AppTextStyles.caption,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Lote y Potrero
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: loteController,
                          style: AppTextStyles.bodyBold,
                          decoration: InputDecoration(
                            labelText: 'Lote',
                            labelStyle: AppTextStyles.caption,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: potreroController,
                          style: AppTextStyles.bodyBold,
                          decoration: InputDecoration(
                            labelText: 'Potrero',
                            labelStyle: AppTextStyles.caption,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // GPS Coordenadas
                  TextFormField(
                    controller: gpsCoordsController,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      labelText: 'Coordenadas GPS (Opcional - ej: -4.008, -79.201)',
                      labelStyle: AppTextStyles.caption,
                      prefixIcon: const Icon(LucideIcons.mapPin, size: 20, color: AppColors.primaryGreen),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),

              // PESTAÑA 3: SALUD Y NUTRICIÓN
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('4. Información Sanitaria e Inicial', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreen)),
                  const SizedBox(height: 14),

                  // Estado de salud
                  DropdownButtonFormField<String>(
                    value: selectedHealthStatus,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Estado de Salud Inicial',
                      labelStyle: AppTextStyles.caption,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Saludable', child: Text('Saludable')),
                      DropdownMenuItem(value: 'Enfermo', child: Text('Enfermo')),
                      DropdownMenuItem(value: 'En Tratamiento', child: Text('En Tratamiento')),
                      DropdownMenuItem(value: 'Cuarentena', child: Text('Cuarentena')),
                    ],
                    onChanged: (val) => setModalState(() => selectedHealthStatus = val!),
                  ),
                  const SizedBox(height: 12),

                  // Veterinario Responsable
                  TextFormField(
                    controller: vetResponsibleController,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Veterinario Responsable',
                      labelStyle: AppTextStyles.caption,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Enfermedades Previas
                  TextFormField(
                    controller: prevDiseasesController,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      labelText: 'Enfermedades Previas',
                      labelStyle: AppTextStyles.caption,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Alergias y Medicación
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: allergiesController,
                          style: AppTextStyles.body,
                          decoration: InputDecoration(
                            labelText: 'Alergias',
                            labelStyle: AppTextStyles.caption,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: currentMedicationController,
                          style: AppTextStyles.body,
                          decoration: InputDecoration(
                            labelText: 'Medicación Actual',
                            labelStyle: AppTextStyles.caption,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text('Información Nutricional', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreen)),
                  const SizedBox(height: 12),

                  // Tipo de alimentación
                  DropdownButtonFormField<String>(
                    value: selectedDietType,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Tipo de Alimentación',
                      labelStyle: AppTextStyles.caption,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Pasto', child: Text('Pasto')),
                      DropdownMenuItem(value: 'Silo', child: Text('Silo')),
                      DropdownMenuItem(value: 'Concentrado', child: Text('Concentrado')),
                      DropdownMenuItem(value: 'Mixto', child: Text('Mixto')),
                    ],
                    onChanged: (val) => setModalState(() => selectedDietType = val!),
                  ),
                  const SizedBox(height: 12),

                  // Consumo diario
                  TextFormField(
                    controller: dailyConsumptionController,
                    style: AppTextStyles.bodyBold,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Consumo Diario Aprox. (kg/día)',
                      labelStyle: AppTextStyles.caption,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Objetivo Productivo
                  DropdownButtonFormField<String>(
                    value: selectedProductionObjective,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Objetivo Nutricional',
                      labelStyle: AppTextStyles.caption,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Mantenimiento', child: Text('Mantenimiento')),
                      DropdownMenuItem(value: 'Ganancia de peso', child: Text('Ganancia de peso')),
                      DropdownMenuItem(value: 'Producción láctea', child: Text('Producción láctea')),
                    ],
                    onChanged: (val) => setModalState(() => selectedProductionObjective = val!),
                  ),
                  const SizedBox(height: 12),

                  // Toggles de Nutrición
                  Wrap(
                    spacing: 16,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: grazing,
                            activeColor: AppColors.primaryGreen,
                            onChanged: (val) => setModalState(() => grazing = val!),
                          ),
                          Text('Pastoreo', style: AppTextStyles.bodyBold),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: balancedFeed,
                            activeColor: AppColors.primaryGreen,
                            onChanged: (val) => setModalState(() => balancedFeed = val!),
                          ),
                          Text('Balanceado', style: AppTextStyles.bodyBold),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: supplements,
                            activeColor: AppColors.primaryGreen,
                            onChanged: (val) => setModalState(() => supplements = val!),
                          ),
                          Text('Suplementos', style: AppTextStyles.bodyBold),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // PESTAÑA 4: ECONÓMICA Y DOCUMENTOS
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('5. Información Económica', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreen)),
                  const SizedBox(height: 14),

                  // Precio Compra
                  TextFormField(
                    controller: purchaseValueController,
                    style: AppTextStyles.bodyBold,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Valor / Costo de Compra (\$ USD)',
                      labelStyle: AppTextStyles.caption,
                      prefixIcon: const Icon(LucideIcons.dollarSign, size: 20, color: AppColors.primaryGreen),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Proveedor
                  TextFormField(
                    controller: providerController,
                    style: AppTextStyles.bodyBold,
                    decoration: InputDecoration(
                      labelText: 'Proveedor / Comercializador',
                      labelStyle: AppTextStyles.caption,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Disponible venta Switch
                  SwitchListTile(
                    title: Text('Disponible para Venta', style: AppTextStyles.bodyBold),
                    subtitle: Text('Habilitar para visualización en Marketplace', style: AppTextStyles.caption),
                    value: availableForSale,
                    activeColor: AppColors.primaryGreen,
                    onChanged: (val) => setModalState(() => availableForSale = val),
                  ),
                  const SizedBox(height: 20),

                  Text('Fotografías y Documentos Adicionales', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreen)),
                  const SizedBox(height: 12),

                  // Simular adjuntar fotos lateral y certificados
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // Mock attach
                          setModalState(() {
                            imageFrontPath = 'attached_front';
                          });
                          ScaffoldMessenger.of(modalContext).showSnackBar(
                            const SnackBar(content: Text('Foto Frontal Adjuntada'), duration: Duration(seconds: 1)),
                          );
                        },
                        icon: Icon(LucideIcons.camera, size: 16, color: imageFrontPath != null ? Colors.white : AppColors.primaryGreen),
                        label: const Text('Foto Frontal', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: imageFrontPath != null ? AppColors.primaryGreen : AppColors.background,
                          foregroundColor: imageFrontPath != null ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          setModalState(() {
                            imageSidePath = 'attached_side';
                          });
                          ScaffoldMessenger.of(modalContext).showSnackBar(
                            const SnackBar(content: Text('Foto Lateral Adjuntada'), duration: Duration(seconds: 1)),
                          );
                        },
                        icon: Icon(LucideIcons.camera, size: 16, color: imageSidePath != null ? Colors.white : AppColors.primaryGreen),
                        label: const Text('Foto Lateral', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: imageSidePath != null ? AppColors.primaryGreen : AppColors.background,
                          foregroundColor: imageSidePath != null ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setModalState(() {
                            certSanitaryPath = 'attached_cert';
                          });
                          ScaffoldMessenger.of(modalContext).showSnackBar(
                            const SnackBar(content: Text('Certificado Adjuntado'), duration: Duration(seconds: 1)),
                          );
                        },
                        icon: Icon(LucideIcons.fileText, size: 16, color: certSanitaryPath != null ? Colors.white : AppColors.primaryGreen),
                        label: const Text('Cert. Sanitario', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: certSanitaryPath != null ? AppColors.primaryGreen : AppColors.background,
                          foregroundColor: certSanitaryPath != null ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          setModalState(() {
                            docPurchasePath = 'attached_doc';
                          });
                          ScaffoldMessenger.of(modalContext).showSnackBar(
                            const SnackBar(content: Text('Ficha Compra Adjuntada'), duration: Duration(seconds: 1)),
                          );
                        },
                        icon: Icon(LucideIcons.fileText, size: 16, color: docPurchasePath != null ? Colors.white : AppColors.primaryGreen),
                        label: const Text('Doc. Compra', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: docPurchasePath != null ? AppColors.primaryGreen : AppColors.background,
                          foregroundColor: docPurchasePath != null ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ];

            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(modalContext).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabecera con micrófono de Voz IA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            animalToEdit != null ? 'Editar Animal' : 'Registrar Nuevo Animal',
                            style: AppTextStyles.h2,
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(LucideIcons.mic, color: AppColors.primaryGreen, size: 24),
                                tooltip: 'Registrar por Voz IA',
                                onPressed: () {
                                  _showVoiceRegistrationSimulation(
                                    modalContext,
                                    setModalState,
                                    nameController,
                                    tagController,
                                    weightController,
                                    descController,
                                    colorController,
                                    (val) => selectedCategory = val,
                                    (val) => selectedBreed = val,
                                    (val) => selectedSex = val,
                                    (val) => selectedStage = val,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.x),
                                onPressed: () => Navigator.pop(modalContext),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Stepper / Indicador de pestañas
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          bool isActive = activeTab == index;
                          bool isCompleted = activeTab > index;
                          return Container(
                            width: 32,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primaryGreen
                                  : isCompleted
                                      ? AppColors.primaryGreen.withOpacity(0.4)
                                      : AppColors.border,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Contenedor principal de pestañas
                      tabPages[activeTab],
                      const SizedBox(height: 24),

                      // Botones de Navegación del Wizard
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (activeTab > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setModalState(() => activeTab--),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.primaryGreen),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text('Anterior', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreen)),
                              ),
                            )
                          else
                            const Spacer(),
                          const SizedBox(width: 12),
                          if (activeTab < 4)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  // Validar primera pestaña si se avanza
                                  if (activeTab == 0 && !formKey.currentState!.validate()) {
                                    return;
                                  }
                                  setModalState(() => activeTab++);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text('Siguiente', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
                              ),
                            )
                          else
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (formKey.currentState!.validate()) {
                                    final provider = Provider.of<DataProvider>(context, listen: false);
                                    final cleanTag = tagController.text.trim();
                                    
                                    // Verificar arete único en edición
                                    final exists = provider.animals.any((a) => a.id == cleanTag);
                                    if (exists && (animalToEdit == null || animalToEdit.id != cleanTag)) {
                                      ScaffoldMessenger.of(modalContext).showSnackBar(
                                        SnackBar(
                                          content: Text('Ya existe un animal con el arete #$cleanTag', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
                                          backgroundColor: AppColors.alertRed,
                                        ),
                                      );
                                      return;
                                    }

                                    double weight = double.parse(weightController.text);
                                    String? production;
                                    if (isLechera && prodController.text.isNotEmpty) {
                                      production = '${double.parse(prodController.text).toStringAsFixed(1)} L/dia';
                                    }

                                    final savedAnimal = Animal(
                                      id: animalToEdit?.id ?? cleanTag,
                                      name: nameController.text.trim(),
                                      tag: '#$cleanTag',
                                      category: selectedCategory,
                                      score: animalToEdit?.score ?? 95,
                                      description: descController.text.isEmpty 
                                          ? 'Animal en óptimo estado corporal' 
                                          : descController.text.trim(),
                                      weightKg: weight,
                                      productionLiters: production,
                                      vaccineStatus: animalToEdit?.vaccineStatus,
                                      hasAlert: animalToEdit?.hasAlert ?? false,
                                      imagePath: selectedImagePath,
                                      breed: selectedBreed,
                                      sex: selectedSex,
                                      birthDate: birthDateController.text,
                                      status: selectedStatus,
                                      purpose: selectedPurpose,
                                      stage: selectedStage,
                                      bodyCondition: bodyCondition,
                                      color: colorController.text,
                                      geneticFather: fatherController.text.isEmpty ? null : fatherController.text.trim(),
                                      geneticMother: motherController.text.isEmpty ? null : motherController.text.trim(),
                                      geneticLine: geneticLineController.text.isEmpty ? null : geneticLineController.text.trim(),
                                      origin: originController.text.isEmpty ? null : originController.text.trim(),
                                      healthStatus: selectedHealthStatus,
                                      vetResponsible: vetResponsibleController.text.isEmpty ? null : vetResponsibleController.text.trim(),
                                      prevDiseases: prevDiseasesController.text.isEmpty ? null : prevDiseasesController.text.trim(),
                                      allergies: allergiesController.text.isEmpty ? null : allergiesController.text.trim(),
                                      currentMedication: currentMedicationController.text.isEmpty ? null : currentMedicationController.text.trim(),
                                      dietType: selectedDietType,
                                      grazing: grazing,
                                      balancedFeed: balancedFeed,
                                      supplements: supplements,
                                      dailyConsumption: double.tryParse(dailyConsumptionController.text),
                                      productionObjective: selectedProductionObjective,
                                      finca: fincaController.text,
                                      lote: loteController.text,
                                      potrero: potreroController.text,
                                      gpsCoords: gpsCoordsController.text.isEmpty ? null : gpsCoordsController.text.trim(),
                                      purchaseValue: double.tryParse(purchaseValueController.text),
                                      purchaseDate: purchaseDateController.text.isEmpty ? null : purchaseDateController.text.trim(),
                                      provider: providerController.text.isEmpty ? null : providerController.text.trim(),
                                      availableForSale: availableForSale,
                                      imageFrontPath: imageFrontPath,
                                      imageSidePath: imageSidePath,
                                      certSanitaryPath: certSanitaryPath,
                                      docPurchasePath: docPurchasePath,
                                    );

                                    if (animalToEdit != null) {
                                      await provider.updateAnimal(savedAnimal);
                                    } else {
                                      await provider.addAnimal(savedAnimal);
                                    }

                                    if (modalContext.mounted) {
                                      Navigator.pop(modalContext);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            animalToEdit != null 
                                                ? 'Se han guardado los cambios de ${savedAnimal.name}'
                                                : 'Se ha registrado a ${savedAnimal.name} con éxito', 
                                            style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
                                          ),
                                          backgroundColor: AppColors.primaryGreen,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(
                                  animalToEdit != null ? 'Guardar Cambios' : 'Registrar Animal',
                                  style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, provider, child) {
        final role = provider.profile?['role'] ?? 'Ganadero';

        if (provider.isLoading) {
          return Scaffold(
            appBar: AuraTopBar(role: role),
            body: const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
          );
        }

        // Conteo de alertas reales para el chip
        final alertsCount = provider.alerts.length;

        // Filtrado dinámico
        List<Animal> filteredAnimals = provider.animals;
        if (_activeFilter == 'Vacas') {
          filteredAnimals = provider.animals.where((a) => a.category.contains('Vaca') || a.category.contains('Vaquilla')).toList();
        } else if (_activeFilter == 'Toros') {
          filteredAnimals = provider.animals.where((a) => a.category.contains('Toro')).toList();
        } else if (_activeFilter == 'Terneros') {
          filteredAnimals = provider.animals.where((a) => a.category.contains('Ternero')).toList();
        } else if (_activeFilter == 'Con Alertas') {
          filteredAnimals = provider.animals.where((a) => a.hasAlert).toList();
        }

        return Scaffold(
          appBar: AuraTopBar(role: role),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddAnimalDialog(context),
            backgroundColor: AppColors.primaryGreen,
            icon: const Icon(LucideIcons.plus, color: Colors.white),
            label: Text(
              'Nuevo',
              style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
            ),
          ),
          floatingActionButtonLocation: const _AboveBottomNavFabLocation(),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mi Ganado', style: AppTextStyles.h1),
                  IconButton(
                    icon: const Icon(LucideIcons.qrCode, color: AppColors.primaryGreen, size: 26),
                    tooltip: 'Escanear QR / Arete',
                    onPressed: () => _showScanQRDialog(context, provider),
                  ),
                ],
              ),
              Text(
                '${provider.animals.length} animales registrados',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 16),
              FilterChips(
                alertsCount: alertsCount,
                onFilterChanged: (filter) {
                  setState(() => _activeFilter = filter);
                },
              ),
              const SizedBox(height: 16),
              HerdSummary(animals: provider.animals),
              const SizedBox(height: 20),
              if (filteredAnimals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No se encontraron animales para este filtro',
                      style: AppTextStyles.body,
                    ),
                  ),
                )
              else
                ...filteredAnimals.map(
                  (a) {
                    final activePlans = provider.nutritionPlans.where((p) => p.status == 'Activo' && (p.targetGroup == a.category || p.targetGroup == a.id || p.targetGroup == a.name)).toList();
                    double? compliance;
                    if (activePlans.isNotEmpty) {
                      final analysis = PlanHistoryAnalyzer.analyze(
                        a,
                        provider.nutritionPlans,
                        provider.weightRecords,
                        provider.productionRecords,
                      );
                      if (!analysis.feedbackNote.contains("No se encontraron")) {
                        compliance = analysis.complianceScore * 100;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AnimalCard(
                        animal: a,
                        nutritionCompliance: compliance,
                        onTap: () => _showAnimalDetailSheet(context, a, provider),
                        onWeightTap: () => _showWeightRegisterSheet(context, a, provider, isFromDetail: false),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAnimalDetailSheet(BuildContext context, Animal animal, DataProvider provider) {
    final List<WeightRecord> animalWeights = provider.weightRecords.where((r) => r.animalId == animal.id).toList();
    animalWeights.sort((a, b) => b.date.compareTo(a.date));

    final List<ProductionRecord> animalProds = provider.productionRecords.where((r) => r.animalId == animal.id).toList();
    animalProds.sort((a, b) => b.date.compareTo(a.date));

    final bool isNotified = provider.alerts.any((AlertModel al) => al.animalTag == animal.tag && al.title.contains('Vacunación Solicitada'));

    final vaccineStatusLower = animal.vaccineStatus?.toLowerCase() ?? '';
    final isVaccineVencida = vaccineStatusLower == 'vencida';
    final isVaccinePorVencer = vaccineStatusLower == 'por vencer' || vaccineStatusLower.contains('próxima') || vaccineStatusLower.contains('vence pronto') || animal.vaccineStatus == null;
    final needsVaccineAlert = isVaccineVencida || isVaccinePorVencer;

    int activeDetailTab = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Color scoreColor = AppColors.scoreColor(animal.score);
            IconData categoryIcon = LucideIcons.milk;
            if (animal.category.contains('Toro')) categoryIcon = LucideIcons.flame;
            if (animal.category.contains('Ternero')) categoryIcon = LucideIcons.heart;

            // IA Recordatorios dinámicos según etapa
            String iaReminder = "Programar pesaje de control y revisión de ración en 20 días.";
            if (animal.stage == 'Ternero') {
              iaReminder = "IA Sugiere: Control de desparasitación y refuerzo de complejo B en 10 días.";
            } else if (animal.stage == 'Lactancia' || animal.category == 'Vaca Lechera') {
              iaReminder = "IA Sugiere: Control de mastitis clínico preventivo mañana. Incrementar balanceado en 1 kg por producción de leche.";
            } else if (animal.stage == 'Gestación') {
              iaReminder = "IA Sugiere: Suplementar con sales minerales pre-parto. Apartar a potrero de maternidad en 3 semanas.";
            }

            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(modalContext).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    // Fila de encabezado con foto circular y Código QR
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.greenSurface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: animal.imagePath != null && animal.imagePath!.isNotEmpty
                                ? (animal.imagePath!.startsWith('http')
                                    ? Image.network(animal.imagePath!, fit: BoxFit.cover)
                                    : Image.file(File(animal.imagePath!), fit: BoxFit.cover))
                                : Icon(categoryIcon, color: AppColors.primaryGreenDark, size: 28),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(animal.name, style: AppTextStyles.h2, overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Text(animal.tag, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              Text('${animal.breed} • ${animal.sex} • ${_calculateAge(animal.birthDate)}', style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // QR Code dinámico
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: _buildMockQR(animal.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Selector de Pestañas del Detalle
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _buildDetailTabButton(0, 'Dashboard', activeDetailTab, (val) => setModalState(() => activeDetailTab = val)),
                          _buildDetailTabButton(1, 'Sanidad y Dieta', activeDetailTab, (val) => setModalState(() => activeDetailTab = val)),
                          _buildDetailTabButton(2, 'Genética y Econ.', activeDetailTab, (val) => setModalState(() => activeDetailTab = val)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // CONTENIDO DE PESTAÑAS
                    if (activeDetailTab == 0) ...[
                      // PESTAÑA RESUMEN
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              'Peso Actual',
                              '${animal.weightKg.toStringAsFixed(0)} kg',
                              LucideIcons.scale,
                              AppColors.earthBrown,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricCard(
                              'Cond. Corporal',
                              '${animal.bodyCondition.toStringAsFixed(1)} / 5',
                              LucideIcons.heartPulse,
                              scoreColor,
                            ),
                          ),
                          if (animal.productionLiters != null) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildMetricCard(
                                'Producción',
                                animal.productionLiters!,
                                LucideIcons.milk,
                                const Color(0xFF1E88E5),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text('Ubicación Actual', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.mapPin, color: AppColors.primaryGreen, size: 20),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${animal.finca} — ${animal.lote}', style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
                                Text('Potrero: ${animal.potrero} ${animal.gpsCoords != null ? "(${animal.gpsCoords})" : ""}', style: AppTextStyles.caption),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // IA Recordatorios
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.sparkles, color: AppColors.primaryGreen, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('IA Sugerencias & Alertas', style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: AppColors.primaryGreenDark)),
                                  const SizedBox(height: 2),
                                  Text(iaReminder, style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (activeDetailTab == 1) ...[
                      // PESTAÑA SANIDAD Y DIETA
                      Text('Estado Sanitario', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Estado de Salud:', style: AppTextStyles.body),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: animal.healthStatus == 'Saludable' ? AppColors.greenSurface : AppColors.alertOrangeSurface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    animal.healthStatus,
                                    style: AppTextStyles.bodyBold.copyWith(
                                      color: animal.healthStatus == 'Saludable' ? AppColors.primaryGreenDark : AppColors.alertOrange,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (animal.vetResponsible != null) ...[
                              const Divider(color: AppColors.border),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Veterinario:', style: AppTextStyles.body),
                                  Text(animal.vetResponsible!, style: AppTextStyles.bodyBold),
                                ],
                              ),
                            ],
                            if (animal.prevDiseases != null) ...[
                              const Divider(color: AppColors.border),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Enfermedades Previas:', style: AppTextStyles.body),
                                  Text(animal.prevDiseases!, style: AppTextStyles.bodyBold),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Alimentación y Nutrición', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Tipo de Dieta:', style: AppTextStyles.body),
                                Text(animal.dietType, style: AppTextStyles.bodyBold),
                              ],
                            ),
                            const Divider(color: AppColors.border),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Consumo Diario Aprox:', style: AppTextStyles.body),
                                Text('${animal.dailyConsumption?.toStringAsFixed(1) ?? "12"} kg/día', style: AppTextStyles.bodyBold),
                              ],
                            ),
                            const Divider(color: AppColors.border),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Tácticas de alimentación:', style: AppTextStyles.body),
                                Text(
                                  '${animal.grazing ? "Pastoreo " : ""}${animal.balancedFeed ? "• Balanceado " : ""}${animal.supplements ? "• Supl. " : ""}',
                                  style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Esquema de Vacunas
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: needsVaccineAlert 
                              ? AppColors.alertOrange.withOpacity(0.08)
                              : AppColors.primaryGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: needsVaccineAlert 
                                ? AppColors.alertOrange.withOpacity(0.3)
                                : AppColors.primaryGreen.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  needsVaccineAlert ? LucideIcons.alertTriangle : LucideIcons.checkCircle,
                                  color: needsVaccineAlert ? AppColors.alertOrange : AppColors.primaryGreen,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  needsVaccineAlert 
                                      ? (isVaccineVencida ? 'Vacuna Vencida' : 'Vacuna por Vencer')
                                      : 'Vacuna al Día',
                                  style: AppTextStyles.bodyBold.copyWith(
                                    color: needsVaccineAlert ? AppColors.alertOrange : AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                            if (needsVaccineAlert) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 38,
                                child: isNotified
                                    ? Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryGreen.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                                        ),
                                        alignment: Alignment.center,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(LucideIcons.check, color: AppColors.primaryGreen, size: 16),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Notificación enviada al médico',
                                              style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreen, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ElevatedButton.icon(
                                        onPressed: () async {
                                          await provider.sendVaccineNotification(animal);
                                          setModalState(() {});
                                        },
                                        icon: const Icon(LucideIcons.send, size: 14, color: Colors.white),
                                        label: Text('Notificar al Veterinario', style: AppTextStyles.bodyBold.copyWith(color: Colors.white, fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryGreen,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          elevation: 0,
                                        ),
                                      ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      // PESTAÑA GENÉTICA Y FINANZAS
                      Text('Línea Genealógica', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Padre / Sire:', style: AppTextStyles.body),
                                Text(animal.geneticFather ?? 'Sin registro', style: AppTextStyles.bodyBold),
                              ],
                            ),
                            const Divider(color: AppColors.border),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Madre / Dam:', style: AppTextStyles.body),
                                Text(animal.geneticMother ?? 'Sin registro', style: AppTextStyles.bodyBold),
                              ],
                            ),
                            const Divider(color: AppColors.border),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Línea Genética:', style: AppTextStyles.body),
                                Text(animal.geneticLine ?? 'Sin registro', style: AppTextStyles.bodyBold),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Información de Compra y Ventas', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Costo de Compra:', style: AppTextStyles.body),
                                Text(
                                  animal.purchaseValue != null ? '\$${animal.purchaseValue!.toStringAsFixed(2)} USD' : 'Nacido en finca',
                                  style: AppTextStyles.bodyBold,
                                ),
                              ],
                            ),
                            if (animal.provider != null) ...[
                              const Divider(color: AppColors.border),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Proveedor:', style: AppTextStyles.body),
                                  Text(animal.provider!, style: AppTextStyles.bodyBold),
                                ],
                              ),
                            ],
                            const Divider(color: AppColors.border),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Disponible para Venta:', style: AppTextStyles.body),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: animal.availableForSale ? AppColors.greenSurface : AppColors.border,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    animal.availableForSale ? 'Sí' : 'No',
                                    style: AppTextStyles.bodyBold.copyWith(
                                      color: animal.availableForSale ? AppColors.primaryGreenDark : AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    if (animal.category == 'Vaca Lechera' || animal.category == 'Vaca Seca') ...[
                      _DairyProductionSection(
                        animal: animal,
                        provider: provider,
                        onNavigate: widget.onNavigate,
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Acciones Principales
                    Center(
                      child: FloatingActionButton.extended(
                        heroTag: 'register_weight_fab_${animal.id}',
                        onPressed: () {
                          _showWeightRegisterSheet(context, animal, provider, isFromDetail: true);
                        },
                        backgroundColor: AppColors.primaryGreen,
                        icon: const Icon(LucideIcons.scale, color: Colors.white),
                        label: Text('Registrar peso', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // BOTONES DE EXPORTACIÓN PDF
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await PdfExportService.instance.exportTraceabilityCertificate(animal);
                            },
                            icon: const Icon(LucideIcons.qrCode, size: 16, color: Colors.white),
                            label: const Text('Certificado QR', style: TextStyle(color: Colors.white, fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final vaccines = provider.vaccines.where((v) => v['animal_id'] == animal.id).toList();
                              final treatments = provider.medicalTreatments.where((t) => t['animal_id'] == animal.id).toList();
                              await PdfExportService.instance.exportClinicalHistory(animal, vaccines, treatments);
                            },
                            icon: const Icon(LucideIcons.fileText, size: 16, color: Colors.white),
                            label: const Text('Historial Clínico', style: TextStyle(color: Colors.white, fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreenDark,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(modalContext); // Cerrar hoja de detalle
                              _showAddAnimalDialog(context, animalToEdit: animal);
                            },
                            icon: const Icon(LucideIcons.edit2, size: 16, color: AppColors.primaryGreenDark),
                            label: Text('Editar', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreenDark)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.greenSurface,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppColors.primaryGreen, width: 1),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showDeregisterConfirmation(context, animal, provider);
                            },
                            icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.alertRed),
                            label: Text('Dar de Baja', style: AppTextStyles.bodyBold.copyWith(color: AppColors.alertRed)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.alertOrangeSurface,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppColors.alertRed, width: 1),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Historial
                    if (animalWeights.isNotEmpty || animalProds.isNotEmpty) ...[
                      Text('Historial de Registros', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            if (animalProds.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text('Producción Reciente (Leche)', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                              ),
                              ...animalProds.take(3).map((r) => _buildHistoryRow(
                                    r.date.split('T')[0],
                                    '${r.liters.toStringAsFixed(1)} L',
                                    LucideIcons.milk,
                                  )),
                              const SizedBox(height: 8),
                            ],
                            if (animalWeights.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text('Peso Reciente', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                              ),
                              ...animalWeights.take(3).map((r) => _buildHistoryRow(
                                    r.date.split('T')[0],
                                    '${r.weightKg.toStringAsFixed(0)} kg',
                                    LucideIcons.scale,
                                  )),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );

          },
        );
      },
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(String date, String val, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(date, style: AppTextStyles.body.copyWith(fontSize: 12)),
            ],
          ),
          Text(val, style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: AppColors.primaryGreenDark)),
        ],
      ),
    );
  }

  void _showWeightRegisterSheet(BuildContext context, Animal animal, DataProvider provider, {required bool isFromDetail}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _WeightRegisterSheet(
          animal: animal,
          provider: provider,
          isFromDetail: isFromDetail,
          onNavigate: widget.onNavigate,
        );
      },
    );
  }

  void _showVoiceRegistrationSimulation(
    BuildContext context,
    StateSetter setModalState,
    TextEditingController nameController,
    TextEditingController tagController,
    TextEditingController weightController,
    TextEditingController descController,
    TextEditingController colorController,
    Function(String) setCategory,
    Function(String) setBreed,
    Function(String) setSex,
    Function(String) setStage,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (subContext, setSubState) {
            Future.delayed(const Duration(milliseconds: 2200), () {
              if (sheetContext.mounted) {
                Navigator.pop(sheetContext);
                setModalState(() {
                  nameController.text = "Holstein Premium";
                  tagController.text = "0999";
                  weightController.text = "180.0";
                  colorController.text = "Blanco con Negro";
                  descController.text = "Ternero Holstein macho registrado por voz";
                  setCategory("Ternero");
                  setBreed("Holstein");
                  setSex("Macho");
                  setStage("Ternero");
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Transcripción por Voz IA:', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
                        Text(
                          '"Ternero Holstein macho, 6 meses, 180 kilos, color blanco con negro"',
                          style: AppTextStyles.caption.copyWith(color: Colors.white, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.primaryGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            });

            return Container(
              decoration: const BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  const Icon(LucideIcons.mic, color: AppColors.primaryGreenLight, size: 48)
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .scale(duration: 600.ms, begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
                  const SizedBox(height: 16),
                  Text('Asistente de Voz IA', style: AppTextStyles.h2.copyWith(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Escuchando... Hable ahora', style: AppTextStyles.body.copyWith(color: Colors.white.withOpacity(0.7))),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      8,
                      (index) => Container(
                        width: 4,
                        height: 20 + (index % 3 * 10).toDouble(),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreenLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .scale(
                            duration: (400 + (index * 80)).ms,
                            begin: const Offset(1, 0.4),
                            end: const Offset(1, 1.4),
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailTabButton(int index, String label, int activeIndex, Function(int) onTap) {
    bool isActive = index == activeIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.bodyBold.copyWith(
              color: isActive ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMockQR(String data) {
    final int hash = data.hashCode;
    return SizedBox(
      width: 40,
      height: 40,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          7,
          (row) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              7,
              (col) {
                bool isCorner = (row < 2 && col < 2) || (row < 2 && col > 4) || (row > 4 && col < 2);
                bool isActive = isCorner || ((hash ^ (row * 7 + col)) % 3 == 0);
                return Container(
                  width: 4.5,
                  height: 4.5,
                  color: isActive ? Colors.black : Colors.transparent,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _calculateAge(String birthDateStr) {
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final now = DateTime.now();
      final difference = now.difference(birthDate).inDays;
      if (difference < 0) return 'F. futura';
      if (difference < 30) return '$difference d';
      final months = (difference / 30.4).floor();
      if (months < 12) return '$months m';
      final years = (months / 12).floor();
      final remainingMonths = months % 12;
      if (remainingMonths == 0) return '$years a';
      return '$years a, $remainingMonths m';
    } catch (_) {
      return 'N/A';
    }
  }

  void _showExitDetailsDialog(BuildContext context, Animal animal, String exitType, DataProvider provider) {
    final priceController = TextEditingController();
    final buyerController = TextEditingController();
    final observationsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final isSale = exitType.toLowerCase() == 'venta';
        return AlertDialog(
          title: Text('Detalles de la Baja (${exitType.toUpperCase()})', style: AppTextStyles.bodyBold),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSale) ...[
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Precio de Venta (\$)', hintText: 'Ej. 850.00'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: buyerController,
                    decoration: const InputDecoration(labelText: 'Comprador', hintText: 'Ej. Juan Pérez'),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: observationsController,
                  decoration: InputDecoration(
                    labelText: isSale ? 'Observaciones de Venta' : 'Causa de muerte / Observaciones',
                    hintText: 'Detalles adicionales...',
                  ),
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
                double price = 0.0;
                if (isSale) {
                  price = double.tryParse(priceController.text) ?? 0.0;
                  if (price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Ingresa un precio de venta válido")),
                    );
                    return;
                  }
                }

                final row = {
                  'id': "exit_${DateTime.now().millisecondsSinceEpoch}",
                  'animal_id': animal.id,
                  'exit_type': exitType,
                  'exit_date': DateTime.now().toIso8601String().split('T')[0],
                  'reason': observationsController.text.trim().isNotEmpty
                      ? observationsController.text.trim()
                      : "Baja por $exitType",
                  'sale_price': price,
                  'buyer': buyerController.text.trim().isNotEmpty ? buyerController.text.trim() : 'N/D',
                  'observations': observationsController.text.trim(),
                  'created_at': DateTime.now().toIso8601String(),
                  'synced': 0,
                };

                await provider.addAnimalExit(row);
                Navigator.pop(context); // Cerrar este dialogo
                Navigator.pop(context); // Cerrar modal sheet de detalles de animal

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Baja del animal ${animal.name} registrada exitosamente.', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
                    backgroundColor: AppColors.primaryGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
              child: const Text('Confirmar Baja', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showDeregisterConfirmation(BuildContext context, Animal animal, DataProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dar de Baja a ${animal.name}',
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: 8),
              Text(
                'Seleccione el motivo de la baja. Esta acción no se puede deshacer.',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: AppColors.greenSurface, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.dollarSign, color: AppColors.primaryGreen),
                ),
                title: Text('Vendido / Comercializado', style: AppTextStyles.bodyBold),
                subtitle: Text('El animal fue vendido a otra finca o mercado.', style: AppTextStyles.caption),
                trailing: const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textSecondary),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showExitDetailsDialog(context, animal, 'Venta', provider);
                },
              ),
              const Divider(color: AppColors.border),
              
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: AppColors.alertOrangeSurface, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.skull, color: AppColors.alertRed),
                ),
                title: Text('Muerte / Fallecimiento', style: AppTextStyles.bodyBold.copyWith(color: AppColors.alertRed)),
                subtitle: Text('El animal falleció debido a enfermedad o accidente.', style: AppTextStyles.caption),
                trailing: const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textSecondary),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showExitDetailsDialog(context, animal, 'Muerte', provider);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showScanQRDialog(BuildContext context, DataProvider provider) {
    final tokenController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(LucideIcons.qrCode, color: AppColors.primaryGreen),
              SizedBox(width: 10),
              Text('Buscar por Arete / QR', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ingresa el código del arete o el token del código QR público para consultar trazabilidad.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: tokenController,
                decoration: const InputDecoration(
                  labelText: 'Token QR o Tag / Arete',
                  hintText: 'Ej. 0999, Holstein Premium...',
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {
                  final active = provider.animals.where((a) => a.status.toLowerCase() == 'activo').toList();
                  if (active.isNotEmpty) {
                    final randomAnimal = active[DateTime.now().second % active.length];
                    tokenController.text = randomAnimal.qrToken ?? randomAnimal.tag;
                  }
                },
                icon: const Icon(LucideIcons.camera, size: 16),
                label: const Text('Simular Cámara'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.greenSurface,
                  foregroundColor: AppColors.primaryGreenDark,
                  elevation: 0,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final query = tokenController.text.trim().toLowerCase();
                if (query.isEmpty) return;

                final animal = provider.animals.firstWhere(
                  (a) => a.id.toLowerCase() == query ||
                         a.tag.toLowerCase().replaceAll('#', '') == query ||
                         a.tag.toLowerCase() == query ||
                         (a.qrToken != null && a.qrToken!.toLowerCase() == query),
                  orElse: () => Animal(id: '', name: '', tag: '', category: '', score: 0, description: '', weightKg: 0.0, status: ''),
                );

                Navigator.pop(context); // Cerrar dialogo de busqueda

                if (animal.id.isNotEmpty) {
                  _showAnimalDetailSheet(context, animal, provider);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Código o Token "$query" no encontrado en el hato local.'),
                      backgroundColor: AppColors.alertOrange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
              child: const Text('Consultar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
class _AboveBottomNavFabLocation extends FloatingActionButtonLocation {
  const _AboveBottomNavFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabWidth = scaffoldGeometry.floatingActionButtonSize.width;
    final double fabHeight = scaffoldGeometry.floatingActionButtonSize.height;
    
    final double contentWidth = scaffoldGeometry.scaffoldSize.width;
    final double contentHeight = scaffoldGeometry.scaffoldSize.height;
    
    // Bottom nav sits 16px above bottom + height 72 + extra space 16 = 104px
    double x = contentWidth - fabWidth - 16;
    double y = contentHeight - fabHeight - 104;
    return Offset(x, y);
  }
}

class _WeightRegisterSheet extends StatefulWidget {
  final Animal animal;
  final DataProvider provider;
  final bool isFromDetail;
  final Function(int)? onNavigate;

  const _WeightRegisterSheet({
    required this.animal,
    required this.provider,
    required this.isFromDetail,
    this.onNavigate,
  });

  @override
  State<_WeightRegisterSheet> createState() => _WeightRegisterSheetState();
}

class _WeightRegisterSheetState extends State<_WeightRegisterSheet> {
  DateTime selectedDate = DateTime.now();
  final obsController = TextEditingController();
  final weightController = TextEditingController();
  bool showSuccessCheck = false;
  bool isSaving = false;

  @override
  void dispose() {
    obsController.dispose();
    weightController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  double getTargetWeight(String category) {
    if (category.contains('Engorde')) return 600.0;
    if (category.contains('Lechera')) return 500.0;
    if (category.contains('Reproductor')) return 750.0;
    if (category.contains('Ternero')) return 120.0;
    return 500.0;
  }

  double getCategoryAverageGdp(String category) {
    if (category.contains('Lechera')) return 0.6;
    if (category.contains('Reproductor')) return 0.8;
    if (category.contains('Ternero')) return 0.7;
    if (category.contains('Engorde')) return 1.0;
    return 0.6;
  }

  @override
  Widget build(BuildContext context) {
    final animalWeights = widget.provider.weightRecords
        .where((r) => r.animalId == widget.animal.id)
        .toList();
    animalWeights.sort((a, b) => b.date.compareTo(a.date));

    String lastWeightHeader = '';
    WeightRecord? latestRecord;
    if (animalWeights.isNotEmpty) {
      latestRecord = animalWeights.first;
      final date = DateTime.tryParse(latestRecord.date) ?? DateTime.now();
      final days = DateTime.now().difference(date).inDays;
      final daysText = days == 1 ? '1 día' : '$days días';
      lastWeightHeader = 'último peso: ${latestRecord.weightKg.toStringAsFixed(0)} kg hace $daysText';
    } else {
      lastWeightHeader = 'último peso: ${widget.animal.weightKg.toStringAsFixed(0)} kg (inicial)';
    }

    final double? newWeight = double.tryParse(weightController.text);

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
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.animal.name} ${widget.animal.tag}',
                            style: AppTextStyles.h2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            lastWeightHeader,
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 200,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.border, width: 2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: TextFormField(
                                    controller: weightController,
                                    autofocus: true,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                                        color: AppColors.textSecondary.withOpacity(0.3),
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    onChanged: (val) {
                                      setState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'kg',
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
                        const SizedBox(height: 16),
                        if (newWeight != null && newWeight > 0)
                          _buildRealTimeResultPanel(newWeight, latestRecord),
                        const SizedBox(height: 20),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppColors.primaryGreen,
                                      onPrimary: Colors.white,
                                      onSurface: AppColors.textPrimary,
                                    ),
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() => selectedDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.calendar, color: AppColors.primaryGreen, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Fecha del Registro',
                                        style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        _formatDate(selectedDate),
                                        style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreen),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(LucideIcons.chevronRight, color: AppColors.textSecondary, size: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '¿Registras un peso de días anteriores? Cámbialo aquí.',
                            style: AppTextStyles.caption.copyWith(fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: obsController,
                          maxLines: 1,
                          style: AppTextStyles.bodyBold,
                          decoration: InputDecoration(
                            labelText: 'Observación (Opcional)',
                            labelStyle: AppTextStyles.caption,
                            prefixIcon: const Icon(LucideIcons.clipboard, size: 20, color: AppColors.primaryGreen),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              'Pos-destete',
                              'Inicio engorde',
                              'Pos-enfermedad',
                              'Control rutinario',
                              'Pre-venta',
                            ].map((chip) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ActionChip(
                                label: Text(
                                  chip,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: AppColors.greenSurface,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                onPressed: () {
                                  setState(() {
                                    obsController.text = chip;
                                  });
                                },
                              ),
                            )).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (isSaving || newWeight == null || newWeight <= 0)
                        ? null
                        : () => _handleSave(newWeight),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      disabledBackgroundColor: AppColors.primaryGreen.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Guardar peso',
                            style: AppTextStyles.bodyBold.copyWith(color: Colors.white, fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (showSuccessCheck)
            Container(
              color: Colors.white.withOpacity(0.9),
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
                      'Peso registrado con éxito',
                      style: AppTextStyles.h2.copyWith(color: AppColors.primaryGreen),
                    ).animate().fadeIn(duration: 400.ms),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRealTimeResultPanel(double newWeight, WeightRecord? latestRecord) {
    if (latestRecord == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF90CAF9)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.info, color: Color(0xFF1E88E5), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Primer registro guardado. Registra el próximo en 15-30 días para ver la evolución.',
                style: AppTextStyles.bodyBold.copyWith(color: const Color(0xFF1565C0), fontSize: 13),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, duration: 300.ms);
    }

    double diff = newWeight - latestRecord.weightKg;
    final lastDate = DateTime.tryParse(latestRecord.date) ?? DateTime.now();
    int days = selectedDate.difference(lastDate).inDays;
    if (days <= 0) days = 1;

    double gdp = diff / days;

    if (gdp < 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.alertOrangeSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.alertOrange.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.trendingDown, color: AppColors.alertOrange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sin ganancia de peso — revisa alimentación',
                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.alertOrange, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (widget.isFromDetail) {
                    Navigator.pop(context);
                  }
                  widget.onNavigate?.call(2);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.alertOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ver plan de IA Nutrición',
                      style: AppTextStyles.bodyBold.copyWith(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    const Icon(LucideIcons.arrowRight, size: 14, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, duration: 300.ms);
    }

    double target = getTargetWeight(widget.animal.category);
    double remaining = target - newWeight;
    String projectionText = '';
    if (remaining <= 0) {
      projectionText = 'Objetivo de peso alcanzado para la categoría';
    } else if (gdp == 0) {
      projectionText = 'Peso estable (sin ganancia de peso)';
    } else {
      double daysToTarget = remaining / gdp;
      DateTime targetDate = DateTime.now().add(Duration(days: daysToTarget.round()));
      projectionText = 'Listo para venta en ~${daysToTarget.round()} días  (aprox. ${_formatDate(targetDate)})';
    }

    double avg = getCategoryAverageGdp(widget.animal.category);
    double compDiff = gdp - avg;
    String compText = '';
    if (compDiff > 0) {
      compText = 'Por encima del promedio para ${widget.animal.category} (+${compDiff.toStringAsFixed(1)} kg/día)';
    } else if (compDiff < 0) {
      compText = 'Por debajo del promedio para ${widget.animal.category} (${compDiff.toStringAsFixed(1)} kg/día)';
    } else {
      compText = 'Igual al promedio para ${widget.animal.category} (+0.0 kg/día)';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.greenSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResultRow(
            'GDP calculado:',
            '+${gdp.toStringAsFixed(1)} kg/día  ↑',
            LucideIcons.trendingUp,
            AppColors.primaryGreen,
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            'Proyección:',
            projectionText,
            LucideIcons.calendarClock,
            AppColors.textPrimary,
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            'Comparación:',
            compText,
            LucideIcons.gitCompare,
            AppColors.textSecondary,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, duration: 300.ms);
  }

  Widget _buildResultRow(String label, String value, IconData icon, Color valColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryGreen, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, fontSize: 13),
              children: [
                TextSpan(
                  text: '$label ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: valColor,
                    fontWeight: valColor == AppColors.primaryGreen ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSave(double weight) async {
    setState(() {
      isSaving = true;
    });

    final animalWeights = widget.provider.weightRecords
        .where((r) => r.animalId == widget.animal.id)
        .toList();
    animalWeights.sort((a, b) => b.date.compareTo(a.date));

    double gdpValue = 0.0;
    if (animalWeights.isNotEmpty) {
      final latest = animalWeights.first;
      final lastDate = DateTime.tryParse(latest.date) ?? DateTime.now();
      int days = selectedDate.difference(lastDate).inDays;
      if (days <= 0) days = 1;
      gdpValue = (weight - latest.weightKg) / days;
    }

    String gdpText = gdpValue >= 0 
        ? '+${gdpValue.toStringAsFixed(1)} kg/día' 
        : '${gdpValue.toStringAsFixed(1)} kg/día';

    await widget.provider.addWeightRecord(
      animalId: widget.animal.id,
      weightKg: weight,
      date: selectedDate.toIso8601String(),
    );

    setState(() {
      showSuccessCheck = true;
    });

    await Future.delayed(const Duration(milliseconds: 1100));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Peso registrado — GDP: $gdpText',
            style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

class _DairyProductionSection extends StatefulWidget {
  final Animal animal;
  final DataProvider provider;
  final Function(int)? onNavigate;

  const _DairyProductionSection({
    required this.animal,
    required this.provider,
    this.onNavigate,
  });

  @override
  State<_DairyProductionSection> createState() => _DairyProductionSectionState();
}

class _DairyProductionSectionState extends State<_DairyProductionSection> {
  int? selectedBarIndex;

  String _formatDate(DateTime date) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final animal = widget.animal;

    // Filtrar todos los registros de producción del animal
    final animalProds = provider.productionRecords
        .where((r) => r.animalId == animal.id)
        .toList();
    // Ordenar por fecha descendente
    animalProds.sort((a, b) => b.date.compareTo(a.date));

    // 1. Hoy litros
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final todayRecords = animalProds.where((r) => r.date.startsWith(todayStr)).toList();
    double todayLiters = todayRecords.fold(0.0, (sum, r) => sum + r.liters);

    // 2. Promedio 7 días
    double sum7Days = 0.0;
    int active7Days = 0;
    for (int i = 1; i <= 7; i++) {
      final dateStr = DateTime.now().subtract(Duration(days: i)).toIso8601String().split('T')[0];
      final daySum = animalProds
          .where((r) => r.date.startsWith(dateStr))
          .fold(0.0, (sum, r) => sum + r.liters);
      if (daySum > 0) {
        sum7Days += daySum;
        active7Days++;
      }
    }
    double avg7Days = active7Days > 0 ? sum7Days / active7Days : 12.1;

    // 3. Tendencia vs semana pasada
    double sumPrev7Days = 0.0;
    int prevActive7Days = 0;
    for (int i = 8; i <= 14; i++) {
      final dateStr = DateTime.now().subtract(Duration(days: i)).toIso8601String().split('T')[0];
      final daySum = animalProds
          .where((r) => r.date.startsWith(dateStr))
          .fold(0.0, (sum, r) => sum + r.liters);
      if (daySum > 0) {
        sumPrev7Days += daySum;
        prevActive7Days++;
      }
    }
    double avgPrev7Days = prevActive7Days > 0 ? sumPrev7Days / prevActive7Days : 11.8;

    double trendPercent = 0.0;
    if (avgPrev7Days > 0) {
      trendPercent = ((avg7Days - avgPrev7Days) / avgPrev7Days) * 100;
    }

    // Alerta de caída de producción (> 15% vs promedio 7d)
    bool showDropAlert = todayLiters > 0 && avg7Days > 0 && todayLiters < (avg7Days * 0.85);

    // Preparar datos de 14 días para el gráfico
    List<({DateTime date, double morning, double afternoon, double total})> chartData = [];
    double maxTotal = 15.0; // mínimo para escalar
    double sum14Days = 0.0;
    int active14Days = 0;

    for (int i = 13; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final dateStr = day.toIso8601String().split('T')[0];

      final dayRecords = animalProds.where((r) => r.date.startsWith(dateStr)).toList();
      double morning = dayRecords.where((r) => r.turn == 'Mañana').fold(0.0, (sum, r) => sum + r.liters);
      double afternoon = dayRecords.where((r) => r.turn == 'Tarde').fold(0.0, (sum, r) => sum + r.liters);
      double other = dayRecords.where((r) => r.turn != 'Mañana' && r.turn != 'Tarde').fold(0.0, (sum, r) => sum + r.liters);

      double total = morning + afternoon + other;
      if (total > maxTotal) maxTotal = total;
      
      chartData.add((
        date: day,
        morning: morning + other, // Apilar "otros" en la base
        afternoon: afternoon,
        total: total,
      ));

      if (total > 0) {
        sum14Days += total;
        active14Days++;
      }
    }

    double avg14Days = active14Days > 0 ? sum14Days / active14Days : avg7Days;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Producción de Leche', style: AppTextStyles.h3),
            ElevatedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) {
                    return ProductionRegisterSheet(
                      animal: animal,
                      onNavigate: widget.onNavigate,
                    );
                  },
                );
              },
              icon: const Icon(LucideIcons.plus, size: 14, color: Colors.white),
              label: Text(
                'Registrar ordeño',
                style: AppTextStyles.bodyBold.copyWith(color: Colors.white, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tarjetas métricas
        Row(
          children: [
            _buildSummaryMetric(
              'Hoy',
              todayLiters > 0 ? '${todayLiters.toStringAsFixed(1)} L' : 'Sin registro',
              valueColor: todayLiters > 0 ? AppColors.primaryGreen : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            _buildSummaryMetric(
              'Promedio 7d',
              '${avg7Days.toStringAsFixed(1)} L/día',
            ),
            const SizedBox(width: 8),
            _buildSummaryMetric(
              'Tendencia',
              trendPercent == 0
                  ? 'Estable'
                  : '${trendPercent > 0 ? '↑' : '↓'} ${trendPercent.abs().toStringAsFixed(0)}%',
              sub: 'vs sem pasada',
              valueColor: trendPercent >= 0 ? AppColors.primaryGreen : AppColors.alertOrange,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Alerta de caída de producción
        if (showDropAlert) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.alertOrangeSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.alertOrange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.alertTriangle, color: AppColors.alertOrange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Caída en producción detectada (${((todayLiters - avg7Days) / avg7Days * 100).toStringAsFixed(0)}%) — puede indicar estrés, mastitis o cambio en alimentación.',
                        style: AppTextStyles.bodyBold.copyWith(color: AppColors.alertOrange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Cerrar modal de detalle
                      widget.onNavigate?.call(3); // Ir a tab veterinario
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.alertOrange,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      '¿Ver alertas de salud? →',
                      style: AppTextStyles.bodyBold.copyWith(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Gráfico de barras apiladas
        Container(
          height: 180,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = constraints.maxWidth;
              return Stack(
                children: [
                  // Línea de promedio 14d punteada
                  if (avg14Days > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 30 + (avg14Days / maxTotal) * 110.0,
                      child: Row(
                        children: [
                          Expanded(
                            child: CustomPaint(
                              size: const Size(double.infinity, 1),
                              painter: _DashedLinePainter(color: AppColors.primaryGreen.withOpacity(0.5)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Prom: ${avg14Days.toStringAsFixed(1)} L',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 9, 
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Barras
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    top: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(chartData.length, (index) {
                        final data = chartData[index];
                        final isSelected = selectedBarIndex == index;

                        final totalHeight = 110.0;
                        final double barHeight = data.total > 0
                            ? (data.total / maxTotal) * totalHeight
                            : 4.0; // Altura mínima para días sin registros

                        final double morningHeight = data.morning > 0
                            ? (data.morning / maxTotal) * totalHeight
                            : 0.0;

                        final double afternoonHeight = data.afternoon > 0
                            ? (data.afternoon / maxTotal) * totalHeight
                            : 0.0;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selectedBarIndex == index) {
                                selectedBarIndex = null;
                              } else {
                                selectedBarIndex = index;
                              }
                            });
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: 14,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: data.total > 0
                                      ? Colors.transparent
                                      : AppColors.border,
                                  borderRadius: BorderRadius.circular(3),
                                  border: isSelected 
                                      ? Border.all(color: AppColors.textPrimary, width: 1.5)
                                      : null,
                                ),
                                child: data.total > 0
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (afternoonHeight > 0)
                                            Container(
                                              width: 14,
                                              height: afternoonHeight,
                                              decoration: const BoxDecoration(
                                                color: AppColors.primaryGreenDark,
                                                borderRadius: BorderRadius.only(
                                                  topLeft: Radius.circular(3),
                                                  topRight: Radius.circular(3),
                                                ),
                                              ),
                                            ),
                                          if (morningHeight > 0)
                                            Container(
                                              width: 14,
                                              height: morningHeight,
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryGreenLight,
                                                borderRadius: BorderRadius.only(
                                                  bottomLeft: const Radius.circular(3),
                                                  bottomRight: const Radius.circular(3),
                                                  topLeft: afternoonHeight == 0 ? const Radius.circular(3) : Radius.zero,
                                                  topRight: afternoonHeight == 0 ? const Radius.circular(3) : Radius.zero,
                                                ),
                                              ),
                                            ),
                                        ],
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${data.date.day}',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 9,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),

                  // Tooltip
                  if (selectedBarIndex != null)
                    _buildTooltip(chartData[selectedBarIndex!], chartWidth),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Lista de registros recientes (últimos 7)
        Text('Historial Reciente (Leche)', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (animalProds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('Sin registros de ordeño previos', style: AppTextStyles.caption),
            ),
          )
        else
          ...List.generate(
            animalProds.length.clamp(0, 7),
            (index) {
              final record = animalProds[index];
              String varText = 'Estable';
              Color varColor = AppColors.textSecondary;

              if (index + 1 < animalProds.length) {
                final prev = animalProds[index + 1];
                if (prev.liters > 0) {
                  final diff = ((record.liters - prev.liters) / prev.liters) * 100;
                  varText = '${diff >= 0 ? '↑ +' : '↓ '}${diff.toStringAsFixed(1)}%';
                  varColor = diff >= 0 ? AppColors.primaryGreen : AppColors.alertOrange;
                }
              }

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.milk, size: 14, color: AppColors.primaryGreen),
                        const SizedBox(width: 8),
                        Text(
                          record.date.split('T')[0],
                          style: AppTextStyles.body.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${record.turn ?? 'Total'})',
                          style: AppTextStyles.caption.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '${record.liters.toStringAsFixed(1)} L',
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: AppColors.primaryGreenDark),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: varColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            varText,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              color: varColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSummaryMetric(String label, String value, {String? sub, Color? valueColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.bodyBold.copyWith(
                fontSize: 14,
                color: valueColor ?? AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub, style: AppTextStyles.caption.copyWith(fontSize: 8)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTooltip(
    ({DateTime date, double morning, double afternoon, double total}) data,
    double chartWidth,
  ) {
    final step = chartWidth / 14;
    double leftOffset = selectedBarIndex! * step;

    if (leftOffset > chartWidth - 110) {
      leftOffset = chartWidth - 110;
    }

    return Positioned(
      top: 0,
      left: leftOffset,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDate(data.date),
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              'Total: ${data.total.toStringAsFixed(1)} L',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            if (data.total > 0) ...[
              Text(
                'M: ${data.morning.toStringAsFixed(1)} L · T: ${data.afternoon.toStringAsFixed(1)} L',
                style: const TextStyle(color: Colors.white70, fontSize: 8),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 150.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), duration: 150.ms);
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0.0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
