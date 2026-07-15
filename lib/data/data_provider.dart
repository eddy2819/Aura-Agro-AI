import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
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
import '../services/health_alert_engine.dart';
import '../services/notification_service.dart';

class DataProvider extends ChangeNotifier {
  bool _syncScheduled = false;
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

  // Nuevas tablas MVP
  List<Map<String, dynamic>> _sosCases = [];
  List<Map<String, dynamic>> _animalExits = [];
  List<Map<String, dynamic>> _medicines = [];
  List<Map<String, dynamic>> _medicineMovements = [];
  List<Map<String, dynamic>> _medicalTreatments = [];
  List<Map<String, dynamic>> _reproductionRecords = [];
  List<Map<String, dynamic>> _operatingExpenses = [];
  List<Map<String, dynamic>> _vetFarmLinks = [];
  List<Map<String, dynamic>> _clinicalCaseChats = [];
  List<Map<String, dynamic>> _clinicalCaseMessages = [];
  List<Map<String, dynamic>> _vetVisits = [];
  List<Map<String, dynamic>> _vetValidations = [];

  List<Map<String, dynamic>> get sosCases => _sosCases;
  List<Map<String, dynamic>> get animalExits => _animalExits;
  List<Map<String, dynamic>> get medicines => _medicines;
  List<Map<String, dynamic>> get medicineMovements => _medicineMovements;
  List<Map<String, dynamic>> get medicalTreatments => _medicalTreatments;
  List<Map<String, dynamic>> get reproductionRecords => _reproductionRecords;
  List<Map<String, dynamic>> get operatingExpenses => _operatingExpenses;
  List<Map<String, dynamic>> get vetFarmLinks => _vetFarmLinks;
  List<Map<String, dynamic>> get clinicalCaseChats => _clinicalCaseChats;
  List<Map<String, dynamic>> get clinicalCaseMessages => _clinicalCaseMessages;
  List<Map<String, dynamic>> get vetVisits => _vetVisits;
  List<Map<String, dynamic>> get vetValidations => _vetValidations;

  List<Animal> get animals => _animals;
  List<AlertModel> get alerts {
    final allAlerts = List<AlertModel>.from(_alerts);

    // Alertas dinámicas de nutrición
    final activePlans = _nutritionPlans
        .where((p) => p.status == 'Activo')
        .toList();
    for (var plan in activePlans) {
      List<Animal> coveredAnimals = [];
      if (plan.targetGroup == 'Todo el Hato') {
        coveredAnimals = _animals;
      } else {
        coveredAnimals = _animals
            .where(
              (a) =>
                  a.category == plan.targetGroup ||
                  a.id == plan.targetGroup ||
                  a.name == plan.targetGroup,
            )
            .toList();
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

        if (analysis.complianceScore < 0.75 &&
            !analysis.feedbackNote.contains("No se encontraron")) {
          generateAlert = true;
          alertTitle =
              "Bajo rendimiento de plan: ${(analysis.complianceScore * 100).toStringAsFixed(0)}%";
          aiRec =
              "El animal ${animal.name} está rindiendo por debajo de la meta del plan nutricional. Revisa si está consumiendo la ración completa o ajusta los recursos.";
        }

        if (!generateAlert) {
          DateTime? lastRecordDate;
          if (animal.category == 'Vaca Lechera') {
            final animalProds = _productionRecords
                .where((r) => r.animalId == animal.id)
                .toList();
            if (animalProds.isNotEmpty) {
              animalProds.sort((a, b) => b.date.compareTo(a.date));
              lastRecordDate = DateTime.tryParse(animalProds.first.date);
            }
          } else {
            final animalWeights = _weightRecords
                .where((r) => r.animalId == animal.id)
                .toList();
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
              aiRec =
                  "Registra el peso o producción de ${animal.name} para evaluar el progreso de su plan nutricional activo.";
            }
          }
        }

        if (generateAlert) {
          final exists = allAlerts.any(
            (a) =>
                a.animalTag == animal.tag &&
                a.title.startsWith(alertTitle.split(":")[0]),
          );
          if (!exists) {
            allAlerts.add(
              AlertModel(
                id: 'alert_nut_${animal.id}_${DateTime.now().millisecondsSinceEpoch}',
                animalId: animal.id,
                animalName: "${animal.name} (${animal.category})",
                animalTag: animal.tag,
                type: 'nutrition',
                riskLevel: 'amarillo',
                title: alertTitle,
                description: 'Plan Activo, Falta Seguimiento : $aiRec',
                source: _profile?['farm_name'] ?? 'Mi Finca',
                createdAt: DateTime.now().toIso8601String(),
              ),
            );
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
  List<NutritionRequirement> get nutritionRequirements =>
      _nutritionRequirements;

  List<MarketplaceItem> get marketplaceItems => _marketplaceItems;
  List<MarketplaceItem> get myPublications => _myPublications;

  List<MarketplaceItem> _ownedMarketplaceItems(List<MarketplaceItem> items) {
    final userId = SupabaseService.instance.currentUserId;
    return items.where((item) {
      if (item.sellerUserId == null) return true;
      return userId != null && item.sellerUserId == userId;
    }).toList();
  }

  List<MarketplaceItem> _visibleMarketplaceItems(
    List<MarketplaceItem> persistedItems,
  ) {
    if (SupabaseService.instance.isAuthenticated) return persistedItems;
    return [...persistedItems, ...MockData.marketplaceItems];
  }

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

  void _scheduleSync() {
    if (_syncScheduled ||
        !SupabaseService.instance.isEnabled ||
        !SupabaseService.instance.isAuthenticated) {
      return;
    }
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      unawaited(
        SyncService.instance.sync().catchError((
          Object error,
          StackTrace stack,
        ) {
          debugPrint('Error de sincronización en segundo plano: $error');
        }),
      );
    });
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
      _nutritionRequirements = await DBHelper.instance
          .getAllNutritionRequirements();
      await _loadAllWeightsAndProduction();

      // Cargar nuevas tablas MVP
      _sosCases = await DBHelper.instance.getAllSosCases();
      _animalExits = await DBHelper.instance.getAllAnimalExits();
      _medicines = await DBHelper.instance.getAllMedicines();
      _medicineMovements = await DBHelper.instance.getMedicineMovements();
      _medicalTreatments = await DBHelper.instance.getAllMedicalTreatments();
      _reproductionRecords = await DBHelper.instance
          .getAllReproductionRecords();
      _operatingExpenses = await DBHelper.instance.getAllOperatingExpenses();
      await _loadClinicalCollaborationData();

      final dbMarketplaceItems = await DBHelper.instance
          .getAllMarketplaceItems();
      _myPublications = _ownedMarketplaceItems(dbMarketplaceItems);
      _marketplaceItems = _visibleMarketplaceItems(dbMarketplaceItems);

      _farmAuthorizations = await DBHelper.instance.getFarmAuthorizations();
      if (_profile?['role'] == 'Admin') {
        await loadPendingVeterinarians();
      }

      if (SupabaseService.instance.isEnabled &&
          SupabaseService.instance.isAuthenticated) {
        await SupabaseService.instance.startMarketplaceNotificationListener((
          notification,
        ) {
          final type = notification['notification_type'] == 'offer'
              ? 'Nueva oferta'
              : 'Nuevo mensaje';
          unawaited(
            NotificationService.instance.showInstantNotification(
              id: notification['id'].toString().hashCode & 0x7fffffff,
              title: '$type en Marketplace',
              body:
                  '${notification['listing_title']}: ${notification['message']}',
              payload: 'marketplace:${notification['marketplace_local_id']}',
            ),
          );
        });
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
      final p = await DBHelper.instance.getProductionRecordsForAnimal(
        animal.id,
      );
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
    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }

    notifyListeners();
  }

  // Cerrar Sesión (Resetear Onboarding, limpiar Supabase y SQLite)
  Future<void> logout() async {
    // 1. Forzar una sincronización final para asegurar que los datos locales suban antes de limpiar la base de datos
    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
      try {
        await SyncService.instance.sync();
      } catch (e) {
        debugPrint("Error in final sync during logout: $e");
      }
    }

    await SupabaseService.instance.stopMarketplaceNotificationListener();

    // 2. Cerrar sesión en Supabase
    await SupabaseService.instance.signOut();

    // 3. Limpiar todos los datos locales de SQLite
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

      _sosCases = await DBHelper.instance.getAllSosCases();
      _animalExits = await DBHelper.instance.getAllAnimalExits();
      _medicines = await DBHelper.instance.getAllMedicines();
      _medicineMovements = await DBHelper.instance.getMedicineMovements();
      _medicalTreatments = await DBHelper.instance.getAllMedicalTreatments();
      _reproductionRecords = await DBHelper.instance
          .getAllReproductionRecords();
      _operatingExpenses = await DBHelper.instance.getAllOperatingExpenses();
      await _loadClinicalCollaborationData();

      final dbMarketplaceItems = await DBHelper.instance
          .getAllMarketplaceItems();
      _myPublications = _ownedMarketplaceItems(dbMarketplaceItems);
      _marketplaceItems = _visibleMarketplaceItems(dbMarketplaceItems);
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
    final stopwatch = Stopwatch()..start();
    await DBHelper.instance.insertAnimal(animal);
    _animals = await DBHelper.instance.getAllAnimals();
    await _syncAnimalMarketplaceListing(animal);
    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds > 16) {
      debugPrint(
        'Rendimiento addAnimal local: ${stopwatch.elapsedMilliseconds} ms',
      );
    }
    notifyListeners();
    _scheduleSync();
  }

  // Actualizar Animal
  Future<void> updateAnimal(Animal animal) async {
    await DBHelper.instance.updateAnimal(animal);
    _animals = await DBHelper.instance.getAllAnimals();
    await _syncAnimalMarketplaceListing(animal);
    await _loadAllWeightsAndProduction();
    notifyListeners();
    _scheduleSync();
  }

  Future<void> _syncAnimalMarketplaceListing(Animal animal) async {
    if (!animal.availableForSale) {
      await DBHelper.instance.deleteMarketplaceItemForAnimal(animal.id);
    } else {
      final photos = <String>{
        if (animal.imagePath?.isNotEmpty == true) animal.imagePath!,
        if (animal.imageFrontPath?.isNotEmpty == true) animal.imageFrontPath!,
        if (animal.imageSidePath?.isNotEmpty == true) animal.imageSidePath!,
      }.toList();
      final vaccineText = animal.vaccineStatus?.toLowerCase() ?? '';
      final vaccinesCurrent =
          vaccineText.isNotEmpty &&
          !vaccineText.contains('vencid') &&
          !vaccineText.contains('pendiente');
      final hasTraceability = animal.tag.trim().isNotEmpty;
      final price = animal.purchaseValue != null && animal.purchaseValue! > 0
          ? animal.purchaseValue!
          : (animal.weightKg * 2.5).clamp(1, double.infinity).toDouble();
      final locationParts = [
        animal.finca,
        animal.lote,
      ].where((value) => value.trim().isNotEmpty).toList();

      await DBHelper.instance.upsertMarketplaceItemForAnimal(
        MarketplaceItem(
          title: '${animal.name} · ${animal.category}',
          score: animal.score.clamp(0, 100),
          badge: hasTraceability ? 'Trazable' : 'Disponible',
          price: price,
          negotiable: true,
          weight: '${animal.weightKg.toStringAsFixed(0)} kg',
          production: animal.productionLiters,
          location: locationParts.isEmpty
              ? 'Ubicación por confirmar'
              : locationParts.join(' · '),
          responseTime: '< 5 min',
          certified: hasTraceability && vaccinesCurrent,
          category: 'Ganado',
          imagePaths: photos,
          description: [
            animal.description,
            'Raza: ${animal.breed}',
            'Sexo: ${animal.sex}',
            'Propósito: ${animal.purpose}',
            'Estado sanitario: ${animal.healthStatus}',
          ].where((value) => value.trim().isNotEmpty).join('\n'),
          areteSisa: animal.tag,
          cvmState: hasTraceability ? 'verified' : 'none',
          sisaVerified: hasTraceability,
          vacunasAlDia: vaccinesCurrent,
          historialCompleto: animal.weightKg > 0 && animal.birthDate.isNotEmpty,
          fotosCalidad: photos.isNotEmpty,
          sourceAnimalId: animal.id,
          sellerUserId: SupabaseService.instance.currentUserId,
        ),
      );
    }

    final dbMarketplaceItems = await DBHelper.instance.getAllMarketplaceItems();
    _myPublications = _ownedMarketplaceItems(dbMarketplaceItems);
    _marketplaceItems = _visibleMarketplaceItems(dbMarketplaceItems);
  }

  // Eliminar / Dar de baja Animal
  Future<void> removeAnimal(String id) async {
    await DBHelper.instance.deleteAnimal(id);
    await DBHelper.instance.deleteMarketplaceItemForAnimal(id);
    _animals = await DBHelper.instance.getAllAnimals();
    final dbMarketplaceItems = await DBHelper.instance.getAllMarketplaceItems();
    _myPublications = _ownedMarketplaceItems(dbMarketplaceItems);
    _marketplaceItems = _visibleMarketplaceItems(dbMarketplaceItems);
    await _loadAllWeightsAndProduction();
    notifyListeners();
    _scheduleSync();
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

      await DBHelper.instance.updateAnimalVaccineStatus(
        animalId,
        formattedDate,
        hasAlert,
      );
    }

    // 4. Recargar datos de la base de datos para asegurar consistencia
    _animals = await DBHelper.instance.getAllAnimals();
    _alerts = await DBHelper.instance.getAllAlerts();
    _vaccines = await DBHelper.instance.getAllVaccines();
    notifyListeners();
    _scheduleSync();
  }

  // Notificar al Veterinario para actualizar vacuna
  Future<void> sendVaccineNotification(Animal animal) async {
    final newAlert = AlertModel(
      id: 'alert_vac_${animal.id}_${DateTime.now().millisecondsSinceEpoch}',
      animalId: animal.id,
      animalName: "${animal.name} (${animal.category})",
      animalTag: animal.tag,
      type: 'health',
      riskLevel: 'amarillo',
      title: 'Vacunación Solicitada: ${animal.vaccineStatus ?? "Vencida"}',
      description:
          'Pendiente, Solicitado por propietario : El propietario ha solicitado actualizar la vacuna de ${animal.name} (${animal.tag}). Por favor, programe una visita para su aplicación.',
      source: _profile?['farm_name'] ?? 'Mi Finca',
      createdAt: DateTime.now().toIso8601String(),
    );

    await DBHelper.instance.insertAlert(newAlert);

    // Actualizar el estado de alerta del animal a true para reflejar la solicitud activa
    await DBHelper.instance.updateAnimalVaccineStatus(
      animal.id,
      animal.vaccineStatus,
      true,
    );

    // Recargar datos para actualizar la UI en toda la aplicación
    _animals = await DBHelper.instance.getAllAnimals();
    _alerts = await DBHelper.instance.getAllAlerts();
    notifyListeners();
    _scheduleSync();
  }

  // Ayudante para formatear "2026-06-14" a "14 Jun"
  String _formatDateString(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final day = int.parse(parts[2]);
        final month = int.parse(parts[1]);
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
    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  Future<void> removeNutritionResource(int id) async {
    await DBHelper.instance.deleteNutritionResource(id);
    _nutritionResources = await DBHelper.instance.getAllNutritionResources();
    notifyListeners();
    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
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
    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  Future<void> saveNutritionRequirement(NutritionRequirement req) async {
    await DBHelper.instance.upsertNutritionRequirement(req);
    _nutritionRequirements = await DBHelper.instance
        .getAllNutritionRequirements();
    notifyListeners();
  }

  Future<void> updatePlanStatus(int id, String status) async {
    await DBHelper.instance.updateNutritionPlanStatus(id, status);
    _nutritionPlans = await DBHelper.instance.getAllNutritionPlans();
    notifyListeners();
    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
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
    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
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
    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
    return record;
  }

  // --- SERVICIO DE IA NUTRICIONAL ---
  final NutritionAiService _nutritionAiService = RemoteNutritionAiService();

  Future<NutritionPlanResult> generateNutritionPlan({
    required List<Animal> targetAnimals,
    List<NutritionResource>? selectedResources,
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
      resources: selectedResources ?? _nutritionResources,
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
      sellerUserId: SupabaseService.instance.currentUserId,
    );

    await DBHelper.instance.insertMarketplaceItem(newItem);
    final dbMarketplaceItems = await DBHelper.instance.getAllMarketplaceItems();
    _myPublications = _ownedMarketplaceItems(dbMarketplaceItems);
    _marketplaceItems = _visibleMarketplaceItems(dbMarketplaceItems);
    notifyListeners();

    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  Future<void> updateMarketplaceItem(MarketplaceItem item) async {
    await DBHelper.instance.updateMarketplaceItem(item);
    final persisted = await DBHelper.instance.getAllMarketplaceItems();
    _myPublications = _ownedMarketplaceItems(persisted);
    _marketplaceItems = _visibleMarketplaceItems(persisted);
    notifyListeners();
    _scheduleSync();
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
      _pendingVeterinarians = await SupabaseService.instance
          .getPendingVeterinarians();
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
      await SupabaseService.instance.updateVeterinarianStatus(
        userId,
        'rejected',
      );
      await loadPendingVeterinarians();
    }
  }

  // --- ACCIONES DE AUTORIZACIONES DE FINCAS ---
  Future<void> loadFarmAuthorizations() async {
    _farmAuthorizations = await DBHelper.instance.getFarmAuthorizations();
    notifyListeners();

    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
      try {
        final remoteAuths = await SupabaseService.instance
            .fetchRemoteFarmAuthorizations();
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
      await SupabaseService.instance.respondToAuthorizationRequest(
        authId,
        status,
      );
      await loadFarmAuthorizations();
      // Forzar ciclo de sincronización para actualizar los animales disponibles localmente
      await SyncService.instance.sync();
    }
  }

  // --- MÉTODOS MVP Y LOGICA DE NEGOCIO ---

  Future<void> _loadClinicalCollaborationData() async {
    final db = DBHelper.instance;
    _vetFarmLinks = await db.getClinicalRecords('vet_farm_links');
    _clinicalCaseChats = await db.getClinicalRecords('clinical_case_chats');
    _clinicalCaseMessages = await db.getClinicalRecords(
      'clinical_case_messages',
      orderBy: 'created_at ASC',
    );
    _vetVisits = await db.getClinicalRecords('vet_visits');
    _vetValidations = await db.getClinicalRecords('vet_validations');
  }

  String _clinicalId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}';

  Future<void> inviteVeterinarian({
    required String vetId,
    required String farmId,
    required List<String> permissions,
  }) async {
    final farmerId = SupabaseService.instance.currentUserId ?? 'local_farmer';
    final resolvedVetId =
        await SupabaseService.instance.resolveApprovedVeterinarian(vetId) ??
        vetId.trim();
    final now = DateTime.now().toIso8601String();
    await DBHelper.instance.upsertClinicalRecord('vet_farm_links', {
      'id': _clinicalId('vfl'),
      'farmer_id': farmerId,
      'vet_id': resolvedVetId,
      'farm_id': farmId,
      'status': 'pending',
      'permissions': jsonEncode(permissions),
      'created_at': now,
      'updated_at': now,
      'expires_at': null,
      'synced': 0,
    });
    await _loadClinicalCollaborationData();
    notifyListeners();
    _scheduleSync();
  }

  Future<void> updateVetFarmLinkStatus(String id, String status) async {
    final current = _vetFarmLinks.firstWhere((row) => row['id'] == id);
    await DBHelper.instance.upsertClinicalRecord('vet_farm_links', {
      ...current,
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
      'synced': 0,
    }, action: 'UPDATE');
    await _loadClinicalCollaborationData();
    notifyListeners();
    _scheduleSync();
  }

  Map<String, dynamic>? acceptedVetLink({String? farmId}) {
    for (final link in _vetFarmLinks) {
      if (link['status'] == 'accepted' &&
          (farmId == null || link['farm_id'] == farmId))
        return link;
    }
    return null;
  }

  Future<Map<String, dynamic>?> createChatForSosCase(
    Map<String, dynamic> sosCase,
  ) async {
    final farmId =
        sosCase['farm_id']?.toString() ??
        _profile?['farm_id']?.toString() ??
        _profile?['farm_name']?.toString() ??
        'default_farm';
    final link = acceptedVetLink(farmId: farmId) ?? acceptedVetLink();
    if (link == null) return null;
    final existing = _clinicalCaseChats.where(
      (c) => c['case_id'] == sosCase['id'],
    );
    if (existing.isNotEmpty) return existing.first;
    final now = DateTime.now().toIso8601String();
    final risk = sosCase['risk_level']?.toString().toLowerCase() ?? 'green';
    final chat = <String, dynamic>{
      'id': _clinicalId('chat'),
      'case_id': sosCase['id'],
      'animal_id': sosCase['animal_id'],
      'farm_id': farmId,
      'farmer_id': link['farmer_id'],
      'vet_id': link['vet_id'],
      'status': 'waiting_vet',
      'priority': risk == 'rojo'
          ? 'urgent'
          : (risk == 'amarillo' ? 'yellow' : 'green'),
      'created_at': now,
      'updated_at': now,
      'closed_at': null,
      'synced': 0,
    };
    await DBHelper.instance.upsertClinicalRecord('clinical_case_chats', chat);
    await sendClinicalMessage(
      chatId: chat['id'] as String,
      caseId: sosCase['id'] as String,
      message:
          'AURA organizó la información para el veterinario. Riesgo: ${sosCase['risk_level']}. Síntomas: ${sosCase['symptoms_text'] ?? sosCase['selected_symptoms'] ?? 'sin detalle'}. Contacte al veterinario y evite automedicar.',
      senderRole: 'AURA',
      messageType: 'ai_summary',
      aiGenerated: true,
    );
    await _loadClinicalCollaborationData();
    notifyListeners();
    return chat;
  }

  Future<void> sendClinicalMessage({
    required String chatId,
    required String message,
    String? caseId,
    String messageType = 'text',
    String? mediaPath,
    String? senderRole,
    bool aiGenerated = false,
  }) async {
    if (message.trim().isEmpty && mediaPath == null) return;
    final currentUser = SupabaseService.instance.currentUserId ?? 'local_user';
    final role = senderRole ?? _profile?['role']?.toString() ?? 'Ganadero';
    await DBHelper.instance.upsertClinicalRecord('clinical_case_messages', {
      'id': _clinicalId('msg'),
      'chat_id': chatId,
      'case_id': caseId,
      'sender_id': aiGenerated ? 'aura_ai' : currentUser,
      'sender_role': role,
      'message_type': messageType,
      'message': message,
      'media_path': mediaPath,
      'ai_generated': aiGenerated ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
      'synced': 0,
    });
    await _loadClinicalCollaborationData();
    notifyListeners();
    _scheduleSync();
  }

  Future<void> addVetVisit(Map<String, dynamic> visit) async {
    final now = DateTime.now().toIso8601String();
    visit.addAll({
      'id': visit['id'] ?? _clinicalId('visit'),
      'created_at': visit['created_at'] ?? now,
      'updated_at': now,
      'synced': 0,
    });
    await DBHelper.instance.upsertClinicalRecord('vet_visits', visit);
    await _loadClinicalCollaborationData();
    notifyListeners();
    _scheduleSync();
  }

  Future<void> addVetValidation(Map<String, dynamic> validation) async {
    final now = DateTime.now().toIso8601String();
    validation.addAll({
      'id': validation['id'] ?? _clinicalId('validation'),
      'created_at': validation['created_at'] ?? now,
      'updated_at': now,
      'synced': 0,
    });
    await DBHelper.instance.upsertClinicalRecord('vet_validations', validation);
    await _loadClinicalCollaborationData();
    notifyListeners();
    _scheduleSync();
  }

  Future<void> addSosCase(Map<String, dynamic> row) async {
    final db = DBHelper.instance;
    await db.insertSosCase(row);

    final risk = row['risk_level']?.toString().toLowerCase();
    if (risk == 'rojo' || risk == 'amarillo') {
      await createChatForSosCase(row);
    }

    // Si el caso es rojo, generar una alerta sanitaria crítica instantánea
    if (row['risk_level'] == 'rojo') {
      final animal = _animals.firstWhere(
        (a) => a.id == row['animal_id'],
        orElse: () => _animals.first,
      );
      final alertId = "sos_alert_${row['id']}";

      final alert = AlertModel(
        id: alertId,
        animalId: animal.id,
        animalName: animal.name,
        animalTag: animal.tag,
        type: 'sos',
        riskLevel: 'rojo',
        title: 'CRÍTICO: SOS - ${row['title']}',
        description:
            row['explanation'] as String? ?? 'Atención inmediata requerida.',
        source: 'Aura SOS',
        createdAt: DateTime.now().toIso8601String(),
      );

      await db.insertAlert(alert);

      // Mostrar notificación local instantánea
      await NotificationService.instance.showInstantNotification(
        id: row['id'].hashCode,
        title: '🔴 EMERGENCIAS AURA SOS: ${animal.name}',
        body: acceptedVetLink() == null
            ? 'Riesgo crítico detectado. Contacta a un veterinario de inmediato.'
            : 'Riesgo crítico detectado y caso preparado para el veterinario autorizado.',
        payload: alertId,
      );
    }

    await HealthAlertEngine.instance.runEngine();
    await _reloadMemoryDataOnly();

    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  Future<void> addAnimalExit(Map<String, dynamic> row) async {
    final db = DBHelper.instance;
    await db.insertAnimalExit(row);

    // Buscar y actualizar el estado de salud y estado general del animal
    final animalId = row['animal_id'] as String;
    final animal = _animals.firstWhere((a) => a.id == animalId);

    String newStatus = 'Inactivo';
    final exitType = row['exit_type'].toString().toLowerCase();
    if (exitType == 'venta')
      newStatus = 'Vendido';
    else if (exitType == 'muerte')
      newStatus = 'Fallecido';
    else if (exitType == 'descarte')
      newStatus = 'Descartado';
    else if (exitType == 'traslado')
      newStatus = 'Trasladado';

    final updatedAnimal = animal.copyWith(status: newStatus);
    await db.updateAnimal(updatedAnimal);

    // Si fue venta, registrar automáticamente un ingreso financiero positivo
    if (exitType == 'venta') {
      final double price = (row['sale_price'] as num?)?.toDouble() ?? 0.0;
      await addOperatingExpense({
        'id': 'inc_${row['id']}',
        'category': 'Ventas de animales',
        'amount': price, // Monto positivo representa ingreso
        'date': row['exit_date'],
        'description':
            "Venta de animal ${animal.name} (${animal.tag}). Comprador: ${row['buyer'] ?? 'N/D'}",
        'animal_id': animalId,
        'farm_id': _profile?['farm_name'] ?? 'Mi Finca',
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
      });
    }

    await HealthAlertEngine.instance.runEngine();
    await _reloadMemoryDataOnly();

    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  Future<void> addMedicine(Map<String, dynamic> row) async {
    final now = DateTime.now().toIso8601String();
    row['quantity'] = max(0.0, (row['quantity'] as num?)?.toDouble() ?? 0.0);
    row['created_at'] ??= now;
    row['updated_at'] = now;
    row['synced'] = 0;
    await DBHelper.instance.insertMedicine(row);
    if ((row['quantity'] as double) > 0) {
      await registerMedicineMovement(
        medicineId: row['id'] as String,
        movementType: 'Ingreso',
        quantity: row['quantity'] as double,
        reason: 'Stock inicial',
      );
    }
    await HealthAlertEngine.instance.runEngine();
    await _reloadMemoryDataOnly();

    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  Future<void> updateMedicine(Map<String, dynamic> row) async {
    final previous = _medicines.firstWhere(
      (medicine) => medicine['id'] == row['id'],
      orElse: () => <String, dynamic>{},
    );
    final oldQuantity = (previous['quantity'] as num?)?.toDouble() ?? 0.0;
    final newQuantity = max(0.0, (row['quantity'] as num?)?.toDouble() ?? 0.0);
    row['quantity'] = newQuantity;
    row['created_at'] ??= previous['created_at'];
    row['updated_at'] = DateTime.now().toIso8601String();
    row['synced'] = 0;
    await DBHelper.instance.updateMedicine(row);
    final difference = newQuantity - oldQuantity;
    if (difference.abs() > 0.0001) {
      await registerMedicineMovement(
        medicineId: row['id'] as String,
        movementType: difference > 0 ? 'Ingreso' : 'Corrección de stock',
        quantity: difference.abs(),
        reason: difference > 0
            ? 'Reposición o ajuste de entrada'
            : 'Corrección manual de inventario',
      );
    }
    await HealthAlertEngine.instance.runEngine();
    await _reloadMemoryDataOnly();

    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  Future<void> deleteMedicineItem(String id) async {
    await DBHelper.instance.deleteMedicine(id);
    await _reloadMemoryDataOnly();
    _scheduleSync();
  }

  Future<void> registerMedicineMovement({
    required String medicineId,
    required String movementType,
    required double quantity,
    String? animalId,
    String reason = '',
    String? responsible,
  }) async {
    if (quantity <= 0) return;
    final now = DateTime.now();
    await DBHelper.instance.insertMedicineMovement({
      'id': 'mov_${now.microsecondsSinceEpoch}_${Random().nextInt(9999)}',
      'medicine_id': medicineId,
      'animal_id': animalId,
      'movement_type': movementType,
      'quantity': quantity,
      'reason': reason,
      'responsible': responsible ?? _profile?['owner_name'] ?? 'Usuario AURA',
      'created_at': now.toIso8601String(),
      'synced': 0,
    });
    _medicineMovements = await DBHelper.instance.getMedicineMovements();
  }

  Future<bool> deductMedicineStock({
    required String medicineId,
    required double quantity,
    String? animalId,
    String reason = 'Uso en tratamiento',
  }) async {
    if (quantity <= 0) return false;
    final medicine = _medicines.firstWhere(
      (item) => item['id'] == medicineId,
      orElse: () => <String, dynamic>{},
    );
    if (medicine.isEmpty) return false;
    final current = (medicine['quantity'] as num?)?.toDouble() ?? 0.0;
    if (current < quantity) return false;
    await DBHelper.instance.updateMedicineStock(
      medicineId,
      max(0.0, current - quantity),
    );
    await registerMedicineMovement(
      medicineId: medicineId,
      movementType: 'Uso en tratamiento',
      quantity: quantity,
      animalId: animalId,
      reason: reason,
    );
    await HealthAlertEngine.instance.runEngine();
    await _reloadMemoryDataOnly();
    _scheduleSync();
    return true;
  }

  List<Map<String, dynamic>> getLowStockMedicines() => _medicines.where((item) {
    final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
    final minimum = (item['min_stock'] as num?)?.toDouble() ?? 0.0;
    return quantity <= minimum;
  }).toList();

  List<Map<String, dynamic>> getExpiringMedicines({int withinDays = 60}) {
    final now = DateTime.now();
    return _medicines.where((item) {
      final expiration = DateTime.tryParse(
        item['expiration_date']?.toString() ?? '',
      );
      if (expiration == null) return false;
      final days = expiration.difference(now).inDays;
      return days >= 0 && days <= withinDays;
    }).toList();
  }

  List<Map<String, dynamic>> getAvailableMedicinesByType(String type) =>
      _medicines.where((item) {
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final expiration = DateTime.tryParse(
          item['expiration_date']?.toString() ?? '',
        );
        return item['type'] == type &&
            quantity > 0 &&
            (expiration == null || expiration.isAfter(DateTime.now()));
      }).toList();

  List<Map<String, dynamic>> getMedicinesForVetReviewBySymptoms(
    List<String> symptoms,
  ) {
    final text = symptoms.join(' ').toLowerCase();
    final usefulTypes = <String>{'Vitamina', 'Mineral', 'Suplemento'};
    if (text.contains('inflam') || text.contains('cojera')) {
      usefulTypes.add('Antiinflamatorio');
    }
    if (text.contains('parás') || text.contains('diarrea')) {
      usefulTypes.add('Desparasitante');
    }
    if (text.contains('fiebre') || text.contains('herida')) {
      usefulTypes.add('Antibiótico');
    }
    return _medicines.where((item) {
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      return quantity > 0 && usefulTypes.contains(item['type']);
    }).toList();
  }

  Future<void> addMedicalTreatment(Map<String, dynamic> row) async {
    final db = DBHelper.instance;
    await db.insertMedicalTreatment(row);

    // Descontar inventario de medicamentos si aplica
    final medId = row['medicine_id'] as String?;
    final double dose = (row['dose'] as num?)?.toDouble() ?? 0.0;
    if (medId != null && medId.isNotEmpty && dose > 0) {
      await deductMedicineStock(
        medicineId: medId,
        quantity: dose,
        animalId: row['animal_id'] as String?,
        reason: 'Tratamiento: ${row['diagnosis'] ?? row['treatment'] ?? ''}',
      );
    }

    await HealthAlertEngine.instance.runEngine();
    await _reloadMemoryDataOnly();

    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  Future<void> addReproductionRecord(Map<String, dynamic> row) async {
    final db = DBHelper.instance;
    await db.insertReproductionRecord(row);

    // Si el evento es gestación confirmada, programar una notificación local 48h antes del parto
    if (row['event_type'] == 'Gestación confirmada' &&
        row['expected_birth_date'] != null) {
      try {
        final birthDate = DateTime.parse(row['expected_birth_date'] as String);
        final notifyDate = birthDate.subtract(const Duration(days: 2));
        final animal = _animals.firstWhere((a) => a.id == row['animal_id']);

        await NotificationService.instance.scheduleNotification(
          id: row['id'].hashCode,
          title: '🐄 PARTO PRÓXIMO: ${animal.name}',
          body:
              'Se estima el parto de ${animal.name} en 48 horas. Prepara el área de parición.',
          scheduledDate: notifyDate,
        );
      } catch (e) {
        debugPrint("Error programando notificación de parto: $e");
      }
    }

    await HealthAlertEngine.instance.runEngine();
    await _reloadMemoryDataOnly();

    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  Future<void> addOperatingExpense(Map<String, dynamic> row) async {
    await DBHelper.instance.insertOperatingExpense(row);
    await _reloadMemoryDataOnly();

    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }

  Future<void> applyBatchEvent({
    required String lote,
    required String eventType,
    required String description,
    required DateTime date,
    String? medicineId,
    double? dose,
  }) async {
    final batchAnimals = _animals
        .where((a) => a.lote == lote && a.status.toLowerCase() == 'activo')
        .toList();
    if (batchAnimals.isEmpty) return;

    final db = DBHelper.instance;

    for (var animal in batchAnimals) {
      final String id =
          "${eventType.toLowerCase().substring(0, 3)}_${animal.id}_${DateTime.now().millisecondsSinceEpoch}";

      if (eventType.toLowerCase() == 'vacunación' ||
          eventType.toLowerCase() == 'vacunacion') {
        final Map<String, dynamic> vacMap = {
          'animal_id': animal.id,
          'name': medicineId ?? description,
          'date_applied': date.toIso8601String().split('T')[0],
          'dose': dose != null ? "${dose.toStringAsFixed(1)} ml" : "N/D",
          'notes': description,
        };
        await db.insertVaccine(vacMap);
      } else if (eventType.toLowerCase() == 'pesaje') {
        double wt = animal.weightKg;
        try {
          wt =
              double.tryParse(description.replaceAll(RegExp(r'[^0-9.]'), '')) ??
              animal.weightKg;
        } catch (_) {}
        await db.insertWeightRecord(
          WeightRecord(
            animalId: animal.id,
            date: date.toIso8601String().split('T')[0],
            weightKg: wt,
          ),
        );
      } else {
        final Map<String, dynamic> treatmentMap = {
          'id': id,
          'animal_id': animal.id,
          'diagnosis': eventType,
          'symptoms': 'Lote event',
          'treatment': description,
          'medicine_id': medicineId ?? '',
          'dose': dose ?? 0.0,
          'responsible': _profile?['owner_name'] ?? 'Ganadero',
          'date': date.toIso8601String().split('T')[0],
          'observations': 'Aplicación colectiva en lote $lote',
          'created_at': DateTime.now().toIso8601String(),
          'synced': 0,
        };
        await db.insertMedicalTreatment(treatmentMap);
      }
    }

    // Descontar del inventario
    if (medicineId != null &&
        medicineId.isNotEmpty &&
        dose != null &&
        dose > 0) {
      final med = _medicines.firstWhere(
        (m) => m['id'] == medicineId,
        orElse: () => {},
      );
      if (med.isNotEmpty) {
        final double currentQty = (med['quantity'] as num?)?.toDouble() ?? 0.0;
        final double totalDose = dose * batchAnimals.length;
        final double newQty = max(0.0, currentQty - totalDose);
        await db.updateMedicineStock(medicineId, newQty);
      }
    }

    await HealthAlertEngine.instance.runEngine();
    await _reloadMemoryDataOnly();

    if (SupabaseService.instance.isEnabled &&
        SupabaseService.instance.isAuthenticated) {
      SyncService.instance.sync();
    }
  }
}
