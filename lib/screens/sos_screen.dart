import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../data/data_provider.dart';
import '../services/emergency_ai_service.dart';
import '../services/speech_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  String? _selectedAnimalId;
  final TextEditingController _symptomsController = TextEditingController();
  final List<String> _selectedSymptoms = [];
  bool _isAnalyzing = false;
  EmergencyResult? _result;

  final List<String> _quickSymptoms = [
    'No come',
    'Fiebre',
    'Diarrea',
    'Cojera',
    'Hinchazón',
    'Dificultad para respirar',
    'Baja producción de leche',
    'Decaimiento',
    'Herida visible',
    'Parto complicado',
    'No puede levantarse',
  ];

  @override
  void dispose() {
    _symptomsController.dispose();
    super.dispose();
  }

  void _toggleSymptom(String symptom) {
    setState(() {
      if (_selectedSymptoms.contains(symptom)) {
        _selectedSymptoms.remove(symptom);
      } else {
        _selectedSymptoms.add(symptom);
      }
    });
  }

  Future<void> _startVoiceDictation() async {
    final speech = SpeechService.instance;
    final success = await speech.startListening((text) {
      setState(() {
        _symptomsController.text = text;
      });
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(speech.errorMsg.isNotEmpty ? speech.errorMsg : "Error al iniciar el dictado por voz."),
          backgroundColor: AppColors.alertOrange,
        ),
      );
    }
  }

  Future<void> _stopVoiceDictation() async {
    await SpeechService.instance.stopListening();
  }

  Future<void> _analyzeEmergency() async {
    if (_selectedAnimalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor selecciona el animal afectado."),
          backgroundColor: AppColors.alertOrange,
        ),
      );
      return;
    }

    if (_selectedSymptoms.isEmpty && _symptomsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor describe o selecciona al menos un síntoma."),
          backgroundColor: AppColors.alertOrange,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _result = null;
    });

    try {
      final res = await EmergencyAiService.instance.analyzeSymptoms(
        animalId: _selectedAnimalId!,
        symptomsText: _symptomsController.text,
        selectedSymptoms: _selectedSymptoms,
      );

      setState(() {
        _result = res;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error durante el análisis: $e")),
      );
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _saveCaseAndExit() async {
    if (_result == null || _selectedAnimalId == null) return;

    final provider = Provider.of<DataProvider>(context, listen: false);
    final String caseId = "sos_${const Uuid().v4()}";

    final Map<String, dynamic> sosCase = {
      'id': caseId,
      'animal_id': _selectedAnimalId,
      'symptoms_text': _symptomsController.text,
      'selected_symptoms': _selectedSymptoms.join(','),
      'risk_level': _result!.riskLevel,
      'title': _result!.title,
      'explanation': _result!.explanation,
      'safe_actions': _result!.safeActions.join('|'),
      'notify_vet': _result!.notifyVet ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    };

    await provider.addSosCase(sosCase);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Caso SOS guardado en historial clínico y alertas."),
        backgroundColor: AppColors.primaryGreen,
      ),
    );

    Navigator.of(context).pop();
  }

  Color _getRiskColor(String level) {
    switch (level.toLowerCase()) {
      case 'rojo':
        return AppColors.alertOrange;
      case 'amarillo':
        return const Color(0xFFFFB300);
      case 'verde':
        return AppColors.primaryGreen;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DataProvider>(context);
    final activeAnimals = provider.animals.where((a) => a.status.toLowerCase() == 'activo').toList();
    final speech = SpeechService.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AURA SOS Ganadero', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryGreenDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.alertOrange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.alertOrange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.shieldAlert, color: AppColors.alertOrange, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AURA SOS no reemplaza al veterinario. Su función es orientar y acelerar la atención de emergencias.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.alertOrange, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Animal Selection
            Text('1. Selecciona el Animal Afectado', style: AppTextStyles.bodyBold),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedAnimalId,
                  isExpanded: true,
                  hint: Text('Elige un animal...', style: AppTextStyles.body),
                  items: activeAnimals.map((animal) {
                    return DropdownMenuItem<String>(
                      value: animal.id,
                      child: Text('${animal.name} (${animal.tag}) - ${animal.category}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedAnimalId = val;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quick Symptoms Chips
            Text('2. Síntomas Rápidos', style: AppTextStyles.bodyBold),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickSymptoms.map((symptom) {
                final isSelected = _selectedSymptoms.contains(symptom);
                return FilterChip(
                  label: Text(symptom),
                  selected: isSelected,
                  selectedColor: AppColors.greenSurface,
                  checkmarkColor: AppColors.primaryGreen,
                  labelStyle: AppTextStyles.caption.copyWith(
                    color: isSelected ? AppColors.primaryGreenDark : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? AppColors.primaryGreen : AppColors.border),
                  ),
                  onSelected: (_) => _toggleSymptom(symptom),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Symptoms Description & Voice
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('3. Detalles Adicionales', style: AppTextStyles.bodyBold),
                ListenableBuilder(
                  listenable: speech,
                  builder: (context, child) {
                    final listening = speech.isListening;
                    return InkWell(
                      onTap: listening ? _stopVoiceDictation : _startVoiceDictation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: listening ? Colors.red.withOpacity(0.1) : AppColors.greenSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: listening ? Colors.red : AppColors.primaryGreen),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              listening ? LucideIcons.micOff : LucideIcons.mic,
                              color: listening ? Colors.red : AppColors.primaryGreen,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              listening ? 'Escuchando...' : 'Dictar por voz',
                              style: AppTextStyles.caption.copyWith(
                                color: listening ? Colors.red : AppColors.primaryGreenDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _symptomsController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe el estado general del animal o detalla otros síntomas observados...',
                hintStyle: AppTextStyles.caption,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Analyze button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _analyzeEmergency,
                icon: _isAnalyzing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(LucideIcons.activity),
                label: const Text('ANALIZAR EMERGENCIA CON IA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Result Display
            if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _getRiskColor(_result!.riskLevel), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _getRiskColor(_result!.riskLevel),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _result!.title.toUpperCase(),
                            style: AppTextStyles.bodyBold.copyWith(
                              color: _getRiskColor(_result!.riskLevel),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(_result!.explanation, style: AppTextStyles.body),
                    const Divider(height: 24),
                    Text('Acciones seguras recomendadas en campo:', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 8),
                    ..._result!.safeActions.map((action) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(LucideIcons.checkCircle2, color: AppColors.primaryGreen, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(action, style: AppTextStyles.caption)),
                            ],
                          ),
                        )),
                    if (_result!.notifyVet) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.alertOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.bellRing, color: AppColors.alertOrange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Caso Crítico: Se ha enviado una notificación automática a tus veterinarios autorizados.',
                                style: AppTextStyles.caption.copyWith(color: AppColors.alertOrange, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saveCaseAndExit,
                  icon: const Icon(LucideIcons.save),
                  label: const Text('GUARDAR EN HISTORIAL CLÍNICO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreenDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
