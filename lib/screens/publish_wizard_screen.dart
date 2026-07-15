import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/animal.dart';
import '../../models/marketplace_item.dart';
import '../../data/data_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../services/marketplace_ai_service.dart';
import '../../widgets/marketplace/market_item_card.dart';

class PublishWizardScreen extends StatefulWidget {
  const PublishWizardScreen({super.key});

  @override
  State<PublishWizardScreen> createState() => _PublishWizardScreenState();
}

class PhotoSlot {
  final String id; // 'principal', 'lateral', 'arete', 'sena', 'marca', 'empaque', 'elaboracion'
  final String label;
  final String sublabel;
  final bool isRequired;
  final bool isSuggested;
  final String? helperText;

  PhotoSlot({
    required this.id,
    required this.label,
    required this.sublabel,
    this.isRequired = false,
    this.isSuggested = false,
    this.helperText,
  });
}

class _PublishWizardScreenState extends State<PublishWizardScreen> {
  final MarketplaceAiService _aiService = LocalHeuristicMarketplaceAiService();
  final ImagePicker _imagePicker = ImagePicker();

  int _currentStep = 0;

  List<String> get _activeSteps {
    if (_category == 'Ganado') {
      return ['¿Qué vendes?', 'Identificación', 'Fotos de calidad', 'Verificación', 'Datos de venta', 'Vista previa'];
    } else {
      return ['¿Qué vendes?', 'Fotos de calidad', 'Verificación', 'Datos de venta', 'Vista previa'];
    }
  }

  // Paso 1 State
  String _category = 'Ganado';
  Animal? _selectedAnimal;

  // Paso 2 State (Identificación)
  String _via = 'via_a'; // via_a, via_b
  final TextEditingController _senasParticularesController = TextEditingController();
  bool _tieneMarcaHierro = false;

  // Slots de Fotos State
  Map<String, String> _slotImages = {};
  List<String> _extraImagePaths = [];

  List<String> _imagePaths = [];
  bool _isAnalyzingPhoto = false;
  PhotoAnalysisResult? _photoAnalysisResult;

  List<PhotoSlot> _getActivePhotoSlots() {
    if (_category != 'Ganado') {
      return [
        PhotoSlot(id: 'principal', label: 'Producto\n(General)', sublabel: '(Obligatorio)', isRequired: true),
        PhotoSlot(id: 'empaque', label: 'Empaque\n(Si tiene)', sublabel: '(Sugerida)', isSuggested: true),
        PhotoSlot(id: 'elaboracion', label: 'Elaboración\n(Lugar)', sublabel: '(Sugerida)', isSuggested: true),
      ];
    }

    if (_via == 'via_a') {
      return [
        PhotoSlot(id: 'principal', label: 'Principal\n(Cuerpo perfil)', sublabel: '(Obligatoria)', isRequired: true),
        PhotoSlot(id: 'lateral', label: 'Lateral\n(Otro ángulo)', sublabel: '(Sugerida)', isSuggested: true),
        PhotoSlot(id: 'arete', label: 'Arete\n(Acercamiento)', sublabel: '(Sugerida)', isSuggested: true),
      ];
    } else {
      final List<PhotoSlot> slots = [
        PhotoSlot(id: 'principal', label: 'Principal\n(Cuerpo perfil)', sublabel: '(Obligatoria)', isRequired: true),
        PhotoSlot(id: 'lateral', label: 'Lateral\n(Otro ángulo)', sublabel: '(Sugerida)', isSuggested: true),
        PhotoSlot(
          id: 'sena',
          label: 'Seña particular',
          sublabel: '(Sugerida)',
          isSuggested: true,
          helperText: 'Foto de la mancha, marca o seña que describiste — ayuda a identificar al animal con confianza.',
        ),
      ];
      if (_tieneMarcaHierro) {
        slots.add(
          PhotoSlot(id: 'marca', label: 'Marca/Señal', sublabel: '(Opcional)'),
        );
      }
      return slots;
    }
  }

  void _updateGlobalImagePaths() {
    List<String> paths = [];
    final activeSlots = _getActivePhotoSlots();
    for (var slot in activeSlots) {
      final path = _slotImages[slot.id];
      if (path != null && path.isNotEmpty) {
        paths.add(path);
      }
    }
    paths.addAll(_extraImagePaths);
    _imagePaths = paths;
  }

  // Paso 3 State
  bool _isVerifyingRequirements = false;
  bool _sisaVerified = false;
  bool _vacunasAlDia = false;
  bool _historialCompleto = false;
  bool _fotosCalidad = false;
  String _areteSisa = '';
  String _cvmState = 'pending'; // verified, pending, none

  // Paso 4 State
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  double? _suggestedPrice;
  bool _negotiable = false;
  List<String> _selectedConditions = [];
  String _location = 'Loja, Ecuador';
  bool _isGeneratingDescription = false;
  bool _isDictating = false;

  // Standard chips for conditions
  final List<String> _allConditions = [
    'Entrega en finca',
    'Pago al contado',
    'Transporte incluido',
    'Precio fijo',
    'Vacunado completo',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-load draft if exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadDraft();
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _descriptionController.dispose();
    _senasParticularesController.dispose();
    super.dispose();
  }

  // --- DRAFT MANAGEMENT ---

  Future<void> _checkAndLoadDraft() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final draftJson = await provider.getListingDraft();
    if (draftJson != null && mounted) {
      final data = jsonDecode(draftJson);
      final animalName = data['animalName'] ?? 'tu producto';
      
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(LucideIcons.rotateCcw, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Text('Continuar Borrador', style: AppTextStyles.h2),
              ],
            ),
            content: Text(
              '¿Quieres continuar con tu publicación de "$animalName" donde la dejaste?',
              style: AppTextStyles.body,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  provider.deleteListingDraft();
                  Navigator.pop(context);
                },
                child: Text('Empezar de nuevo', style: AppTextStyles.body.copyWith(color: AppColors.alertRed)),
              ),
              ElevatedButton(
                onPressed: () {
                  _loadStateFromMap(data);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Continuar', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
              ),
            ],
          );
        },
      );
    }
  }

  void _loadStateFromMap(Map<String, dynamic> data) {
    setState(() {
      _currentStep = data['currentStep'] ?? 0;
      _category = data['category'] ?? 'Ganado';
      _via = data['via'] ?? 'via_a';
      _senasParticularesController.text = data['senasParticulares'] ?? '';
      _tieneMarcaHierro = data['tieneMarcaHierro'] ?? false;
      
      final slotImagesRaw = data['slotImages'] ?? {};
      _slotImages = Map<String, String>.from(slotImagesRaw);
      
      _extraImagePaths = List<String>.from(data['extraImagePaths'] ?? []);

      _imagePaths = List<String>.from(data['imagePaths'] ?? []);
      _areteSisa = data['areteSisa'] ?? '';
      _cvmState = data['cvmState'] ?? 'pending';
      _sisaVerified = data['sisaVerified'] ?? false;
      _vacunasAlDia = data['vacunasAlDia'] ?? false;
      _historialCompleto = data['historialCompleto'] ?? false;
      _fotosCalidad = data['fotosCalidad'] ?? false;
      _priceController.text = data['price'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _negotiable = data['negotiable'] ?? false;
      _selectedConditions = List<String>.from(data['selectedConditions'] ?? []);
      _location = data['location'] ?? 'Loja, Ecuador';

      final animalId = data['selectedAnimalId'];
      if (animalId != null) {
        final provider = Provider.of<DataProvider>(context, listen: false);
        _selectedAnimal = provider.animals.firstWhere((a) => a.id == animalId, orElse: () => provider.animals.first);
      }
    });

    if (_imagePaths.isNotEmpty) {
      _runPhotoAnalysis(_imagePaths.first);
    }
  }

  Future<void> _saveCurrentDraft() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final draftMap = {
      'currentStep': _currentStep,
      'category': _category,
      'selectedAnimalId': _selectedAnimal?.id,
      'animalName': _selectedAnimal?.name ?? _category,
      'via': _via,
      'senasParticulares': _senasParticularesController.text,
      'tieneMarcaHierro': _tieneMarcaHierro,
      'slotImages': _slotImages,
      'extraImagePaths': _extraImagePaths,
      'imagePaths': _imagePaths,
      'areteSisa': _areteSisa,
      'cvmState': _cvmState,
      'sisaVerified': _sisaVerified,
      'vacunasAlDia': _vacunasAlDia,
      'historialCompleto': _historialCompleto,
      'fotosCalidad': _fotosCalidad,
      'price': _priceController.text,
      'description': _descriptionController.text,
      'negotiable': _negotiable,
      'selectedConditions': _selectedConditions,
      'location': _location,
    };
    await provider.saveListingDraft(jsonEncode(draftMap));
  }

  // --- IA ACTIONS ---

  Future<void> _runPhotoAnalysis(String imagePath) async {
    setState(() {
      _isAnalyzingPhoto = true;
      _photoAnalysisResult = null;
    });

    final result = await _aiService.analyzePhoto(
      imagePath: imagePath,
      category: _category,
      animal: _selectedAnimal,
    );

    if (mounted) {
      setState(() {
        _isAnalyzingPhoto = false;
        _photoAnalysisResult = result;
        _fotosCalidad = result.isWellFramed;
      });
    }
  }

  Future<void> _generateDescriptionWithIa() async {
    setState(() {
      _isGeneratingDescription = true;
    });

    final desc = await _aiService.generateDescription(
      category: _category,
      breed: _selectedAnimal?.breed ?? 'Mestizo',
      sex: _selectedAnimal?.sex ?? 'Hembra',
      weight: _selectedAnimal?.weightKg ?? 450,
      production: _selectedAnimal?.productionLiters,
      healthScore: _selectedAnimal?.score ?? 90,
      vaccineStatus: _selectedAnimal?.vaccineStatus ?? 'Al día',
      name: _selectedAnimal?.name ?? 'Animal',
    );

    if (mounted) {
      setState(() {
        _descriptionController.text = desc;
        _isGeneratingDescription = false;
      });
    }
  }

  Future<void> _simulateDictation() async {
    setState(() {
      _isDictating = true;
    });

    // Simulate listening for 2 seconds
    await Future.delayed(const Duration(milliseconds: 2200));

    if (mounted) {
      setState(() {
        _isDictating = false;
        String dictation = "Vaca lechera muy sana y activa, produce muy buena leche todos los días y es dócil.";
        if (_descriptionController.text.isNotEmpty) {
          _descriptionController.text += " " + dictation;
        } else {
          _descriptionController.text = dictation;
        }
      });
    }
  }

  // --- PHOTO CAPTURE ---

  Future<void> _pickSlotImage(String slotId, ImageSource source) async {
    final file = await _imagePicker.pickImage(source: source);
    if (file != null && mounted) {
      setState(() {
        _slotImages[slotId] = file.path;
        _updateGlobalImagePaths();
      });
      _saveCurrentDraft();

      // If it's the primary photo, run visual AI diagnostics
      if (slotId == 'principal') {
        _runPhotoAnalysis(file.path);
      }
    }
  }

  void _removeSlotImage(String slotId) {
    setState(() {
      _slotImages.remove(slotId);
      _updateGlobalImagePaths();
      if (slotId == 'principal') {
        _photoAnalysisResult = null;
        _fotosCalidad = false;
      }
    });
    _saveCurrentDraft();
  }

  Future<void> _pickExtraImage(int index, ImageSource source) async {
    final file = await _imagePicker.pickImage(source: source);
    if (file != null && mounted) {
      setState(() {
        if (index < _extraImagePaths.length) {
          _extraImagePaths[index] = file.path;
        } else {
          _extraImagePaths.add(file.path);
        }
        _updateGlobalImagePaths();
      });
      _saveCurrentDraft();
    }
  }

  void _removeExtraImage(int index) {
    setState(() {
      _extraImagePaths.removeAt(index);
      _updateGlobalImagePaths();
    });
    _saveCurrentDraft();
  }

  void _showSlotImageSelectorSheet(String slotId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Seleccionar Foto',
                style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 70,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _pickSlotImage(slotId, ImageSource.camera);
                        },
                        icon: const Icon(LucideIcons.camera, color: Colors.white, size: 24),
                        label: Text(
                          'Cámara',
                          style: AppTextStyles.bodyBold.copyWith(color: Colors.white, fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 70,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _pickSlotImage(slotId, ImageSource.gallery);
                        },
                        icon: const Icon(LucideIcons.image, color: AppColors.primaryGreenDark, size: 24),
                        label: Text(
                          'Galería',
                          style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreenDark, fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryGreen),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExtraImageSelectorSheet(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Seleccionar Foto Extra',
                style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 70,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _pickExtraImage(index, ImageSource.camera);
                        },
                        icon: const Icon(LucideIcons.camera, color: Colors.white, size: 24),
                        label: Text(
                          'Cámara',
                          style: AppTextStyles.bodyBold.copyWith(color: Colors.white, fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 70,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _pickExtraImage(index, ImageSource.gallery);
                        },
                        icon: const Icon(LucideIcons.image, color: AppColors.primaryGreenDark, size: 24),
                        label: Text(
                          'Galería',
                          style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryGreenDark, fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryGreen),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- STEP VERIFICATION RUNNER ---

  Future<void> _runRequirementsVerification() async {
    setState(() {
      _isVerifyingRequirements = true;
    });

    // Simulate Agrocalidad verification sweep (1.5s delay)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() {
        _isVerifyingRequirements = false;
        
        if (_category == 'Ganado' && _selectedAnimal != null) {
          _areteSisa = _selectedAnimal!.tag.replaceAll('#', 'EC-2026-00');
          _sisaVerified = true;
          _vacunasAlDia = _selectedAnimal!.vaccineStatus != 'Vencida';
          _historialCompleto = _selectedAnimal!.score > 80;
          _cvmState = 'pending'; // require CVM trigger
        } else {
          // Defaults for product/leche
          _areteSisa = 'N/A (Producto elaborado)';
          _sisaVerified = true;
          _vacunasAlDia = true;
          _historialCompleto = true;
          _cvmState = 'verified'; // Leche/Queso no necesita CVM de ganado en pie
        }
      });
      _saveCurrentDraft();
    }
  }

  // --- WIZARD FLOW CONTROL ---

  void _nextStep() {
    final stepName = _activeSteps[_currentStep];

    if (stepName == '¿Qué vendes?') {
      if (_category == 'Ganado' && _selectedAnimal == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seleccione un animal de su hato antes de continuar', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
            backgroundColor: AppColors.alertOrange,
          ),
        );
        return;
      }
      // Populate defaults based on animal if ganado
      if (_category == 'Ganado' && _selectedAnimal != null) {
        _suggestedPrice = 1500.0 + _randomSuggestedPriceOffset();
        _priceController.text = _suggestedPrice!.toStringAsFixed(0);
        _location = _selectedAnimal!.finca + ', Ecuador';
        _selectedConditions = ['Entrega en finca', 'Pago al contado'];
      } else {
        _suggestedPrice = _category == 'Leche' ? 0.55 : (_category == 'Queso' ? 4.50 : 150);
        _priceController.text = _suggestedPrice!.toString();
        _selectedConditions = ['Pago al contado'];
      }
    }

    if (stepName == 'Identificación') {
      if (_via == 'via_b' && _senasParticularesController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Por favor, describa las señas particulares del animal', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
            backgroundColor: AppColors.alertOrange,
          ),
        );
        return;
      }
    }

    if (stepName == 'Fotos de calidad') {
      if (_slotImages['principal'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se requiere al menos la foto principal obligatoria', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
            backgroundColor: AppColors.alertOrange,
          ),
        );
        return;
      }
      // Trigger verification when moving to next step
      _runRequirementsVerification();
    }

    if (stepName == 'Datos de venta') {
      if (_priceController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Por favor, ingrese un precio válido', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
            backgroundColor: AppColors.alertOrange,
          ),
        );
        return;
      }
    }

    setState(() {
      _currentStep++;
    });
    _saveCurrentDraft();
  }

  double _randomSuggestedPriceOffset() {
    if (_selectedAnimal == null) return 0;
    return (_selectedAnimal!.score * 5) + (_selectedAnimal!.weightKg * 1.5);
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _saveCurrentDraft();
    } else {
      Navigator.pop(context);
    }
  }

  // --- FINAL ACTIONS ---

  Future<void> _finishAndPublish() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final price = double.tryParse(_priceController.text) ?? 1500.0;

    final bool isElite = _category == 'Ganado'
        ? (_via == 'via_a' && _fotosCalidad && _sisaVerified && _vacunasAlDia && _cvmState == 'verified')
        : (_fotosCalidad && _cvmState == 'verified');
    final badge = isElite ? 'Elite' : 'Verificado';

    await provider.publishMarketplaceItem(
      title: _category == 'Ganado' 
          ? '${_selectedAnimal?.category} ${_selectedAnimal?.breed} - ${_selectedAnimal?.name}'
          : '$_category Fresco de Finca',
      price: price,
      category: _category,
      weight: _selectedAnimal?.weightKg != null ? '${_selectedAnimal!.weightKg.toStringAsFixed(0)} kg' : null,
      production: _selectedAnimal?.productionLiters,
      location: _location,
      negotiable: _negotiable,
      imagePaths: _imagePaths,
      description: _descriptionController.text.trim(),
      score: _selectedAnimal?.score ?? 92,
      badge: badge,
      areteSisa: _areteSisa,
      cvmState: _cvmState,
      sisaVerified: _sisaVerified,
      vacunasAlDia: _vacunasAlDia,
      historialCompleto: _historialCompleto,
      fotosCalidad: _fotosCalidad,
    );

    // Delete draft
    await provider.deleteListingDraft();

    // Show Confetti + Success BottomSheet
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: const BoxDecoration(
                  color: AppColors.greenSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.checkCircle2,
                  size: 48,
                  color: AppColors.primaryGreen,
                ),
              ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 20),
              Text(
                '¡Publicación Exitosa!',
                style: AppTextStyles.h1.copyWith(color: AppColors.primaryGreenDark),
              ),
              const SizedBox(height: 8),
              Text(
                _category == 'Ganado'
                    ? '¡Listo! ${_selectedAnimal?.name} ya está disponible en el Marketplace con ${_imagePaths.length} fotos y certificación completa.'
                    : '¡Listo! Tu producto de $_category ya está disponible en el Marketplace.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close bottomsheet
                    Navigator.pop(context); // Close WizardScreen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Volver al Marketplace',
                    style: AppTextStyles.bodyBold.copyWith(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- ACCESSIBILITY HELP TOOLTIP ---

  void _showHelpTooltip() {
    String message = '';
    final stepName = _activeSteps[_currentStep];
    switch (stepName) {
      case '¿Qué vendes?':
        message = 'Selecciona qué tipo de producto vas a vender. Si es un animal del hato, selecciónalo de la lista para verificar automáticamente sus vacunas y arete SISA.';
        break;
      case 'Identificación':
        message = 'Define si tu animal cuenta con arete oficial (Vía A) o si registrarás señas particulares de identificación (Vía B).';
        break;
      case 'Fotos de calidad':
        message = _category == 'Ganado'
            ? 'Sube fotos de tu animal. El grid se adapta según la vía elegida. La única foto obligatoria es la Principal.'
            : 'Sube fotos claras de tu producto. La foto principal es obligatoria.';
        break;
      case 'Verificación':
        message = 'Aquí el sistema verifica en tiempo real que tu animal cumpla con los esquemas de vacunación oficiales de AGROCALIDAD o tus señas de identificación.';
        break;
      case 'Datos de venta':
        message = 'Define el precio. La IA te sugiere un rango de mercado. Puedes usar el dictado por voz (ícono del micrófono) para grabar la descripción sin escribir.';
        break;
      case 'Vista previa':
        message = 'Revisa cómo se verá tu publicación en vivo antes de subirla. Si ves algún error, puedes tocar "Atrás" para corregirlo.';
        break;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(LucideIcons.helpCircle, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text('Ayuda - ${stepName}', style: AppTextStyles.h2),
            ],
          ),
          content: Text(message, style: AppTextStyles.body),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Entendido', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- SUB-SCREEN BUILDERS ---

  Widget _buildStepIndicator() {
    final steps = _activeSteps;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Paso ${_currentStep + 1} de ${steps.length}',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              Text(
                steps[_currentStep],
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryGreenDark),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(steps.length, (index) {
              final isPassed = index <= _currentStep;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isPassed ? AppColors.primaryGreen : AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // PASO 1: ¿Qué vendes?
  Widget _buildStep1() {
    final provider = Provider.of<DataProvider>(context);
    final availableAnimals = provider.animals;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Qué deseas publicar en el mercado?',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 6),
          Text(
            'Elige la categoría del producto. Si vendes ganado, vincúlalo a un animal registrado para certificarlo automáticamente.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 20),

          // Categorías
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ['Ganado', 'Leche', 'Queso', 'Insumos'].map((cat) {
              final isSelected = _category == cat;
              return InkWell(
                onTap: () {
                  setState(() {
                    _category = cat;
                    if (cat != 'Ganado') {
                      _selectedAnimal = null;
                    }
                  });
                  _saveCurrentDraft();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.43,
                  height: 70, // >= 56px clickable area
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.greenSurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primaryGreen : AppColors.border,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    cat,
                    style: AppTextStyles.bodyBold.copyWith(
                      color: isSelected ? AppColors.primaryGreenDark : AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Lista de animales si es categoría Ganado
          if (_category == 'Ganado') ...[
            Text('Vincula un Animal de tu Hato', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            if (availableAnimals.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'No tienes animales registrados en tu hato para vender.',
                  style: AppTextStyles.body,
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: availableAnimals.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final animal = availableAnimals[index];
                    final isSelected = _selectedAnimal?.id == animal.id;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAnimal = animal;
                        });
                        _saveCurrentDraft();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        color: isSelected ? AppColors.greenSurface.withOpacity(0.4) : Colors.transparent,
                        child: Row(
                          children: [
                            Container(
                              height: 24,
                              width: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Center(
                                      child: Icon(Icons.circle, size: 12, color: AppColors.primaryGreen),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${animal.name} (${animal.category})',
                                    style: AppTextStyles.bodyBold,
                                  ),
                                  Text(
                                    'Raza: ${animal.breed} · Peso: ${animal.weightKg} kg · Arete SISA: ${animal.tag}',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: animal.score >= 90 ? AppColors.greenSurface : AppColors.sandBeige,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${animal.score}/100',
                                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  // PASO 2: Identificación
  Widget _buildStepIdentificacion() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Identificación del Animal',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 6),
          Text(
            'Seleccione la vía oficial de registro e identificación de su animal.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 20),

          // Vía A Card
          InkWell(
            onTap: () {
              setState(() {
                _via = 'via_a';
              });
              _saveCurrentDraft();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _via == 'via_a' ? AppColors.greenSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _via == 'via_a' ? AppColors.primaryGreen : AppColors.border,
                  width: 2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _via == 'via_a' ? AppColors.primaryGreen.withOpacity(0.2) : AppColors.border.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.binary,
                      color: AppColors.primaryGreenDark,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vía A — Con arete oficial',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: _via == 'via_a' ? AppColors.primaryGreenDark : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'El animal cuenta con un arete oficial visible registrado en AGROCALIDAD o SISA.',
                          style: AppTextStyles.caption,
                        ),
                        if (_selectedAnimal != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                            ),
                            child: Text(
                              'Arete actual: ${_selectedAnimal!.tag}',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreenDark,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Vía B Card
          InkWell(
            onTap: () {
              setState(() {
                _via = 'via_b';
              });
              _saveCurrentDraft();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _via == 'via_b' ? AppColors.greenSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _via == 'via_b' ? AppColors.primaryGreen : AppColors.border,
                  width: 2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _via == 'via_b' ? AppColors.primaryGreen.withOpacity(0.2) : AppColors.border.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.shieldAlert,
                      color: AppColors.primaryGreenDark,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vía B — Sin arete oficial',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: _via == 'via_b' ? AppColors.primaryGreenDark : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'El animal no posee arete oficial en este momento. Se identificará mediante señas particulares.',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Condicional para Vía B
          if (_via == 'via_b') ...[
            Text('Detalles de Identificación Alternativa', style: AppTextStyles.h3),
            const SizedBox(height: 10),

            // Campo de texto de Señas Particulares
            TextFormField(
              controller: _senasParticularesController,
              maxLines: 3,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                labelText: 'Señas particulares (Obligatorio)',
                labelStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                hintText: 'Describa marcas, manchas, color de cuernos, etc. que distingan al animal.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                alignLabelWithHint: true,
              ),
              onChanged: (val) {
                _saveCurrentDraft();
              },
            ),

            const SizedBox(height: 16),

            // Toggle de marca de hierro o señal propia
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tiene marca de hierro o señal propia',
                          style: AppTextStyles.bodyBold,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Habilita un slot de foto adicional para verificar físicamente la marca.',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _tieneMarcaHierro,
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: (val) {
                      setState(() {
                        _tieneMarcaHierro = val;
                      });
                      _saveCurrentDraft();
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getIaMessage() {
    if (_category != 'Ganado') {
      return _photoAnalysisResult?.summary ?? 'Encuadre correcto ✓';
    }

    final hasPrimary = _slotImages['principal'] != null;
    if (!hasPrimary) return '';

    if (_via == 'via_a') {
      final hasArete = _slotImages['arete'] != null;
      if (!hasArete) {
        return "🤖 La IA analizó tu foto\nBuena condición corporal detectada ✓\nSugerencia: agrega una foto del arete\npara alcanzar el nivel de certificación ELITE";
      } else {
        return "🤖 La IA analizó tu foto\nBuena condición corporal detectada ✓\nArete visible y encuadre correcto. ¡Listo para certificar!";
      }
    } else {
      final hasSena = _slotImages['sena'] != null;
      if (!hasSena) {
        return "🤖 La IA analizó tu foto\nBuena condición corporal detectada ✓\nSugerencia: agrega una foto de la seña que\ndescribiste para reforzar tu nivel VERIFICADA";
      } else {
        return "🤖 La IA analizó tu foto\nBuena condición corporal detectada ✓\nSeña particular registrada. ¡Listo para certificar!";
      }
    }
  }

  // PASO 3: Fotos
  Widget _buildStep2() {
    final activeSlots = _getActivePhotoSlots();
    final totalGridItems = activeSlots.length + _extraImagePaths.length + 1;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fotos de tu ${_category == 'Ganado' ? 'Animal' : 'Producto'}',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 6),
          Text(
            'Agrega fotos — entre más claras, más confianza generan en los compradores.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 20),

          // Grid de fotos
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.15,
            ),
            itemCount: totalGridItems,
            itemBuilder: (context, index) {
              if (index < activeSlots.length) {
                // Pre-defined slot
                final slot = activeSlots[index];
                final path = _slotImages[slot.id];
                final hasImage = path != null && path.isNotEmpty;

                if (hasImage) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: path.startsWith('http')
                                ? Image.network(path, fit: BoxFit.cover)
                                : Image.file(File(path), fit: BoxFit.cover),
                          ),
                        ),
                        // Delete button
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: () => _removeSlotImage(slot.id),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.alertRed,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.x, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                        // Edit/Replace button
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: InkWell(
                            onTap: () => _showSlotImageSelectorSheet(slot.id),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                              ),
                              child: const Icon(LucideIcons.pencil, size: 14, color: AppColors.primaryGreenDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Empty slot card
                  return InkWell(
                    onTap: () => _showSlotImageSelectorSheet(slot.id),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: slot.isRequired ? AppColors.alertOrange : AppColors.primaryGreen.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.camera,
                            size: 32,
                            color: slot.isRequired ? AppColors.alertOrange : AppColors.primaryGreen,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            slot.label,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: slot.isRequired ? AppColors.alertOrange : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            slot.sublabel,
                            style: AppTextStyles.caption.copyWith(
                              color: slot.isRequired ? AppColors.alertRed : AppColors.textSecondary,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              } else if (index < activeSlots.length + _extraImagePaths.length) {
                // Extra image card
                final extraIndex = index - activeSlots.length;
                final path = _extraImagePaths[extraIndex];

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: path.startsWith('http')
                              ? Image.network(path, fit: BoxFit.cover)
                              : Image.file(File(path), fit: BoxFit.cover),
                        ),
                      ),
                      // Delete button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: InkWell(
                          onTap: () => _removeExtraImage(extraIndex),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.alertRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.x, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                      // Edit button
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: InkWell(
                          onTap: () => _showExtraImageSelectorSheet(extraIndex),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                            ),
                            child: const Icon(LucideIcons.pencil, size: 14, color: AppColors.primaryGreenDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                // "Agregar más" slot card
                final extraIndex = index - activeSlots.length;
                return InkWell(
                  onTap: () => _showExtraImageSelectorSheet(extraIndex),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primaryGreen.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.plusCircle,
                          size: 32,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Agregar más\n(+)',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 20),

          // Helper tooltip below slot if Vía B has sena slot empty
          if (_category == 'Ganado' && _via == 'via_b' && _slotImages['sena'] == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.greenSurface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.info, color: AppColors.primaryGreenDark, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Foto de Seña Particular: Foto de la mancha, marca o seña que describiste — ayuda a identificar al animal con confianza.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.primaryGreenDark, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Progreso de carga
          Row(
            children: [
              Icon(
                _imagePaths.isNotEmpty ? LucideIcons.checkCircle : LucideIcons.alertTriangle,
                color: _imagePaths.isNotEmpty ? AppColors.primaryGreen : AppColors.alertOrange,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '${_imagePaths.length} de 3 fotos sugeridas · ${_extraImagePaths.length} fotos extra agregadas',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _imagePaths.isNotEmpty ? AppColors.primaryGreenDark : AppColors.alertOrange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // IA Card
          if (_isAnalyzingPhoto)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.greenSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                  ),
                  const SizedBox(width: 14),
                  Text('La IA está analizando tu foto principal...', style: AppTextStyles.bodyBold),
                ],
              ),
            )
          else if (_slotImages['principal'] != null) // Only show if principal photo exists
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F2FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC0DAFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.bot, color: Color(0xFF0F5BCC), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'La IA analizó tu foto',
                        style: AppTextStyles.bodyBold.copyWith(color: const Color(0xFF0F5BCC)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getIaMessage(),
                    style: AppTextStyles.body.copyWith(color: const Color(0xFF1E4680)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // PASO 3: Verificación automática
  Widget _buildStep3() {
    if (_isVerifyingRequirements) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.cpu,
              size: 56,
              color: AppColors.primaryGreen,
            ).animate(onPlay: (controller) => controller.repeat())
             .scale(duration: 800.ms, curve: Curves.easeInOut)
             .then()
             .scale(duration: 800.ms, curve: Curves.easeInOut),
            const SizedBox(height: 20),
            Text('Revisando los requisitos oficiales...', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text('Consultando bases de datos de AGROCALIDAD y registros locales...', style: AppTextStyles.body),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verificando tu Publicación',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 6),
          Text(
            'Para vender ganado en Ecuador, es ideal contar con la verificación de vacunación y aretes SISA.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 20),

          // Arete o Señas particulares
          if (_via == 'via_a')
            _buildRequirementCheck(
              label: 'Arete SISA registrado',
              value: _areteSisa.isNotEmpty ? _areteSisa : 'No detectado',
              isOk: _sisaVerified,
            )
          else
            _buildRequirementCheck(
              label: 'Señas particulares registradas',
              value: _senasParticularesController.text.isNotEmpty
                  ? _senasParticularesController.text
                  : 'No descritas',
              isOk: _senasParticularesController.text.isNotEmpty,
            ),
          // Aftosa
          _buildRequirementCheck(
            label: 'Vacuna Fiebre Aftosa',
            value: _vacunasAlDia ? 'Aplicada hace 38 días' : 'Vencida o no registrada',
            isOk: _vacunasAlDia,
          ),
          // Brucelosis
          _buildRequirementCheck(
            label: 'Vacuna Brucelosis',
            value: _vacunasAlDia ? 'Aplicada hace 65 días' : 'Pendiente',
            isOk: _vacunasAlDia,
          ),
          // Historial clínico
          _buildRequirementCheck(
            label: 'Historial clínico',
            value: _historialCompleto ? '3 registros recientes ✓' : 'Faltan registros recientes',
            isOk: _historialCompleto,
          ),

          const SizedBox(height: 18),
          const Divider(color: AppColors.border),
          const SizedBox(height: 14),

          // CVM Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _cvmState == 'verified' ? LucideIcons.checkCircle : LucideIcons.alertTriangle,
                color: _cvmState == 'verified' ? AppColors.primaryGreen : AppColors.alertOrange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Certificado Veterinario de Movilización (CVM)',
                      style: AppTextStyles.bodyBold,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _cvmState == 'verified' 
                          ? 'CVM Verificado y registrado con éxito ✓'
                          : '🤖 "Para vender ganado en pie en Ecuador necesitas un Certificado Veterinario de Movilización (documento que certifica que el animal está sano) vigente. Puedes solicitarlo a tu veterinario o a AGROCALIDAD antes de mover al animal."',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          if (_cvmState != 'verified')
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _cvmState = 'pending';
                        });
                        _nextStep();
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Continuar sin CVM',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyBold.copyWith(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _cvmState = 'verified';
                        });
                        _saveCurrentDraft();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('CVM marcado como verificado.', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
                            backgroundColor: AppColors.primaryGreen,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Ya tengo CVM',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyBold.copyWith(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRequirementCheck({
    required String label,
    required String value,
    required bool isOk,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            isOk ? LucideIcons.check : LucideIcons.x,
            color: isOk ? AppColors.primaryGreen : AppColors.alertRed,
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodyBold),
                Text(value, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PASO 4: Datos de venta
  Widget _buildStep4() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Datos de Venta y Descripción',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 6),
          Text(
            'Define el precio de venta y las condiciones del trato.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 20),

          // Precio
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  style: AppTextStyles.h2,
                  decoration: InputDecoration(
                    labelText: 'Precio de venta (USD)',
                    prefixText: r'$ ',
                    labelStyle: AppTextStyles.caption,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              if (_suggestedPrice != null) ...[
                const SizedBox(width: 10),
                SizedBox(
                  height: 56, // Accessible height target
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _priceController.text = _suggestedPrice!.toStringAsFixed(0);
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.greenSurface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.primaryGreen),
                      ),
                    ),
                    child: Text(
                      'Usar sugerido\n(\$${_suggestedPrice!.toStringAsFixed(0)})',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(color: AppColors.primaryGreenDark, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Negociable switch
          Row(
            children: [
              Text('¿El precio es negociable?', style: AppTextStyles.bodyBold),
              const Spacer(),
              Switch(
                value: _negotiable,
                activeColor: AppColors.primaryGreen,
                onChanged: (val) {
                  setState(() {
                    _negotiable = val;
                  });
                  _saveCurrentDraft();
                },
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Descripción & IA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Descripción del anuncio', style: AppTextStyles.h3),
              if (_category == 'Ganado' && _selectedAnimal != null)
                IconButton(
                  icon: const Icon(LucideIcons.sparkles, color: AppColors.primaryGreenDark),
                  onPressed: _isGeneratingDescription ? null : _generateDescriptionWithIa,
                  tooltip: 'Generar descripción con IA',
                ),
            ],
          ),
          const SizedBox(height: 8),

          Stack(
            children: [
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: 'Describe tu animal o producto (ej: edad, temperamento, condiciones de salud, etc.)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.fromLTRB(14, 14, 48, 14),
                ),
              ),
              // Mic / dictation button
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: _isDictating ? AppColors.alertOrange : AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(_isDictating ? LucideIcons.mic : LucideIcons.mic, color: Colors.white, size: 18),
                    onPressed: _isDictating ? null : _simulateDictation,
                  ),
                ),
              ),
            ],
          ),

          if (_isGeneratingDescription)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primaryGreen),
                  ),
                  const SizedBox(width: 8),
                  Text('Escribiendo descripción con IA...', style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          if (_isDictating)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.alertOrange),
                  ),
                  const SizedBox(width: 8),
                  Text('Escuchando voz (Rosa Elvira)... Hable ahora.', style: AppTextStyles.caption.copyWith(color: AppColors.alertOrange, fontStyle: FontStyle.italic)),
                ],
              ),
            ),

          const SizedBox(height: 18),

          // Condiciones Chips
          Text('Condiciones de venta', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allConditions.map((cond) {
              final isSelected = _selectedConditions.contains(cond);
              return FilterChip(
                label: Text(cond, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                selected: isSelected,
                selectedColor: AppColors.greenSurface,
                checkmarkColor: AppColors.primaryGreen,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedConditions.add(cond);
                    } else {
                      _selectedConditions.remove(cond);
                    }
                  });
                  _saveCurrentDraft();
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // Ubicación
          TextFormField(
            initialValue: _location,
            style: AppTextStyles.bodyBold,
            decoration: InputDecoration(
              labelText: 'Ubicación de entrega',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onChanged: (val) {
              _location = val;
              _saveCurrentDraft();
            },
          ),
        ],
      ),
    );
  }

  // PASO 5: Confirmar y publicar
  Widget _buildStep5() {
    final price = double.tryParse(_priceController.text) ?? 1500.0;
    
    final bool isElite = _category == 'Ganado'
        ? (_via == 'via_a' && _fotosCalidad && _sisaVerified && _vacunasAlDia && _cvmState == 'verified')
        : (_fotosCalidad && _cvmState == 'verified');
    final badge = isElite ? 'Elite' : 'Verificado';

    final previewItem = MarketplaceItem(
      title: _category == 'Ganado' 
          ? '${_selectedAnimal?.category} ${_selectedAnimal?.breed} - ${_selectedAnimal?.name}'
          : '$_category Fresco de Finca',
      price: price,
      category: _category,
      weight: _selectedAnimal?.weightKg != null ? '${_selectedAnimal!.weightKg.toStringAsFixed(0)} kg' : null,
      production: _selectedAnimal?.productionLiters,
      location: _location,
      responseTime: '< 5 min',
      negotiable: _negotiable,
      imagePaths: _imagePaths,
      description: _descriptionController.text.trim(),
      score: _selectedAnimal?.score ?? 92,
      badge: badge,
      areteSisa: _areteSisa,
      cvmState: _cvmState,
      sisaVerified: _sisaVerified,
      vacunasAlDia: _vacunasAlDia,
      historialCompleto: _historialCompleto,
      fotosCalidad: _fotosCalidad,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirmar y Publicar',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 6),
          Text(
            'Confirma cómo se verá tu publicación en el Marketplace general.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 20),

          // Live visual card
          MarketItemCard(
            item: previewItem,
            onTap: () {},
            onContact: () {},
          ),

          const SizedBox(height: 24),

          // Certification Badge Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.shieldAlert, color: AppColors.primaryGreen, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Nivel de Certificación: ${previewItem.badge.toUpperCase()}',
                      style: AppTextStyles.h3.copyWith(color: AppColors.primaryGreenDark),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_category == 'Ganado' && _via == 'via_b')
                  _buildVerifyBadgeCheck('Señas particulares registradas', _senasParticularesController.text.isNotEmpty)
                else
                  _buildVerifyBadgeCheck('Arete SISA verificado', _sisaVerified),
                _buildVerifyBadgeCheck('Vacunas al día (Aftosa, Brucelosis)', _vacunasAlDia),
                _buildVerifyBadgeCheck('Historial clínico verificado', _historialCompleto),
                _buildVerifyBadgeCheck('Calidad de fotos validada por IA', _fotosCalidad),
                
                // CVM pending check
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _cvmState == 'verified' ? LucideIcons.check : LucideIcons.alertCircle,
                        color: _cvmState == 'verified' ? AppColors.primaryGreen : AppColors.alertOrange,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _cvmState == 'verified' ? 'CVM Registrado' : 'CVM Pendiente (no bloquea publicación)',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _cvmState == 'verified' ? AppColors.primaryGreenDark : AppColors.alertOrange,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                Text(
                  'Tu publicación tendrá máxima visibilidad en el Marketplace de AURA Agro debido a sus factores de trazabilidad.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyBadgeCheck(String label, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isOk ? LucideIcons.check : LucideIcons.x,
            color: isOk ? AppColors.primaryGreen : AppColors.alertRed,
            size: 16,
          ),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // --- BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: _prevStep,
        ),
        title: Text(
          'Vender Animal / Producto',
          style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.helpCircle, color: AppColors.primaryGreen),
            onPressed: _showHelpTooltip,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Siempre visible step progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildStepIndicator(),
            ),
            const SizedBox(height: 16),

            // Form Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildStepContent(),
              ),
            ),

            // Navigation Buttons (fijos abajo)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  // Botón Atrás
                  Expanded(
                    child: SizedBox(
                      height: 56, // Accesibilidad: Mínimo 56px de altura
                      child: TextButton(
                        onPressed: _prevStep,
                        child: Text(
                          'Atrás',
                          style: AppTextStyles.bodyBold.copyWith(color: AppColors.textSecondary, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Botón Siguiente / Publicar
                  Expanded(
                    child: SizedBox(
                      height: 56, // Accesibilidad: Mínimo 56px de altura
                      child: ElevatedButton(
                        onPressed: _currentStep == _activeSteps.length - 1 ? _finishAndPublish : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          _currentStep == _activeSteps.length - 1 ? 'Publicar ahora' : 'Siguiente',
                          style: AppTextStyles.bodyBold.copyWith(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    final stepName = _activeSteps[_currentStep];
    switch (stepName) {
      case '¿Qué vendes?':
        return _buildStep1();
      case 'Identificación':
        return _buildStepIdentificacion();
      case 'Fotos de calidad':
        return _buildStep2();
      case 'Verificación':
        return _buildStep3();
      case 'Datos de venta':
        return _buildStep4();
      case 'Vista previa':
        return _buildStep5();
      default:
        return Container();
    }
  }
}
