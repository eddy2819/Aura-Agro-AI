import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Servicio principal para la interacción directa con Supabase.
/// Soporta fallback seguro si no se configuran las llaves en el archivo `.env`.
class SupabaseService {
  static final SupabaseService instance = SupabaseService._init();
  
  bool _initialized = false;

  SupabaseService._init();

  /// Retorna si Supabase está activo y tiene credenciales válidas
  bool get isEnabled => _initialized && _hasValidCredentials();

  bool _hasValidCredentials() {
    try {
      final url = dotenv.maybeGet('SUPABASE_URL');
      final key = dotenv.maybeGet('SUPABASE_ANON_KEY');
      if (url == null || key == null) return false;
      if (url.isEmpty || key.isEmpty) return false;
      if (url.contains('TU_PROYECTO') || key.contains('TU_ANON_KEY')) return false;
      return url.startsWith('https://');
    } catch (_) {
      return false;
    }
  }

  /// Inicializa la conexión con Supabase.
  /// Si ocurre un error o las credenciales no son válidas, deshabilita silenciosamente
  /// el servicio permitiendo a la aplicación funcionar en Modo Local.
  Future<void> initialize() async {
    try {
      if (_hasValidCredentials()) {
        var url = dotenv.get('SUPABASE_URL').trim();
        final key = dotenv.get('SUPABASE_ANON_KEY').trim();
        
        // Limpiar URL si contiene /rest/v1/ al final
        if (url.endsWith('/rest/v1/')) {
          url = url.substring(0, url.length - 9);
        } else if (url.endsWith('/rest/v1')) {
          url = url.substring(0, url.length - 8);
        }
        if (url.endsWith('/')) {
          url = url.substring(0, url.length - 1);
        }

        await Supabase.initialize(
          url: url,
          anonKey: key,
        );
        _initialized = true;
        debugPrint("Supabase initialized successfully on URL: $url");
      } else {
        debugPrint("Supabase bypass: invalid or missing credentials in .env.");
        _initialized = false;
      }
    } catch (e) {
      debugPrint("Error initializing Supabase: $e");
      _initialized = false;
    }
  }

  /// Cliente directo de Supabase
  SupabaseClient get client {
    if (!isEnabled) {
      throw Exception("Intento de acceder al cliente de Supabase cuando está inactivo o sin configurar.");
    }
    return Supabase.instance.client;
  }

  /// Retorna el usuario actual de Supabase
  User? get currentUser {
    if (!isEnabled) return null;
    try {
      return client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Retorna el ID del usuario actual de Supabase
  String? get currentUserId => currentUser?.id;

  /// Retorna si hay una sesión activa en Supabase
  bool get isAuthenticated => currentUser != null;

  // ==========================================
  // AUTENTICACIÓN
  // ==========================================

  /// Registrar usuario con Email y Contraseña
  Future<AuthResponse> signUp({
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
    if (!isEnabled) throw Exception("Supabase no está configurado.");
    
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'owner_name': ownerName,
        'farm_name': farmName,
        'location': location,
        'animal_count': animalCount,
        'role': role,
        'license_number': licenseNumber,
        'status': status,
      },
    );

    if (response.user != null) {
      // Guardar el perfil público en la tabla de Supabase
      await client.from('user_profiles').upsert({
        'user_id': response.user!.id,
        'owner_name': ownerName,
        'farm_name': farmName,
        'location': location,
        'animal_count': animalCount,
        'role': role,
        'license_number': licenseNumber,
        'status': status,
        'email': email,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    return response;
  }

  /// Iniciar sesión con Email y Contraseña
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    if (!isEnabled) throw Exception("Supabase no está configurado.");
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Cerrar Sesión en Supabase
  Future<void> signOut() async {
    if (isEnabled && isAuthenticated) {
      try {
        await client.auth.signOut();
      } catch (e) {
        debugPrint("Error signing out from Supabase: $e");
      }
    }
  }

  // ==========================================
  // ADMINISTRACIÓN (VETERINARIOS PENDIENTES)
  // ==========================================

  /// Obtener veterinarios pendientes de aprobación (Solo para Admin)
  Future<List<Map<String, dynamic>>> getPendingVeterinarians() async {
    if (!isEnabled) return [];
    try {
      final response = await client
          .from('user_profiles')
          .select()
          .eq('role', 'Veterinario')
          .eq('status', 'pending');
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint("Error al obtener veterinarios pendientes: $e");
      return [];
    }
  }

  /// Actualizar el estado de un veterinario (Solo para Admin)
  Future<void> updateVeterinarianStatus(String userId, String status) async {
    if (!isEnabled) return;
    try {
      if (status == 'rejected') {
        await client.from('user_profiles').delete().eq('user_id', userId);
      } else {
        await client.from('user_profiles').update({'status': status}).eq('user_id', userId);
      }
    } catch (e) {
      debugPrint("Error al actualizar estado del veterinario ($userId) a $status: $e");
    }
  }

  // ==========================================
  // AUTORIZACIONES DE FINCAS (VET <-> GANADERO)
  // ==========================================

  /// Enviar solicitud de acceso a una finca usando el email del ganadero (Veterinario)
  Future<void> requestFarmAuthorization(String ganaderoEmail) async {
    if (!isEnabled) throw Exception("Supabase no está configurado.");
    final vetId = currentUserId;
    if (vetId == null) throw Exception("Usuario no autenticado.");

    // 1. Buscar al ganadero por correo electrónico en user_profiles
    final ganaderoResponse = await client
        .from('user_profiles')
        .select('user_id')
        .eq('email', ganaderoEmail)
        .eq('role', 'Ganadero')
        .maybeSingle();

    if (ganaderoResponse == null) {
      throw Exception("No se encontró ningún ganadero con ese correo electrónico.");
    }

    final ganaderoId = ganaderoResponse['user_id'] as String;

    // 2. Comprobar si ya existe una solicitud o autorización
    final existingResponse = await client
        .from('farm_authorizations')
        .select()
        .eq('ganadero_id', ganaderoId)
        .eq('veterinario_id', vetId)
        .maybeSingle();

    if (existingResponse != null) {
      throw Exception("Ya existe una solicitud o autorización activa para este ganadero.");
    }

    // 3. Crear la autorización con estado 'pending'
    await client.from('farm_authorizations').insert({
      'ganadero_id': ganaderoId,
      'veterinario_id': vetId,
      'status': 'pending',
    });
  }

  /// Responder a una solicitud de autorización (Ganadero)
  Future<void> respondToAuthorizationRequest(String authId, String status) async {
    if (!isEnabled) return;
    try {
      if (status == 'rejected') {
        await client.from('farm_authorizations').delete().eq('id', authId);
      } else {
        await client.from('farm_authorizations').update({'status': status}).eq('id', authId);
      }
    } catch (e) {
      debugPrint("Error al responder a la autorización ($authId) con $status: $e");
    }
  }

  /// Cargar solicitudes de autorización del usuario actual (Ganadero o Veterinario)
  Future<List<Map<String, dynamic>>> fetchRemoteFarmAuthorizations() async {
    if (!isEnabled) return [];
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final response = await client
          .from('farm_authorizations')
          .select();

      final list = List<Map<String, dynamic>>.from(response as List);
      final enrichedList = <Map<String, dynamic>>[];

      for (var auth in list) {
        final ganaderoId = auth['ganadero_id'] as String;
        final vetId = auth['veterinario_id'] as String;

        // Si no estamos involucrados en esta autorización, ignorarla (por RLS no debería cargarse, pero validamos)
        if (ganaderoId != userId && vetId != userId) continue;

        // Traer ganadero profile
        final ganaderoProfile = await client
            .from('user_profiles')
            .select('owner_name, farm_name, email')
            .eq('user_id', ganaderoId)
            .maybeSingle();

        // Traer vet profile
        final vetProfile = await client
            .from('user_profiles')
            .select('owner_name, email, license_number')
            .eq('user_id', vetId)
            .maybeSingle();

        enrichedList.add({
          ...auth,
          'ganadero_name': ganaderoProfile?['owner_name'] ?? 'Ganadero',
          'farm_name': ganaderoProfile?['farm_name'] ?? 'Finca',
          'ganadero_email': ganaderoProfile?['email'] ?? '',
          'veterinario_name': vetProfile?['owner_name'] ?? 'Veterinario',
          'veterinario_email': vetProfile?['email'] ?? '',
          'license_number': vetProfile?['license_number'] ?? '',
        });
      }

      return enrichedList;
    } catch (e) {
      debugPrint("Error fetching farm authorizations: $e");
      return [];
    }
  }

  // ==========================================
  // IA NUTRICIÓN & EDGE FUNCTIONS
  // ==========================================

  /// Sube de forma privada una foto de animal a Supabase Storage
  Future<String?> uploadAnimalPhoto(String filePath, String fileName) async {
    if (!isEnabled) {
      debugPrint("Supabase deshabilitado. No se puede subir foto.");
      return null;
    }
    try {
      final file = File(filePath);
      final fileBytes = await file.readAsBytes();
      final user = currentUser;
      if (user == null) return null;

      final path = 'animals/${user.id}/$fileName';
      
      // Subir al bucket 'animal-photos'
      await client.storage.from('animal-photos').uploadBinary(
        path,
        fileBytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      
      return path;
    } catch (e) {
      debugPrint("Error al subir foto a Supabase Storage: $e");
      return null;
    }
  }

  /// Invoca la Edge Function aura-ai para análisis y recomendación nutricional
  Future<Map<String, dynamic>?> invokeNutritionEdgeFunction(Map<String, dynamic> payload) async {
    if (!isEnabled) {
      debugPrint("Supabase deshabilitado. No se puede llamar a Edge Function.");
      return null;
    }
    try {
      final response = await client.functions.invoke(
        'aura-ai',
        body: payload,
      );
      if (response.status == 200) {
        if (response.data is Map) {
          return Map<String, dynamic>.from(response.data);
        } else if (response.data is String) {
          return jsonDecode(response.data) as Map<String, dynamic>;
        }
      }
      debugPrint("Edge Function returned code: ${response.status}");
      return null;
    } catch (e) {
      debugPrint("Error invocando Edge Function: $e");
      return null;
    }
  }
}
