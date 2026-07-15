/// Modelo de alerta sanitaria / IA completo y persistido
class AlertModel {
  final String id;
  final String animalId;
  final String animalName;
  final String animalTag;
  final String type; // health, nutrition, reproduction, inventory, sos, marketplace, system
  final String riskLevel; // verde, amarillo, rojo
  final String title;
  final String description;
  final String source;
  final String createdAt;
  final bool isRead;
  final bool synced;

  const AlertModel({
    required this.id,
    required this.animalId,
    required this.animalName,
    required this.animalTag,
    required this.type,
    required this.riskLevel,
    required this.title,
    required this.description,
    required this.source,
    required this.createdAt,
    this.isRead = false,
    this.synced = false,
  });

  /// Retorna un texto amigable indicando cuándo se detectó la alerta.
  String get detectedAgo {
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        return "Hace ${diff.inMinutes} min";
      } else if (diff.inHours < 24) {
        return "Hace ${diff.inHours} horas";
      } else {
        return "Hace ${diff.inDays} días";
      }
    } catch (_) {
      return "Reciente";
    }
  }

  // --- GETTERS COMPATIBLES CON CLINICAL_ALERT_CARD ---

  int get riskScore {
    switch (riskLevel.toLowerCase()) {
      case 'rojo':
        return 95;
      case 'amarillo':
        return 75;
      case 'verde':
      default:
        return 45;
    }
  }

  String? get farm => source.isNotEmpty ? source : null;

  List<String> get symptoms {
    if (description.isEmpty) return [];
    if (description.contains(':')) {
      final parts = description.split(':');
      if (parts.length > 1) {
        return parts[0].split(',').map((s) => s.trim()).toList();
      }
    }
    return [description];
  }

  String? get aiRecommendation => description;

  factory AlertModel.fromMap(Map<String, dynamic> map, {required String animalName, required String animalTag}) {
    return AlertModel(
      id: map['id'] as String,
      animalId: map['animal_id'] as String? ?? '',
      animalName: animalName,
      animalTag: animalTag,
      type: map['type'] as String? ?? 'system',
      riskLevel: map['risk_level'] as String? ?? 'amarillo',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      source: map['source'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      isRead: (map['is_read'] as int? ?? 0) == 1,
      synced: (map['synced'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animal_id': animalId,
      'type': type,
      'risk_level': riskLevel,
      'title': title,
      'description': description,
      'source': source,
      'created_at': createdAt,
      'is_read': isRead ? 1 : 0,
      'synced': synced ? 1 : 0,
    };
  }
}
