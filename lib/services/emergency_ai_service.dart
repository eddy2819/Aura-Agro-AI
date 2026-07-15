import 'dart:math';

class EmergencyResult {
  final String riskLevel; // 'verde', 'amarillo', 'rojo'
  final String title;
  final String explanation;
  final List<String> safeActions;
  final bool notifyVet;
  final DateTime createdAt;

  EmergencyResult({
    required this.riskLevel,
    required this.title,
    required this.explanation,
    required this.safeActions,
    required this.notifyVet,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'risk_level': riskLevel,
      'title': title,
      'explanation': explanation,
      'safe_actions': safeActions.join('|'),
      'notify_vet': notifyVet ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class EmergencyAiService {
  static final EmergencyAiService instance = EmergencyAiService._init();

  EmergencyAiService._init();

  Future<EmergencyResult> analyzeSymptoms({
    required String animalId,
    required String symptomsText,
    required List<String> selectedSymptoms,
  }) async {
    // Simular latencia de análisis cognitivo (1.5 segundos)
    await Future.delayed(const Duration(milliseconds: 1500));

    final textLower = symptomsText.toLowerCase();

    // 1. Reglas de riesgo Rojo (Grave - Emergencia Veterinaria)
    bool isRed = false;
    List<String> redSymptomsFound = [];

    final redKeywords = [
      'sangrado fuerte', 'hemorragia', 'sangre', 'no puede levantarse', 'caido', 'caida',
      'dificultad para respirar', 'asfixia', 'parto complicado', 'distocia', 'retencion de placenta',
      'hinchazon severa', 'timpanismo', 'fiebre alta', 'convulsion'
    ];

    for (var sym in selectedSymptoms) {
      final s = sym.toLowerCase();
      if (s.contains('dificultad para respirar') ||
          s.contains('parto complicado') ||
          s.contains('no puede levantarse') ||
          s.contains('hinchazón') ||
          s.contains('fiebre')) {
        // Hinchazón y Fiebre pueden ser rojas si vienen con decaimiento o gravedad en texto
        if (s.contains('hinchazón') || s.contains('fiebre')) {
          if (textLower.contains('grave') || textLower.contains('fuerte') || textLower.contains('alto') || textLower.contains('decaimiento')) {
            isRed = true;
            redSymptomsFound.add(sym);
          }
        } else {
          isRed = true;
          redSymptomsFound.add(sym);
        }
      }
    }

    for (var kw in redKeywords) {
      if (textLower.contains(kw)) {
        isRed = true;
        if (!redSymptomsFound.contains(kw)) {
          redSymptomsFound.add(kw);
        }
      }
    }

    if (isRed) {
      return EmergencyResult(
        riskLevel: 'rojo',
        title: 'CRÍTICO: Emergencia Veterinaria Detectada',
        explanation: 'Los síntomas reportados (${redSymptomsFound.join(', ')}) indican un peligro inminente para la vida del animal. Requiere atención médica inmediata.',
        safeActions: [
          'Mantén al animal en un lugar sombreado, seco y ventilado.',
          'Evita forzar al animal a levantarse si no puede hacerlo por sí mismo.',
          'Si hay sangrado externo visible, aplica presión constante con un paño limpio.',
          'No administres medicamentos orales a menos que el veterinario te lo indique expresamente.',
          'Prepara la ficha clínica y el historial del animal para mostrárselo al técnico.'
        ],
        notifyVet: true,
        createdAt: DateTime.now(),
      );
    }

    // 2. Reglas de riesgo Amarillo (Moderado - Monitoreo y consulta)
    bool isYellow = false;
    List<String> yellowSymptomsFound = [];

    final yellowKeywords = [
      'no come', 'apetito', 'inapetencia', 'baja produccion', 'leche',
      'diarrea leve', 'cojera', 'tos', 'herida pequeña', 'debilidad', 'moco'
    ];

    for (var sym in selectedSymptoms) {
      final s = sym.toLowerCase();
      if (s.contains('no come') ||
          s.contains('baja producción') ||
          s.contains('diarrea') ||
          s.contains('cojera') ||
          s.contains('herida') ||
          s.contains('decaimiento')) {
        isYellow = true;
        yellowSymptomsFound.add(sym);
      }
    }

    for (var kw in yellowKeywords) {
      if (textLower.contains(kw)) {
        isYellow = true;
        if (!yellowSymptomsFound.contains(kw)) {
          yellowSymptomsFound.add(kw);
        }
      }
    }

    if (isYellow) {
      return EmergencyResult(
        riskLevel: 'amarillo',
        title: 'MODERADO: Alerta Sanitaria de Atención',
        explanation: 'El animal presenta signos de malestar (${yellowSymptomsFound.join(', ')}) que requieren monitoreo estrecho en las próximas 24 horas.',
        safeActions: [
          'Aísla al animal del resto del hato para evitar posibles contagios.',
          'Suministra agua fresca de forma libre y alimento de fácil digestión (como heno tierno).',
          'Toma la temperatura rectal del animal si dispones de termómetro.',
          'Inspecciona visualmente ubre, pezuñas y ojos en busca de anomalías adicionales.',
          'Registra diariamente los cambios de producción láctea o peso.'
        ],
        notifyVet: false,
        createdAt: DateTime.now(),
      );
    }

    // 3. Verde (Leve - Observación preventiva)
    return EmergencyResult(
      riskLevel: 'verde',
      title: 'LEVE: Observación y Control Preventivo',
      explanation: 'No se detectaron síntomas críticos ni moderados. Los síntomas sugeridos entran en rangos de observación leve o comportamiento transitorio.',
      safeActions: [
        'Continúa el monitoreo ordinario durante el pastoreo diario.',
        'Asegura que el animal consuma su ración de sal mineralizada y agua adecuadamente.',
        'Verifica si el animal cuenta con su esquema de vacunación al día.',
        'Si los signos persisten por más de 48 horas, contacta a tu veterinario.'
      ],
      notifyVet: false,
      createdAt: DateTime.now(),
    );
  }
}
