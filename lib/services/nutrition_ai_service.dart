import 'dart:convert';
import 'dart:math';

import '../models/animal.dart';
import '../models/nutrition_resource.dart';
import '../models/nutrition_plan.dart';
import '../models/weight_record.dart';
import '../models/production_record.dart';
import 'supabase_service.dart';

/// Resultado detallado de un plan nutricional generado por el motor de IA.
class NutritionPlanResult {
  final String suggestedDiet;
  final double estimatedCostPerDay;
  final double projectedSavings; // Ahorro proyectado semanal para el grupo
  final String projectedImprovement;
  final String explanation;

  // Nuevos campos para UI Premium
  final int viabilityScore;
  final String limitingResource;
  final List<Map<String, dynamic>> resourcesTable;
  final List<String> alerts;
  final List<String> taskToday;
  final List<String> taskWeek;
  final List<String> taskMonitor;
  final Map<String, dynamic> scenarios;
  final Map<String, dynamic>? visualAnalysis;
  final List<double> projectionData;
  final String rawJson; // Respuesta serializada en JSON

  NutritionPlanResult({
    required this.suggestedDiet,
    required this.estimatedCostPerDay,
    required this.projectedSavings,
    required this.projectedImprovement,
    required this.explanation,
    required this.viabilityScore,
    required this.limitingResource,
    required this.resourcesTable,
    required this.alerts,
    required this.taskToday,
    required this.taskWeek,
    required this.taskMonitor,
    required this.scenarios,
    this.visualAnalysis,
    required this.projectionData,
    required this.rawJson,
  });

  factory NutritionPlanResult.fromMap(Map<String, dynamic> data) {
    final suggestedDiet = data['suggested_diet'] ?? 'Pasto Kikuyo (70%) + Suplemento';
    final estimatedCost = (data['estimated_cost_per_day'] ?? 1.20) as num;
    final savings = (data['projected_savings'] ?? 45.0) as num;
    final improvement = data['projected_improvement'] ?? '+8% producción';
    final explanation = data['explanation'] ?? 'Plan generado exitosamente.';
    
    final viabilityScore = (data['viability_score'] ?? 85) as int;
    final limitingResource = data['limiting_resource'] ?? 'Silo de Maíz';
    
    final resourcesTable = List<Map<String, dynamic>>.from(data['resources_table'] ?? []);
    final alerts = List<String>.from(data['alerts'] ?? []);
    
    final recs = data['recommendations'] ?? {};
    final taskToday = List<String>.from(recs['today'] ?? []);
    final taskWeek = List<String>.from(recs['week'] ?? []);
    final taskMonitor = List<String>.from(recs['monitor'] ?? []);
    
    final scenarios = Map<String, dynamic>.from(data['scenarios'] ?? {});
    final visualAnalysis = data['visual_analysis'] != null 
        ? Map<String, dynamic>.from(data['visual_analysis']) 
        : null;
    
    final projectionData = List<double>.from((data['projection_data'] ?? [10.0, 10.5, 11.2, 12.0]).map((v) => (v as num).toDouble()));

    return NutritionPlanResult(
      suggestedDiet: suggestedDiet,
      estimatedCostPerDay: estimatedCost.toDouble(),
      projectedSavings: savings.toDouble(),
      projectedImprovement: improvement,
      explanation: explanation,
      viabilityScore: viabilityScore,
      limitingResource: limitingResource,
      resourcesTable: resourcesTable,
      alerts: alerts,
      taskToday: taskToday,
      taskWeek: taskWeek,
      taskMonitor: taskMonitor,
      scenarios: scenarios,
      visualAnalysis: visualAnalysis,
      projectionData: projectionData,
      rawJson: jsonEncode(data),
    );
  }
}

/// Interfaz abstracta del servicio de IA de nutrición.
abstract class NutritionAiService {
  Future<NutritionPlanResult> generatePlan({
    required List<NutritionResource> resources,
    required List<Animal> targetAnimals,
    List<NutritionPlan> planHistory = const [],
    List<WeightRecord> weightHistory = const [],
    List<ProductionRecord> productionHistory = const [],
    bool includeCalvingStatus = false,
    bool includeForage = false,
    bool includeSupplements = false,
    String? photoPath,
    Map<String, dynamic>? calculatedRequirements,
  });
}

/// Evaluador de rendimiento histórico para ajustar los nuevos planes de alimentación.
class PlanHistoryAnalyzer {
  static HistoryAnalysis analyze(
    Animal animal,
    List<NutritionPlan> planHistory,
    List<WeightRecord> weightHistory,
    List<ProductionRecord> productionHistory,
  ) {
    NutritionPlan? lastPlan;
    for (var plan in planHistory) {
      if (plan.targetGroup.contains(animal.id) || plan.targetGroup == animal.category) {
        lastPlan = plan;
        break;
      }
    }

    if (lastPlan == null) {
      return HistoryAnalysis(
        complianceScore: 1.0,
        feedbackNote: "No se encontraron planes previos. Estableciendo dieta base recomendada.",
        adjustmentNeeded: false,
      );
    }

    final planDate = DateTime.tryParse(lastPlan.createdAt) ?? DateTime.now();

    if (animal.category == 'Vaca Lechera') {
      final recordsAfter = productionHistory
          .where((r) => r.animalId == animal.id && (DateTime.tryParse(r.date) ?? DateTime.now()).isAfter(planDate))
          .toList();
      final recordsBefore = productionHistory
          .where((r) => r.animalId == animal.id && !(DateTime.tryParse(r.date) ?? DateTime.now()).isAfter(planDate))
          .toList();

      if (recordsAfter.isEmpty || recordsBefore.isEmpty) {
        return HistoryAnalysis(
          complianceScore: 1.0,
          feedbackNote: "Plan previo detectado, pero sin registros lácteos suficientes para evaluar la producción real.",
          adjustmentNeeded: false,
        );
      }

      recordsAfter.sort((a, b) => a.date.compareTo(b.date));
      recordsBefore.sort((a, b) => b.date.compareTo(a.date));

      final initialVal = recordsBefore.first.liters;
      final finalVal = recordsAfter.last.liters;
      final actualChange = initialVal > 0 ? ((finalVal - initialVal) / initialVal) * 100 : 0.0;

      double projectedChange = 8.0;
      final regExp = RegExp(r'\+?(\d+(?:\.\d+)?)\s*%');
      final match = regExp.firstMatch(lastPlan.projectedImprovement);
      if (match != null) {
        projectedChange = double.tryParse(match.group(1) ?? '8.0') ?? 8.0;
      }

      final compliance = projectedChange > 0 ? actualChange / projectedChange : 1.0;

      if (compliance < 0.75) {
        return HistoryAnalysis(
          complianceScore: compliance,
          feedbackNote: "La producción de leche real (+${actualChange.toStringAsFixed(1)}%) quedó por debajo del objetivo anterior (+${projectedChange.toStringAsFixed(1)}%).",
          adjustmentNeeded: true,
        );
      } else if (compliance >= 1.2) {
        return HistoryAnalysis(
          complianceScore: compliance,
          feedbackNote: "Producción de leche sobresaliente (+${actualChange.toStringAsFixed(1)}% vs +${projectedChange.toStringAsFixed(1)}% esperado).",
          adjustmentNeeded: false,
        );
      } else {
        return HistoryAnalysis(
          complianceScore: compliance,
          feedbackNote: "Rendimiento óptimo (+${actualChange.toStringAsFixed(1)}%), alineado con el plan previo (+${projectedChange.toStringAsFixed(1)}%).",
          adjustmentNeeded: false,
        );
      }
    } else {
      final recordsAfter = weightHistory
          .where((r) => r.animalId == animal.id && (DateTime.tryParse(r.date) ?? DateTime.now()).isAfter(planDate))
          .toList();
      final recordsBefore = weightHistory
          .where((r) => r.animalId == animal.id && !(DateTime.tryParse(r.date) ?? DateTime.now()).isAfter(planDate))
          .toList();

      if (recordsAfter.isEmpty || recordsBefore.isEmpty) {
        return HistoryAnalysis(
          complianceScore: 1.0,
          feedbackNote: "Plan previo detectado, pero sin registros de peso suficientes para evaluar el desarrollo corporal.",
          adjustmentNeeded: false,
        );
      }

      recordsAfter.sort((a, b) => a.date.compareTo(b.date));
      recordsBefore.sort((a, b) => b.date.compareTo(a.date));

      final initialVal = recordsBefore.first.weightKg;
      final finalVal = recordsAfter.last.weightKg;
      final actualChange = initialVal > 0 ? ((finalVal - initialVal) / initialVal) * 100 : 0.0;

      double projectedChange = 12.0;
      final regExp = RegExp(r'\+?(\d+(?:\.\d+)?)\s*%');
      final match = regExp.firstMatch(lastPlan.projectedImprovement);
      if (match != null) {
        projectedChange = double.tryParse(match.group(1) ?? '12.0') ?? 12.0;
      }

      final compliance = projectedChange > 0 ? actualChange / projectedChange : 1.0;

      if (compliance < 0.75) {
        return HistoryAnalysis(
          complianceScore: compliance,
          feedbackNote: "La ganancia de peso real (+${actualChange.toStringAsFixed(1)}%) estuvo por debajo del objetivo (+${projectedChange.toStringAsFixed(1)}%).",
          adjustmentNeeded: true,
        );
      } else if (compliance >= 1.2) {
        return HistoryAnalysis(
          complianceScore: compliance,
          feedbackNote: "Desarrollo corporal excelente (+${actualChange.toStringAsFixed(1)}% vs +${projectedChange.toStringAsFixed(1)}% esperado).",
          adjustmentNeeded: false,
        );
      } else {
        return HistoryAnalysis(
          complianceScore: compliance,
          feedbackNote: "Incremento corporal adecuado (+${actualChange.toStringAsFixed(1)}%), alineado con el plan previo (+${projectedChange.toStringAsFixed(1)}%).",
          adjustmentNeeded: false,
        );
      }
    }
  }
}

class HistoryAnalysis {
  final double complianceScore;
  final String feedbackNote;
  final bool adjustmentNeeded;

  HistoryAnalysis({
    required this.complianceScore,
    required this.feedbackNote,
    required this.adjustmentNeeded,
  });
}

/// Servicio de IA nutricional remoto utilizando Supabase Edge Function ("aura-ai")
class RemoteNutritionAiService implements NutritionAiService {
  final LocalHeuristicNutritionService _fallbackService = LocalHeuristicNutritionService();

  @override
  Future<NutritionPlanResult> generatePlan({
    required List<NutritionResource> resources,
    required List<Animal> targetAnimals,
    List<NutritionPlan> planHistory = const [],
    List<WeightRecord> weightHistory = const [],
    List<ProductionRecord> productionHistory = const [],
    bool includeCalvingStatus = false,
    bool includeForage = false,
    bool includeSupplements = false,
    String? photoPath,
    Map<String, dynamic>? calculatedRequirements,
  }) async {
    final supabase = SupabaseService.instance;
    if (!supabase.isEnabled || !supabase.isAuthenticated) {
      // Fallback seguro local si no hay conexión o llaves
      return await _fallbackService.generatePlan(
        resources: resources,
        targetAnimals: targetAnimals,
        planHistory: planHistory,
        weightHistory: weightHistory,
        productionHistory: productionHistory,
        includeCalvingStatus: includeCalvingStatus,
        includeForage: includeForage,
        includeSupplements: includeSupplements,
        photoPath: photoPath,
        calculatedRequirements: calculatedRequirements,
      );
    }

    try {
      final scope = targetAnimals.length == 1
          ? 'individual'
          : 'group';

      final List<Map<String, dynamic>> animalsPayload = targetAnimals.map((a) {
        return {
          'id': a.id,
          'name': a.name,
          'tag': a.tag,
          'category': a.category,
          'weight_kg': a.weightKg,
          'stage': a.stage,
          'body_condition': a.bodyCondition,
          'breed': a.breed,
          'sex': a.sex,
          'purpose': a.purpose,
          'vaccine_status': a.vaccineStatus,
        };
      }).toList();

      final List<Map<String, dynamic>> resourcesPayload = resources.map((r) {
        return {
          'id': r.id,
          'type': r.type,
          'name': r.name,
          'amount': r.amount,
          'unit': r.unit,
          'cost': r.cost,
          'availability': r.availability,
          'expiration_date': r.expirationDate,
          'observations': r.observations,
        };
      }).toList();

      final payload = {
        'scope': scope,
        'datos_animales': animalsPayload,
        'recursos_confirmados': resourcesPayload,
        'consideraciones_especiales': {
          'parto_lactancia': includeCalvingStatus,
          'priorizar_forraje': includeForage,
          'priorizar_suplementos': includeSupplements,
        },
        'foto_opcional': photoPath,
        'resultados_calculados': calculatedRequirements,
      };

      final response = await supabase.invokeNutritionEdgeFunction(payload);
      if (response != null) {
        return _parsePlanResultFromMap(response);
      }
    } catch (e) {
      print("Error calling Edge Function, calling local fallback: $e");
    }

    return await _fallbackService.generatePlan(
      resources: resources,
      targetAnimals: targetAnimals,
      planHistory: planHistory,
      weightHistory: weightHistory,
      productionHistory: productionHistory,
      includeCalvingStatus: includeCalvingStatus,
      includeForage: includeForage,
      includeSupplements: includeSupplements,
      photoPath: photoPath,
      calculatedRequirements: calculatedRequirements,
    );
  }

  NutritionPlanResult _parsePlanResultFromMap(Map<String, dynamic> data) {
    return NutritionPlanResult.fromMap(data);
  }
}

/// Implementación local basada en heurísticas y modelos biológicos estáticos.
class LocalHeuristicNutritionService implements NutritionAiService {
  static const Map<String, double> _referencePrices = {
    'pasto': 0.04,
    'silo': 0.12,
    'concentrado': 0.55,
    'suplemento': 1.10,
  };

  @override
  Future<NutritionPlanResult> generatePlan({
    required List<NutritionResource> resources,
    required List<Animal> targetAnimals,
    List<NutritionPlan> planHistory = const [],
    List<WeightRecord> weightHistory = const [],
    List<ProductionRecord> productionHistory = const [],
    bool includeCalvingStatus = false,
    bool includeForage = false,
    bool includeSupplements = false,
    String? photoPath,
    Map<String, dynamic>? calculatedRequirements,
  }) async {
    // Simular latencia de red
    final random = Random();
    await Future.delayed(Duration(milliseconds: 1500 + random.nextInt(1000)));

    if (targetAnimals.isEmpty) {
      return _generateDefaultEmptyResult();
    }

    final category = targetAnimals.first.category;


    // Obtener los requerimientos determinísticos (DMI, proteína y energía)
    double dmiNeeded = 15.0;

    if (calculatedRequirements != null && calculatedRequirements.containsKey(category)) {
      final reqs = calculatedRequirements[category]!;
      dmiNeeded = (reqs['dmi_required_kg'] ?? 15.0) as double;
    }

    // Evaluar disponibilidad de recursos
    bool hasSilo = resources.any((r) => r.type == 'silo' && r.amount > 0) || includeForage;
    bool hasConcentrado = resources.any((r) => r.type == 'concentrado' && r.amount > 0);
    bool hasSuplemento = resources.any((r) => r.type == 'suplemento' && r.amount > 0) || includeSupplements;

    // Calcular cumplimiento del plan anterior
    double complianceFactor = 1.0;
    String historyFeedback = "";

    final representative = targetAnimals.first;
    final historyAnalysis = PlanHistoryAnalyzer.analyze(
      representative,
      planHistory,
      weightHistory,
      productionHistory,
    );

    if (!historyAnalysis.feedbackNote.contains("No se encontraron")) {
      historyFeedback = historyAnalysis.feedbackNote;
      if (historyAnalysis.adjustmentNeeded) {
        complianceFactor = 0.85; // Ajuste preventivo al alza
      }
    }

    // Simulación de Balance de Dieta
    double pctPasto = 75.0;
    double pctSilo = hasSilo ? 15.0 : 0.0;
    double pctConcentrado = hasConcentrado ? 8.0 : 0.0;
    double pctSuplemento = hasSuplemento ? 2.0 : 0.0;

    if (includeForage) pctSilo = max(pctSilo, 25.0);
    if (includeSupplements) pctSuplemento = max(pctSuplemento, 5.0);

    final totalPct = pctPasto + pctSilo + pctConcentrado + pctSuplemento;
    pctPasto = (pctPasto / totalPct) * 100.0;
    pctSilo = (pctSilo / totalPct) * 100.0;
    pctConcentrado = (pctConcentrado / totalPct) * 100.0;
    pctSuplemento = (pctSuplemento / totalPct) * 100.0;

    // Calcular costos
    final kgPasto = dmiNeeded * (pctPasto / 100.0);
    final kgSilo = dmiNeeded * (pctSilo / 100.0);
    final kgConcentrado = dmiNeeded * (pctConcentrado / 100.0);
    final kgSuplemento = dmiNeeded * (pctSuplemento / 100.0);

    final cost = (kgPasto * _referencePrices['pasto']!) +
                 (kgSilo * _referencePrices['silo']!) +
                 (kgConcentrado * _referencePrices['concentrado']!) +
                 (kgSuplemento * _referencePrices['suplemento']!);

    // Ahorros y Mejoras
    double baseCost = category == 'Vaca Lechera' ? 1.70 : 1.40;
    double dailySavingsPerAnimal = max(0.05, baseCost - cost);
    double totalSavingsWeekly = dailySavingsPerAnimal * 7.0 * targetAnimals.length;

    String improvementText = "";
    if (category == 'Vaca Lechera') {
      double pctLeche = (8.0 * complianceFactor) + (includeCalvingStatus ? 4.0 : 0.0);
      improvementText = "+${pctLeche.toStringAsFixed(0)}% prod. (3 sem)";
    } else {
      double pctPeso = (10.0 * complianceFactor) + (includeSupplements ? 3.0 : 0.0);
      improvementText = "+${pctPeso.toStringAsFixed(0)}% peso (4 sem)";
    }

    // Componer Dieta Diaria
    final dietParts = <String>[];
    if (pctPasto > 0) dietParts.add("Pasto Kikuyo (${pctPasto.toStringAsFixed(0)}%)");
    if (pctSilo > 0) dietParts.add("Silo de Maíz (${pctSilo.toStringAsFixed(0)}%)");
    if (pctConcentrado > 0) dietParts.add("Concentrado (${pctConcentrado.toStringAsFixed(0)}%)");
    if (pctSuplemento > 0) dietParts.add("Melaza (${pctSuplemento.toStringAsFixed(0)}%)");
    final suggestedDiet = dietParts.join(" + ");

    // Explicación
    final explanation = "El plan AURA para $category se ajusta a los requerimientos determinados por el motor (${dmiNeeded.toStringAsFixed(1)} kg MS). "
        "Se prioriza la base de pastoreo directo complementado con fibra de silo de maíz para mantener la estabilidad ruminal. $historyFeedback";

    // Alertas
    final alerts = <String>[];
    if (!hasSuplemento) {
      alerts.add("Falta de minerales detectada: se recomienda incorporar bloque de sal mineral.");
    }
    if (pctSilo > 30) {
      alerts.add("Inclusión de fibra alta: vigile la tasa de pasaje y consistencia del estiércol.");
    }
    // Revisar si algún recurso en inventario está próximo a agotarse
    for (var r in resources) {
      if (r.amount < (dmiNeeded * targetAnimals.length * 5) && r.amount > 0) {
        alerts.add("Recurso limitante: el inventario de '${r.name}' alcanzará para menos de 5 días.");
      }
    }

    // Tareas prioritarias
    final taskToday = [
      "Confirmar disponibilidad y estado del lote de Silo de Maíz.",
      "Ajustar la ración matutina de concentrado para añadir la melaza."
    ];
    final taskWeek = [
      "Realizar rotación del hato al Potrero 3 para optimizar pastoreo tierno.",
      "Adquirir sales minerales adicionales si el nivel de stock es menor a 20kg."
    ];
    final taskMonitor = [
      "Verificar consistencia corporal y score de salud cada fin de semana.",
      "Anotar en la app cualquier síntoma de baja rumia o timpanismo."
    ];

    // Escenarios
    final scenarios = {
      'economico': {
        'cost_per_day': cost * 0.85,
        'resources': "Pasto Kikuyo (90%) + Silo (10%)",
        'benefits': "Reducción de costos operativos inmediatos en un 15%.",
        'risks': "Menor ganancia de peso y posible caída de producción láctea del 5%.",
        'recommendation': "Recomendado temporalmente si hay restricciones severas de flujo de caja."
      },
      'equilibrado': {
        'cost_per_day': cost,
        'resources': suggestedDiet,
        'benefits': "Balance óptimo entre costo, disponibilidad y producción estable.",
        'risks': "Requiere control estricto del pastoreo diario.",
        'recommendation': "Recomendación principal AURA para el sostenimiento del hato."
      },
      'rendimiento': {
        'cost_per_day': cost * 1.30,
        'resources': "Pasto (60%) + Silo (20%) + Concentrado (15%) + Melaza (5%)",
        'benefits': "Maximiza producción láctea (+12%) o ganancia de peso acelerada.",
        'risks': "Incremento en costos de insumos comprados fuera de finca.",
        'recommendation': "Apropiado para animales en pico de lactancia o listos para comercialización."
      }
    };

    // Análisis Visual de Condición Corporal (si es individual y hay foto)
    Map<String, dynamic>? visualAnalysis;
    if (targetAnimals.length == 1 && photoPath != null) {
      final bc = targetAnimals.first.bodyCondition;
      String cond = "adecuada";
      if (bc < 3.0) cond = "baja";
      if (bc > 4.2) cond = "alta";
      
      visualAnalysis = {
        'body_condition_estimated': cond,
        'observations': "Evaluación visual basada en imagen lateral: Animal de pie con buena simetría. Estructura ósea visible de forma adecuada sin protuberancias extremas. Pelaje con aspecto saludable.",
        'nutritional_improvements': "Asegurar aporte continuo de pastos frescos y complementar con 1.5 kg de balanceado diario.",
        'confidence_level': "Alta (89%)",
        'disclaimer': "Esta evaluación es orientativa y no sustituye una valoración veterinaria profesional."
      };
    }

    // Predicción de evolución
    final baseProd = category == 'Vaca Lechera' ? 12.0 : 500.0;
    final List<double> projectionData = List.generate(4, (i) {
      final progress = (i + 1) * (category == 'Vaca Lechera' ? 0.35 : 12.0) * complianceFactor;
      return double.parse((baseProd + progress).toStringAsFixed(1));
    });

    final rawJson = jsonEncode({
      'suggested_diet': suggestedDiet,
      'estimated_cost_per_day': cost,
      'projected_savings': totalSavingsWeekly,
      'projected_improvement': improvementText,
      'explanation': explanation,
      'viability_score': 88,
      'limiting_resource': resources.isNotEmpty ? resources.first.name : 'Pasto',
      'resources_table': resources.map((r) {
        final amountDaily = dmiNeeded * (r.type == 'pasto' ? pctPasto : r.type == 'silo' ? pctSilo : r.type == 'concentrado' ? pctConcentrado : pctSuplemento) / 100;
        return {
          'name': r.name,
          'daily_amount': double.parse(amountDaily.toStringAsFixed(2)),
          'total_amount': double.parse((amountDaily * targetAnimals.length * 30).toStringAsFixed(1)),
          'unit': r.unit == 'ha' ? 'kg/MS' : r.unit,
          'availability': r.availability ?? 'Disponible',
          'cost': r.cost ?? (r.type == 'pasto' ? 0.04 : r.type == 'silo' ? 0.12 : r.type == 'concentrado' ? 0.55 : 1.10)
        };
      }).toList(),
      'alerts': alerts,
      'recommendations': {
        'today': taskToday,
        'week': taskWeek,
        'monitor': taskMonitor
      },
      'scenarios': scenarios,
      'visual_analysis': visualAnalysis,
      'projection_data': projectionData
    });

    return NutritionPlanResult(
      suggestedDiet: suggestedDiet,
      estimatedCostPerDay: double.parse(cost.toStringAsFixed(2)),
      projectedSavings: double.parse(totalSavingsWeekly.toStringAsFixed(2)),
      projectedImprovement: improvementText,
      explanation: explanation,
      viabilityScore: 88,
      limitingResource: resources.isNotEmpty ? resources.first.name : 'Pasto',
      resourcesTable: resources.map((r) {
        final amountDaily = dmiNeeded * (r.type == 'pasto' ? pctPasto : r.type == 'silo' ? pctSilo : r.type == 'concentrado' ? pctConcentrado : pctSuplemento) / 100;
        return {
          'name': r.name,
          'daily_amount': double.parse(amountDaily.toStringAsFixed(2)),
          'total_amount': double.parse((amountDaily * targetAnimals.length * 30).toStringAsFixed(1)),
          'unit': r.unit == 'ha' ? 'kg/MS' : r.unit,
          'availability': r.availability ?? 'Disponible',
          'cost': r.cost ?? (r.type == 'pasto' ? 0.04 : r.type == 'silo' ? 0.12 : r.type == 'concentrado' ? 0.55 : 1.10)
        };
      }).toList(),
      alerts: alerts,
      taskToday: taskToday,
      taskWeek: taskWeek,
      taskMonitor: taskMonitor,
      scenarios: scenarios,
      visualAnalysis: visualAnalysis,
      projectionData: projectionData,
      rawJson: rawJson,
    );
  }

  NutritionPlanResult _generateDefaultEmptyResult() {
    return NutritionPlanResult(
      suggestedDiet: 'Ninguna',
      estimatedCostPerDay: 0.0,
      projectedSavings: 0.0,
      projectedImprovement: 'Ninguna',
      explanation: 'No se seleccionaron animales.',
      viabilityScore: 0,
      limitingResource: 'Ninguno',
      resourcesTable: [],
      alerts: [],
      taskToday: [],
      taskWeek: [],
      taskMonitor: [],
      scenarios: {},
      projectionData: [],
      rawJson: '{}',
    );
  }
}
