import 'dart:math';
import '../models/animal.dart';

class PhotoAnalysisResult {
  final bool isWellFramed;
  final String? suggestedCropAlert;
  final double bodyConditionScore;
  final String? bodyConditionAlert;
  final bool isAreteVisible;
  final String? areteAlert;
  final String summary;

  PhotoAnalysisResult({
    required this.isWellFramed,
    this.suggestedCropAlert,
    required this.bodyConditionScore,
    this.bodyConditionAlert,
    required this.isAreteVisible,
    this.areteAlert,
    required this.summary,
  });
}

abstract class MarketplaceAiService {
  Future<PhotoAnalysisResult> analyzePhoto({
    required String imagePath,
    required String category,
    Animal? animal,
  });

  Future<String> generateDescription({
    required String category,
    required String breed,
    required String sex,
    required double weight,
    String? production,
    required int healthScore,
    required String vaccineStatus,
    required String name,
  });
}

class LocalHeuristicMarketplaceAiService implements MarketplaceAiService {
  final Random _random = Random();

  @override
  Future<PhotoAnalysisResult> analyzePhoto({
    required String imagePath,
    required String category,
    Animal? animal,
  }) async {
    // 1. Simular latencia de análisis de visión por computadora en segundo plano (2.0 segundos)
    await Future.delayed(const Duration(milliseconds: 2000));

    final isWellFramed = _random.nextDouble() > 0.15; // 85% de probabilidad de estar bien encuadrada
    final suggestedCropAlert = isWellFramed 
        ? null 
        : "La foto se ve recortada — ¿quieres tomar otra que muestre el cuerpo completo?";

    final isAreteVisible = _random.nextDouble() > 0.25; // 75% de probabilidad de detectar arete
    final areteAlert = isAreteVisible
        ? null
        : "Sugerencia: agrega una foto del arete para mejorar tu nivel de certificación.";

    // Estimar visualmente la condición corporal y compararla con el peso
    double estimatedCondition = 3.5;
    if (animal != null) {
      estimatedCondition = animal.bodyCondition;
    }
    
    // Simular discrepancia
    bool hasDiscrepancy = _random.nextDouble() > 0.8;
    String? bodyConditionAlert;
    if (hasDiscrepancy && animal != null) {
      bodyConditionAlert = "Esta foto sugiere una condición corporal distinta a tu último registro de peso (${animal.weightKg} kg). ¿Quieres actualizar el peso antes de publicar?";
    }

    String summary;
    if (category == 'Ganado') {
      summary = isWellFramed && isAreteVisible
          ? "🤖 La IA analizó tu foto\nBuena condición corporal detectada ✓\nArete visible y encuadre correcto."
          : "🤖 La IA analizó tu foto\n" + (suggestedCropAlert ?? "Encuadre correcto ✓") + "\n" + (areteAlert ?? "Arete detectado ✓");
    } else {
      summary = "🤖 La IA analizó tu foto\nProducto de calidad verificado ✓\nBuen encuadre y presentación.";
    }

    return PhotoAnalysisResult(
      isWellFramed: isWellFramed,
      suggestedCropAlert: suggestedCropAlert,
      bodyConditionScore: estimatedCondition,
      bodyConditionAlert: bodyConditionAlert,
      isAreteVisible: isAreteVisible,
      areteAlert: areteAlert,
      summary: summary,
    );
  }

  @override
  Future<String> generateDescription({
    required String category,
    required String breed,
    required String sex,
    required double weight,
    String? production,
    required int healthScore,
    required String vaccineStatus,
    required String name,
  }) async {
    // 1. Simular latencia de generación (1.5 segundos)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (category == 'Ganado') {
      final isFemale = sex.toLowerCase() == 'hembra';
      final isDairy = breed.contains('Holstein') || breed.contains('Jersey') || breed.contains('Suizo') || production != null;

      if (isDairy && isFemale) {
        return "$breed de excelente condición y alta genética láctea. Ficha de salud de $healthScore/100 con esquema de vacunas al día ($vaccineStatus) y sin alertas veterinarias activas. "
            "Producción promedio de ${production ?? '12.5'} litros diarios con excelente comportamiento en ordeño. Ideal para reproducción y lechería continua.";
      } else {
        return "$breed de excelente alzada y desarrollo corporal. Peso actual verificado de ${weight.toStringAsFixed(0)} kg, ideal para engorde o pie de cría. "
            "Ficha zoosanitaria impecable con score $healthScore/100 y vacunación al día ($vaccineStatus). Libre de enfermedades transmisibles.";
      }
    } else if (category == 'Leche') {
      return "Leche entera de alta calidad, ordeñada bajo estrictos controles higiénicos en finca con vacas Holstein certificadas sanas. "
          "Alta densidad y gran sabor natural, lista para pasteurizar o elaborar quesos finos.";
    } else if (category == 'Queso') {
      return "Queso artesanal fresco elaborado con leche pura de vaca en Saraguro, Loja. Proceso natural con cuajo seleccionado, "
          "textura suave, balance justo de sal, bajo en grasa y con el sabor tradicional del campo ecuatoriano.";
    } else {
      return "Insumo agropecuario seleccionado y verificado de excelente calidad. Cumple con normas y estándares técnicos requeridos.";
    }
  }
}
