/// Modelo que representa un registro de peso de un animal.
class WeightRecord {
  final int? id;
  final String date; // Fecha del registro (ISO 8601)
  final String animalId;
  final double weightKg;

  const WeightRecord({
    this.id,
    required this.date,
    required this.animalId,
    required this.weightKg,
  });

  /// Convertir a Map para la base de datos
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'animal_id': animalId,
      'weight_kg': weightKg,
    };
  }

  /// Crear una instancia desde un Map
  factory WeightRecord.fromMap(Map<String, dynamic> map) {
    return WeightRecord(
      id: map['id'] as int?,
      date: map['date'] as String,
      animalId: map['animal_id'] as String,
      weightKg: (map['weight_kg'] as num).toDouble(),
    );
  }
}
