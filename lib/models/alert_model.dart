/// Modelo de alerta sanitaria / IA
class AlertModel {
  final String animalName;
  final String animalTag;
  final String? farm;
  final String detectedAgo; // "Hace 2 horas"
  final String title; // "Riesgo de mastitis detectado"
  final int? riskScore; // 0-100, opcional para alertas clínicas
  final List<String> symptoms;
  final String? aiRecommendation;

  const AlertModel({
    required this.animalName,
    required this.animalTag,
    this.farm,
    required this.detectedAgo,
    required this.title,
    this.riskScore,
    this.symptoms = const [],
    this.aiRecommendation,
  });
}
