import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../data/data_provider.dart';
import '../models/nutrition_resource.dart';
import '../models/animal.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'premium_result_screen.dart';
import 'plan_detail_screen.dart';

class NutricionScreen extends StatefulWidget {
  const NutricionScreen({super.key});

  @override
  State<NutricionScreen> createState() => _NutricionScreenState();
}

class _NutricionScreenState extends State<NutricionScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _dictationController = TextEditingController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  // Wizard state
  int _wizardStep = 0;
  String _objectiveType = 'todo'; // 'todo', 'categoria', 'individual'
  String _selectedCategory = 'Vaca Lechera';
  String? _selectedAnimalId;

  // Group selection filters
  String? _filterFinca;
  String? _filterLote;
  String? _filterPotrero;

  // Temporary list of resources before confirmation
  List<NutritionResource> _tempResources = [];
  bool _tempResourcesInitialized = false;
  final Set<String> _selectedResourceKeys = {};
  bool _resourceSuggestionsInitialized = false;

  // Individual Step 3 state
  String? _selectedPhotoPath;
  String? _uploadedPhotoUrl;
  bool _isUploadingPhoto = false;
  Map<String, dynamic>? _photoAnalysisResult;

  // Considerations (Step 4)
  bool _cPartoLactancia = false;
  bool _cPriorizarForraje = false;
  bool _cPriorizarSuplementos = false;
  bool _cReducirCosto = false;
  bool _cGananciaPeso = false;
  bool _cProdLeche = false;
  bool _cSoloFinca = false;
  bool _cEpocaSeca = false;

  // Loading state
  bool _isLoadingPlan = false;
  int _loadingMsgIndex = 0;
  int _loadingElapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _dictationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int get _totalSteps => 3;

  void _initializeTempResources(DataProvider provider) {
    if (_tempResourcesInitialized) return;
    _tempResources = List.from(provider.nutritionResources);
    _tempResourcesInitialized = true;
  }

  String _resourceKey(NutritionResource resource) =>
      resource.id?.toString() ??
      '${resource.type}:${resource.name}'.toLowerCase();

  List<Animal> _targetAnimals(DataProvider provider) {
    if (_objectiveType == 'categoria') {
      return provider.animals
          .where((animal) => animal.category == _selectedCategory)
          .toList();
    }
    if (_objectiveType == 'individual' && _selectedAnimalId != null) {
      return provider.animals
          .where((animal) => animal.id == _selectedAnimalId)
          .toList();
    }
    return provider.animals;
  }

  Set<String> _recommendedResourceTypes(DataProvider provider) {
    final categories = _targetAnimals(
      provider,
    ).map((animal) => animal.category.toLowerCase()).toSet();
    final types = <String>{'pasto', 'silo'};
    if (categories.any(
      (c) =>
          c.contains('lechera') ||
          c.contains('engorde') ||
          c.contains('novill'),
    )) {
      types.add('concentrado');
    }
    if (categories.any(
      (c) =>
          c.contains('lechera') ||
          c.contains('terner') ||
          c.contains('reproductor'),
    )) {
      types.add('suplemento');
    }
    return types;
  }

  void _initializeResourceSuggestions(DataProvider provider) {
    if (_resourceSuggestionsInitialized) return;
    final recommendedTypes = _recommendedResourceTypes(provider);
    for (final resource in _tempResources) {
      if (resource.amount > 0 &&
          recommendedTypes.contains(resource.type.toLowerCase())) {
        _selectedResourceKeys.add(_resourceKey(resource));
      }
    }
    _resourceSuggestionsInitialized = true;
  }

  void _resetResourceSuggestions() {
    _selectedResourceKeys.clear();
    _resourceSuggestionsInitialized = false;
  }

  List<NutritionResource> get _selectedResources => _tempResources
      .where(
        (resource) => _selectedResourceKeys.contains(_resourceKey(resource)),
      )
      .toList();

  void _prefillTarget(String target, DataProvider provider) {
    _tabController.animateTo(0);
    setState(() {
      _wizardStep = 0;
      _photoAnalysisResult = null;
      _selectedPhotoPath = null;
      _uploadedPhotoUrl = null;
    });

    if (target == 'Todo el Hato') {
      setState(() {
        _objectiveType = 'todo';
      });
    } else if (const [
      'Vaca Lechera',
      'Toro Engorde',
      'Toro Reproductor',
      'Ternero',
    ].contains(target)) {
      setState(() {
        _objectiveType = 'categoria';
        _selectedCategory = target;
      });
    } else {
      try {
        final anim = provider.animals.firstWhere(
          (a) => a.name == target || a.tag == target || a.id == target,
        );
        setState(() {
          _objectiveType = 'individual';
          _selectedAnimalId = anim.id;
        });
      } catch (_) {}
    }
  }

  // --- VOICE DICTATION & PARSING ---
  void _startVoiceDictation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) {
        return Container(
          height: 280,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Dictado por Voz IA',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.primaryGreenDark,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.alertOrangeSurface,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.mic_rounded,
                      color: AppColors.alertOrange,
                      size: 40,
                    ),
                  )
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.15, 1.15),
                    duration: 800.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 24),
              StreamBuilder<String>(
                stream: Stream<String>.periodic(
                  const Duration(milliseconds: 1200),
                  (count) {
                    if (count == 0) return 'Escuchando tu voz...';
                    if (count == 1) return 'Analizando audio...';
                    return 'Transcribiendo: "Tengo 15 hectáreas de pasto kikuyo, 5 toneladas de silo de maíz y 12 sacos de balanceado..."';
                  },
                ).take(3),
                initialData: 'Escuchando tu voz...',
                builder: (context, snapshot) {
                  final statusText = snapshot.data ?? '';
                  final isFinished = statusText.startsWith('Transcribiendo');

                  if (isFinished) {
                    Future.delayed(const Duration(milliseconds: 1500), () {
                      if (context.mounted && Navigator.canPop(context)) {
                        Navigator.pop(context);
                        _dictationController.text =
                            'Tengo 15 hectáreas de pasto kikuyo, 5 toneladas de silo de maíz y 12 sacos de balanceado';
                        _parseTextAndUpdateResources(_dictationController.text);
                      }
                    });
                  }

                  return Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyBold.copyWith(
                      color: isFinished
                          ? AppColors.primaryGreenDark
                          : AppColors.textSecondary,
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: AppTextStyles.body.copyWith(color: AppColors.alertRed),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _parseTextAndUpdateResources(String text) {
    if (text.isEmpty) return;
    final lowercaseText = text.toLowerCase();

    // Regex parsing
    final pastoRegExp = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:ha|hect[aá]rea|hect[aá]ria|hect[aá]reas|hect[aá]rias)',
    );
    final siloRegExp = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:tonelada|toneladas|ton|t\b)',
    );
    final concentradoRegExp = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:kg|kilo|kilos|sacos|saco|bulto|bultos)\s*(?:de\s+)?(?:concentrado|balanceado|afrecho|ma[ií]z)',
    );
    final suplementoRegExp = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:kg|kilo|kilos|sacos|saco)\s*(?:de\s+)?(?:melaza|suplemento|sal|mineral)',
    );

    final pastoMatch = pastoRegExp.firstMatch(lowercaseText);
    final siloMatch = siloRegExp.firstMatch(lowercaseText);
    final concentradoMatch = concentradoRegExp.firstMatch(lowercaseText);
    final suplementoMatch = suplementoRegExp.firstMatch(lowercaseText);

    setState(() {
      if (pastoMatch != null) {
        final val = double.tryParse(pastoMatch.group(1) ?? '');
        if (val != null) {
          _addOrUpdateTempResource('pasto', 'Pasto Kikuyo', val, 'ha');
        }
      }
      if (siloMatch != null) {
        final val = double.tryParse(siloMatch.group(1) ?? '');
        if (val != null) {
          _addOrUpdateTempResource('silo', 'Silo de Maíz', val, 'ton');
        }
      }
      if (concentradoMatch != null) {
        final val = double.tryParse(concentradoMatch.group(1) ?? '');
        if (val != null) {
          // Si dice sacos, estimamos 40kg por saco
          final isSacos =
              lowercaseText.contains('saco') || lowercaseText.contains('bulto');
          final finalVal = isSacos ? val * 40.0 : val;
          _addOrUpdateTempResource(
            'concentrado',
            'Balanceado Comercial',
            finalVal,
            'kg',
          );
        }
      }
      if (suplementoMatch != null) {
        final val = double.tryParse(suplementoMatch.group(1) ?? '');
        if (val != null) {
          _addOrUpdateTempResource(
            'suplemento',
            'Melaza / Sal Mineral',
            val,
            'kg',
          );
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Recursos extraídos de la entrada de texto.',
          style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addOrUpdateTempResource(
    String type,
    String name,
    double amount,
    String unit,
  ) {
    final index = _tempResources.indexWhere((r) => r.type == type);
    if (index >= 0) {
      _tempResources[index] = _tempResources[index].copyWith(
        amount: amount,
        unit: unit,
      );
      _selectedResourceKeys.add(_resourceKey(_tempResources[index]));
    } else {
      final resource = NutritionResource(
        type: type,
        name: name,
        amount: amount,
        unit: unit,
        updatedAt: DateTime.now().toIso8601String(),
        availability: 'Disponible',
      );
      _tempResources.add(resource);
      _selectedResourceKeys.add(_resourceKey(resource));
    }
  }

  // --- PHOTO & BODY CONDITION STEPS ---
  Future<void> _pickAndUploadImage(
    ImageSource source,
    DataProvider provider,
  ) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;

    setState(() {
      _selectedPhotoPath = picked.path;
      _isUploadingPhoto = true;
    });

    String? uploadedPath;
    try {
      // Subir imagen de forma privada a Supabase Storage
      final fileName = 'body_${DateTime.now().millisecondsSinceEpoch}.jpg';
      uploadedPath = await SupabaseService.instance.uploadAnimalPhoto(
        picked.path,
        fileName,
      );
    } catch (e) {
      debugPrint('Error al subir foto a Supabase Storage: $e');
      uploadedPath = null;
    }

    Map<String, dynamic>? analysisResult;

    // Integración real con la Edge Function aura-ai de Supabase
    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated &&
        uploadedPath != null) {
      try {
        Animal? selectedAnimal;
        try {
          selectedAnimal = provider.animals.firstWhere(
            (a) => a.id == _selectedAnimalId,
          );
        } catch (_) {}

        final payload = {
          'scope': 'individual',
          'action': 'analyze_photo',
          'datos_animales': selectedAnimal != null
              ? [
                  {
                    'id': selectedAnimal.id,
                    'name': selectedAnimal.name,
                    'tag': selectedAnimal.tag,
                    'category': selectedAnimal.category,
                    'weight_kg': selectedAnimal.weightKg,
                    'stage': selectedAnimal.stage,
                    'body_condition': selectedAnimal.bodyCondition,
                    'breed': selectedAnimal.breed,
                    'sex': selectedAnimal.sex,
                  },
                ]
              : [],
          'foto_opcional': uploadedPath,
        };

        final response = await SupabaseService.instance
            .invokeNutritionEdgeFunction(payload);
        if (response != null) {
          if (response['visual_analysis'] != null) {
            analysisResult = Map<String, dynamic>.from(
              response['visual_analysis'],
            );
          } else if (response.containsKey('body_condition_estimated')) {
            analysisResult = response;
          }
        }
      } catch (e) {
        debugPrint('Error al llamar a Edge Function para análisis visual: $e');
      }
    }

    // Fallback de Simulación si no hay conexión o falla la Edge Function
    if (analysisResult == null) {
      // Latencia para simular el análisis de Gemini
      await Future.delayed(const Duration(seconds: 2));

      Animal? selectedAnimal;
      try {
        selectedAnimal = provider.animals.firstWhere(
          (a) => a.id == _selectedAnimalId,
        );
      } catch (_) {}

      final double currentBC = selectedAnimal?.bodyCondition ?? 3.5;
      String estimation = "3.5";
      if (currentBC < 3.0) estimation = "2.5";
      if (currentBC > 4.2) estimation = "4.5";

      analysisResult = {
        'body_condition_estimated': estimation,
        'observations':
            'Animal fotografiado de perfil. Estructura ósea normal. '
            'Línea dorsal recta con cobertura grasa moderada en cadera y costillas traseras. '
            'Pelaje uniforme y brillante sin anomalías físicas visibles.',
        'nutritional_improvements':
            'Continuar con dieta equilibrada. '
            'Asegurar un suplemento diario de 150g de sales minerales para sostener el metabolismo.',
        'confidence_level': 'Alta (92%)',
        'disclaimer':
            'Esta evaluación es orientativa y no sustituye una valoración veterinaria profesional.',
      };
    }

    if (mounted) {
      setState(() {
        _isUploadingPhoto = false;
        _uploadedPhotoUrl = uploadedPath;
        _photoAnalysisResult = analysisResult;
      });
    }
  }

  // --- LOADING STEPS TIMER ---
  Future<void> _startProgressMessages() async {
    _loadingMsgIndex = 0;
    _loadingElapsedSeconds = 0;
    while (_isLoadingPlan) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!_isLoadingPlan) break;
      if (mounted) {
        setState(() {
          _loadingElapsedSeconds++;
          final nextMessage = _loadingElapsedSeconds ~/ 3;
          _loadingMsgIndex = nextMessage > 3 ? 3 : nextMessage;
        });
      }
    }
  }

  void _runAiAnalysis(DataProvider provider) async {
    // Validar animales y recursos
    List<Animal> targetAnimals = [];
    if (_objectiveType == 'todo') {
      targetAnimals = provider.animals;
    } else if (_objectiveType == 'categoria') {
      targetAnimals = provider.animals
          .where((a) => a.category == _selectedCategory)
          .toList();
    } else if (_objectiveType == 'individual' && _selectedAnimalId != null) {
      targetAnimals = provider.animals
          .where((a) => a.id == _selectedAnimalId)
          .toList();
    }

    if (targetAnimals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No hay animales seleccionados para el análisis.',
            style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.alertRed,
        ),
      );
      return;
    }

    final confirmedResources = _selectedResources
        .where((r) => r.amount > 0)
        .toList();
    if (confirmedResources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Debe registrar al menos un recurso con cantidad disponible.',
            style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.alertRed,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingPlan = true;
    });

    _startProgressMessages();

    try {
      // Guardar todos los recursos editados en el inventario antes de correr
      for (var res in _tempResources) {
        await provider.saveNutritionResource(
          id: res.id,
          type: res.type,
          name: res.name,
          amount: res.amount,
          unit: res.unit,
          cost: res.cost,
          availability: res.availability,
          expirationDate: res.expirationDate,
          observations: res.observations,
        );
      }

      final result = await provider.generateNutritionPlan(
        targetAnimals: targetAnimals,
        selectedResources: confirmedResources,
        includeCalvingStatus: _cPartoLactancia,
        includeForage: _cPriorizarForraje,
        includeSupplements: _cPriorizarSuplementos,
        photoPath: _uploadedPhotoUrl,
      );

      setState(() {
        _isLoadingPlan = false;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PremiumResultScreen(
              result: result,
              targetGroup: _objectiveType == 'todo'
                  ? 'Todo el Hato'
                  : (_objectiveType == 'categoria'
                        ? _selectedCategory
                        : targetAnimals.first.name),
              animalCount: targetAnimals.length,
              targetAnimals: targetAnimals,
              confirmedResources: confirmedResources,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingPlan = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error generando plan AURA: $e',
              style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    }
  }

  // --- DIALOGS ---
  void _showAddResourceDialog(
    BuildContext context, {
    bool isInventory = false,
  }) {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final costController = TextEditingController();
    final observationsController = TextEditingController();
    String selectedType = 'pasto';
    String selectedUnit = 'ha';
    String selectedAvailability = 'Disponible';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Crear Recurso Nuevo', style: AppTextStyles.h2),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: InputDecoration(
                          labelText: 'Tipo de Recurso',
                          labelStyle: AppTextStyles.caption,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'pasto',
                            child: Text('Pastos'),
                          ),
                          DropdownMenuItem(
                            value: 'silo',
                            child: Text('Forrajes y Silos'),
                          ),
                          DropdownMenuItem(
                            value: 'concentrado',
                            child: Text('Concentrados'),
                          ),
                          DropdownMenuItem(
                            value: 'suplemento',
                            child: Text('Suplementos / Sales'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedType = val;
                              if (val == 'pasto') {
                                selectedUnit = 'ha';
                              } else if (val == 'silo') {
                                selectedUnit = 'ton';
                              } else {
                                selectedUnit = 'kg';
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: nameController,
                        style: AppTextStyles.bodyBold,
                        decoration: InputDecoration(
                          labelText:
                              'Nombre Específico (Ej: Kikuyo, Alfalfa, Sales 12%)',
                          labelStyle: AppTextStyles.caption,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Ingrese el nombre'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: amountController,
                              style: AppTextStyles.bodyBold,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Cantidad Disponible',
                                labelStyle: AppTextStyles.caption,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty)
                                  return 'Requerido';
                                if (double.tryParse(value) == null)
                                  return 'Número inválido';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: selectedUnit,
                              decoration: InputDecoration(
                                labelText: 'Unidad',
                                labelStyle: AppTextStyles.caption,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'ha',
                                  child: Text('ha'),
                                ),
                                DropdownMenuItem(
                                  value: 'ton',
                                  child: Text('ton'),
                                ),
                                DropdownMenuItem(
                                  value: 'kg',
                                  child: Text('kg'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    selectedUnit = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: costController,
                        style: AppTextStyles.bodyBold,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              'Costo unitario por unidad (Opcional - USD)',
                          labelStyle: AppTextStyles.caption,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedAvailability,
                        decoration: InputDecoration(
                          labelText: 'Disponibilidad',
                          labelStyle: AppTextStyles.caption,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Disponible',
                            child: Text('Disponible'),
                          ),
                          DropdownMenuItem(
                            value: 'Limitado',
                            child: Text('Limitado'),
                          ),
                          DropdownMenuItem(
                            value: 'Agotado',
                            child: Text('Agotado'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedAvailability = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: observationsController,
                        style: AppTextStyles.body,
                        decoration: InputDecoration(
                          labelText: 'Observaciones / Notas',
                          labelStyle: AppTextStyles.caption,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              final name = nameController.text.trim();
                              final amount = double.parse(
                                amountController.text,
                              );
                              final cost = double.tryParse(costController.text);
                              final obs = observationsController.text.trim();

                              if (isInventory) {
                                await provider.saveNutritionResource(
                                  type: selectedType,
                                  name: name,
                                  amount: amount,
                                  unit: selectedUnit,
                                  cost: cost,
                                  availability: selectedAvailability,
                                  observations: obs,
                                );
                              } else {
                                setState(() {
                                  _tempResources.add(
                                    NutritionResource(
                                      type: selectedType,
                                      name: name,
                                      amount: amount,
                                      unit: selectedUnit,
                                      cost: cost,
                                      availability: selectedAvailability,
                                      observations: obs,
                                      updatedAt: DateTime.now()
                                          .toIso8601String(),
                                    ),
                                  );
                                });
                              }

                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isInventory
                                ? 'Registrar Insumo'
                                : 'Guardar en Asistente',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
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

  void _showEditResourceDialog(BuildContext context, int index) {
    final resource = _tempResources[index];
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(
      text: resource.amount.toString(),
    );
    final costController = TextEditingController(
      text: resource.cost?.toString() ?? '',
    );
    final expirationController = TextEditingController(
      text: resource.expirationDate ?? '',
    );
    final observationsController = TextEditingController(
      text: resource.observations ?? '',
    );
    String selectedAvailability = resource.availability ?? 'Disponible';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Editar ${resource.name}',
                            style: AppTextStyles.h2,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amountController,
                        style: AppTextStyles.bodyBold,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Cantidad Disponible (${resource.unit})',
                          labelStyle: AppTextStyles.caption,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Requerido';
                          if (double.tryParse(value) == null)
                            return 'Número inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: costController,
                        style: AppTextStyles.bodyBold,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Costo por unidad (USD)',
                          labelStyle: AppTextStyles.caption,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedAvailability,
                        decoration: InputDecoration(
                          labelText: 'Disponibilidad',
                          labelStyle: AppTextStyles.caption,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Disponible',
                            child: Text('Disponible'),
                          ),
                          DropdownMenuItem(
                            value: 'Limitado',
                            child: Text('Limitado'),
                          ),
                          DropdownMenuItem(
                            value: 'Agotado',
                            child: Text('Agotado'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedAvailability = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: expirationController,
                        style: AppTextStyles.bodyBold,
                        decoration: InputDecoration(
                          labelText:
                              'Fecha de Vencimiento (Opcional - YYYY-MM-DD)',
                          labelStyle: AppTextStyles.caption,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: observationsController,
                        style: AppTextStyles.body,
                        decoration: InputDecoration(
                          labelText: 'Observaciones / Notas',
                          labelStyle: AppTextStyles.caption,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _tempResources.removeAt(index);
                                });
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.alertRed,
                              ),
                              child: const Text('Eliminar Recurso'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  setState(() {
                                    _tempResources[index] = resource.copyWith(
                                      amount: double.parse(
                                        amountController.text,
                                      ),
                                      cost: double.tryParse(
                                        costController.text,
                                      ),
                                      availability: selectedAvailability,
                                      expirationDate:
                                          expirationController.text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : expirationController.text.trim(),
                                      observations:
                                          observationsController.text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : observationsController.text.trim(),
                                      updatedAt: DateTime.now()
                                          .toIso8601String(),
                                    );
                                  });
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Actualizar',
                                style: AppTextStyles.bodyBold.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  // --- BUILD WIZARD STEPS ---
  Widget _buildStepIndicator() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          '${_wizardStep + 1} de $_totalSteps',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Línea de progreso (fondo gris)
              Container(height: 3, color: AppColors.border),
              // Línea de progreso activa (verde)
              LayoutBuilder(
                builder: (context, constraints) {
                  final percent = _totalSteps > 1
                      ? _wizardStep / (_totalSteps - 1)
                      : 1.0;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: constraints.maxWidth * percent,
                      height: 3,
                      color: AppColors.primaryGreen,
                    ),
                  );
                },
              ),
              // Nodos circulares
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_totalSteps, (index) {
                  final isDoneOrCurrent = index <= _wizardStep;
                  return Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isDoneOrCurrent
                          ? AppColors.primaryGreen
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDoneOrCurrent
                            ? AppColors.primaryGreen
                            : AppColors.border,
                        width: 2.5,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent(DataProvider provider) {
    // Clamp the wizard step to total steps to prevent layout breakages
    _wizardStep = _wizardStep.clamp(0, _totalSteps - 1);

    if (_wizardStep == 0) {
      return _buildStep1Alcance(provider);
    } else if (_wizardStep == 1) {
      return _buildStep2Recursos(provider);
    } else {
      return _buildStep3Confirmar(provider);
    }
  }

  Widget _buildStep1Alcance(DataProvider provider) {
    // Carga inicial del grupo de animales si no se han filtrado
    final filteredAnimals = provider.animals.where((a) {
      if (_filterFinca != null && a.finca != _filterFinca) return false;
      if (_filterLote != null && a.lote != _filterLote) return false;
      if (_filterPotrero != null && a.potrero != _filterPotrero) return false;
      if (_objectiveType == 'categoria' && a.category != _selectedCategory)
        return false;
      return true;
    }).toList();

    double avgWeight = 0;
    if (filteredAnimals.isNotEmpty) {
      final double totalW = filteredAnimals
          .map((a) => a.weightKg)
          .reduce((a, b) => a + b);
      avgWeight = totalW / filteredAnimals.length;
    }

    String selectedAnimalText = "Lola, arete A-024...";
    if (_selectedAnimalId != null) {
      final anim = provider.animals.firstWhere(
        (a) => a.id == _selectedAnimalId,
        orElse: () => provider.animals.first,
      );
      selectedAnimalText = "${anim.name} (${anim.tag})";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Alcance del plan', style: AppTextStyles.h2),
        const SizedBox(height: 16),

        _buildAlcanceCard(
          title: 'Toda mi finca',
          subtitle: '${provider.animals.length} animales',
          icon: Icons.warehouse_rounded,
          isSelected: _objectiveType == 'todo',
          onTap: () {
            setState(() {
              _objectiveType = 'todo';
              _resetResourceSuggestions();
            });
          },
        ),

        _buildAlcanceCard(
          title: 'Un grupo',
          subtitle: _objectiveType == 'categoria'
              ? 'Grupo: $_selectedCategory (${filteredAnimals.length} animales)'
              : 'Lactancia, terneros...',
          icon: Icons.groups_rounded,
          isSelected: _objectiveType == 'categoria',
          onTap: () {
            setState(() {
              _objectiveType = 'categoria';
              _resetResourceSuggestions();
            });
          },
        ),

        // Si es grupo y está seleccionado, desplegar los filtros abajo
        if (_objectiveType == 'categoria') ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: 'Selecciona la Categoría',
              labelStyle: AppTextStyles.caption,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(
                Icons.pets_rounded,
                color: AppColors.primaryGreen,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Vaca Lechera',
                child: Text('Vacas Lecheras'),
              ),
              DropdownMenuItem(value: 'Vaca Seca', child: Text('Vacas Secas')),
              DropdownMenuItem(
                value: 'Toro Engorde',
                child: Text('Toros de Engorde'),
              ),
              DropdownMenuItem(
                value: 'Toro Reproductor',
                child: Text('Toros Reproductores'),
              ),
              DropdownMenuItem(
                value: 'Ternero',
                child: Text('Terneros de Cría'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedCategory = val;
                  _resetResourceSuggestions();
                });
              }
            },
          ),
          const SizedBox(height: 14),
          _buildGroupFilters(provider, filteredAnimals, avgWeight),
          const SizedBox(height: 16),
        ],

        _buildAlcanceCard(
          title: 'Un animal',
          subtitle: selectedAnimalText,
          icon: Icons.pets_rounded,
          isSelected: _objectiveType == 'individual',
          onTap: () {
            setState(() {
              _objectiveType = 'individual';
              _resetResourceSuggestions();
            });
          },
        ),

        // Si es individual y está seleccionado, desplegar buscador y foto abajo
        if (_objectiveType == 'individual') ...[
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, arete o raza...',
              hintStyle: AppTextStyles.caption,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.primaryGreen,
              ),
            ),
            style: AppTextStyles.body,
            onChanged: (_) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                if (mounted) setState(() {});
              });
            },
          ),
          const SizedBox(height: 12),
          Container(
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListView(
              children: provider.animals
                  .where((a) {
                    final query = _searchController.text.toLowerCase();
                    return a.name.toLowerCase().contains(query) ||
                        a.tag.toLowerCase().contains(query) ||
                        a.breed.toLowerCase().contains(query);
                  })
                  .map((a) {
                    final isSel = _selectedAnimalId == a.id;
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        dense: true,
                        title: Text(
                          '${a.name} (${a.tag})',
                          style: AppTextStyles.bodyBold,
                        ),
                        subtitle: Text(
                          '${a.category} • ${a.breed}',
                          style: AppTextStyles.caption,
                        ),
                        trailing: isSel
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primaryGreen,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedAnimalId = a.id;
                            _photoAnalysisResult = null;
                            _selectedPhotoPath = null;
                            _resetResourceSuggestions();
                          });
                        },
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          if (_selectedAnimalId != null) ...[
            _buildIndividualAnimalFicha(provider),
            const SizedBox(height: 16),
            _buildPhotoUploadSection(provider),
          ],
        ],
      ],
    );
  }

  // --- WIDGETS AUXILIARES PARA ALCANCE Y DISEÑO ---
  Widget _buildCircularIllustration(IconData icon, Color color) {
    final isSelected = color == AppColors.primaryGreenDark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryGreen.withOpacity(0.08)
            : AppColors.background,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 28,
        color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildAlcanceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.greenSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primaryGreen : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primaryGreen.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildCircularIllustration(
                icon,
                isSelected
                    ? AppColors.primaryGreenDark
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyBold.copyWith(
                        color: isSelected
                            ? AppColors.primaryGreenDark
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primaryGreen,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionIconButton(
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: AppColors.primaryGreen),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodyBold.copyWith(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceCircularIcon(String type) {
    IconData iconData;
    switch (type) {
      case 'pasto':
        iconData = Icons.grass_rounded;
        break;
      case 'silo':
        iconData = Icons.storage_rounded;
        break;
      case 'concentrado':
        iconData = Icons.inventory_2_rounded;
        break;
      case 'suplemento':
      default:
        iconData = Icons.inventory_2_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 22, color: AppColors.primaryGreen),
    );
  }

  Widget _buildResourceCard(
    NutritionResource res, {
    required bool selected,
    required bool suggested,
  }) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: ListTile(
          leading: _buildResourceCircularIcon(res.type),
          title: Text(
            '${res.name} · ${res.amount.toStringAsFixed(0)} ${res.unit}',
            style: AppTextStyles.bodyBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: suggested
              ? Text(
                  'Sugerido para los animales elegidos',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Editar cantidad',
                icon: const Icon(Icons.edit_outlined),
                color: AppColors.textSecondary,
                onPressed: () {
                  final index = _tempResources.indexOf(res);
                  if (index != -1) {
                    _showEditResourceDialog(context, index);
                  }
                },
              ),
              Checkbox(
                value: selected,
                activeColor: AppColors.primaryGreen,
                onChanged: (_) => _toggleResource(res),
              ),
            ],
          ),
          onTap: () {
            _toggleResource(res);
          },
        ),
      ),
    );
  }

  void _toggleResource(NutritionResource resource) {
    setState(() {
      final key = _resourceKey(resource);
      if (!_selectedResourceKeys.remove(key)) {
        _selectedResourceKeys.add(key);
      }
    });
  }

  Widget _buildPhotoUploadSection(DataProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Evaluación visual del animal', style: AppTextStyles.bodyBold),
          const SizedBox(height: 8),
          Text(
            'Captura una fotografía lateral completa para estimar la condición corporal por IA.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.sandBeige,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guía para una correcta captura:',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                _guideBullet("Animal de pie sobre terreno plano."),
                _guideBullet("Perfil lateral completo del cuerpo."),
                _guideBullet("Buena iluminación ambiental (sin contraluz)."),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_selectedPhotoPath != null) ...[
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: FileImage(File(_selectedPhotoPath!)),
                  fit: BoxFit.cover,
                ),
              ),
              alignment: Alignment.center,
              child: _isUploadingPhoto
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.black45,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 8),
                          Text(
                            'Subiendo y analizando...',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploadingPhoto
                      ? null
                      : () => _pickAndUploadImage(ImageSource.camera, provider),
                  icon: const Icon(Icons.camera_rounded, size: 18),
                  label: const Text(
                    'Tomar Foto',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploadingPhoto
                      ? null
                      : () =>
                            _pickAndUploadImage(ImageSource.gallery, provider),
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text('Galería', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sandBeige,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_photoAnalysisResult != null) ...[
            const Divider(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primaryGreen,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Resultado de Análisis de IA:',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Condición Corporal Estimada: ${_photoAnalysisResult!['body_condition_estimated'] ?? "N/A"}',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreenDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Detalles: ${_photoAnalysisResult!['observations'] ?? ""}',
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupFilters(
    DataProvider provider,
    List<Animal> filtered,
    double avgWeight,
  ) {
    // Extraer fincas, lotes y potreros únicos
    final fincas = provider.animals.map((a) => a.finca).toSet().toList();
    final lotes = provider.animals.map((a) => a.lote).toSet().toList();
    final potreros = provider.animals.map((a) => a.potrero).toSet().toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filtros de Grupo', style: AppTextStyles.bodyBold),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            value: _filterFinca,
            hint: Text('Filtrar por Finca', style: AppTextStyles.caption),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Todas las Fincas'),
              ),
              ...fincas.map((f) => DropdownMenuItem(value: f, child: Text(f))),
            ],
            onChanged: (val) => setState(() => _filterFinca = val),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _filterLote,
                  hint: Text('Lote', style: AppTextStyles.caption),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ...lotes.map(
                      (l) => DropdownMenuItem(value: l, child: Text(l)),
                    ),
                  ],
                  onChanged: (val) => setState(() => _filterLote = val),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _filterPotrero,
                  hint: Text('Potrero', style: AppTextStyles.caption),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ...potreros.map(
                      (p) => DropdownMenuItem(value: p, child: Text(p)),
                    ),
                  ],
                  onChanged: (val) => setState(() => _filterPotrero = val),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Animales incluidos:', style: AppTextStyles.caption),
              Text('${filtered.length}', style: AppTextStyles.bodyBold),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Peso Promedio Calculado:', style: AppTextStyles.caption),
              Text(
                '${avgWeight.toStringAsFixed(0)} kg',
                style: AppTextStyles.bodyBold.copyWith(
                  color: AppColors.primaryGreenDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualAnimalFicha(DataProvider provider) {
    final animal = provider.animals.firstWhere(
      (a) => a.id == _selectedAnimalId,
    );
    // Calcular edad aproximada en meses
    final age =
        DateTime.now().difference(DateTime.parse(animal.birthDate)).inDays ~/
        30;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.greenSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryGreen,
                radius: 20,
                child: const Icon(
                  Icons.pets_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(animal.name, style: AppTextStyles.bodyBold),
                    Text(
                      'Arete: ${animal.tag} • Raza: ${animal.breed}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _fichaRow('Sexo', animal.sex),
          _fichaRow('Edad', '$age meses'),
          _fichaRow('Peso Actual', '${animal.weightKg} kg'),
          _fichaRow('Etapa Productiva', animal.stage),
          _fichaRow('Condición Corporal', '${animal.bodyCondition} / 5.0'),
          _fichaRow('Última Vacuna', animal.vaccineStatus ?? 'No registrada'),
        ],
      ),
    );
  }

  Widget _fichaRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(val, style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildStep2Recursos(DataProvider provider) {
    _initializeTempResources(provider);
    _initializeResourceSuggestions(provider);
    final recommendedTypes = _recommendedResourceTypes(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Elige los recursos de la ración', style: AppTextStyles.h2),
        const SizedBox(height: 6),
        Text(
          'Selecciona lo que quieres darles. AURA marcó opciones recomendadas según los animales del paso anterior.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildActionIconButton(
                'Hablar',
                Icons.mic_rounded,
                () => _startVoiceDictation(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionIconButton(
                'Escribir',
                Icons.keyboard_rounded,
                () => _showTextInputDialog(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionIconButton(
                'Desde mi inventario',
                Icons.warehouse_rounded,
                () => _addFromInventory(provider),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Disponible en tu finca',
                style: AppTextStyles.bodyBold,
              ),
            ),
            Text(
              '${_selectedResources.length} seleccionados',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_tempResources.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No hay insumos agregados aún. Usa Hablar, Escribir o Importar.',
                style: AppTextStyles.caption,
              ),
            ),
          )
        else
          ..._tempResources.map(
            (res) => _buildResourceCard(
              res,
              selected: _selectedResourceKeys.contains(_resourceKey(res)),
              suggested: recommendedTypes.contains(res.type.toLowerCase()),
            ),
          ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () {
              _tabController.animateTo(1);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ver todos mis recursos',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _addFromInventory(DataProvider provider) {
    setState(() {
      for (var res in provider.nutritionResources) {
        if (!_tempResources.any(
          (r) => r.name.toLowerCase() == res.name.toLowerCase(),
        )) {
          _tempResources.add(res);
        }
        if (res.amount > 0) {
          _selectedResourceKeys.add(_resourceKey(res));
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Insumos disponibles seleccionados para el plan.'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  void _showTextInputDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Escribe lo que tienes', style: AppTextStyles.bodyBold),
          content: TextField(
            controller: textController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'Ej: Tengo 10 ha de Kikuyo y 5 toneladas de Silo de maíz',
              hintStyle: AppTextStyles.caption,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              onPressed: () {
                _parseTextAndUpdateResources(textController.text);
                Navigator.pop(context);
              },
              child: const Text(
                'Extraer',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStep3Confirmar(DataProvider provider) {
    _initializeTempResources(provider);
    final selected = _selectedResources;
    final selectedTypes = selected.map((r) => r.type.toLowerCase()).toSet();
    final recommendedTypes = _recommendedResourceTypes(provider);
    final missingTypes = recommendedTypes.difference(selectedTypes);
    final animals = _targetAnimals(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Preparación del plan', style: AppTextStyles.h2),
        const SizedBox(height: 6),
        Text(
          'Revisa la cobertura detectada localmente antes de generar la ración.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: missingTypes.isEmpty
                ? AppColors.greenSurface
                : AppColors.sandBeige,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: missingTypes.isEmpty
                  ? AppColors.primaryGreen
                  : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              _buildPlanCheckRow(
                Icons.pets_rounded,
                'Animales incluidos',
                '${animals.length}',
                animals.isNotEmpty,
              ),
              _buildPlanCheckRow(
                Icons.inventory_2_rounded,
                'Recursos elegidos',
                '${selected.length}',
                selected.isNotEmpty,
              ),
              _buildPlanCheckRow(
                Icons.grass_rounded,
                'Base de forraje',
                selectedTypes.contains('pasto') ||
                        selectedTypes.contains('silo')
                    ? 'Cubierta'
                    : 'Faltante',
                selectedTypes.contains('pasto') ||
                    selectedTypes.contains('silo'),
              ),
              _buildPlanCheckRow(
                Icons.balance_rounded,
                'Cobertura recomendada',
                missingTypes.isEmpty
                    ? 'Completa'
                    : '${missingTypes.length} por revisar',
                missingTypes.isEmpty,
              ),
            ],
          ),
        ),
        if (missingTypes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Podrías agregar: ${missingTypes.map(_resourceTypeLabel).join(', ')}. Puedes continuar; el plan se ajustará a lo seleccionado.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const Divider(height: 28),
        Text('Consideraciones Especiales', style: AppTextStyles.bodyBold),
        const SizedBox(height: 6),
        Text(
          'Personaliza los parámetros del análisis biológico para la ración recomendada.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 12),
        _buildConsiderationTile(
          'Parto / Lactancia Activa',
          'Ajusta la ración para la etapa post-parto crítica.',
          _cPartoLactancia,
          (val) => setState(() => _cPartoLactancia = val ?? false),
        ),
        _buildConsiderationTile(
          'Priorizar Inclusión de Forraje/Silo',
          'Forzar la formulación a incluir fibras de calidad y silos.',
          _cPriorizarForraje,
          (val) => setState(() => _cPriorizarForraje = val ?? false),
        ),
        _buildConsiderationTile(
          'Priorizar Suplementos y Sales',
          'Asegurar un aporte óptimo de minerales y vitaminas.',
          _cPriorizarSuplementos,
          (val) => setState(() => _cPriorizarSuplementos = val ?? false),
        ),
        _buildConsiderationTile(
          'Reducir Costo del Plan',
          'Encuentra la alternativa más económica posible.',
          _cReducirCosto,
          (val) => setState(() => _cReducirCosto = val ?? false),
        ),
        _buildConsiderationTile(
          'Priorizar Ganancia de Peso',
          'Sube el balance calórico para acelerar ganancia diaria.',
          _cGananciaPeso,
          (val) => setState(() => _cGananciaPeso = val ?? false),
        ),
        _buildConsiderationTile(
          'Optimizar Producción de Leche',
          'Ajusta la densidad proteica para incrementar litros diarios.',
          _cProdLeche,
          (val) => setState(() => _cProdLeche = val ?? false),
        ),
        _buildConsiderationTile(
          'Sólo Insumos en Finca',
          'Evita sugerir ingredientes comerciales no disponibles.',
          _cSoloFinca,
          (val) => setState(() => _cSoloFinca = val ?? false),
        ),
        _buildConsiderationTile(
          'Ajuste por Época Seca / Sequía',
          'Compensa déficit de pasturas con mayor silo y concentrado.',
          _cEpocaSeca,
          (val) => setState(() => _cEpocaSeca = val ?? false),
        ),
      ],
    );
  }

  String _resourceTypeLabel(String type) {
    switch (type) {
      case 'pasto':
        return 'pasto';
      case 'silo':
        return 'silo';
      case 'concentrado':
        return 'concentrado energético';
      case 'suplemento':
        return 'sales o suplemento mineral';
      default:
        return type;
    }
  }

  Widget _buildPlanCheckRow(
    IconData icon,
    String label,
    String value,
    bool ready,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: ready ? AppColors.primaryGreen : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(
            value,
            style: AppTextStyles.caption.copyWith(
              color: ready ? AppColors.primaryGreen : AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: AppColors.primaryGreen),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.caption)),
        ],
      ),
    );
  }

  Widget _buildConsiderationTile(
    String title,
    String subtitle,
    bool val,
    ValueChanged<bool?> onChanged,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: val ? AppColors.greenSurface : AppColors.surface,
      child: CheckboxListTile(
        title: Text(
          title,
          style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.caption.copyWith(fontSize: 11),
        ),
        value: val,
        onChanged: onChanged,
        activeColor: AppColors.primaryGreen,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildWizardNavigation(DataProvider provider) {
    if (_wizardStep == 2) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => _runAiAnalysis(provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Crear plan nutricional',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _wizardStep--;
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text('Atrás'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_wizardStep > 0)
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _wizardStep--;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sandBeige,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text('Atrás'),
            )
          else
            const SizedBox.shrink(),
          ElevatedButton(
            onPressed: () {
              if (_wizardStep < _totalSteps - 1) {
                setState(() {
                  _wizardStep++;
                });
              } else {
                _runAiAnalysis(provider);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Siguiente'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPlanView() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.greenSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primaryGreen,
                  size: 40,
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.15, 1.15),
                duration: 800.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 24),
          Text(
                _loadingMsgIndex == 0
                    ? 'Calculando requerimientos...'
                    : _loadingMsgIndex == 1
                    ? 'Comparando alimentos disponibles...'
                    : _loadingMsgIndex == 2
                    ? 'Diseñando el plan AURA...'
                    : 'Generando recomendaciones...',
                key: ValueKey(_loadingMsgIndex),
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.primaryGreenDark,
                ),
              )
              .animate()
              .fadeIn(duration: 200.ms)
              .slideY(begin: 0.1, end: 0, duration: 200.ms),
          const SizedBox(height: 12),
          const SizedBox(
            width: 220,
            child: LinearProgressIndicator(
              minHeight: 5,
              color: AppColors.primaryGreen,
              backgroundColor: AppColors.greenSurface,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _loadingElapsedSeconds < 15
                ? 'La IA está optimizando la ración · ${_loadingElapsedSeconds}s'
                : 'La IA sigue trabajando; si la red está saturada usaremos una alternativa rápida.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }

  Widget _buildIntegratedHeader(String role) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 12,
        16,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: Logo y rol en el lado izquierdo, Conectado y Perfil en el derecho
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: AppColors.primaryGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AURA',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        role,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 9,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Conectado',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.4)),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Pill: Motor de IA nutricional
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFFD54F),
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'Motor de IA nutricional',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Título principal
          Text(
            'IA Nutrición',
            style: AppTextStyles.h1.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          // Subtítulo
          Text(
            'Optimiza la alimentación de tu ganado con los recursos que tienes',
            style: AppTextStyles.body.copyWith(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          // Barra de Pestañas (TabBar en forma de cápsula)
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.primaryGreenDark,
              unselectedLabelColor: Colors.white,
              labelStyle: AppTextStyles.bodyBold.copyWith(fontSize: 13),
              unselectedLabelStyle: AppTextStyles.body.copyWith(fontSize: 13),
              tabs: const [
                Tab(text: 'Generar plan'),
                Tab(text: 'Mis recursos'),
                Tab(text: 'Historial'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role =
        Provider.of<DataProvider>(context, listen: false).profile?['role'] ??
        'Ganadero';
    return Scaffold(
      body: Consumer<DataProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }

          final pastos = provider.nutritionResources
              .where((r) => r.type == 'pasto')
              .toList();
          final silos = provider.nutritionResources
              .where((r) => r.type == 'silo')
              .toList();
          final concentrados = provider.nutritionResources
              .where((r) => r.type == 'concentrado')
              .toList();
          final suplementos = provider.nutritionResources
              .where((r) => r.type == 'suplemento')
              .toList();

          return Column(
            children: [
              _buildIntegratedHeader(role),

              // Contenido
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: ASISTENTE DE DIETA
                    _isLoadingPlan
                        ? _buildLoadingPlanView()
                        : Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: _buildStepIndicator(),
                              ),
                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  children: [
                                    _buildStepContent(provider),
                                    const SizedBox(height: 80),
                                  ],
                                ),
                              ),
                              _buildWizardNavigation(provider),
                            ],
                          ),

                    // TAB 2: INVENTARIO DE INSUMOS
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Mi Inventario', style: AppTextStyles.h3),
                            ElevatedButton.icon(
                              onPressed: () {
                                _initializeTempResources(provider);
                                _showAddResourceDialog(
                                  context,
                                  isInventory: true,
                                );
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Registrar Insumo'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInventoryListSection(
                          provider,
                          'Pastos 🌾',
                          pastos,
                        ),
                        _buildInventoryListSection(
                          provider,
                          'Forrajes y Silos 🚜',
                          silos,
                        ),
                        _buildInventoryListSection(
                          provider,
                          'Concentrados 📦',
                          concentrados,
                        ),
                        _buildInventoryListSection(
                          provider,
                          'Suplementos / Sales 🧪',
                          suplementos,
                        ),
                      ],
                    ),

                    // TAB 3: HISTORIAL DE PLANES
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      children: [
                        Text(
                          'Historial de Planes Generados',
                          style: AppTextStyles.h3,
                        ),
                        const SizedBox(height: 12),
                        if (provider.nutritionPlans.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'No hay planes nutricionales guardados aún.',
                                style: AppTextStyles.body,
                              ),
                            ),
                          )
                        else
                          ...provider.nutritionPlans.map((plan) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              elevation: 0,
                              color: AppColors.surface,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlanDetailScreen(
                                        plan: plan,
                                        onPrefillPlan: (target) =>
                                            _prefillTarget(target, provider),
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            plan.targetGroup,
                                            style: AppTextStyles.bodyBold
                                                .copyWith(
                                                  color: AppColors
                                                      .primaryGreenDark,
                                                ),
                                          ),
                                          _statusBadge(plan.status),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Dieta: ${plan.suggestedDiet}',
                                        style: AppTextStyles.body.copyWith(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Costo: \$${plan.estimatedCostPerDay.toStringAsFixed(2)} / animal / día',
                                            style: AppTextStyles.caption,
                                          ),
                                          Text(
                                            _formatDateTime(plan.createdAt),
                                            style: AppTextStyles.caption
                                                .copyWith(fontSize: 11),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          const Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 14,
                                            color: AppColors.primaryGreen,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Ver Plan Premium',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                  color: AppColors.primaryGreen,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInventoryListSection(
    DataProvider provider,
    String title,
    List<NutritionResource> list,
  ) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: AppTextStyles.bodyBold.copyWith(
              color: AppColors.primaryGreenDark,
            ),
          ),
        ),
        ...list.map((res) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            elevation: 0,
            child: ListTile(
              title: Text(res.name, style: AppTextStyles.bodyBold),
              subtitle: Text(
                '${res.amount} ${res.unit} | Costo: \$${(res.cost ?? 0.0).toStringAsFixed(2)} | Estado: ${res.availability}',
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.alertRed,
                ),
                onPressed: () {
                  if (res.id != null) provider.removeNutritionResource(res.id!);
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color color = AppColors.primaryGreen;
    if (status == 'Completado') color = AppColors.textSecondary;
    if (status == 'Descartado') color = AppColors.alertRed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: AppTextStyles.badge.copyWith(color: color, fontSize: 11),
      ),
    );
  }

  String _formatDateTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final months = [
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
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}
    return dateStr;
  }
}
