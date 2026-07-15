import 'dart:convert';
import 'dart:io';

import '../models/medicine_scan_result.dart';
import 'supabase_service.dart';

class MedicineVisionService {
  static final MedicineVisionService instance = MedicineVisionService._();

  MedicineVisionService._();

  Future<MedicineScanResult> scanMedicineLabel(File image) async {
    if (!await image.exists()) {
      throw Exception('No se encontró la fotografía seleccionada.');
    }
    final response = await SupabaseService.instance
        .invokeNutritionEdgeFunction({
          'action': 'analyze_medicine_label',
          'image_base64': base64Encode(await image.readAsBytes()),
          'image_mime_type': _mimeType(image.path),
        });
    final analysis = response?['medicine_analysis'];
    if (analysis is! Map) {
      throw Exception(
        'No se pudo leer la etiqueta. Intenta con una foto más clara.',
      );
    }
    return MedicineScanResult.fromMap(Map<String, dynamic>.from(analysis));
  }

  String _mimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
