class ChatAiAssistantService {
  static final instance = ChatAiAssistantService._();
  ChatAiAssistantService._();

  static const disclaimer =
      'AURA organiza la información y orienta el triaje. La evaluación y decisión clínica corresponde al veterinario.';

  String generateCaseSummary({
    required String animalName,
    required String riskLevel,
    required List<String> symptoms,
    required List<Map<String, dynamic>> messages,
    int availableMedicines = 0,
  }) {
    return 'AURA organizó la información para el veterinario.\n\n'
        'Resumen del caso:\n'
        '• Animal: $animalName\n'
        '• Riesgo: $riskLevel\n'
        '• Síntomas reportados: ${symptoms.where((e) => e.trim().isNotEmpty).join(', ')}\n'
        '• Mensajes registrados: ${messages.length}\n'
        '• Inventario disponible: $availableMedicines productos registrados\n'
        '• Acción segura: contactar al veterinario y evitar automedicar.\n\n'
        '$disclaimer';
  }

  List<String> suggestVetQuestions({
    required String riskLevel,
    required String symptomsText,
  }) => const [
    '¿Desde qué hora empezó el problema?',
    '¿El animal puede levantarse y tomar agua?',
    '¿Cuál es su temperatura actual?',
    '¿Hay diarrea, tos o secreciones?',
    '¿Puede enviar una foto del animal?',
  ];

  List<String> generateFarmerChecklist({
    required String riskLevel,
    required List<String> selectedSymptoms,
  }) => const [
    'Mantenga al animal en un lugar seguro y observable.',
    'Registre cambios de temperatura, respiración y apetito.',
    'No administre medicamentos sin validación veterinaria.',
    'En una emergencia grave, contacte directamente al veterinario.',
  ];
}
