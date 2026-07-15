import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/db_helper.dart';
import '../models/alert_model.dart';

class HealthAlertEngine {
  static final HealthAlertEngine instance = HealthAlertEngine._init();

  HealthAlertEngine._init();

  Future<List<AlertModel>> runEngine() async {
    final dbHelper = DBHelper.instance;
    final List<AlertModel> newAlerts = [];

    try {
      final animals = await dbHelper.getAllAnimals();
      final db = await dbHelper.database;
      final weightRecords = await db.query('weight_records');
      final productionRecords = await db.query('production_records');
      final medicines = await dbHelper.getAllMedicines();
      final medicineMovements = await dbHelper.getMedicineMovements();
      final reproRecords = await dbHelper.getAllReproductionRecords();
      final sosCases = await dbHelper.getAllSosCases();

      final today = DateTime.now();

      // 1. Alertas de inventario
      for (var med in medicines) {
        final double qty = (med['quantity'] as num?)?.toDouble() ?? 0.0;
        final double min = (med['min_stock'] as num?)?.toDouble() ?? 0.0;
        if (qty <= min) {
          newAlerts.add(
            AlertModel(
              id: 'inv_${med['id']}',
              animalId: '',
              animalName: 'Inventario',
              animalTag: 'Insumo',
              type: 'inventory',
              riskLevel: 'amarillo',
              title: 'Stock bajo: ${med['name']}',
              description:
                  'Quedan ${qty.toStringAsFixed(1)} ${med['unit']} (Mínimo: ${min.toStringAsFixed(1)}). Solicita reabastecimiento.',
              source: 'Inventory Engine',
              createdAt: today.toIso8601String(),
            ),
          );
        }
        final expiration = DateTime.tryParse(
          med['expiration_date']?.toString() ?? '',
        );
        if (expiration != null) {
          final days = expiration.difference(today).inDays;
          if (days < 0) {
            newAlerts.add(
              AlertModel(
                id: 'med_expired_${med['id']}',
                animalId: '',
                animalName: 'Inventario',
                animalTag: 'Medicamento',
                type: 'inventory',
                riskLevel: 'rojo',
                title: 'Producto vencido: ${med['name']}',
                description:
                    'No usar sin revisión profesional. Registra su descarte seguro.',
                source: 'Inventory Engine',
                createdAt: today.toIso8601String(),
              ),
            );
          } else if (days <= 60) {
            newAlerts.add(
              AlertModel(
                id: 'med_expiring_${med['id']}',
                animalId: '',
                animalName: 'Inventario',
                animalTag: 'Medicamento',
                type: 'inventory',
                riskLevel: 'amarillo',
                title: 'Medicamento próximo a vencer: ${med['name']}',
                description:
                    'Vence en $days días. Revisa el lote y planifica su uso responsable.',
                source: 'Inventory Engine',
                createdAt: today.toIso8601String(),
              ),
            );
          }
        }

        final recentUses = medicineMovements.where((movement) {
          if (movement['medicine_id'] != med['id'] ||
              movement['movement_type'] != 'Uso en tratamiento') {
            return false;
          }
          final date = DateTime.tryParse(
            movement['created_at']?.toString() ?? '',
          );
          return date != null && today.difference(date).inDays <= 30;
        }).length;
        if (recentUses >= 5) {
          newAlerts.add(
            AlertModel(
              id: 'med_frequent_${med['id']}',
              animalId: '',
              animalName: 'Inventario',
              animalTag: 'Uso frecuente',
              type: 'inventory',
              riskLevel: 'amarillo',
              title: 'Uso frecuente: ${med['name']}',
              description:
                  '$recentUses usos registrados en los últimos 30 días. Solicita revisión veterinaria.',
              source: 'Inventory Engine',
              createdAt: today.toIso8601String(),
            ),
          );
        }
      }

      for (var animal in animals) {
        if (animal.status.toLowerCase() != 'activo') continue;

        // 2. Alertas de vacunas vencidas
        if (animal.vaccineStatus?.toLowerCase() == 'vencida') {
          newAlerts.add(
            AlertModel(
              id: 'vac_${animal.id}',
              animalId: animal.id,
              animalName: animal.name,
              animalTag: animal.tag,
              type: 'health',
              riskLevel: 'amarillo',
              title: 'Vacunas vencidas',
              description:
                  'El esquema de vacunación de ${animal.name} está vencido. Programa vacunación.',
              source: 'Sanitary Engine',
              createdAt: today.toIso8601String(),
            ),
          );
        }

        // 3. Alertas de caída de peso (>10%)
        final animalWeights = weightRecords
            .where((w) => w['animal_id'] == animal.id)
            .toList();
        if (animalWeights.length >= 2) {
          animalWeights.sort(
            (a, b) => (b['date'] as String).compareTo(a['date'] as String),
          );
          final double lastWeight = (animalWeights[0]['weight_kg'] as num)
              .toDouble();
          final double avgRecent =
              animalWeights
                  .skip(1)
                  .map((w) => (w['weight_kg'] as num).toDouble())
                  .reduce((a, b) => a + b) /
              (animalWeights.length - 1);
          if (lastWeight < avgRecent * 0.9) {
            newAlerts.add(
              AlertModel(
                id: 'weight_${animal.id}',
                animalId: animal.id,
                animalName: animal.name,
                animalTag: animal.tag,
                type: 'health',
                riskLevel: 'amarillo',
                title: 'Pérdida de peso significativa',
                description:
                    'El peso bajó a ${lastWeight.toStringAsFixed(1)} kg (Promedio reciente: ${avgRecent.toStringAsFixed(1)} kg). Revisa nutrición o descarta parasitosis.',
                source: 'Weight Engine',
                createdAt: today.toIso8601String(),
              ),
            );
          }
        }

        // 4. Caída de producción de leche (>10% en 3 consecutivos)
        final animalProds = productionRecords
            .where((p) => p['animal_id'] == animal.id)
            .toList();
        if (animalProds.length >= 4) {
          animalProds.sort(
            (a, b) => (b['date'] as String).compareTo(a['date'] as String),
          );
          final double l1 = (animalProds[0]['liters'] as num).toDouble();
          final double l2 = (animalProds[1]['liters'] as num).toDouble();
          final double l3 = (animalProds[2]['liters'] as num).toDouble();
          final double avgPrev =
              animalProds
                  .skip(3)
                  .take(5)
                  .map((p) => (p['liters'] as num).toDouble())
                  .reduce((a, b) => a + b) /
              min(5, animalProds.length - 3);

          if (l1 < avgPrev * 0.9 && l2 < avgPrev * 0.9 && l3 < avgPrev * 0.9) {
            newAlerts.add(
              AlertModel(
                id: 'milk_${animal.id}',
                animalId: animal.id,
                animalName: animal.name,
                animalTag: animal.tag,
                type: 'health',
                riskLevel: 'amarillo',
                title: 'Caída consecutiva de producción',
                description:
                    'Producción láctea en descenso sostenido por 3 días (${l1.toStringAsFixed(1)} L vs promedio histórico de ${avgPrev.toStringAsFixed(1)} L). Posible indicio de mastitis.',
                source: 'Production Engine',
                createdAt: today.toIso8601String(),
              ),
            );
          }
        }

        // 5. Alertas de partos próximos (<48 horas)
        final animalRepros = reproRecords
            .where((r) => r['animal_id'] == animal.id)
            .toList();
        for (var rep in animalRepros) {
          if (rep['event_type'] == 'Gestación confirmada' &&
              rep['expected_birth_date'] != null) {
            try {
              final birthDate = DateTime.parse(
                rep['expected_birth_date'] as String,
              );
              final hoursDiff = birthDate.difference(today).inHours;
              if (hoursDiff > 0 && hoursDiff <= 48) {
                newAlerts.add(
                  AlertModel(
                    id: 'birth_${animal.id}',
                    animalId: animal.id,
                    animalName: animal.name,
                    animalTag: animal.tag,
                    type: 'reproduction',
                    riskLevel: 'verde',
                    title: 'Parto próximo programado',
                    description:
                        'Fecha esperada de parto dentro de ${hoursDiff} horas (${rep['expected_birth_date']}). Prepara cubículo de parición.',
                    source: 'Reproduction Engine',
                    createdAt: today.toIso8601String(),
                  ),
                );
              }
            } catch (_) {}
          }
        }

        // 6. Alertas de eventos SOS críticos recientes
        final animalSos = sosCases
            .where((s) => s['animal_id'] == animal.id)
            .toList();
        if (animalSos.isNotEmpty) {
          animalSos.sort(
            (a, b) => (b['created_at'] as String).compareTo(
              a['created_at'] as String,
            ),
          );
          final latestSos = animalSos.first;
          final risk = latestSos['risk_level'] as String;
          if (risk == 'rojo') {
            newAlerts.add(
              AlertModel(
                id: 'sos_${latestSos['id']}',
                animalId: animal.id,
                animalName: animal.name,
                animalTag: animal.tag,
                type: 'sos',
                riskLevel: 'rojo',
                title: 'CRÍTICO: Triaje SOS Activo',
                description:
                    'Síntoma: ${latestSos['symptoms_text']}. Requiere atención veterinaria urgente.',
                source: 'SOS Engine',
                createdAt: latestSos['created_at'] as String,
              ),
            );
          }
        }
      }

      // Persistir las alertas en la base de datos
      for (var alert in newAlerts) {
        await dbHelper.insertAlert(alert);
      }
    } catch (e) {
      debugPrint("Error running Health Alert Engine: $e");
    }

    return newAlerts;
  }
}
