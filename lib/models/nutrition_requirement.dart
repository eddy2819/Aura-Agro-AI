/// Modelo que representa los requerimientos nutricionales de referencia para una categoría de animal.
class NutritionRequirement {
  final String category;
  final double dryMatterPercentage; // % de Materia Seca según peso vivo (ej: 3.2% de su peso)
  final double proteinPercentage; // Requerimiento proteico aproximado (ej: 16.0 para 16%)
  final double energyMcalPerKg; // Energía metabolizable sugerida (Mcal/kg de Materia Seca)
  final String stageNotes; // Notas adicionales sobre la etapa / fase

  const NutritionRequirement({
    required this.category,
    required this.dryMatterPercentage,
    required this.proteinPercentage,
    required this.energyMcalPerKg,
    required this.stageNotes,
  });

  /// Convertir a Map para la base de datos
  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'dry_matter_percentage': dryMatterPercentage,
      'protein_percentage': proteinPercentage,
      'energy_mcal_per_kg': energyMcalPerKg,
      'stage_notes': stageNotes,
    };
  }

  /// Crear instancia desde un Map
  factory NutritionRequirement.fromMap(Map<String, dynamic> map) {
    return NutritionRequirement(
      category: map['category'] as String,
      dryMatterPercentage: (map['dry_matter_percentage'] as num).toDouble(),
      proteinPercentage: (map['protein_percentage'] as num).toDouble(),
      energyMcalPerKg: (map['energy_mcal_per_kg'] as num).toDouble(),
      stageNotes: map['stage_notes'] as String,
    );
  }

  /// Valores constantes por defecto de requerimientos por categoría
  static const Map<String, NutritionRequirement> defaultRequirements = {
    'Vaca Lechera': NutritionRequirement(
      category: 'Vaca Lechera',
      dryMatterPercentage: 3.5, // 3.5% del peso vivo
      proteinPercentage: 16.0,   // 16% de proteína cruda
      energyMcalPerKg: 2.7,      // 2.7 Mcal/kg de MS
      stageNotes: 'Alta demanda en lactancia. Requiere balance constante de calcio y fósforo.',
    ),
    'Vaca Seca': NutritionRequirement(
      category: 'Vaca Seca',
      dryMatterPercentage: 2.0, // 2.0% del peso vivo
      proteinPercentage: 12.0,   // 12% de proteína cruda
      energyMcalPerKg: 2.0,      // 2.0 Mcal/kg de MS
      stageNotes: 'Fase de descanso y transición preparto. Evitar exceso de energía para no engordar.',
    ),
    'Toro Reproductor': NutritionRequirement(
      category: 'Toro Reproductor',
      dryMatterPercentage: 2.2, // 2.2% del peso vivo
      proteinPercentage: 12.0,   // 12% de proteína cruda
      energyMcalPerKg: 2.3,      // 2.3 Mcal/kg de MS
      stageNotes: 'Mantenimiento de líbido y condición física. Alta importancia de Zinc y Selenio.',
    ),
    'Toro Engorde': NutritionRequirement(
      category: 'Toro Engorde',
      dryMatterPercentage: 2.8, // 2.8% del peso vivo
      proteinPercentage: 14.0,   // 14% de proteína cruda
      energyMcalPerKg: 2.8,      // 2.8 Mcal/kg de MS
      stageNotes: 'Enfoque en ganancia de peso (musculatura). Alta energía digestible y carbohidratos.',
    ),
    'Ternero': NutritionRequirement(
      category: 'Ternero',
      dryMatterPercentage: 3.0, // 3.0% del peso vivo
      proteinPercentage: 18.0,   // 18% de proteína cruda (muy alta por desarrollo)
      energyMcalPerKg: 2.9,      // 2.9 Mcal/kg de MS
      stageNotes: 'Etapa crítica de crecimiento. Alta digestibilidad requerida, fibra tierna y núcleos iniciadores.',
    ),
  };

  /// Obtener requerimiento por categoría. Si no existe, retorna el de Ternero como respaldo
  static NutritionRequirement getByCategory(String category) {
    return defaultRequirements[category] ?? defaultRequirements['Ternero']!;
  }
}
