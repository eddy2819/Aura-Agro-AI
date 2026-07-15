class MedicineScanResult {
  final String? name;
  final String? activeIngredient;
  final String? type;
  final String? presentation;
  final String? concentration;
  final String? expirationDate;
  final String? batchNumber;
  final String? provider;
  final String? withdrawalPeriod;
  final String? indications;
  final String? contraindications;
  final double confidence;

  const MedicineScanResult({
    this.name,
    this.activeIngredient,
    this.type,
    this.presentation,
    this.concentration,
    this.expirationDate,
    this.batchNumber,
    this.provider,
    this.withdrawalPeriod,
    this.indications,
    this.contraindications,
    required this.confidence,
  });

  factory MedicineScanResult.fromMap(Map<String, dynamic> map) {
    String? text(String key) {
      final value = map[key]?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    return MedicineScanResult(
      name: text('name'),
      activeIngredient: text('active_ingredient'),
      type: text('type'),
      presentation: text('presentation'),
      concentration: text('concentration'),
      expirationDate: text('expiration_date'),
      batchNumber: text('batch_number'),
      provider: text('provider'),
      withdrawalPeriod: text('withdrawal_period'),
      indications: text('indications'),
      contraindications: text('contraindications'),
      confidence: ((map['confidence'] as num?) ?? 0).toDouble().clamp(0, 1),
    );
  }
}
