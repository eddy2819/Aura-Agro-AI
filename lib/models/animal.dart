/// Modelo de un animal del hato
class Animal {
  final String id;
  final String name;
  final String tag; // ej: #0234
  final String category; // Vaca Lechera, Toro Reproductor, Ternero, Toro Engorde
  final int score;
  final String description;
  final double weightKg;
  final String? productionLiters; // ej: "12.5 L/dia"
  final String? vaccineStatus; // ej: "Vencida" o "28 May"
  final bool hasAlert;
  final String? imagePath;

  // 1. Información básica adicional
  final String breed; // Holstein, Brahman, Gyr, Jersey, Angus, Pardo Suizo, Mestizo, etc.
  final String sex; // Macho / Hembra
  final String birthDate; // YYYY-MM-DD
  final String status; // Activo / Vendido / Fallecido

  // 2. Información Productiva adicional
  final String purpose; // Carne / Leche / Doble propósito
  final String stage; // Ternero / Novillo / Vaca / Toro / Gestación / Lactancia
  final double bodyCondition; // 1-5 (Slider)
  final String color;

  // 3. Información Genética
  final String? geneticFather;
  final String? geneticMother;
  final String? geneticLine;
  final String? origin;

  // 4. Información Sanitaria
  final String healthStatus; // Saludable / Enfermo / En Tratamiento / Cuarentena
  final String? lastVetCheck; // YYYY-MM-DD
  final String? vetResponsible;
  final String? prevDiseases;
  final String? allergies;
  final String? currentMedication;

  // 5. Información Nutricional
  final String dietType; // Pasto / Silo / Concentrado / Mixto
  final bool grazing;
  final bool balancedFeed;
  final bool supplements;
  final double? dailyConsumption;
  final String productionObjective; // Mantenimiento / Ganancia de peso / Producción láctea

  // 6. Ubicación
  final String finca;
  final String lote;
  final String potrero;
  final String? gpsCoords;

  // 7. Información Económica y Documentos
  final double? purchaseValue;
  final String? purchaseDate;
  final String? provider;
  final bool availableForSale;

  // 8. Documentos adicionales (Rutas locales)
  final String? imageFrontPath;
  final String? imageSidePath;
  final String? certSanitaryPath;
  final String? docPurchasePath;

  // 9. QR de Trazabilidad AURA
  final String? qrToken;
  final bool qrIsActive;
  final String? qrGeneratedAt;

  const Animal({
    required this.id,
    required this.name,
    required this.tag,
    required this.category,
    required this.score,
    required this.description,
    required this.weightKg,
    this.productionLiters,
    this.vaccineStatus,
    this.hasAlert = false,
    this.imagePath,
    this.breed = 'Mestizo',
    this.sex = 'Hembra',
    this.birthDate = '2024-01-01',
    this.status = 'Activo',
    this.purpose = 'Doble propósito',
    this.stage = 'Vaca',
    this.bodyCondition = 3.5,
    this.color = 'Blanco con Negro',
    this.geneticFather,
    this.geneticMother,
    this.geneticLine,
    this.origin,
    this.healthStatus = 'Saludable',
    this.lastVetCheck,
    this.vetResponsible,
    this.prevDiseases,
    this.allergies,
    this.currentMedication,
    this.dietType = 'Pasto',
    this.grazing = true,
    this.balancedFeed = false,
    this.supplements = false,
    this.dailyConsumption,
    this.productionObjective = 'Producción láctea',
    this.finca = 'Finca Principal',
    this.lote = 'Lote A',
    this.potrero = 'Potrero 1',
    this.gpsCoords,
    this.purchaseValue,
    this.purchaseDate,
    this.provider,
    this.availableForSale = false,
    this.imageFrontPath,
    this.imageSidePath,
    this.certSanitaryPath,
    this.docPurchasePath,
    this.qrToken,
    this.qrIsActive = true,
    this.qrGeneratedAt,
  });

  Animal copyWith({
    String? id,
    String? name,
    String? tag,
    String? category,
    int? score,
    String? description,
    double? weightKg,
    String? productionLiters,
    String? vaccineStatus,
    bool? hasAlert,
    String? imagePath,
    String? breed,
    String? sex,
    String? birthDate,
    String? status,
    String? purpose,
    String? stage,
    double? bodyCondition,
    String? color,
    String? geneticFather,
    String? geneticMother,
    String? geneticLine,
    String? origin,
    String? healthStatus,
    String? lastVetCheck,
    String? vetResponsible,
    String? prevDiseases,
    String? allergies,
    String? currentMedication,
    String? dietType,
    bool? grazing,
    bool? balancedFeed,
    bool? supplements,
    double? dailyConsumption,
    String? productionObjective,
    String? finca,
    String? lote,
    String? potrero,
    String? gpsCoords,
    double? purchaseValue,
    String? purchaseDate,
    String? provider,
    bool? availableForSale,
    String? imageFrontPath,
    String? imageSidePath,
    String? certSanitaryPath,
    String? docPurchasePath,
    String? qrToken,
    bool? qrIsActive,
    String? qrGeneratedAt,
  }) {
    return Animal(
      id: id ?? this.id,
      name: name ?? this.name,
      tag: tag ?? this.tag,
      category: category ?? this.category,
      score: score ?? this.score,
      description: description ?? this.description,
      weightKg: weightKg ?? this.weightKg,
      productionLiters: productionLiters ?? this.productionLiters,
      vaccineStatus: vaccineStatus ?? this.vaccineStatus,
      hasAlert: hasAlert ?? this.hasAlert,
      imagePath: imagePath ?? this.imagePath,
      breed: breed ?? this.breed,
      sex: sex ?? this.sex,
      birthDate: birthDate ?? this.birthDate,
      status: status ?? this.status,
      purpose: purpose ?? this.purpose,
      stage: stage ?? this.stage,
      bodyCondition: bodyCondition ?? this.bodyCondition,
      color: color ?? this.color,
      geneticFather: geneticFather ?? this.geneticFather,
      geneticMother: geneticMother ?? this.geneticMother,
      geneticLine: geneticLine ?? this.geneticLine,
      origin: origin ?? this.origin,
      healthStatus: healthStatus ?? this.healthStatus,
      lastVetCheck: lastVetCheck ?? this.lastVetCheck,
      vetResponsible: vetResponsible ?? this.vetResponsible,
      prevDiseases: prevDiseases ?? this.prevDiseases,
      allergies: allergies ?? this.allergies,
      currentMedication: currentMedication ?? this.currentMedication,
      dietType: dietType ?? this.dietType,
      grazing: grazing ?? this.grazing,
      balancedFeed: balancedFeed ?? this.balancedFeed,
      supplements: supplements ?? this.supplements,
      dailyConsumption: dailyConsumption ?? this.dailyConsumption,
      productionObjective: productionObjective ?? this.productionObjective,
      finca: finca ?? this.finca,
      lote: lote ?? this.lote,
      potrero: potrero ?? this.potrero,
      gpsCoords: gpsCoords ?? this.gpsCoords,
      purchaseValue: purchaseValue ?? this.purchaseValue,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      provider: provider ?? this.provider,
      availableForSale: availableForSale ?? this.availableForSale,
      imageFrontPath: imageFrontPath ?? this.imageFrontPath,
      imageSidePath: imageSidePath ?? this.imageSidePath,
      certSanitaryPath: certSanitaryPath ?? this.certSanitaryPath,
      docPurchasePath: docPurchasePath ?? this.docPurchasePath,
      qrToken: qrToken ?? this.qrToken,
      qrIsActive: qrIsActive ?? this.qrIsActive,
      qrGeneratedAt: qrGeneratedAt ?? this.qrGeneratedAt,
    );
  }
}
