import '../models/animal.dart';
import '../models/nutrition_requirement.dart';

/// Motor nutricional determinístico para rumiantes.
/// Calcula requerimientos aproximados de Materia Seca (CMS/DMI),
/// Proteína Cruda (PC) y Energía Metabolizable (EM).
class DeterministicNutritionEngine {
  /// Calcula los requerimientos estimados para un listado de animales,
  /// agrupados por sus categorías productivas.
  static Map<String, Map<String, dynamic>> calculateHerdRequirements({
    required List<Animal> animals,
    required List<NutritionRequirement> requirements,
    bool includeCalvingStatus = false,
  }) {
    final Map<String, List<Animal>> grouped = {};
    for (var a in animals) {
      final cat = a.category;
      grouped.putIfAbsent(cat, () => []).add(a);
    }

    final Map<String, Map<String, dynamic>> results = {};

    grouped.forEach((category, list) {
      double totalWeight = 0;
      int count = 0;

      for (var a in list) {
        totalWeight += a.weightKg;
        count++;
      }

      final avgWeight = count > 0 ? totalWeight / count : 0.0;

      // Buscar el requerimiento configurado o fallback a estático por defecto
      NutritionRequirement? req;
      try {
        req = requirements.firstWhere((r) => r.category == category);
      } catch (_) {
        req = NutritionRequirement.getByCategory(category);
      }

      // 1. DMI (Consumo Diario de Materia Seca) en kg/día
      // Ajustar por estado de parto/lactancia activa si aplica (aumenta consumo voluntario)
      double dmiPct = req.dryMatterPercentage;
      if (includeCalvingStatus && category == 'Vaca Lechera') {
        dmiPct += 0.5; // Mayor consumo por lactancia
      }
      final double dmiRequired = avgWeight * (dmiPct / 100);

      // 2. Proteína requerida (%)
      double proteinPct = req.proteinPercentage;
      if (includeCalvingStatus && category == 'Vaca Lechera') {
        proteinPct += 2.0; // Lactancia temprana requiere más proteína
      }

      // 3. Energía requerida (Mcal/kg de Materia Seca)
      double energyMcal = req.energyMcalPerKg;
      if (includeCalvingStatus && category == 'Vaca Lechera') {
        energyMcal += 0.25; // Alta densidad energética
      }

      results[category] = {
        'count': count,
        'avg_weight': double.parse(avgWeight.toStringAsFixed(1)),
        'dmi_required_kg': double.parse(dmiRequired.toStringAsFixed(2)),
        'protein_required_pct': double.parse(proteinPct.toStringAsFixed(1)),
        'energy_required_mcal_per_kg': double.parse(energyMcal.toStringAsFixed(2)),
        'notes': req.stageNotes,
      };
    });

    return results;
  }
}
