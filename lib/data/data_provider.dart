import 'package:flutter/material.dart';
import 'db_helper.dart';
import '../models/animal.dart';
import '../models/alert_model.dart';
import '../models/nutrition_resource.dart';
import '../models/nutrition_plan.dart';
import '../models/weight_record.dart';
import '../models/production_record.dart';
import '../services/nutrition_ai_service.dart';
import '../services/deterministic_nutrition_engine.dart';
import '../models/nutrition_requirement.dart';
import '../services/shared_preferences.dart';
import '../models/marketplace_item.dart';
import 'mock_data.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';


class DataProvider extends ChangeNotifier {
  List<Animal> _animals = [];
  List<AlertModel> _alerts = [];
  List<Map<String, dynamic>> _vaccines = [];
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  int _activeVetTab = 0;
  bool _isOnboardingCompleted = false;
  bool _isOnboardingShown = false;
  List<Map<String, dynamic>> _pendingVeterinarians = [];
  List<Map<String, dynamic>> _farmAuthorizations = [];
  
  List<NutritionResource> _nutritionResources = [];
  List<NutritionPlan> _nutritionPlans = [];
  List<WeightRecord> _weightRecords = [];
  List<ProductionRecord> _productionRecords = [];
  List<NutritionRequirement> _nutritionRequirements = [];

  List<MarketplaceItem> _marketplaceItems = [];
  List<MarketplaceItem> _myPublications = [];

  List<Animal> get animals => _animals;
  List<AlertModel> get alerts {
    final allAlerts = List<AlertModel>.from(_alerts);
    
    // Alertas dinámicas de nutrición
    final activePlans = _nutritionPlans.where((p) => p.status == 'Activo').toList();
    for (var plan in activePlans) {
      List<Animal> coveredAnimals = [];
      if (plan.targetGroup == 'Todo el Hato') {
        coveredAnimals = _animals;
      } else {
        coveredAnimals = _animals.where((a) => a.category == plan.targetGroup || a.id == plan.targetGroup || a.name == plan.targetGroup).toList();
      }

      for (var animal in coveredAnimals) {
        final analysis = PlanHistoryAnalyzer.analyze(
          animal,
          _nutritionPlans,
          _weightRecords,
          _productionRecords,
        );

        bool generateAlert = false;
        String alertTitle = "";
        String aiRec = "";

        if (analysis.complianceScore < 0.75 && !analysis.feedbackNote.contains("No se encontraron")) {
          generateAlert = true;
          alertTitle = "Bajo rendimiento de plan: ${(analysis.complianceScore * 100).toStringAsFixed(0)}%";
          aiRec = "El animal ${animal.name} está rindiendo por debajo de la meta del plan nutricional. Revisa si está consumiendo la ración completa o ajusta los recursos.";
        }

        if (!generateAlert) {
          DateTime? lastRecordDate;
          if (animal.category == 'Vaca Lechera') {
            final animalProds = _productionRecords.where((r) => r.animalId == animal.id).toList();
            if (animalProds.isNotEmpty) {
              animalProds.sort((a, b) => b.date.compareTo(a.date));
              lastRecordDate = DateTime.tryParse(animalProds.first.date);
            }
          } else {
            final animalWeights = _weightRecords.where((r) => r.animalId == animal.id).toList();
            if (animalWeights.isNotEmpty) {
              animalWeights.sort((a, b) => b.date.compareTo(a.date));
              lastRecordDate = DateTime.tryParse(animalWeights.first.date);
            }
          }

          if (lastRecordDate != null) {
            final daysSince = DateTime.now().difference(lastRecordDate).inDays;
            if (daysSince > 7) {
              generateAlert = true;
              alertTitle = "Plan estancado: $daysSince días sin registros";
              aiRec = "Registra el peso o producción de ${animal.name} para evaluar el progreso de su plan nutricional activo.";
            }
          }
        }

        if (generateAlert) {
          final exists = allAlerts.any((a) => a.animalTag == animal.tag && a.title.startsWith(alertTitle.split(":")[0]));
          if (!exists) {
            allAlerts.add(AlertModel(
              animalName: "${animal.name} (${animal.category})",
              animalTag: animal.tag,
              farm: _profile?['farm_name'] ?? 'Mi Finca',
              detectedAgo: 'Hace unas horas',
              title: alertTitle,
              riskScore: 78,
              symptoms: const ['Plan Activo', 'Falta Seguimiento'],
              aiRecommendation: aiRec,
            ));
          }
        }
      }
    }

    return allAlerts;
  }
  List<Map<String, dynamic>> get vaccines => _vaccines;
  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _isLoading;
  int get activeVetTab => _activeVetTab;
  bool get isOnboardingCompleted => _isOnboardingCompleted;
  bool get isOnboardingShown => _isOnboardingShown;

  List<NutritionResource> get nutritionResources => _nutritionResources;
  List<NutritionPlan> get nutritionPlans => _nutritionPlans;
  List<WeightRecord> get weightRecords => _weightRecords;
  List<ProductionRecord> get productionRecords => _productionRecords;
  List<NutritionRequirement> get nutritionRequirements => _nutritionRequirements;

  List<MarketplaceItem> get marketplaceItems => _marketplaceItems;
  List<MarketplaceItem> get myPublications => _myPublications;
  List<Map<String, dynamic>> get pendingVeterinarians => _pendingVeterinarians;
  List<Map<String, dynamic>> get farmAuthorizations => _farmAuthorizations;

  void setActiveVetTab(int tab) {
    _activeVetTab = tab;
    notifyListeners();
  }

  DataProvider({bool loadInitialData = true}) {
    // Configurar callback para recargar la UI silenciosamente cuando SyncService termine un ciclo
    SyncService.instance.onSyncCompleted = () {
      _reloadMemoryDataOnly();
    };

    if (loadInitialData) {
      loadData();
    } else {
      _isLoading = false;
    }
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _isOnboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
      _isOnboardingShown = prefs.getBool('onboarding_shown') ?? false;

      _profile = await DBHelper.instance.getUserProfile();
      _animals = await DBHelper.instance.getAllAnimals();
      _alerts = await DBHelper.instance.getAllAlerts();
      _vaccines = await DBHelper.instance.getAllVaccines();
      _nutritionResources = await DBHelper.instance.getAllNutritionResources();
      _nutritionPlans = await DBHelper.instance.getAllNutritionPlans();
      _nutritionRequirements = await DBHelper.instance.getAllNutritionRequirements();
      await _loadAllWeightsAndProduction();
      
      final dbMarketplaceItems = await DBHelper.instance.getAllMarketplaceItems();
      _myPublications = dbMarketplaceItems;
      _marketplaceItems = [...dbMarketplaceItems, ...MockData.marketplaceItems];
      
      _farmAuthorizations = await DBHelper.instance.getFarmAuthorizations();
      if (_profile?['role'] == 'Admin') {
        await loadPendingVeterinarians();
      }
      
      if (SupabaseService.instance.isEnabled && SupabaseService.instance.isAuthenticated) {
        SyncService.instance.sync();
      }
    } catch (e) {
      debugPrint("Error loading data from SQLite: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAllWeightsAndProduction() async {
    List<WeightRecord> tempWeights = [];
    List<ProductionRecord> tempProduction = [];
    for (var animal in _animals) {
      final w = await DBHelper.instance.getWeightRecordsForAnimal(animal.id);
      final p = await DBHelper.instance.getProductionRecordsForAnimal(animal.id);
      tempWeights.addAll(w);
      tempProduction.addAll(p);
    }
    _weightRecords = tempWeights;
    _productionRecords = tempProduction;
  }

  // Actualizar Perfil
  Future<void> updateProfile({
    required String ownerName,
    required String farmName,
    required String location,
    required String email,
  }) async {
    final updatedProfile = {
      'id': 1,
      'owner_name': ownerName,
      'farm_name': farmName,
      'location': location,
      'email': email,
    };

    await DBHelper.instance.updateProfile(updatedProfile);
    _profile = updatedProfile;
    notifyListeners();
  }

  // Finalizar Onboarding
  Future<void> completeOnboarding({
    required String ownerName,
    required String farmName,
    required String location,
    required int? animalCount,
    required String role,
    String status = 'active',
    String? licenseNumber,
  }) async {
    await DBHelper.instance.saveUserProfile(
      ownerName: ownerName,
      farmName: farmName,
      location: location,
      animalCount: animalCount,
      role: role,
      status: status,
      licenseNumber: licenseNumber,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    _isOnboardingCompleted = true;
    _profile = await DBHelper.instance.getUserProfile();
    
    // Si hay un usuario autenticado, sincronizar
    if (SupabaseService.instance.isEnabled && SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
    
    notifyListeners();
  }

  // Cerrar Sesión (Resetear Onboarding, limpiar Supabase y SQLite)
  Future<void> logout() async {
    // 1. Cerrar sesión en Supabase
    await SupabaseService.instance.signOut();

    // 2. Limpiar todos los datos locales de SQLite
    await DBHelper.instance.clearAllData();

    // 3. Resetear Onboarding
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', false);
    _isOnboardingCompleted = false;

    // 4. Limpiar variables en memoria
    _animals = [];
    _alerts = [];
    _vaccines = [];
    _profile = null;
    _nutritionResources = [];
    _nutritionPlans = [];
    _weightRecords = [];
    _productionRecords = [];
    _myPublications = [];

    notifyListeners();
  }

  // --- MÉTODOS AUXILIARES DE SUPABASE AUTH ---

  Future<void> loginWithSupabase({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Autenticar en Supabase
      await SupabaseService.instance.signIn(email: email, password: password);

      // 2. Limpiar datos locales (evita mezclar hatos de usuarios diferentes)
      await DBHelper.instance.clearAllData();

      // 3. Configurar onboarding completado
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      _isOnboardingCompleted = true;

      // 4. Descargar todos los datos de la nube
      await SyncService.instance.sync();

      // 5. Cargar datos en memoria
      await loadData();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> registerWithSupabase({
    required String email,
    required String password,
    required String ownerName,
    required String farmName,
    required String location,
    required int? animalCount,
    required String role,
    String? licenseNumber,
    String status = 'active',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Registrar usuario y crear perfil en Supabase
      await SupabaseService.instance.signUp(
        email: email,
        password: password,
        ownerName: ownerName,
        farmName: farmName,
        location: location,
        animalCount: animalCount,
        role: role,
        licenseNumber: licenseNumber,
        status: status,
      );

      // 2. Guardar perfil localmente
      await DBHelper.instance.saveUserProfile(
        ownerName: ownerName,
        farmName: farmName,
        location: location,
        animalCount: animalCount,
        role: role,
        status: status,
        licenseNumber: licenseNumber,
      );

      // 3. Configurar onboarding completado
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      _isOnboardingCompleted = true;

      // 4. Cargar datos
      await loadData();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _reloadMemoryDataOnly() async {
    try {
      _profile = await DBHelper.instance.getUserProfile();
      _animals = await DBHelper.instance.getAllAnimals();
      _alerts = await DBHelper.instance.getAllAlerts();
      _vaccines = await DBHelper.instance.getAllVaccines();
      _nutritionResources = await DBHelper.instance.getAllNutritionResources();
      _nutritionPlans = await DBHelper.instance.getAllNutritionPlans();
      await _loadAllWeightsAndProduction();
      final dbMarketplaceItems = await DBHelper.instance.getAllMarketplaceItems();
      _myPublications = dbMarketplaceItems;
      _marketplaceItems = [...dbMarketplaceItems, ...MockData.marketplaceItems];
      notifyListeners();
    } catch (e) {
      debugPrint("Error al recargar datos en memoria silenciosamente: $e");
    }
  }

  Future<void> setOnboardingShown(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_shown', val);
    _isOnboardingShown = val;
    notifyListeners();
  }

  // Registrar Animal
  Future<void> addAnimal(Animal animal) async {
    await DBHelper.instance.insertAnimal(animal);
    _animals = await DBHelper.instance.getAllAnimals();
    notifyListeners();
    if (SupabaseService.instance.isEnabled && SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  // Actualizar Animal
  Future<void> updateAnimal(Animal animal) async {
    await DBHelper.instance.updateAnimal(animal);
    _animals = await DBHelper.instance.getAllAnimals();
    await _loadAllWeightsAndProduction();
    notifyListeners();
    if (SupabaseService.instance.isEnabled && SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  // Eliminar / Dar de baja Animal
  Future<void> removeAnimal(String id) async {
    await DBHelper.instance.deleteAnimal(id);
    _animals = await DBHelper.instance.getAllAnimals();
    await _loadAllWeightsAndProduction();
    notifyListeners();
    if (SupabaseService.instance.isEnabled && SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  // Registrar Vacuna
  Future<void> addVaccine({
    required String animalId,
    required String name,
    required String dateApplied,
    required String dose,
    String? notes,
  }) async {
    // 1. Insertar la vacuna en la base de datos
    await DBHelper.instance.insertVaccine({
      'animal_id': animalId,
      'name': name,
      'date_applied': dateApplied,
      'dose': dose,
      'notes': notes,
    });

    // 2. Formatear la fecha para la visualización (ej: "14 Jun")
    final formattedDate = _formatDateString(dateApplied);

    // 3. Obtener el animal correspondiente para actualizar su estado de vacuna
    final animalIndex = _animals.indexWhere((a) => a.id == animalId);
    if (animalIndex != -1) {
      final animal = _animals[animalIndex];
      
      // Si el animal tenía alerta por vacuna vencida, la removemos.
      // E.g., si el animal es Tormenta (#0089)
      bool hasAlert = animal.hasAlert;
      if (animal.vaccineStatus == 'Vencida') {
        hasAlert = false;
        // Eliminar alerta física de la tabla de alertas
        await DBHelper.instance.deleteAlertByTag(animal.tag, 'Vacuna Vencida');
      }

      await DBHelper.instance.updateAnimalVaccineStatus(animalId, formattedDate, hasAlert);
    }

    // 4. Recargar datos de la base de datos para asegurar consistencia
    _animals = await DBHelper.instance.getAllAnimals();
    _alerts = await DBHelper.instance.getAllAlerts();
    _vaccines = await DBHelper.instance.getAllVaccines();
    notifyListeners();
    if (SupabaseService.instance.isEnabled && SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  // Notificar al Veterinario para actualizar vacuna
  Future<void> sendVaccineNotification(Animal animal) async {
    final newAlert = AlertModel(
      animalName: "${animal.name} (${animal.category})",
      animalTag: animal.tag,
      farm: _profile?['farm_name'] ?? 'Mi Finca',
      detectedAgo: 'Hace un momento',
      title: 'Vacunación Solicitada: ${animal.vaccineStatus ?? "Vencida"}',
      riskScore: 80,
      symptoms: const ['Pendiente', 'Solicitado por propietario'],
      aiRecommendation: 'El propietario ha solicitado actualizar la vacuna de ${animal.name} (${animal.tag}). Por favor, programe una visita para su aplicación.',
    );

    await DBHelper.instance.insertAlert(newAlert);

    // Actualizar el estado de alerta del animal a true para reflejar la solicitud activa
    await DBHelper.instance.updateAnimalVaccineStatus(animal.id, animal.vaccineStatus, true);

    // Recargar datos para actualizar la UI en toda la aplicación
    _animals = await DBHelper.instance.getAllAnimals();
    _alerts = await DBHelper.instance.getAllAlerts();
    notifyListeners();
    if (SupabaseService.instance.isEnabled && SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  // Ayudante para formatear "2026-06-14" a "14 Jun"
  String _formatDateString(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final day = int.parse(parts[2]);
        final month = int.parse(parts[1]);
        const months = [
          'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
          'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
        ];
        return '$day ${months[month - 1]}';
      }
    } catch (_) {}
    return dateStr;
  }

  // --- MÉTODOS DE NUTRICIÓN ---

  Future<void> saveNutritionResource({
    int? id,
    required String type,
    required String name,
    required double amount,
    required String unit,
    double? cost,
    String? availability,
    String? expirationDate,
    String? observations,
  }) async {
    final resource = NutritionResource(
      id: id,
      type: type,
      name: name,
      amount: amount,
      unit: unit,
      updatedAt: DateTime.now().toIso8601String(),
      cost: cost,
      availability: availability,
      expirationDate: expirationDate,
      observations: observations,
    );
    if (id == null) {
      await DBHelper.instance.insertNutritionResource(resource);
    } else {
      await DBHelper.instance.updateNutritionResource(resource);
    }
    _nutritionResources = await DBHelper.instance.getAllNutritionResources();
    notifyListeners();
    if (SupabaseService.instance.isEnabled && SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  Future<void> removeNutritionResource(int id) async {
    await DBHelper.instance.deleteNutritionResource(id);
    _nutritionResources = await DBHelper.instance.getAllNutritionResources();
    notifyListeners();
    if (SupabaseService.instance.isEnabled && SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  Future<void> addNutritionPlan({
    required String targetGroup,
    required String suggestedDiet,
    required double estimatedCostPerDay,
    required double projectedSavings,
    required String projectedImprovement,
    required String explanation,
    String? rawResponse,
  }) async {
    final plan = NutritionPlan(
      createdAt: DateTime.now().toIso8601String(),
      targetGroup: targetGroup,
      suggestedDiet: suggestedDiet,
      estimatedCostPerDay: estimatedCostPerDay,
      projectedSavings: projectedSavings,
      projectedImprovement: projectedImprovement,
      explanation: explanation,
      status: 'Activo',
      rawResponse: rawResponse,
    );
    await DBHelper.instance.insertNutritionPlan(plan);
    _nutritionPlans = await DBHelper.instance.getAllNutritionPlans();
    notifyListeners();
    if (SupabaseService.instance.isEnabled && SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  Future<void> saveNutritionRequirement(NutritionRequirement req) async {
    await DBHelper.instance.upsertNutritionRequirement(req);
    _nutritionRequirements = await DBHelper.instance.getAllNutritionRequirements();
    notifyListeners();
  }

  Future<void> updatePlanStatus(int id, String status) async {
    await DBHelper.instance.updateNutritionPlanStatus(id, status);
    _nutritionPlans = await DBHelper.instance.getAllNutritionPlans();
    notifyListeners();
    if (SupabaseService.instance.isEnabled && SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  Future<void> addWeightRecord({
    required String animalId,
    required double weightKg,
    String? date,
  }) async {
    final record = WeightRecord(
      date: date ?? DateTime.now().toIso8601String(),
      animalId: animalId,
      weightKg: weightKg,
    );
    await DBHelper.instance.insertWeightRecord(record);
    await DBHelper.instance.updateAnimalWeight(animalId, weightKg);
    _animals = await DBHelper.instance.getAllAnimals();
    await _loadAllWeightsAndProduction();
    notifyListeners();
    if (SupabaseService.instance.isEnabled && SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  Future<ProductionRecord> addProductionRecord({
    required String animalId,
    required double liters,
    String? turn,
    String? observation,
    String? date,
  }) async {
    final record = ProductionRecord(
      date: date ?? DateTime.now().toIso8601String(),
      animalId: animalId,
      liters: liters,
      turn: turn,
      observation: observation,
    );
    await DBHelper.instance.insertProductionRecord(record);
    
    // Formatear y actualizar la producción de la ficha del animal
    final formattedProd = '${liters.toStringAsFixed(1)} L/dia';
    await DBHelper.instance.updateAnimalProduction(animalId, formattedProd);
    
    _animals = await DBHelper.instance.getAllAnimals();
    await _loadAllWeightsAndProduction();
    notifyListeners();
    if (SupabaseService.instance.isEnabled && SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
    return record;
  }

  // --- SERVICIO DE IA NUTRICIONAL ---
  final NutritionAiService _nutritionAiService = RemoteNutritionAiService();

  Future<NutritionPlanResult> generateNutritionPlan({
    required List<Animal> targetAnimals,
    bool includeCalvingStatus = false,
    bool includeForage = false,
    bool includeSupplements = false,
    String? photoPath,
  }) async {
    final reqs = DeterministicNutritionEngine.calculateHerdRequirements(
      animals: targetAnimals,
      requirements: _nutritionRequirements,
      includeCalvingStatus: includeCalvingStatus,
    );

    return await _nutritionAiService.generatePlan(
      resources: _nutritionResources,
      targetAnimals: targetAnimals,
      planHistory: _nutritionPlans,
      weightHistory: _weightRecords,
      productionHistory: _productionRecords,
      includeCalvingStatus: includeCalvingStatus,
      includeForage: includeForage,
      includeSupplements: includeSupplements,
      photoPath: photoPath,
      calculatedRequirements: reqs,
    );
  }

  Future<void> publishMarketplaceItem({
    required String title,
    required double price,
    required String category,
    String? weight,
    String? production,
    bool negotiable = false,
    required String location,
    List<String> imagePaths = const [],
    String description = '',
    int score = 95,
    String badge = 'Verificado',
    String? areteSisa,
    String? cvmState = 'none',
    bool sisaVerified = false,
    bool vacunasAlDia = false,
    bool historialCompleto = false,
    bool fotosCalidad = false,
  }) async {
    final newItem = MarketplaceItem(
      title: title,
      price: price,
      category: category,
      weight: weight,
      production: production,
      negotiable: negotiable,
      location: location,
      score: score,
      badge: badge,
      responseTime: '< 5 min',
      certified: sisaVerified && vacunasAlDia,
      imagePaths: imagePaths,
      description: description,
      areteSisa: areteSisa,
      cvmState: cvmState,
      sisaVerified: sisaVerified,
      vacunasAlDia: vacunasAlDia,
      historialCompleto: historialCompleto,
      fotosCalidad: fotosCalidad,
    );
    
    await DBHelper.instance.insertMarketplaceItem(newItem);
    final dbMarketplaceItems = await DBHelper.instance.getAllMarketplaceItems();
    _myPublications = dbMarketplaceItems;
    _marketplaceItems = [...dbMarketplaceItems, ...MockData.marketplaceItems];
    notifyListeners();

    if (SupabaseService.instance.isEnabled && SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  Future<void> saveListingDraft(String draftJson) async {
    await DBHelper.instance.saveDraft(draftJson);
  }

  Future<String?> getListingDraft() async {
    return await DBHelper.instance.getDraft();
  }

  Future<void> deleteListingDraft() async {
    await DBHelper.instance.deleteDraft();
  }

  // --- ACCIONES EXCLUSIVAS DE ADMINISTRADOR ---
  Future<void> loadPendingVeterinarians() async {
    if (SupabaseService.instance.isEnabled) {
      _pendingVeterinarians = await SupabaseService.instance.getPendingVeterinarians();
      notifyListeners();
    }
  }

  Future<void> approveVeterinarian(String userId) async {
    if (SupabaseService.instance.isEnabled) {
      await SupabaseService.instance.updateVeterinarianStatus(userId, 'active');
      await loadPendingVeterinarians();
    }
  }

  Future<void> rejectVeterinarian(String userId) async {
    if (SupabaseService.instance.isEnabled) {
      await SupabaseService.instance.updateVeterinarianStatus(userId, 'rejected');
      await loadPendingVeterinarians();
    }
  }

  // --- ACCIONES DE AUTORIZACIONES DE FINCAS ---
  Future<void> loadFarmAuthorizations() async {
    _farmAuthorizations = await DBHelper.instance.getFarmAuthorizations();
    notifyListeners();

    if (SupabaseService.instance.isEnabled && SupabaseService.instance.isAuthenticated) {
      try {
        final remoteAuths = await SupabaseService.instance.fetchRemoteFarmAuthorizations();
        await DBHelper.instance.clearFarmAuthorizations();
        for (var auth in remoteAuths) {
          await DBHelper.instance.saveFarmAuthorization(auth);
        }
        _farmAuthorizations = await DBHelper.instance.getFarmAuthorizations();
        notifyListeners();
      } catch (e) {
        debugPrint("Error al cargar y refrescar autorizaciones: $e");
      }
    }
  }

  Future<void> requestFarmAccess(String ganaderoEmail) async {
    if (SupabaseService.instance.isEnabled) {
      await SupabaseService.instance.requestFarmAuthorization(ganaderoEmail);
      await loadFarmAuthorizations();
    }
  }

  Future<void> respondToAccessRequest(String authId, String status) async {
    if (SupabaseService.instance.isEnabled) {
      await SupabaseService.instance.respondToAuthorizationRequest(authId, status);
      await loadFarmAuthorizations();
      // Forzar ciclo de sincronización para actualizar los animales disponibles localmente
      await SyncService.instance.sync();
    }
  }
}

