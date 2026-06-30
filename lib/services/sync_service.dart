import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../data/db_helper.dart';
import 'supabase_service.dart';

/// Estado del motor de sincronización.
enum SyncStatus { idle, syncing, success, error }

/// Motor de sincronización local-first (Supabase <-> SQLite)
class SyncService {
  static final SyncService instance = SyncService._init();
  
  final _supabaseService = SupabaseService.instance;
  final _dbHelper = DBHelper.instance;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  final StreamController<SyncStatus> _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  // Callback para notificar al DataProvider cuando los datos locales han cambiado
  VoidCallback? onSyncCompleted;

  SyncService._init() {
    _startConnectivityListener();
  }

  void _startConnectivityListener() {
    try {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
        final hasConnection = results.isNotEmpty && results.first != ConnectivityResult.none;
        if (hasConnection && _supabaseService.isEnabled && _supabaseService.isAuthenticated) {
          // Tratar de sincronizar de forma asíncrona cuando volvemos a tener señal
          sync();
        }
      });
    } catch (e) {
      debugPrint("No se pudo iniciar el listener de conectividad: $e");
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
  }

  /// Ejecuta un ciclo completo de sincronización (Push -> Pull)
  Future<void> sync() async {
    if (_isSyncing) return;
    if (!_supabaseService.isEnabled || !_supabaseService.isAuthenticated) {
      debugPrint("Sync bypass: Supabase está desactivado o no hay sesión activa.");
      return;
    }

    _isSyncing = true;
    _statusController.add(SyncStatus.syncing);

    try {
      // 1. PUSH: Subir cambios locales pendientes
      final pushSuccess = await _pushLocalChanges();
      if (!pushSuccess) {
        throw Exception("Falló la subida de cambios locales (Push)");
      }

      // 2. PULL: Bajar y mezclar cambios remotos
      await _pullRemoteChanges();

      _statusController.add(SyncStatus.success);
      debugPrint("Sincronización completada con éxito.");
      
      // Notificar al DataProvider que recargue los datos
      if (onSyncCompleted != null) {
        onSyncCompleted!();
      }
    } catch (e) {
      debugPrint("Error durante la sincronización: $e");
      _statusController.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
      // Retornar a reposo después de un momento
      Future.delayed(const Duration(seconds: 3), () {
        if (!_statusController.isClosed) {
          _statusController.add(SyncStatus.idle);
        }
      });
    }
  }

  /// Sube los cambios locales pendientes de la tabla `sync_queue` a Supabase.
  Future<bool> _pushLocalChanges() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return false;

    final queue = await _dbHelper.getSyncQueue();
    if (queue.isEmpty) {
      debugPrint("No hay cambios locales pendientes por subir.");
      return true;
    }

    final localProfile = await _dbHelper.getUserProfile();
    final String role = localProfile['role'] ?? 'Ganadero';

    debugPrint("Procesando cola de sincronización (${queue.length} elementos)...");

    for (var item in queue) {
      final queueId = item['id'] as int;
      final tableName = item['table_name'] as String;
      final recordId = item['record_id'] as String;
      final action = item['action'] as String;
      final dataStr = item['data'] as String?;
      
      Map<String, dynamic>? localData;
      if (dataStr != null) {
        try {
          localData = jsonDecode(dataStr) as Map<String, dynamic>;
        } catch (_) {}
      }

      try {
        String targetUserId = userId;

        // Si es Veterinario, necesitamos averiguar a quién pertenece el animal para
        // asociar los registros de vacuna/alertas/peso/prod al Ganadero correspondiente.
        if (role == 'Veterinario' && tableName != 'user_profiles') {
          String? animalId = localData?['animal_id'];
          if (animalId == null && tableName == 'alerts' && localData != null) {
            final String? tag = localData['animal_tag'];
            if (tag != null) {
              final anim = await _supabaseService.client
                  .from('animals')
                  .select('user_id')
                  .eq('tag', tag)
                  .maybeSingle();
              if (anim != null) {
                targetUserId = anim['user_id'] as String;
              }
            }
          } else if (animalId != null) {
            final anim = await _supabaseService.client
                .from('animals')
                .select('user_id')
                .eq('id', animalId)
                .maybeSingle();
            if (anim != null) {
              targetUserId = anim['user_id'] as String;
            }
          }
        }

        if (tableName == 'user_profiles') {
          // El perfil de usuario tiene clave primaria 'user_id' en Supabase y no 'id'
          if (action == 'UPDATE' && localData != null) {
            final payload = {
              'user_id': userId,
              ...localData,
              'updated_at': DateTime.now().toIso8601String(),
            };
            payload.remove('id');
            await _supabaseService.client.from('user_profiles').upsert(payload);
          }
        } else if (tableName == 'animals') {
          // Tabla con ID tipo TEXT
          if (action == 'DELETE') {
            await _supabaseService.client
                .from('animals')
                .delete()
                .match({'user_id': targetUserId, 'id': recordId});
          } else if (localData != null) {
            final payload = {
              'user_id': targetUserId,
              ...localData,
              'updated_at': DateTime.now().toIso8601String(),
            };
            // Convertir booleanos a correspondientes para Postgres
            payload['grazing'] = payload['grazing'] == 1 || payload['grazing'] == true;
            payload['balanced_feed'] = payload['balanced_feed'] == 1 || payload['balanced_feed'] == true;
            payload['supplements'] = payload['supplements'] == 1 || payload['supplements'] == true;
            payload['has_alert'] = payload['has_alert'] == 1 || payload['has_alert'] == true;
            payload['available_for_sale'] = payload['available_for_sale'] == 1 || payload['available_for_sale'] == true;
            
            await _supabaseService.client.from('animals').upsert(payload);
          }
        } else {
          // Tablas con IDs incrementales locales mapeados a local_id
          final localIntId = int.parse(recordId);
          if (action == 'DELETE') {
            await _supabaseService.client
                .from(tableName)
                .delete()
                .match({'user_id': targetUserId, 'local_id': localIntId});
          } else if (localData != null) {
            final payload = {
              'user_id': targetUserId,
              'local_id': localIntId,
              ...localData,
            };
            payload.remove('id'); // Removemos la columna id autoincremental de SQLite
            if (tableName == 'marketplace_items') {
              payload['negotiable'] = payload['negotiable'] == 1 || payload['negotiable'] == true;
              payload['certified'] = payload['certified'] == 1 || payload['certified'] == true;
              payload['promoted'] = payload['promoted'] == 1 || payload['promoted'] == true;
              payload['sisa_verified'] = payload['sisa_verified'] == 1 || payload['sisa_verified'] == true;
              payload['vacunas_al_dia'] = payload['vacunas_al_dia'] == 1 || payload['vacunas_al_dia'] == true;
              payload['historial_completo'] = payload['historial_completo'] == 1 || payload['historial_completo'] == true;
              payload['fotos_calidad'] = payload['fotos_calidad'] == 1 || payload['fotos_calidad'] == true;
            }
            await _supabaseService.client.from(tableName).upsert(payload);
          }
        }

        // Si la operación fue exitosa, removemos el item de la cola local
        await _dbHelper.deleteSyncQueueItem(queueId);
        debugPrint("Sincronizado: $tableName (ID: $recordId, Acción: $action)");
      } catch (e) {
        debugPrint("Error sincronizando fila en cola: $e. Deteniendo push.");
        return false; // Detener sincronización para conservar el orden
      }
    }
    return true;
  }

  /// Descarga los datos de Supabase y los actualiza localmente.
  Future<void> _pullRemoteChanges() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;

    final db = await _dbHelper.database;
    final queue = await _dbHelper.getSyncQueue();

    // Helper para saber si un registro local tiene cambios pendientes por subir
    bool isPending(String table, String keyField, dynamic keyValue) {
      return queue.any((q) => q['table_name'] == table && q['record_id'] == keyValue.toString());
    }

    String role = 'Ganadero';

    // 1. Sincronizar PERFIL (user_profiles)
    try {
      final remoteProfileResponse = await _supabaseService.client
          .from('user_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (remoteProfileResponse != null && !isPending('user_profiles', 'id', '1')) {
        final profileMap = remoteProfileResponse as Map<String, dynamic>;
        role = profileMap['role'] ?? 'Ganadero';
        
        await db.insert('user_profile', {
          'id': 1,
          'owner_name': profileMap['owner_name'],
          'farm_name': profileMap['farm_name'],
          'location': profileMap['location'],
          'animal_count': profileMap['animal_count'],
          'role': profileMap['role'],
          'status': profileMap['status'] ?? 'active',
          'license_number': profileMap['license_number'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        await db.insert('profile', {
          'id': 1,
          'owner_name': profileMap['owner_name'],
          'farm_name': profileMap['farm_name'],
          'location': profileMap['location'],
          'email': profileMap['email'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        final localProfile = await _dbHelper.getUserProfile();
        role = localProfile['role'] ?? 'Ganadero';
      }
    } catch (e) {
      debugPrint("Error haciendo pull de perfil: $e");
      final localProfile = await _dbHelper.getUserProfile();
      role = localProfile['role'] ?? 'Ganadero';
    }

    // Si es Administrador, no tiene hatos de animales ni calendarios
    if (role == 'Admin') {
      return;
    }

    // 2. Sincronizar autorizaciones de finca (Tanto Ganadero como Veterinario las necesitan)
    List<String> authorizedGanaderoIds = [];
    try {
      final remoteAuths = await _supabaseService.fetchRemoteFarmAuthorizations();
      await db.delete('farm_authorizations'); // Limpiar local
      for (var auth in remoteAuths) {
        await db.insert('farm_authorizations', {
          'id': auth['id'],
          'ganadero_id': auth['ganadero_id'],
          'veterinario_id': auth['veterinario_id'],
          'status': auth['status'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        
        if (auth['veterinario_id'] == userId && auth['status'] == 'active') {
          authorizedGanaderoIds.add(auth['ganadero_id'] as String);
        }
      }
    } catch (e) {
      debugPrint("Error al sincronizar autorizaciones de finca: $e");
    }

    // 3. Sincronizar ANIMALES
    try {
      final List<dynamic> animalsList;
      if (role == 'Veterinario') {
        if (authorizedGanaderoIds.isEmpty) {
          await db.delete('animals');
          animalsList = [];
        } else {
          final response = await _supabaseService.client
              .from('animals')
              .select()
              .inFilter('user_id', authorizedGanaderoIds);
          animalsList = response as List<dynamic>;
        }
      } else {
        final response = await _supabaseService.client
            .from('animals')
            .select()
            .eq('user_id', userId);
        animalsList = response as List<dynamic>;
      }

      final List<String> remoteIds = [];

      for (var row in animalsList) {
        final map = row as Map<String, dynamic>;
        final id = map['id'] as String;
        remoteIds.add(id);

        if (!isPending('animals', 'id', id)) {
          // Adaptar tipos (Postgres booleans/decimals a SQLite ints/reals)
          final localMap = {
            'id': map['id'],
            'name': map['name'],
            'tag': map['tag'],
            'category': map['category'],
            'score': map['score'],
            'description': map['description'],
            'weight_kg': (map['weight_kg'] as num).toDouble(),
            'production_liters': map['production_liters'],
            'vaccine_status': map['vaccine_status'],
            'has_alert': map['has_alert'] == true ? 1 : 0,
            'image_path': map['image_path'],
            'breed': map['breed'],
            'sex': map['sex'],
            'birth_date': map['birth_date'],
            'status': map['status'],
            'purpose': map['purpose'],
            'stage': map['stage'],
            'body_condition': map['body_condition'] != null ? (map['body_condition'] as num).toDouble() : null,
            'color': map['color'],
            'genetic_father': map['genetic_father'],
            'genetic_mother': map['genetic_mother'],
            'genetic_line': map['genetic_line'],
            'origin': map['origin'],
            'health_status': map['health_status'],
            'last_vet_check': map['last_vet_check'],
            'vet_responsible': map['vet_responsible'],
            'prev_diseases': map['prev_diseases'],
            'allergies': map['allergies'],
            'current_medication': map['current_medication'],
            'diet_type': map['diet_type'],
            'grazing': map['grazing'] == true ? 1 : 0,
            'balanced_feed': map['balanced_feed'] == true ? 1 : 0,
            'supplements': map['supplements'] == true ? 1 : 0,
            'daily_consumption': map['daily_consumption'] != null ? (map['daily_consumption'] as num).toDouble() : null,
            'production_objective': map['production_objective'],
            'finca': map['finca'],
            'lote': map['lote'],
            'potrero': map['potrero'],
            'gps_coords': map['gps_coords'],
            'purchase_value': map['purchase_value'] != null ? (map['purchase_value'] as num).toDouble() : null,
            'purchase_date': map['purchase_date'],
            'provider': map['provider'],
            'available_for_sale': map['available_for_sale'] == true ? 1 : 0,
            'image_front_path': map['image_front_path'],
            'image_side_path': map['image_side_path'],
            'cert_sanitary_path': map['cert_sanitary_path'],
            'doc_purchase_path': map['doc_purchase_path'],
          };
          await db.insert('animals', localMap, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Borrar localmente animales que fueron eliminados en remoto (y no están en cola de subida)
      final localAnimals = await db.query('animals', columns: ['id']);
      for (var la in localAnimals) {
        final id = la['id'] as String;
        if (!remoteIds.contains(id) && !isPending('animals', 'id', id)) {
          await db.delete('animals', where: 'id = ?', whereArgs: [id]);
        }
      }
    } catch (e) {
      debugPrint("Error haciendo pull de animales: $e");
    }

    // 4. Sincronizar el resto de tablas con ID autoincremental mapeados a local_id
    final tablesToSync = [
      'vaccines',
      'alerts',
      'nutrition_resources',
      'nutrition_plans',
      'weight_records',
      'production_records',
      'marketplace_items'
    ];

    for (var tableName in tablesToSync) {
      try {
        final List<dynamic> rowsList;
        if (role == 'Veterinario') {
          if (authorizedGanaderoIds.isEmpty) {
            await db.delete(tableName);
            rowsList = [];
          } else {
            final response = await _supabaseService.client
                .from(tableName)
                .select()
                .inFilter('user_id', authorizedGanaderoIds);
            rowsList = response as List<dynamic>;
          }
        } else {
          final response = await _supabaseService.client
              .from(tableName)
              .select()
              .eq('user_id', userId);
          rowsList = response as List<dynamic>;
        }

        final List<int> remoteLocalIds = [];

        for (var row in rowsList) {
          final map = row as Map<String, dynamic>;
          final localId = map['local_id'] as int;
          remoteLocalIds.add(localId);

          if (!isPending(tableName, 'id', localId)) {
            // Mapeamos de vuelta local_id a id de SQLite
            final localMap = {
              'id': localId,
              ...map,
            };
            localMap.remove('user_id');
            localMap.remove('local_id');
            localMap.remove('updated_at'); // si existe en postgres

            // Ajustar booleanos / numéricos según la tabla
            if (tableName == 'alerts') {
              // no tiene tipos complejos más allá de enteros / strings
            } else if (tableName == 'nutrition_resources') {
              localMap['amount'] = (map['amount'] as num).toDouble();
              if (map['cost'] != null) {
                localMap['cost'] = (map['cost'] as num).toDouble();
              }
            } else if (tableName == 'nutrition_plans') {
              localMap['estimated_cost_per_day'] = (map['estimated_cost_per_day'] as num).toDouble();
              localMap['projected_savings'] = (map['projected_savings'] as num).toDouble();
            } else if (tableName == 'weight_records') {
              localMap['weight_kg'] = (map['weight_kg'] as num).toDouble();
            } else if (tableName == 'production_records') {
              localMap['liters'] = (map['liters'] as num).toDouble();
            } else if (tableName == 'marketplace_items') {
              localMap['price'] = (map['price'] as num).toDouble();
              if (map['reference_price'] != null) {
                localMap['reference_price'] = (map['reference_price'] as num).toDouble();
              }
              localMap['negotiable'] = (map['negotiable'] == true || map['negotiable'] == 1) ? 1 : 0;
              localMap['certified'] = (map['certified'] == true || map['certified'] == 1) ? 1 : 0;
              localMap['promoted'] = (map['promoted'] == true || map['promoted'] == 1) ? 1 : 0;
              localMap['sisa_verified'] = (map['sisa_verified'] == true || map['sisa_verified'] == 1) ? 1 : 0;
              localMap['vacunas_al_dia'] = (map['vacunas_al_dia'] == true || map['vacunas_al_dia'] == 1) ? 1 : 0;
              localMap['historial_completo'] = (map['historial_completo'] == true || map['historial_completo'] == 1) ? 1 : 0;
              localMap['fotos_calidad'] = (map['fotos_calidad'] == true || map['fotos_calidad'] == 1) ? 1 : 0;
            }

            await db.insert(tableName, localMap, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // Borrar localmente lo que no está en Supabase y no está pendiente de subida
        final localRows = await db.query(tableName, columns: ['id']);
        for (var lr in localRows) {
          final id = lr['id'] as int;
          if (!remoteLocalIds.contains(id) && !isPending(tableName, 'id', id)) {
            await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
          }
        }
      } catch (e) {
        debugPrint("Error haciendo pull de tabla $tableName: $e");
      }
    }
  }
}
