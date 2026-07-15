import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/data_provider.dart';
import '../models/medicine_scan_result.dart';
import '../services/medicine_vision_service.dart';
import '../services/pdf_export_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const _types = [
    'Todos',
    'Vacuna',
    'Antibiótico',
    'Antiinflamatorio',
    'Desparasitante',
    'Vitamina',
    'Mineral',
    'Suplemento',
    'Otro',
  ];
  static const _units = [
    'ml',
    'mg',
    'g',
    'kg',
    'frascos',
    'sobres',
    'tabletas',
    'dosis',
    'unidades',
  ];

  String _filter = 'Todos';
  bool _isScanning = false;

  Future<void> _scanLabel() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() => _isScanning = true);
    try {
      final result = await MedicineVisionService.instance.scanMedicineLabel(
        File(picked.path),
      );
      if (!mounted) return;
      if (result.confidence < 0.5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo leer bien la etiqueta. Ingrese los datos manualmente.',
            ),
          ),
        );
      }
      await _showMedicineForm(scan: result, photoPath: picked.path);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foto borrosa o análisis no disponible: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _showMedicineForm({
    Map<String, dynamic>? item,
    MedicineScanResult? scan,
    String? photoPath,
  }) async {
    final editing = item != null;
    String value(String key, [String fallback = '']) =>
        item?[key]?.toString() ?? fallback;
    final name = TextEditingController(text: scan?.name ?? value('name'));
    final active = TextEditingController(
      text: scan?.activeIngredient ?? value('active_ingredient'),
    );
    final presentation = TextEditingController(
      text: scan?.presentation ?? value('presentation'),
    );
    final concentration = TextEditingController(
      text: scan?.concentration ?? value('concentration'),
    );
    final quantity = TextEditingController(text: value('quantity', '0'));
    final minimum = TextEditingController(text: value('min_stock', '1'));
    final expiration = TextEditingController(
      text: scan?.expirationDate ?? value('expiration_date'),
    );
    final batch = TextEditingController(
      text: scan?.batchNumber ?? value('batch_number'),
    );
    final supplier = TextEditingController(
      text: scan?.provider ?? value('provider'),
    );
    final withdrawal = TextEditingController(
      text: scan?.withdrawalPeriod ?? value('withdrawal_period'),
    );
    final indications = TextEditingController(
      text: scan?.indications ?? value('indications'),
    );
    final contraindications = TextEditingController(
      text: scan?.contraindications ?? value('contraindications'),
    );
    final notes = TextEditingController(text: value('notes'));
    var type = scan?.type != null && _types.contains(scan!.type)
        ? scan.type!
        : (_types.contains(value('type')) ? value('type') : 'Otro');
    var unit = _units.contains(value('unit')) ? value('unit') : 'ml';
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          editing
                              ? 'Editar medicamento'
                              : 'Registrar medicamento',
                          style: AppTextStyles.h2,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                if (scan != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scan.confidence >= 0.8
                          ? AppColors.greenSurface
                          : AppColors.alertOrangeSurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Datos detectados automáticamente. Revise antes de guardar. Confianza ${(scan.confidence * 100).round()}%${scan.confidence < 0.8 ? ' · REVISAR' : ''}',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      _field(name, 'Nombre *', required: true),
                      _field(active, 'Principio activo'),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: _types
                            .skip(1)
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry,
                                child: Text(entry),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setSheetState(() => type = value ?? type),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _field(presentation, 'Presentación')),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _field(concentration, 'Concentración'),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              quantity,
                              'Cantidad *',
                              required: true,
                              numeric: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: unit,
                              decoration: const InputDecoration(
                                labelText: 'Unidad',
                              ),
                              items: _units
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry,
                                      child: Text(entry),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setSheetState(() => unit = value ?? unit),
                            ),
                          ),
                        ],
                      ),
                      _field(minimum, 'Stock mínimo', numeric: true),
                      _dateField(context, expiration, 'Fecha de vencimiento'),
                      _field(batch, 'Número de lote'),
                      _field(supplier, 'Proveedor'),
                      _field(withdrawal, 'Tiempo de retiro'),
                      _field(indications, 'Indicaciones visibles', lines: 2),
                      _field(
                        contraindications,
                        'Contraindicaciones visibles',
                        lines: 2,
                      ),
                      _field(notes, 'Observaciones', lines: 2),
                      const SizedBox(height: 10),
                      _medicalWarning(),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final parsedQuantity =
                              double.tryParse(quantity.text) ?? 0;
                          if (parsedQuantity < 0) return;
                          final provider = context.read<DataProvider>();
                          final now = DateTime.now();
                          final row = <String, dynamic>{
                            'id':
                                item?['id'] ??
                                'med_${now.microsecondsSinceEpoch}',
                            'name': name.text.trim(),
                            'active_ingredient': active.text.trim(),
                            'type': type,
                            'presentation': presentation.text.trim(),
                            'concentration': concentration.text.trim(),
                            'quantity': parsedQuantity,
                            'unit': unit,
                            'min_stock': double.tryParse(minimum.text) ?? 0,
                            'expiration_date': expiration.text.trim(),
                            'batch_number': batch.text.trim(),
                            'provider': supplier.text.trim(),
                            'label_photo_path':
                                photoPath ?? item?['label_photo_path'],
                            'withdrawal_period': withdrawal.text.trim(),
                            'indications': indications.text.trim(),
                            'contraindications': contraindications.text.trim(),
                            'notes': notes.text.trim(),
                            'created_at':
                                item?['created_at'] ?? now.toIso8601String(),
                            'updated_at': now.toIso8601String(),
                            'synced': 0,
                          };
                          // Cerrar primero el formulario. DataProvider notifica a
                          // InventoryScreen durante el guardado y no debe desmontar
                          // dependencias mientras el BottomSheet sigue animándose.
                          Navigator.of(sheetContext).pop();
                          if (editing) {
                            await provider.updateMedicine(row);
                          } else {
                            await provider.addMedicine(row);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Revisé los datos · Guardar'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Los controladores pertenecen al contenido temporal del BottomSheet. No se
    // eliminan inmediatamente porque la ruta conserva widgets durante su
    // animación de salida; disponerlos aquí causaba `_dependents.isEmpty`.
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool numeric = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLines: lines,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? 'Campo obligatorio'
                : null
          : null,
    ),
  );

  Widget _dateField(
    BuildContext context,
    TextEditingController controller,
    String label,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime.now().subtract(const Duration(days: 3650)),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
          initialDate:
              DateTime.tryParse(controller.text) ??
              DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          controller.text = picked.toIso8601String().split('T').first;
        }
      },
    ),
  );

  Future<void> _registerUse(Map<String, dynamic> medicine) async {
    final quantity = TextEditingController();
    final reason = TextEditingController(text: 'Uso registrado en finca');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Registrar uso · ${medicine['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Disponible: ${medicine['quantity']} ${medicine['unit']}'),
            const SizedBox(height: 12),
            _field(quantity, 'Cantidad usada', required: true, numeric: true),
            _field(reason, 'Motivo'),
            if ((medicine['withdrawal_period'] ?? '').toString().isNotEmpty)
              Text(
                'Puede requerir retiro: ${medicine['withdrawal_period']}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.alertOrange,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(quantity.text) ?? 0;
              final ok = await context.read<DataProvider>().deductMedicineStock(
                medicineId: medicine['id'] as String,
                quantity: amount,
                reason: reason.text,
              );
              if (!dialogContext.mounted) return;
              if (ok) {
                Navigator.pop(dialogContext);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No hay stock suficiente.')),
                );
              }
            },
            child: const Text('Registrar uso'),
          ),
        ],
      ),
    );
    quantity.dispose();
    reason.dispose();
  }

  Widget _medicalWarning() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.alertOrangeSurface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      'AURA Agro AI no receta medicamentos ni reemplaza al médico veterinario. Verifica dosis, tiempo de retiro y autorización profesional antes de usar.',
      style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
    ),
  );

  String _status(Map<String, dynamic> medicine) {
    final quantity = (medicine['quantity'] as num?)?.toDouble() ?? 0;
    final minimum = (medicine['min_stock'] as num?)?.toDouble() ?? 0;
    final expiration = DateTime.tryParse(
      medicine['expiration_date']?.toString() ?? '',
    );
    if (expiration != null && expiration.isBefore(DateTime.now()))
      return 'Vencido';
    if (expiration != null &&
        expiration.difference(DateTime.now()).inDays <= 60) {
      return 'Próximo a vencer';
    }
    if (quantity <= minimum) return quantity <= 0 ? 'Agotado' : 'Stock bajo';
    return 'Disponible';
  }

  Color _statusColor(String status) {
    if (status == 'Vencido' || status == 'Agotado') return AppColors.alertRed;
    if (status == 'Stock bajo' || status == 'Próximo a vencer') {
      return AppColors.alertOrange;
    }
    return AppColors.primaryGreen;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    final medicines = provider.medicines
        .where((item) => _filter == 'Todos' || item['type'] == _filter)
        .toList();
    final expiring = provider.getExpiringMedicines();
    final low = provider.getLowStockMedicines();
    final expired = provider.medicines
        .where((item) => _status(item) == 'Vencido')
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventario Inteligente'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'pdf') {
                PdfExportService.instance.exportMedicineInventory(
                  provider.medicines,
                  provider.medicineMovements,
                );
              } else if (value == 'csv') {
                PdfExportService.instance.exportMedicineInventoryCsv(
                  provider.medicines,
                );
              } else {
                PdfExportService.instance.exportMedicineMovementsCsv(
                  provider.medicineMovements,
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('Exportar PDF')),
              PopupMenuItem(value: 'csv', child: Text('Exportar CSV')),
              PopupMenuItem(
                value: 'movements',
                child: Text('Exportar movimientos'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          _medicalWarning(),
          const SizedBox(height: 14),
          Text(
            '${provider.medicines.length} productos registrados',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _summary(
                  'Por vencer',
                  '${expiring.length}',
                  AppColors.alertOrange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summary(
                  'Stock bajo',
                  '${low.length}',
                  AppColors.alertOrange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summary('Críticos', '$expired', AppColors.alertRed),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanLabel,
                  icon: _isScanning
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.camera),
                  label: const Text('Registrar con foto'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showMedicineForm(),
                  icon: const Icon(LucideIcons.pencil),
                  label: const Text('Manualmente'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _types
                  .map(
                    (type) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(type),
                        selected: _filter == type,
                        onSelected: (_) => setState(() => _filter = type),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          if (medicines.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No hay productos en esta categoría.')),
            )
          else
            ...medicines.map((medicine) => _medicineCard(medicine)),
        ],
      ),
    );
  }

  Widget _summary(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Text(value, style: AppTextStyles.h2.copyWith(color: color)),
        Text(label, style: AppTextStyles.caption),
      ],
    ),
  );

  Widget _medicineCard(Map<String, dynamic> medicine) {
    final status = _status(medicine);
    final color = _statusColor(status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(LucideIcons.briefcaseMedical, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine['name'] ?? '',
                        style: AppTextStyles.bodyBold,
                      ),
                      Text(
                        '${medicine['type'] ?? 'Otro'} · ${medicine['active_ingredient'] ?? 'Principio activo no registrado'}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(status),
                  labelStyle: TextStyle(color: color, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Stock: ${medicine['quantity']} ${medicine['unit']} · Vence: ${medicine['expiration_date'] ?? 'Sin fecha'}',
              style: AppTextStyles.body,
            ),
            if ((medicine['withdrawal_period'] ?? '').toString().isNotEmpty)
              Text(
                'Retiro: ${medicine['withdrawal_period']}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.alertOrange,
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showMedicineForm(item: medicine),
                    child: const Text('Ver / editar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: status == 'Agotado'
                        ? null
                        : () => _registerUse(medicine),
                    child: const Text('Registrar uso'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
