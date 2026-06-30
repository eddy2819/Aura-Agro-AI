/// Modelo que representa un recurso nutricional declarado por el usuario.
class NutritionResource {
  final int? id;
  final String type; // pasto, silo, concentrado, suplemento, sales_minerales, subproducto, personalizado
  final String name;
  final double amount;
  final String unit; // ha, kg, ton, etc.
  final String updatedAt;
  final double? cost;
  final String? availability; // Disponible, Limitado, Agotado
  final String? expirationDate;
  final String? observations;

  const NutritionResource({
    this.id,
    required this.type,
    required this.name,
    required this.amount,
    required this.unit,
    required this.updatedAt,
    this.cost,
    this.availability = 'Disponible',
    this.expirationDate,
    this.observations,
  });

  /// Crear una copia con campos modificados
  NutritionResource copyWith({
    int? id,
    String? type,
    String? name,
    double? amount,
    String? unit,
    String? updatedAt,
    double? cost,
    String? availability,
    String? expirationDate,
    String? observations,
  }) {
    return NutritionResource(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      updatedAt: updatedAt ?? this.updatedAt,
      cost: cost ?? this.cost,
      availability: availability ?? this.availability,
      expirationDate: expirationDate ?? this.expirationDate,
      observations: observations ?? this.observations,
    );
  }

  /// Convertir a Map para almacenamiento en base de datos
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type,
      'name': name,
      'amount': amount,
      'unit': unit,
      'updated_at': updatedAt,
      'cost': cost,
      'availability': availability,
      'expiration_date': expirationDate,
      'observations': observations,
    };
  }

  /// Crear una instancia desde un Map proveniente de la base de datos
  factory NutritionResource.fromMap(Map<String, dynamic> map) {
    return NutritionResource(
      id: map['id'] as int?,
      type: map['type'] as String,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      unit: map['unit'] as String,
      updatedAt: map['updated_at'] as String,
      cost: map['cost'] != null ? (map['cost'] as num).toDouble() : null,
      availability: map['availability'] as String?,
      expirationDate: map['expiration_date'] as String?,
      observations: map['observations'] as String?,
    );
  }
}
