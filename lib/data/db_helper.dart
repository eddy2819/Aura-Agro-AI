import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

import '../models/animal.dart';
import '../models/alert_model.dart';
import '../models/nutrition_resource.dart';
import '../models/nutrition_plan.dart';
import '../models/nutrition_requirement.dart';
import '../models/weight_record.dart';
import '../models/production_record.dart';
import '../models/marketplace_item.dart';
import '../services/supabase_service.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;
  static String databaseName = 'aura_agro.db';

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(databaseName);
    return _database!;
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> _initDB(String filePath) async {
    // Inicializar FFI si se ejecuta en escritorio (Windows, Mac, Linux)
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final String path;
    if (filePath == inMemoryDatabasePath) {
      path = inMemoryDatabasePath;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 11,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabla de sync_queue
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        action TEXT NOT NULL,
        data TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Tabla de perfil de usuario
    await db.execute('''
      CREATE TABLE profile (
        id INTEGER PRIMARY KEY,
        owner_name TEXT NOT NULL,
        farm_name TEXT NOT NULL,
        location TEXT NOT NULL,
        email TEXT NOT NULL
      )
    ''');

    // Tabla de perfil de usuario detallado (onboarding)
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY,
        owner_name TEXT NOT NULL,
        farm_name TEXT NOT NULL,
        location TEXT,
        animal_count INTEGER,
        role TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        license_number TEXT
      )
    ''');

    // Tabla de autorizaciones de finca
    await db.execute('''
      CREATE TABLE farm_authorizations (
        id TEXT PRIMARY KEY,
        ganadero_id TEXT NOT NULL,
        veterinario_id TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    // Tabla de settings
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value INTEGER NOT NULL
      )
    ''');

    // Tabla de animales
    await db.execute('''
      CREATE TABLE animals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        tag TEXT NOT NULL,
        category TEXT NOT NULL,
        score INTEGER NOT NULL,
        description TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        production_liters TEXT,
        vaccine_status TEXT,
        has_alert INTEGER NOT NULL DEFAULT 0,
        image_path TEXT,
        breed TEXT,
        sex TEXT,
        birth_date TEXT,
        status TEXT,
        purpose TEXT,
        stage TEXT,
        body_condition REAL,
        color TEXT,
        genetic_father TEXT,
        genetic_mother TEXT,
        genetic_line TEXT,
        origin TEXT,
        health_status TEXT,
        last_vet_check TEXT,
        vet_responsible TEXT,
        prev_diseases TEXT,
        allergies TEXT,
        current_medication TEXT,
        diet_type TEXT,
        grazing INTEGER NOT NULL DEFAULT 1,
        balanced_feed INTEGER NOT NULL DEFAULT 0,
        supplements INTEGER NOT NULL DEFAULT 0,
        daily_consumption REAL,
        production_objective TEXT,
        finca TEXT,
        lote TEXT,
        potrero TEXT,
        gps_coords TEXT,
        purchase_value REAL,
        purchase_date TEXT,
        provider TEXT,
        available_for_sale INTEGER NOT NULL DEFAULT 0,
        image_front_path TEXT,
        image_side_path TEXT,
        cert_sanitary_path TEXT,
        doc_purchase_path TEXT,
        qr_token TEXT,
        qr_is_active INTEGER DEFAULT 1,
        qr_generated_at TEXT
      )
    ''');

    // Tabla de vacunas
    await db.execute('''
      CREATE TABLE vaccines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id TEXT NOT NULL,
        name TEXT NOT NULL,
        date_applied TEXT NOT NULL,
        dose TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (animal_id) REFERENCES animals (id) ON DELETE CASCADE
      )
    ''');

    // Tablas MVP y de alertas (versión 11)
    await _createMvpTables(db);

    await _createNutritionTables(db);
    await _createMarketplaceTable(db);

    // Poblar con datos iniciales (semilla)
    await _seedDatabase(db);
  }

  Future<void> _seedDatabase(Database db) async {
    // 1. Perfil por defecto
    await db.insert('profile', {
      'id': 1,
      'owner_name': 'Eddy',
      'farm_name': 'Finca El Paraíso',
      'location': 'Loja, Ecuador',
      'email': 'eddy@auraagro.ai',
    });

    // 2. Animales iniciales
    final initialAnimals = [
      {
        'id': '0234',
        'name': 'Estrella',
        'tag': '#0234',
        'category': 'Vaca Lechera',
        'score': 96,
        'description': 'Excelente condicion corporal y produccion consistente',
        'weight_kg': 485.0,
        'production_liters': '12.5 L/dia',
        'vaccine_status': '28 May',
        'has_alert': 0,
        'image_path': 'https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?w=150&q=80',
        'breed': 'Jersey',
        'sex': 'Hembra',
        'birth_date': '2023-04-12',
        'status': 'Activo',
        'purpose': 'Leche',
        'stage': 'Vaca',
        'body_condition': 4.2,
        'color': 'Café claro',
        'diet_type': 'Pasto',
        'grazing': 1,
        'balanced_feed': 0,
        'supplements': 1,
        'daily_consumption': 15.0,
        'production_objective': 'Producción láctea',
        'finca': 'Finca El Paraíso',
        'lote': 'Lote A',
        'potrero': 'Potrero 1',
        'available_for_sale': 0,
      },
      {
        'id': '0089',
        'name': 'Tormenta',
        'tag': '#0089',
        'category': 'Toro Reproductor',
        'score': 78,
        'description': 'Vacuna vencida afecta el puntaje. Programa vacunacion urgente.',
        'weight_kg': 720.0,
        'production_liters': null,
        'vaccine_status': 'Vencida',
        'has_alert': 1,
        'image_path': 'https://images.unsplash.com/photo-1596733430284-f7437764b1a9?w=150&q=80',
        'breed': 'Brahman',
        'sex': 'Macho',
        'birth_date': '2021-08-20',
        'status': 'Activo',
        'purpose': 'Carne',
        'stage': 'Toro',
        'body_condition': 4.5,
        'color': 'Blanco Grisáceo',
        'diet_type': 'Mixto',
        'grazing': 1,
        'balanced_feed': 1,
        'supplements': 1,
        'daily_consumption': 25.0,
        'production_objective': 'Mantenimiento',
        'finca': 'Finca El Paraíso',
        'lote': 'Lote B',
        'potrero': 'Potrero 4',
        'available_for_sale': 0,
      },
      {
        'id': '0456',
        'name': 'Manchita',
        'tag': '#0456',
        'category': 'Ternero',
        'score': 82,
        'description': 'Peso ligeramente bajo para su edad. Ajusta la alimentacion.',
        'weight_kg': 95.0,
        'production_liters': null,
        'vaccine_status': '28 May',
        'has_alert': 1,
        'image_path': 'https://images.unsplash.com/photo-1527153857715-3908f2bac5e8?w=150&q=80',
        'breed': 'Holstein',
        'sex': 'Hembra',
        'birth_date': '2025-11-05',
        'status': 'Activo',
        'purpose': 'Leche',
        'stage': 'Ternero',
        'body_condition': 3.8,
        'color': 'Blanco con Negro',
        'diet_type': 'Concentrado',
        'grazing': 0,
        'balanced_feed': 1,
        'supplements': 0,
        'daily_consumption': 5.0,
        'production_objective': 'Ganancia de peso',
        'finca': 'Finca El Paraíso',
        'lote': 'Lote C',
        'potrero': 'Potrero 2',
        'available_for_sale': 0,
      },
      {
        'id': '0178',
        'name': 'Luna',
        'tag': '#0178',
        'category': 'Vaca Lechera',
        'score': 94,
        'description': 'Muy buen rendimiento. Mantiene la produccion stable.',
        'weight_kg': 420.0,
        'production_liters': '10.8 L/dia',
        'vaccine_status': '14 Abr',
        'has_alert': 0,
        'image_path': 'https://images.unsplash.com/photo-1500595046783-ed211a547579?w=150&q=80',
        'breed': 'Holstein',
        'sex': 'Hembra',
        'birth_date': '2022-02-14',
        'status': 'Activo',
        'purpose': 'Leche',
        'stage': 'Vaca',
        'body_condition': 4.0,
        'color': 'Blanco con Negro',
        'diet_type': 'Pasto',
        'grazing': 1,
        'balanced_feed': 0,
        'supplements': 1,
        'daily_consumption': 14.0,
        'production_objective': 'Producción láctea',
        'finca': 'Finca El Paraíso',
        'lote': 'Lote A',
        'potrero': 'Potrero 1',
        'available_for_sale': 0,
      },
      {
        'id': '0312',
        'name': 'Campeon',
        'tag': '#0312',
        'category': 'Toro Engorde',
        'score': 91,
        'description': 'Ganancia de peso optima. Listo para venta en 30 dias.',
        'weight_kg': 580.0,
        'production_liters': null,
        'vaccine_status': '10 Jun',
        'has_alert': 0,
        'image_path': 'https://images.unsplash.com/photo-1532467414612-557d38befbcd?w=150&q=80',
        'breed': 'Angus',
        'sex': 'Macho',
        'birth_date': '2024-05-10',
        'status': 'Activo',
        'purpose': 'Carne',
        'stage': 'Novillo',
        'body_condition': 4.1,
        'color': 'Negro',
        'diet_type': 'Mixto',
        'grazing': 1,
        'balanced_feed': 1,
        'supplements': 0,
        'daily_consumption': 18.0,
        'production_objective': 'Ganancia de peso',
        'finca': 'Finca El Paraíso',
        'lote': 'Lote B',
        'potrero': 'Potrero 3',
        'available_for_sale': 1,
      },
    ];

    for (var a in initialAnimals) {
      await db.insert('animals', a);
    }

    // 3. Vacunas iniciales
    final initialVaccines = [
      {
        'animal_id': '0234',
        'name': 'Fiebre Aftosa',
        'date_applied': '2026-05-28',
        'dose': '5 ml',
        'notes': 'Aplicada en jornada general',
      },
      {
        'animal_id': '0456',
        'name': 'Triple Bovino',
        'date_applied': '2026-05-28',
        'dose': '2 ml',
        'notes': 'Refuerzo ternero',
      },
      {
        'animal_id': '0178',
        'name': 'Fiebre Aftosa',
        'date_applied': '2026-04-14',
        'dose': '5 ml',
        'notes': 'Ok',
      },
      {
        'animal_id': '0312',
        'name': 'Carbonosa',
        'date_applied': '2026-06-10',
        'dose': '2 ml',
        'notes': 'Preventiva antes de comercializacion',
      },
    ];

    for (var v in initialVaccines) {
      await db.insert('vaccines', v);
    }

    // 4. Alertas iniciales
    final initialAlerts = [
      {
        'id': 'mock_alert_1',
        'animal_id': '0234',
        'type': 'health',
        'risk_level': 'rojo',
        'title': 'Riesgo de Mastitis',
        'description': 'Leche con grumos,Ubre inflamada,Fiebre leve : Tratamiento antibiotico recomendado. Separar del hato.',
        'source': 'Finca El Paraiso',
        'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'is_read': 0,
        'synced': 0,
      },
      {
        'id': 'mock_alert_2',
        'animal_id': '0089',
        'type': 'health',
        'risk_level': 'rojo',
        'title': 'Vacuna Vencida - Fiebre Aftosa',
        'description': 'Esquema de vacunacion incompleto : Programar vacunacion inmediata.',
        'source': 'Finca El Paraiso',
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'is_read': 0,
        'synced': 0,
      },
      {
        'id': 'mock_alert_3',
        'animal_id': '0456',
        'type': 'nutrition',
        'risk_level': 'amarillo',
        'title': 'Bajo peso para edad',
        'description': 'Peso 15% bajo promedio,Apetito reducido : Revisar dieta y desparasitar.',
        'source': 'Finca La Esperanza',
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        'is_read': 0,
        'synced': 0,
      },
    ];

    for (var al in initialAlerts) {
      await db.insert('alerts', al);
    }
    await _seedNutritionTablesOnly(db);
    await _seedRequirements(db);
  }

  // Métodos CRUD para Perfil
  Future<Map<String, dynamic>> getProfile() async {
    final db = await instance.database;
    final maps = await db.query('profile', where: 'id = ?', whereArgs: [1]);
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return {
      'id': 1,
      'owner_name': 'Usuario',
      'farm_name': 'Mi Finca',
      'location': 'Ecuador',
      'email': 'usuario@auraagro.ai',
    };
  }

  Future<int> updateProfile(Map<String, dynamic> profile) async {
    final db = await instance.database;
    final count = await db.update(
      'profile',
      profile,
      where: 'id = ?',
      whereArgs: [1],
    );
    await _enqueueSync('user_profiles', '1', 'UPDATE', profile);
    return count;
  }

  // Métodos CRUD para Animales
  Future<List<Animal>> getAllAnimals() async {
    final db = await instance.database;
    final result = await db.query('animals');

    return result.map((json) {
      return Animal(
        id: json['id'] as String,
        name: json['name'] as String,
        tag: json['tag'] as String,
        category: json['category'] as String,
        score: json['score'] as int,
        description: json['description'] as String,
        weightKg: json['weight_kg'] as double,
        productionLiters: json['production_liters'] as String?,
        vaccineStatus: json['vaccine_status'] as String?,
        hasAlert: (json['has_alert'] as int) == 1,
        imagePath: json['image_path'] as String?,
        breed: (json['breed'] as String?) ?? 'Mestizo',
        sex: (json['sex'] as String?) ?? 'Hembra',
        birthDate: (json['birth_date'] as String?) ?? '2024-01-01',
        status: (json['status'] as String?) ?? 'Activo',
        purpose: (json['purpose'] as String?) ?? 'Doble propósito',
        stage: (json['stage'] as String?) ?? 'Vaca',
        bodyCondition: (json['body_condition'] as num?)?.toDouble() ?? 3.5,
        color: (json['color'] as String?) ?? 'Blanco con Negro',
        geneticFather: json['genetic_father'] as String?,
        geneticMother: json['genetic_mother'] as String?,
        geneticLine: json['genetic_line'] as String?,
        origin: json['origin'] as String?,
        healthStatus: (json['health_status'] as String?) ?? 'Saludable',
        lastVetCheck: json['last_vet_check'] as String?,
        vetResponsible: json['vet_responsible'] as String?,
        prevDiseases: json['prev_diseases'] as String?,
        allergies: json['allergies'] as String?,
        currentMedication: json['current_medication'] as String?,
        dietType: (json['diet_type'] as String?) ?? 'Pasto',
        grazing: (json['grazing'] as int?) == 1,
        balancedFeed: (json['balanced_feed'] as int?) == 1,
        supplements: (json['supplements'] as int?) == 1,
        dailyConsumption: (json['daily_consumption'] as num?)?.toDouble(),
        productionObjective: (json['production_objective'] as String?) ?? 'Producción láctea',
        finca: (json['finca'] as String?) ?? 'Finca Principal',
        lote: (json['lote'] as String?) ?? 'Lote A',
        potrero: (json['potrero'] as String?) ?? 'Potrero 1',
        gpsCoords: json['gps_coords'] as String?,
        purchaseValue: (json['purchase_value'] as num?)?.toDouble(),
        purchaseDate: json['purchase_date'] as String?,
        provider: json['provider'] as String?,
        availableForSale: (json['available_for_sale'] as int?) == 1,
        imageFrontPath: json['image_front_path'] as String?,
        imageSidePath: json['image_side_path'] as String?,
        certSanitaryPath: json['cert_sanitary_path'] as String?,
        docPurchasePath: json['doc_purchase_path'] as String?,
        qrToken: json['qr_token'] as String?,
        qrIsActive: (json['qr_is_active'] as int? ?? 1) == 1,
        qrGeneratedAt: json['qr_generated_at'] as String?,
      );
    }).toList();
  }

  Future<int> insertAnimal(Animal animal) async {
    final db = await instance.database;
    final map = {
      'id': animal.id,
      'name': animal.name,
      'tag': animal.tag,
      'category': animal.category,
      'score': animal.score,
      'description': animal.description,
      'weight_kg': animal.weightKg,
      'production_liters': animal.productionLiters,
      'vaccine_status': animal.vaccineStatus,
      'has_alert': animal.hasAlert ? 1 : 0,
      'image_path': animal.imagePath,
      'breed': animal.breed,
      'sex': animal.sex,
      'birth_date': animal.birthDate,
      'status': animal.status,
      'purpose': animal.purpose,
      'stage': animal.stage,
      'body_condition': animal.bodyCondition,
      'color': animal.color,
      'genetic_father': animal.geneticFather,
      'genetic_mother': animal.geneticMother,
      'genetic_line': animal.geneticLine,
      'origin': animal.origin,
      'health_status': animal.healthStatus,
      'last_vet_check': animal.lastVetCheck,
      'vet_responsible': animal.vetResponsible,
      'prev_diseases': animal.prevDiseases,
      'allergies': animal.allergies,
      'current_medication': animal.currentMedication,
      'diet_type': animal.dietType,
      'grazing': animal.grazing ? 1 : 0,
      'balanced_feed': animal.balancedFeed ? 1 : 0,
      'supplements': animal.supplements ? 1 : 0,
      'daily_consumption': animal.dailyConsumption,
      'production_objective': animal.productionObjective,
      'finca': animal.finca,
      'lote': animal.lote,
      'potrero': animal.potrero,
      'gps_coords': animal.gpsCoords,
      'purchase_value': animal.purchaseValue,
      'purchase_date': animal.purchaseDate,
      'provider': animal.provider,
      'available_for_sale': animal.availableForSale ? 1 : 0,
      'image_front_path': animal.imageFrontPath,
      'image_side_path': animal.imageSidePath,
      'cert_sanitary_path': animal.certSanitaryPath,
      'doc_purchase_path': animal.docPurchasePath,
      'qr_token': animal.qrToken,
      'qr_is_active': animal.qrIsActive ? 1 : 0,
      'qr_generated_at': animal.qrGeneratedAt,
    };
    final count = await db.insert('animals', map);
    await _enqueueSync('animals', animal.id, 'INSERT', map);
    return count;
  }

  Future<int> updateAnimalVaccineStatus(String animalId, String? vaccineStatus, bool hasAlert) async {
    final db = await instance.database;
    final map = {
      'vaccine_status': vaccineStatus,
      'has_alert': hasAlert ? 1 : 0,
    };
    final count = await db.update(
      'animals',
      map,
      where: 'id = ?',
      whereArgs: [animalId],
    );
    await _enqueueSync('animals', animalId, 'UPDATE', map);
    return count;
  }

  Future<int> updateAnimalWeight(String animalId, double weightKg) async {
    final db = await instance.database;
    final map = {
      'weight_kg': weightKg,
    };
    final count = await db.update(
      'animals',
      map,
      where: 'id = ?',
      whereArgs: [animalId],
    );
    await _enqueueSync('animals', animalId, 'UPDATE', map);
    return count;
  }

  Future<int> updateAnimalProduction(String animalId, String? productionLiters) async {
    final db = await instance.database;
    final map = {
      'production_liters': productionLiters,
    };
    final count = await db.update(
      'animals',
      map,
      where: 'id = ?',
      whereArgs: [animalId],
    );
    await _enqueueSync('animals', animalId, 'UPDATE', map);
    return count;
  }

  // Métodos CRUD para Vacunas
  Future<List<Map<String, dynamic>>> getVaccinesForAnimal(String animalId) async {
    final db = await instance.database;
    return await db.query(
      'vaccines',
      where: 'animal_id = ?',
      whereArgs: [animalId],
      orderBy: 'date_applied DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllVaccines() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT vaccines.*, animals.name as animal_name, animals.tag as animal_tag
      FROM vaccines
      INNER JOIN animals ON vaccines.animal_id = animals.id
      ORDER BY date_applied DESC
    ''');
  }

  Future<int> insertVaccine(Map<String, dynamic> vaccine) async {
    final db = await instance.database;
    final id = await db.insert('vaccines', vaccine);
    await _enqueueSync('vaccines', id.toString(), 'INSERT', {...vaccine, 'id': id});
    return id;
  }

  // Métodos CRUD para Alertas
  Future<List<AlertModel>> getAllAlerts() async {
    final db = await instance.database;
    final result = await db.query('alerts', orderBy: 'created_at DESC');

    final List<AlertModel> list = [];
    for (var json in result) {
      final animalId = json['animal_id'] as String?;
      String animalName = "Hato General";
      String animalTag = "General";
      if (animalId != null && animalId.isNotEmpty) {
        final anims = await db.query('animals', columns: ['name', 'tag'], where: 'id = ?', whereArgs: [animalId]);
        if (anims.isNotEmpty) {
          animalName = anims.first['name'] as String;
          animalTag = anims.first['tag'] as String;
        }
      }
      list.add(AlertModel.fromMap(json, animalName: animalName, animalTag: animalTag));
    }
    return list;
  }

  Future<int> deleteAlert(String id) async {
    final db = await instance.database;
    final count = await db.delete(
      'alerts',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueSync('alerts', id, 'DELETE', null);
    return count;
  }

  Future<int> deleteAlertByTag(String tag, String titlePart) async {
    final db = await instance.database;
    final anims = await db.query('animals', columns: ['id'], where: 'tag = ?', whereArgs: [tag]);
    if (anims.isEmpty) return 0;
    final animalId = anims.first['id'] as String;

    final alerts = await db.query('alerts', columns: ['id'], where: 'animal_id = ? AND title LIKE ?', whereArgs: [animalId, '%$titlePart%']);
    final count = await db.delete(
      'alerts',
      where: 'animal_id = ? AND title LIKE ?',
      whereArgs: [animalId, '%$titlePart%'],
    );
    for (var a in alerts) {
      final localId = a['id'].toString();
      await _enqueueSync('alerts', localId, 'DELETE', null);
    }
    return count;
  }

  Future<int> insertAlert(AlertModel alert) async {
    final db = await instance.database;
    final map = alert.toMap();
    final count = await db.insert('alerts', map, conflictAlgorithm: ConflictAlgorithm.replace);
    await _enqueueSync('alerts', alert.id, 'INSERT', map);
    return count;
  }

  Future<int> markAlertAsRead(String id) async {
    final db = await instance.database;
    final map = {'is_read': 1};
    final count = await db.update(
      'alerts',
      map,
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueSync('alerts', id, 'UPDATE', map);
    return count;
  }

  // --- MIGRATION AND NUTRITION TABLES ---

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createNutritionTables(db);
      await _seedNutritionTablesOnly(db);
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE production_records ADD COLUMN turn TEXT');
        await db.execute('ALTER TABLE production_records ADD COLUMN observation TEXT');
      } catch (e) {
        debugPrint("Upgrade error adding columns to production_records: $e");
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE user_profile (
            id INTEGER PRIMARY KEY,
            owner_name TEXT NOT NULL,
            farm_name TEXT NOT NULL,
            location TEXT,
            animal_count INTEGER,
            role TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value INTEGER NOT NULL
          )
        ''');
      } catch (e) {
        debugPrint("Upgrade error version 4 tables: $e");
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE animals ADD COLUMN image_path TEXT');
      } catch (e) {
        debugPrint("Upgrade error adding image_path to animals: $e");
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE animals ADD COLUMN breed TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN sex TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN birth_date TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN status TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN purpose TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN stage TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN body_condition REAL');
        await db.execute('ALTER TABLE animals ADD COLUMN color TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN genetic_father TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN genetic_mother TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN genetic_line TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN origin TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN purchase_date TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN purchase_value REAL');
        await db.execute('ALTER TABLE animals ADD COLUMN health_status TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN last_vet_check TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN vet_responsible TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN prev_diseases TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN allergies TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN current_medication TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN diet_type TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN grazing INTEGER NOT NULL DEFAULT 1');
        await db.execute('ALTER TABLE animals ADD COLUMN balanced_feed INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE animals ADD COLUMN supplements INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE animals ADD COLUMN daily_consumption REAL');
        await db.execute('ALTER TABLE animals ADD COLUMN production_objective TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN finca TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN lote TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN potrero TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN gps_coords TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN provider TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN available_for_sale INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE animals ADD COLUMN image_front_path TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN image_side_path TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN cert_sanitary_path TEXT');
        await db.execute('ALTER TABLE animals ADD COLUMN doc_purchase_path TEXT');
      } catch (e) {
        debugPrint("Upgrade error version 6: $e");
      }
    }
    if (oldVersion < 7) {
      try {
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_name TEXT NOT NULL,
            record_id TEXT NOT NULL,
            action TEXT NOT NULL,
            data TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      } catch (e) {
        debugPrint("Upgrade error version 7: $e");
      }
    }
    if (oldVersion < 8) {
      try {
        await db.execute("ALTER TABLE user_profile ADD COLUMN status TEXT DEFAULT 'active'");
        await db.execute("ALTER TABLE user_profile ADD COLUMN license_number TEXT");
        await db.execute('''
          CREATE TABLE farm_authorizations (
            id TEXT PRIMARY KEY,
            ganadero_id TEXT NOT NULL,
            veterinario_id TEXT NOT NULL,
            status TEXT NOT NULL
          )
        ''');
      } catch (e) {
        debugPrint("Upgrade error version 8: $e");
      }
    }
    if (oldVersion < 9) {
      try {
        await db.execute("ALTER TABLE nutrition_resources ADD COLUMN cost REAL");
        await db.execute("ALTER TABLE nutrition_resources ADD COLUMN availability TEXT DEFAULT 'Disponible'");
        await db.execute("ALTER TABLE nutrition_resources ADD COLUMN expiration_date TEXT");
        await db.execute("ALTER TABLE nutrition_resources ADD COLUMN observations TEXT");
        
        await db.execute("ALTER TABLE nutrition_plans ADD COLUMN raw_response TEXT");

        await db.execute('''
          CREATE TABLE nutrition_requirements (
            category TEXT PRIMARY KEY,
            dry_matter_percentage REAL NOT NULL,
            protein_percentage REAL NOT NULL,
            energy_mcal_per_kg REAL NOT NULL,
            stage_notes TEXT
          )
        ''');
        
        await _seedRequirements(db);
      } catch (e) {
        debugPrint("Upgrade error version 9: $e");
      }
    }
    if (oldVersion < 10) {
      try {
        await _createMarketplaceTable(db);
      } catch (e) {
        debugPrint("Upgrade error version 10: $e");
      }
    }
    if (oldVersion < 11) {
      try {
        await _createMvpTables(db);
        try {
          await db.execute('ALTER TABLE animals ADD COLUMN qr_token TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE animals ADD COLUMN qr_is_active INTEGER DEFAULT 1');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE animals ADD COLUMN qr_generated_at TEXT');
        } catch (_) {}
      } catch (e) {
        debugPrint("Upgrade error version 11: $e");
      }
    }
  }

  Future<int> updateAnimal(Animal animal) async {
    final db = await instance.database;
    final map = {
      'name': animal.name,
      'tag': animal.tag,
      'category': animal.category,
      'score': animal.score,
      'description': animal.description,
      'weight_kg': animal.weightKg,
      'production_liters': animal.productionLiters,
      'vaccine_status': animal.vaccineStatus,
      'has_alert': animal.hasAlert ? 1 : 0,
      'image_path': animal.imagePath,
      'breed': animal.breed,
      'sex': animal.sex,
      'birth_date': animal.birthDate,
      'status': animal.status,
      'purpose': animal.purpose,
      'stage': animal.stage,
      'body_condition': animal.bodyCondition,
      'color': animal.color,
      'genetic_father': animal.geneticFather,
      'genetic_mother': animal.geneticMother,
      'genetic_line': animal.geneticLine,
      'origin': animal.origin,
      'health_status': animal.healthStatus,
      'last_vet_check': animal.lastVetCheck,
      'vet_responsible': animal.vetResponsible,
      'prev_diseases': animal.prevDiseases,
      'allergies': animal.allergies,
      'current_medication': animal.currentMedication,
      'diet_type': animal.dietType,
      'grazing': animal.grazing ? 1 : 0,
      'balanced_feed': animal.balancedFeed ? 1 : 0,
      'supplements': animal.supplements ? 1 : 0,
      'daily_consumption': animal.dailyConsumption,
      'production_objective': animal.productionObjective,
      'finca': animal.finca,
      'lote': animal.lote,
      'potrero': animal.potrero,
      'gps_coords': animal.gpsCoords,
      'purchase_value': animal.purchaseValue,
      'purchase_date': animal.purchaseDate,
      'provider': animal.provider,
      'available_for_sale': animal.availableForSale ? 1 : 0,
      'image_front_path': animal.imageFrontPath,
      'image_side_path': animal.imageSidePath,
      'cert_sanitary_path': animal.certSanitaryPath,
      'doc_purchase_path': animal.docPurchasePath,
      'qr_token': animal.qrToken,
      'qr_is_active': animal.qrIsActive ? 1 : 0,
      'qr_generated_at': animal.qrGeneratedAt,
    };
    final count = await db.update(
      'animals',
      map,
      where: 'id = ?',
      whereArgs: [animal.id],
    );
    await _enqueueSync('animals', animal.id, 'UPDATE', map);
    return count;
  }

  Future<int> deleteAnimal(String id) async {
    final db = await instance.database;
    final count = await db.delete(
      'animals',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueSync('animals', id, 'DELETE', null);
    return count;
  }

  Future<void> _createNutritionTables(Database db) async {
    await db.execute('''
      CREATE TABLE nutrition_resources (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        unit TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        cost REAL,
        availability TEXT DEFAULT 'Disponible',
        expiration_date TEXT,
        observations TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE nutrition_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        target_group TEXT NOT NULL,
        suggested_diet TEXT NOT NULL,
        estimated_cost_per_day REAL NOT NULL,
        projected_savings REAL NOT NULL,
        projected_improvement TEXT NOT NULL,
        explanation TEXT NOT NULL,
        status TEXT NOT NULL,
        raw_response TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE nutrition_requirements (
        category TEXT PRIMARY KEY,
        dry_matter_percentage REAL NOT NULL,
        protein_percentage REAL NOT NULL,
        energy_mcal_per_kg REAL NOT NULL,
        stage_notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE weight_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        animal_id TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        FOREIGN KEY (animal_id) REFERENCES animals (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE production_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        animal_id TEXT NOT NULL,
        liters REAL NOT NULL,
        turn TEXT,
        observation TEXT,
        FOREIGN KEY (animal_id) REFERENCES animals (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _seedNutritionTablesOnly(Database db) async {
    final initialResources = [
      {
        'type': 'pasto',
        'name': 'Pasto Kikuyo',
        'amount': 15.0,
        'unit': 'ha',
        'updated_at': '2026-06-14T19:00:00Z',
      },
      {
        'type': 'silo',
        'name': 'Silo de Maíz',
        'amount': 5.0,
        'unit': 'ton',
        'updated_at': '2026-06-14T19:00:00Z',
      },
      {
        'type': 'concentrado',
        'name': 'Balanceado Comercial',
        'amount': 500.0,
        'unit': 'kg',
        'updated_at': '2026-06-14T19:00:00Z',
      },
      {
        'type': 'suplemento',
        'name': 'Melaza',
        'amount': 80.0,
        'unit': 'kg',
        'updated_at': '2026-06-14T19:00:00Z',
      },
    ];
    for (var res in initialResources) {
      await db.insert('nutrition_resources', res);
    }

    final initialPlans = [
      {
        'created_at': '2026-06-14T12:00:00Z',
        'target_group': 'Vaca Lechera',
        'suggested_diet': 'Pasto Kikuyo (70%) + Concentrado (20%) + Melaza (10%)',
        'estimated_cost_per_day': 1.20,
        'projected_savings': 45.0,
        'projected_improvement': '+8% producción (3 sem) / +12% peso (4 sem)',
        'explanation': 'Tus vacas lecheras necesitan más energía en la tarde para mantener la producción nocturna. Agregar 200g de melaza al concentrado vespertino mejora el rendimiento sin requerir insumos adicionales.',
        'status': 'Activo',
      }
    ];
    for (var plan in initialPlans) {
      await db.insert('nutrition_plans', plan);
    }

    final initialWeights = [
      {'date': '2026-05-14T10:00:00Z', 'animal_id': '0234', 'weight_kg': 475.0},
      {'date': '2026-05-28T10:00:00Z', 'animal_id': '0234', 'weight_kg': 480.0},
      {'date': '2026-06-14T10:00:00Z', 'animal_id': '0234', 'weight_kg': 485.0},
      {'date': '2026-05-14T10:00:00Z', 'animal_id': '0089', 'weight_kg': 715.0},
      {'date': '2026-06-14T10:00:00Z', 'animal_id': '0089', 'weight_kg': 720.0},
      {'date': '2026-05-14T10:00:00Z', 'animal_id': '0456', 'weight_kg': 88.0},
      {'date': '2026-05-28T10:00:00Z', 'animal_id': '0456', 'weight_kg': 92.0},
      {'date': '2026-06-14T10:00:00Z', 'animal_id': '0456', 'weight_kg': 95.0},
      {'date': '2026-05-14T10:00:00Z', 'animal_id': '0178', 'weight_kg': 410.0},
      {'date': '2026-06-14T10:00:00Z', 'animal_id': '0178', 'weight_kg': 420.0},
      {'date': '2026-05-14T10:00:00Z', 'animal_id': '0312', 'weight_kg': 560.0},
      {'date': '2026-06-14T10:00:00Z', 'animal_id': '0312', 'weight_kg': 580.0},
    ];
    for (var w in initialWeights) {
      await db.insert('weight_records', w);
    }

    final initialProduction = [
      {'date': '2026-06-10T07:00:00Z', 'animal_id': '0234', 'liters': 12.0},
      {'date': '2026-06-11T07:00:00Z', 'animal_id': '0234', 'liters': 12.2},
      {'date': '2026-06-12T07:00:00Z', 'animal_id': '0234', 'liters': 12.4},
      {'date': '2026-06-13T07:00:00Z', 'animal_id': '0234', 'liters': 12.5},
      {'date': '2026-06-14T07:00:00Z', 'animal_id': '0234', 'liters': 12.5},
      {'date': '2026-06-10T07:00:00Z', 'animal_id': '0178', 'liters': 10.5},
      {'date': '2026-06-11T07:00:00Z', 'animal_id': '0178', 'liters': 10.6},
      {'date': '2026-06-12T07:00:00Z', 'animal_id': '0178', 'liters': 10.7},
      {'date': '2026-06-13T07:00:00Z', 'animal_id': '0178', 'liters': 10.8},
      {'date': '2026-06-14T07:00:00Z', 'animal_id': '0178', 'liters': 10.8},
    ];
    for (var p in initialProduction) {
      await db.insert('production_records', p);
    }
  }

  // --- CRUD DE RECURSOS NUTRICIONALES ---
  Future<List<NutritionResource>> getAllNutritionResources() async {
    final db = await instance.database;
    final result = await db.query('nutrition_resources', orderBy: 'type ASC');
    return result.map((json) => NutritionResource.fromMap(json)).toList();
  }

  Future<int> insertNutritionResource(NutritionResource resource) async {
    final db = await instance.database;
    final map = resource.toMap();
    final id = await db.insert('nutrition_resources', map);
    await _enqueueSync('nutrition_resources', id.toString(), 'INSERT', {...map, 'id': id});
    return id;
  }

  Future<int> updateNutritionResource(NutritionResource resource) async {
    final db = await instance.database;
    final map = resource.toMap();
    final count = await db.update(
      'nutrition_resources',
      map,
      where: 'id = ?',
      whereArgs: [resource.id],
    );
    await _enqueueSync('nutrition_resources', resource.id.toString(), 'UPDATE', map);
    return count;
  }

  Future<int> deleteNutritionResource(int id) async {
    final db = await instance.database;
    final count = await db.delete(
      'nutrition_resources',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueSync('nutrition_resources', id.toString(), 'DELETE', null);
    return count;
  }

  // --- CRUD DE PLANES DE NUTRICIÓN ---
  Future<List<NutritionPlan>> getAllNutritionPlans() async {
    final db = await instance.database;
    final result = await db.query('nutrition_plans', orderBy: 'created_at DESC');
    return result.map((json) => NutritionPlan.fromMap(json)).toList();
  }

  Future<int> insertNutritionPlan(NutritionPlan plan) async {
    final db = await instance.database;
    final map = plan.toMap();
    final id = await db.insert('nutrition_plans', map);
    await _enqueueSync('nutrition_plans', id.toString(), 'INSERT', {...map, 'id': id});
    return id;
  }

  Future<int> updateNutritionPlanStatus(int id, String status) async {
    final db = await instance.database;
    final map = {'status': status};
    final count = await db.update(
      'nutrition_plans',
      map,
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueSync('nutrition_plans', id.toString(), 'UPDATE', map);
    return count;
  }

  // --- CRUD DE REGISTROS DE PESO ---
  Future<List<WeightRecord>> getWeightRecordsForAnimal(String animalId) async {
    final db = await instance.database;
    final result = await db.query(
      'weight_records',
      where: 'animal_id = ?',
      whereArgs: [animalId],
      orderBy: 'date DESC',
    );
    return result.map((json) => WeightRecord.fromMap(json)).toList();
  }

  Future<int> insertWeightRecord(WeightRecord record) async {
    final db = await instance.database;
    final map = record.toMap();
    final id = await db.insert('weight_records', map);
    await _enqueueSync('weight_records', id.toString(), 'INSERT', {...map, 'id': id});
    return id;
  }

  // --- CRUD DE REGISTROS DE PRODUCCIÓN ---
  Future<List<ProductionRecord>> getProductionRecordsForAnimal(String animalId) async {
    final db = await instance.database;
    final result = await db.query(
      'production_records',
      where: 'animal_id = ?',
      whereArgs: [animalId],
      orderBy: 'date DESC',
    );
    return result.map((json) => ProductionRecord.fromMap(json)).toList();
  }

  Future<int> insertProductionRecord(ProductionRecord record) async {
    final db = await instance.database;
    final map = record.toMap();
    final id = await db.insert('production_records', map);
    await _enqueueSync('production_records', id.toString(), 'INSERT', {...map, 'id': id});
    return id;
  }

  // --- CRUD DE SETTINGS (MOCK SHAREDPREFERENCES) ---
  Future<int> saveSetting(String key, int value) async {
    final db = await instance.database;
    return await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int?> getSetting(String key) async {
    final db = await instance.database;
    try {
      final maps = await db.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
      );
      if (maps.isNotEmpty) {
        return maps.first['value'] as int?;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> getSettings() async {
    final db = await instance.database;
    try {
      final maps = await db.query('settings');
      final result = <String, dynamic>{};
      for (var map in maps) {
        final key = map['key'] as String;
        final val = map['value'] as int;
        result[key] = (val == 1);
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  // --- CRUD DE USER_PROFILE (DETALLADO) ---
  Future<Map<String, dynamic>> getUserProfile() async {
    final db = await instance.database;
    try {
      final maps = await db.query('user_profile', where: 'id = ?', whereArgs: [1]);
      if (maps.isNotEmpty) {
        return maps.first;
      }
    } catch (_) {}

    // Fallback al profile original
    try {
      final maps = await db.query('profile', where: 'id = ?', whereArgs: [1]);
      if (maps.isNotEmpty) {
        final p = maps.first;
        return {
          'id': 1,
          'owner_name': p['owner_name'],
          'farm_name': p['farm_name'],
          'location': p['location'],
          'animal_count': null,
          'role': 'Ganadero',
        };
      }
    } catch (_) {}

    return {
      'id': 1,
      'owner_name': 'Usuario',
      'farm_name': 'Mi Finca',
      'location': 'Ecuador',
      'animal_count': null,
      'role': 'Ganadero',
    };
  }

  Future<void> saveUserProfile({
    required String ownerName,
    required String farmName,
    required String location,
    required int? animalCount,
    required String role,
    String status = 'active',
    String? licenseNumber,
  }) async {
    final db = await instance.database;
    final data = {
      'id': 1,
      'owner_name': ownerName,
      'farm_name': farmName,
      'location': location,
      'animal_count': animalCount,
      'role': role,
      'status': status,
      'license_number': licenseNumber,
    };
    await db.insert(
      'user_profile',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Sincronizar con profile original
    final profileData = {
      'id': 1,
      'owner_name': ownerName,
      'farm_name': farmName,
      'location': location,
      'email': SupabaseService.instance.currentUser?.email ?? 'usuario@auraagro.ai',
    };
    await db.insert(
      'profile',
      profileData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _enqueueSync('user_profiles', '1', 'UPDATE', {
      'owner_name': ownerName,
      'farm_name': farmName,
      'location': location,
      'animal_count': animalCount,
      'role': role,
      'status': status,
      'license_number': licenseNumber,
    });
  }

  // --- CRUD DE FARM_AUTHORIZATIONS ---
  Future<List<Map<String, dynamic>>> getFarmAuthorizations() async {
    final db = await instance.database;
    try {
      return await db.query('farm_authorizations');
    } catch (_) {
      return [];
    }
  }

  Future<void> saveFarmAuthorization(Map<String, dynamic> auth) async {
    final db = await instance.database;
    await db.insert(
      'farm_authorizations',
      {
        'id': auth['id'],
        'ganadero_id': auth['ganadero_id'],
        'veterinario_id': auth['veterinario_id'],
        'status': auth['status'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteFarmAuthorization(String id) async {
    final db = await instance.database;
    await db.delete('farm_authorizations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearFarmAuthorizations() async {
    final db = await instance.database;
    try {
      await db.delete('farm_authorizations');
    } catch (_) {}
  }

  Future<void> saveDraft(String draftJson) async {
    final db = await instance.database;
    await db.execute('CREATE TABLE IF NOT EXISTS listing_drafts (id INTEGER PRIMARY KEY, draft_json TEXT, updated_at TEXT)');
    await db.insert(
      'listing_drafts',
      {
        'id': 1,
        'draft_json': draftJson,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getDraft() async {
    final db = await instance.database;
    await db.execute('CREATE TABLE IF NOT EXISTS listing_drafts (id INTEGER PRIMARY KEY, draft_json TEXT, updated_at TEXT)');
    final maps = await db.query('listing_drafts', where: 'id = ?', whereArgs: [1]);
    if (maps.isNotEmpty) {
      return maps.first['draft_json'] as String?;
    }
    return null;
  }

  Future<void> deleteDraft() async {
    final db = await instance.database;
    await db.execute('CREATE TABLE IF NOT EXISTS listing_drafts (id INTEGER PRIMARY KEY, draft_json TEXT, updated_at TEXT)');
    await db.delete('listing_drafts', where: 'id = ?', whereArgs: [1]);
  }

  // --- MÉTODOS DE LA COLA DE SINCRONIZACIÓN Y LIMPIEZA ---

  Future<void> _enqueueSync(String tableName, String recordId, String action, Map<String, dynamic>? data) async {
    final supabase = SupabaseService.instance;
    if (supabase.isEnabled && supabase.isAuthenticated) {
      try {
        final db = await database;
        String? dataJson;
        if (data != null) {
          dataJson = jsonEncode(data);
        }
        await db.insert('sync_queue', {
          'table_name': tableName,
          'record_id': recordId,
          'action': action,
          'data': dataJson,
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint("Enqueued sync: $tableName $recordId $action");
      } catch (e) {
        debugPrint("Error enqueuing sync: $e");
      }
    }
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await instance.database;
    return await db.query('sync_queue', orderBy: 'id ASC');
  }

  Future<void> deleteSyncQueueItem(int id) async {
    final db = await instance.database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearSyncQueue() async {
    final db = await instance.database;
    await db.delete('sync_queue');
  }

  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('profile');
      await txn.delete('user_profile');
      await txn.delete('animals');
      await txn.delete('vaccines');
      await txn.delete('alerts');
      await txn.delete('nutrition_resources');
      await txn.delete('nutrition_plans');
      await txn.delete('weight_records');
      await txn.delete('production_records');
      await txn.delete('sync_queue');
      await txn.delete('farm_authorizations');
      try {
        await txn.delete('marketplace_items');
      } catch (_) {}
    });
    debugPrint("SQLite data cleared successfully.");
  }

  // --- MÉTODOS DE REQUERIMIENTOS NUTRICIONALES ---
  Future<void> _seedRequirements(Database db) async {
    final defaultReqs = [
      {
        'category': 'Vaca Lechera',
        'dry_matter_percentage': 3.5,
        'protein_percentage': 16.0,
        'energy_mcal_per_kg': 2.7,
        'stage_notes': 'Alta demanda en lactancia. Requiere balance constante de calcio y fósforo.',
      },
      {
        'category': 'Vaca Seca',
        'dry_matter_percentage': 2.0,
        'protein_percentage': 12.0,
        'energy_mcal_per_kg': 2.0,
        'stage_notes': 'Fase de descanso y transición preparto. Evitar exceso de energía para no engordar.',
      },
      {
        'category': 'Toro Reproductor',
        'dry_matter_percentage': 2.2,
        'protein_percentage': 12.0,
        'energy_mcal_per_kg': 2.3,
        'stage_notes': 'Mantenimiento de líbido y condición física. Alta importancia de Zinc y Selenio.',
      },
      {
        'category': 'Toro Engorde',
        'dry_matter_percentage': 2.8,
        'protein_percentage': 14.0,
        'energy_mcal_per_kg': 2.8,
        'stage_notes': 'Enfoque en ganancia de peso (musculatura). Alta energía digestible y carbohidratos.',
      },
      {
        'category': 'Ternero',
        'dry_matter_percentage': 3.0,
        'protein_percentage': 18.0,
        'energy_mcal_per_kg': 2.9,
        'stage_notes': 'Etapa crítica de crecimiento. Alta digestibilidad requerida, fibra tierna y núcleos iniciadores.',
      },
    ];
    for (var req in defaultReqs) {
      await db.insert('nutrition_requirements', req, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<NutritionRequirement>> getAllNutritionRequirements() async {
    final db = await instance.database;
    final result = await db.query('nutrition_requirements');
    return result.map((json) => NutritionRequirement.fromMap(json)).toList();
  }

  Future<int> upsertNutritionRequirement(NutritionRequirement req) async {
    final db = await instance.database;
    return await db.insert(
      'nutrition_requirements',
      req.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- CRUD DE MARKETPLACE ITEMS ---
  Future<void> _createMarketplaceTable(Database db) async {
    await db.execute('''
      CREATE TABLE marketplace_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        score INTEGER NOT NULL,
        badge TEXT NOT NULL,
        price REAL NOT NULL,
        reference_price REAL,
        negotiable INTEGER NOT NULL DEFAULT 0,
        weight TEXT,
        production TEXT,
        location TEXT NOT NULL,
        response_time TEXT NOT NULL,
        certified INTEGER NOT NULL DEFAULT 1,
        price_range TEXT,
        category TEXT NOT NULL,
        promoted INTEGER NOT NULL DEFAULT 0,
        offer_tag TEXT,
        image_paths TEXT,
        description TEXT,
        arete_sisa TEXT,
        cvm_state TEXT,
        sisa_verified INTEGER NOT NULL DEFAULT 0,
        vacunas_al_dia INTEGER NOT NULL DEFAULT 0,
        historial_completo INTEGER NOT NULL DEFAULT 0,
        fotos_calidad INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<List<MarketplaceItem>> getAllMarketplaceItems() async {
    final db = await instance.database;
    final result = await db.query('marketplace_items', orderBy: 'id DESC');
    return result.map((json) => MarketplaceItem.fromMap(json)).toList();
  }

  Future<int> insertMarketplaceItem(MarketplaceItem item) async {
    final db = await instance.database;
    final map = item.toMap();
    final id = await db.insert('marketplace_items', map);
    await _enqueueSync('marketplace_items', id.toString(), 'INSERT', {...map, 'id': id});
    return id;
  }

  Future<int> deleteMarketplaceItem(int id) async {
    final db = await instance.database;
    final count = await db.delete(
      'marketplace_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueSync('marketplace_items', id.toString(), 'DELETE', null);
    return count;
  }

  // --- MÉTODOS DE TABLAS MVP (VERSION 11) ---

  Future<void> _createMvpTables(Database db) async {
    await db.execute('DROP TABLE IF EXISTS alerts');
    await db.execute('''
      CREATE TABLE alerts (
        id TEXT PRIMARY KEY,
        animal_id TEXT,
        type TEXT,
        risk_level TEXT,
        title TEXT,
        description TEXT,
        source TEXT,
        created_at TEXT,
        is_read INTEGER DEFAULT 0,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sos_cases (
        id TEXT PRIMARY KEY,
        animal_id TEXT,
        symptoms_text TEXT,
        selected_symptoms TEXT,
        risk_level TEXT,
        title TEXT,
        explanation TEXT,
        safe_actions TEXT,
        notify_vet INTEGER,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE animal_exits (
        id TEXT PRIMARY KEY,
        animal_id TEXT,
        exit_type TEXT,
        exit_date TEXT,
        reason TEXT,
        sale_price REAL,
        buyer TEXT,
        observations TEXT,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE medicine_inventory (
        id TEXT PRIMARY KEY,
        name TEXT,
        type TEXT,
        quantity REAL,
        unit TEXT,
        min_stock REAL,
        expiration_date TEXT,
        provider TEXT,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE medical_treatments (
        id TEXT PRIMARY KEY,
        animal_id TEXT,
        diagnosis TEXT,
        symptoms TEXT,
        treatment TEXT,
        medicine_id TEXT,
        dose REAL,
        responsible TEXT,
        date TEXT,
        observations TEXT,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE reproduction_records (
        id TEXT PRIMARY KEY,
        animal_id TEXT,
        event_type TEXT,
        event_date TEXT,
        notes TEXT,
        expected_birth_date TEXT,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE operating_expenses (
        id TEXT PRIMARY KEY,
        category TEXT,
        amount REAL,
        date TEXT,
        description TEXT,
        animal_id TEXT,
        farm_id TEXT,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');
  }

  // SOS Cases
  Future<int> insertSosCase(Map<String, dynamic> row) async {
    final db = await instance.database;
    final count = await db.insert('sos_cases', row, conflictAlgorithm: ConflictAlgorithm.replace);
    await _enqueueSync('sos_cases', row['id'] as String, 'INSERT', row);
    return count;
  }

  Future<List<Map<String, dynamic>>> getAllSosCases() async {
    final db = await instance.database;
    return await db.query('sos_cases', orderBy: 'created_at DESC');
  }

  // Animal Exits
  Future<int> insertAnimalExit(Map<String, dynamic> row) async {
    final db = await instance.database;
    final count = await db.insert('animal_exits', row, conflictAlgorithm: ConflictAlgorithm.replace);
    await _enqueueSync('animal_exits', row['id'] as String, 'INSERT', row);
    return count;
  }

  Future<List<Map<String, dynamic>>> getAllAnimalExits() async {
    final db = await instance.database;
    return await db.query('animal_exits', orderBy: 'exit_date DESC');
  }

  // Medicine Inventory
  Future<int> insertMedicine(Map<String, dynamic> row) async {
    final db = await instance.database;
    final count = await db.insert('medicine_inventory', row, conflictAlgorithm: ConflictAlgorithm.replace);
    await _enqueueSync('medicine_inventory', row['id'] as String, 'INSERT', row);
    return count;
  }

  Future<int> updateMedicine(Map<String, dynamic> row) async {
    final db = await instance.database;
    final count = await db.update(
      'medicine_inventory',
      row,
      where: 'id = ?',
      whereArgs: [row['id']],
    );
    await _enqueueSync('medicine_inventory', row['id'] as String, 'UPDATE', row);
    return count;
  }

  Future<int> updateMedicineStock(String id, double quantity) async {
    final db = await instance.database;
    final map = {'quantity': quantity};
    final count = await db.update(
      'medicine_inventory',
      map,
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueSync('medicine_inventory', id, 'UPDATE', map);
    return count;
  }

  Future<List<Map<String, dynamic>>> getAllMedicines() async {
    final db = await instance.database;
    return await db.query('medicine_inventory', orderBy: 'name ASC');
  }

  // Medical Treatments
  Future<int> insertMedicalTreatment(Map<String, dynamic> row) async {
    final db = await instance.database;
    final count = await db.insert('medical_treatments', row, conflictAlgorithm: ConflictAlgorithm.replace);
    await _enqueueSync('medical_treatments', row['id'] as String, 'INSERT', row);
    return count;
  }

  Future<List<Map<String, dynamic>>> getAllMedicalTreatments() async {
    final db = await instance.database;
    return await db.query('medical_treatments', orderBy: 'date DESC');
  }

  // Reproduction Records
  Future<int> insertReproductionRecord(Map<String, dynamic> row) async {
    final db = await instance.database;
    final count = await db.insert('reproduction_records', row, conflictAlgorithm: ConflictAlgorithm.replace);
    await _enqueueSync('reproduction_records', row['id'] as String, 'INSERT', row);
    return count;
  }

  Future<List<Map<String, dynamic>>> getAllReproductionRecords() async {
    final db = await instance.database;
    return await db.query('reproduction_records', orderBy: 'event_date DESC');
  }

  Future<List<Map<String, dynamic>>> getReproductionRecordsForAnimal(String animalId) async {
    final db = await instance.database;
    return await db.query(
      'reproduction_records',
      where: 'animal_id = ?',
      whereArgs: [animalId],
      orderBy: 'event_date DESC',
    );
  }

  // Operating Expenses
  Future<int> insertOperatingExpense(Map<String, dynamic> row) async {
    final db = await instance.database;
    final count = await db.insert('operating_expenses', row, conflictAlgorithm: ConflictAlgorithm.replace);
    await _enqueueSync('operating_expenses', row['id'] as String, 'INSERT', row);
    return count;
  }

  Future<List<Map<String, dynamic>>> getAllOperatingExpenses() async {
    final db = await instance.database;
    return await db.query('operating_expenses', orderBy: 'date DESC');
  }
}
