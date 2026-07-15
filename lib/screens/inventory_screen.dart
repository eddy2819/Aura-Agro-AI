import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../data/data_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController(text: 'ml');
  final _minStockController = TextEditingController(text: '5');
  final _expirationDateController = TextEditingController();
  final _providerController = TextEditingController();
  String _selectedType = 'Vacuna'; // Vacuna, Antibiótico, Desparasitante, Suplemento, Otro

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _minStockController.dispose();
    _expirationDateController.dispose();
    _providerController.dispose();
    super.dispose();
  }

  void _showAddEditDialog([Map<String, dynamic>? item]) {
    final isEditing = item != null;
    if (isEditing) {
      _nameController.text = item['name'] ?? '';
      _quantityController.text = (item['quantity'] as num?)?.toString() ?? '';
      _unitController.text = item['unit'] ?? 'ml';
      _minStockController.text = (item['min_stock'] as num?)?.toString() ?? '5';
      _expirationDateController.text = item['expiration_date'] ?? '';
      _providerController.text = item['provider'] ?? '';
      _selectedType = item['type'] ?? 'Vacuna';
    } else {
      _nameController.clear();
      _quantityController.clear();
      _unitController.text = 'ml';
      _minStockController.text = '5';
      _expirationDateController.text = '';
      _providerController.clear();
      _selectedType = 'Vacuna';
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Insumo' : 'Registrar Insumo', style: AppTextStyles.bodyBold),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombre del Insumo', hintText: 'Ej. Fiebre Aftosa, Ivomec...'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: 'Tipo de Insumo'),
                  items: ['Vacuna', 'Antibiótico', 'Desparasitante', 'Suplemento', 'Otro'].map((t) {
                    return DropdownMenuItem(value: t, child: Text(t));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedType = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Stock Actual'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _unitController,
                        decoration: const InputDecoration(labelText: 'Unidad', hintText: 'ml, dosis, kg...'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _minStockController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Stock Mínimo Alerta'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _expirationDateController,
                  decoration: const InputDecoration(labelText: 'Vencimiento (YYYY-MM-DD)', hintText: 'Ej. 2027-05-30'),
                  onTap: () async {
                    FocusScope.of(context).requestFocus(FocusNode());
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 1825)),
                    );
                    if (picked != null) {
                      _expirationDateController.text = picked.toIso8601String().split('T')[0];
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _providerController,
                  decoration: const InputDecoration(labelText: 'Proveedor', hintText: 'Ej. Agropecuaria Local'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_nameController.text.trim().isEmpty || _quantityController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nombre y stock son obligatorios")),
                  );
                  return;
                }

                final provider = Provider.of<DataProvider>(context, listen: false);
                final id = isEditing ? item['id'] as String : const Uuid().v4();
                final Map<String, dynamic> row = {
                  'id': id,
                  'name': _nameController.text.trim(),
                  'type': _selectedType,
                  'quantity': double.tryParse(_quantityController.text) ?? 0.0,
                  'unit': _unitController.text.trim(),
                  'min_stock': double.tryParse(_minStockController.text) ?? 5.0,
                  'expiration_date': _expirationDateController.text.trim(),
                  'provider': _providerController.text.trim(),
                  'created_at': DateTime.now().toIso8601String(),
                  'synced': 0,
                };

                if (isEditing) {
                  await provider.updateMedicine(row);
                } else {
                  await provider.addMedicine(row);
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEditing ? "Insumo actualizado" : "Insumo registrado")),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
              child: Text(isEditing ? 'Guardar' : 'Agregar', style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Color _getStockColor(double quantity, double minStock) {
    if (quantity <= 0) return AppColors.alertOrange;
    if (quantity <= minStock) return const Color(0xFFFFB300);
    return AppColors.primaryGreen;
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'vacuna':
        return LucideIcons.syringe;
      case 'antibiótico':
      case 'antibiotico':
        return LucideIcons.pill;
      case 'desparasitante':
        return LucideIcons.bugOff;
      case 'suplemento':
        return LucideIcons.leaf;
      default:
        return LucideIcons.package;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DataProvider>(context);
    final medicines = provider.medicines;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventario Veterinario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryGreenDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: medicines.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.package2, size: 64, color: AppColors.border),
                  const SizedBox(height: 16),
                  Text('Inventario Vacío', style: AppTextStyles.h3),
                  const SizedBox(height: 8),
                  Text('Registra medicamentos y vacunas para llevar control de stock.', style: AppTextStyles.caption),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditDialog(),
                    icon: const Icon(LucideIcons.plus),
                    label: const Text('Registrar Primer Insumo', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: medicines.length,
              itemBuilder: (context, index) {
                final item = medicines[index];
                final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                final double min = (item['min_stock'] as num?)?.toDouble() ?? 5.0;
                final isLowStock = qty <= min;

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isLowStock ? _getStockColor(qty, min).withOpacity(0.4) : AppColors.border),
                  ),
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getStockColor(qty, min).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_getTypeIcon(item['type'] ?? ''), color: _getStockColor(qty, min), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['name'] ?? '', style: AppTextStyles.bodyBold),
                              const SizedBox(height: 4),
                              Text('${item['type']} • Prov: ${item['provider'] ?? 'N/D'}', style: AppTextStyles.caption),
                              if (item['expiration_date'] != null && item['expiration_date'].toString().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(LucideIcons.calendar, size: 12, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text('Vence: ${item['expiration_date']}', style: AppTextStyles.caption),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$qty ${item['unit']}',
                              style: AppTextStyles.h3.copyWith(
                                color: _getStockColor(qty, min),
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (isLowStock)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStockColor(qty, min).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  qty <= 0 ? 'AGOTADO' : 'STOCK BAJO',
                                  style: TextStyle(
                                    color: _getStockColor(qty, min),
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              Text('Min: $min', style: AppTextStyles.caption),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _showAddEditDialog(item),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(LucideIcons.edit2, size: 14, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: medicines.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showAddEditDialog(),
              backgroundColor: AppColors.primaryGreen,
              child: const Icon(LucideIcons.plus, color: Colors.white),
            )
          : null,
    );
  }
}
