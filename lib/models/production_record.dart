/// Modelo que representa un registro de producción (leche en litros) de un animal.
class ProductionRecord {
  final int? id;
  final String date; // Fecha del registro (ISO 8601)
  final String animalId;
  final double liters;
  final String? turn; // Mañana, Tarde, Total del día
  final String? observation;

  const ProductionRecord({
    this.id,
    required this.date,
    required this.animalId,
    required this.liters,
    this.turn,
    this.observation,
  });

  /// Convertir a Map para la base de datos
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'animal_id': animalId,
      'liters': liters,
      if (turn != null) 'turn': turn,
      if (observation != null) 'observation': observation,
    };
  }

  /// Crear una instancia desde un Map
  factory ProductionRecord.fromMap(Map<String, dynamic> map) {
    return ProductionRecord(
      id: map['id'] as int?,
      date: map['date'] as String,
      animalId: map['animal_id'] as String,
      liters: (map['liters'] as num).toDouble(),
      turn: map['turn'] as String?,
      observation: map['observation'] as String?,
    );
  }
}
