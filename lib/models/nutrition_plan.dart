/// Modelo que representa un plan o análisis nutricional generado por la IA.
class NutritionPlan {
  final int? id;
  final String createdAt;
  final String targetGroup; // ID de animal o grupo objetivo (ej: "0234, 0178" o "Vaca Lechera")
  final String suggestedDiet; // Texto estructurado con la dieta sugerida
  final double estimatedCostPerDay;
  final double projectedSavings;
  final String projectedImprovement; // Mejora proyectada en producción/peso (ej: "+8% prod, +12% peso")
  final String explanation;
  final String status; // Activo, Completado, Descartado
  final String? rawResponse; // Representación completa en JSON del plan nutricional

  const NutritionPlan({
    this.id,
    required this.createdAt,
    required this.targetGroup,
    required this.suggestedDiet,
    required this.estimatedCostPerDay,
    required this.projectedSavings,
    required this.projectedImprovement,
    required this.explanation,
    required this.status,
    this.rawResponse,
  });

  /// Crear una copia con campos modificados
  NutritionPlan copyWith({
    int? id,
    String? createdAt,
    String? targetGroup,
    String? suggestedDiet,
    double? estimatedCostPerDay,
    double? projectedSavings,
    String? projectedImprovement,
    String? explanation,
    String? status,
    String? rawResponse,
  }) {
    return NutritionPlan(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      targetGroup: targetGroup ?? this.targetGroup,
      suggestedDiet: suggestedDiet ?? this.suggestedDiet,
      estimatedCostPerDay: estimatedCostPerDay ?? this.estimatedCostPerDay,
      projectedSavings: projectedSavings ?? this.projectedSavings,
      projectedImprovement: projectedImprovement ?? this.projectedImprovement,
      explanation: explanation ?? this.explanation,
      status: status ?? this.status,
      rawResponse: rawResponse ?? this.rawResponse,
    );
  }

  /// Convertir a Map para la base de datos
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'created_at': createdAt,
      'target_group': targetGroup,
      'suggested_diet': suggestedDiet,
      'estimated_cost_per_day': estimatedCostPerDay,
      'projected_savings': projectedSavings,
      'projected_improvement': projectedImprovement,
      'explanation': explanation,
      'status': status,
      'raw_response': rawResponse,
    };
  }

  /// Crear una instancia desde un Map
  factory NutritionPlan.fromMap(Map<String, dynamic> map) {
    return NutritionPlan(
      id: map['id'] as int?,
      createdAt: map['created_at'] as String,
      targetGroup: map['target_group'] as String,
      suggestedDiet: map['suggested_diet'] as String,
      estimatedCostPerDay: (map['estimated_cost_per_day'] as num).toDouble(),
      projectedSavings: (map['projected_savings'] as num).toDouble(),
      projectedImprovement: map['projected_improvement'] as String,
      explanation: map['explanation'] as String,
      status: map['status'] as String,
      rawResponse: map['raw_response'] as String?,
    );
  }
}
