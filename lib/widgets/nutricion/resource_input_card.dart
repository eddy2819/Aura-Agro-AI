import 'package:flutter/material.dart';
import '../../models/nutrition_resource.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';


/// Tarjeta con campo de entrada por voz/texto y resumen de recursos
class ResourceInputCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onMicTap;
  final VoidCallback? onAnalyze;

  const ResourceInputCard({
    super.key,
    required this.controller,
    this.onMicTap,
    this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text('Dicta tus recursos', style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText:
                          "Ejemplo: 'Tengo 15 hectáreas de pasto y 5 toneladas de silo'",
                      hintStyle: AppTextStyles.caption,
                      border: InputBorder.none,
                    ),
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onMicTap,
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('O selecciona manualmente:', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// Sección expandible de tipo de recurso (Pastos, Forrajes, Concentrados, Suplementos)
class ResourceCategoryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<NutritionResource> resources;
  final bool selected;
  final VoidCallback? onTap;
  final Function(NutritionResource, double) onAmountChanged;

  const ResourceCategoryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.resources,
    this.selected = false,
    this.onTap,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.greenSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.primaryGreen : AppColors.border,
        ),
      ),
      child: ExpansionTile(
        onExpansionChanged: (isExpanded) {
          if (isExpanded && onTap != null) {
            onTap!();
          }
        },
        leading: Icon(
          icon,
          color: selected
              ? AppColors.primaryGreenDark
              : AppColors.textSecondary,
        ),
        title: Text(title, style: AppTextStyles.bodyBold),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        children: resources
            .map(
              (res) => ResourceItemRow(
                key: ValueKey(res.id ?? res.name),
                resource: res,
                onAmountChanged: (val) => onAmountChanged(res, val),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Fila individual para un recurso con su respectivo campo de entrada numérico.
/// Es Stateful para evitar la pérdida de foco o resets al reconstruir el widget padre.
class ResourceItemRow extends StatefulWidget {
  final NutritionResource resource;
  final Function(double) onAmountChanged;

  const ResourceItemRow({
    super.key,
    required this.resource,
    required this.onAmountChanged,
  });

  @override
  State<ResourceItemRow> createState() => _ResourceItemRowState();
}

class _ResourceItemRowState extends State<ResourceItemRow> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.resource.amount.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant ResourceItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Solo actualizar el controlador externo si el foco no está activo en este campo
    if (oldWidget.resource.amount != widget.resource.amount && !_focusNode.hasFocus) {
      _controller.text = widget.resource.amount.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _submitValue();
    }
  }

  void _submitValue() {
    final val = double.tryParse(_controller.text);
    if (val != null && val >= 0) {
      widget.onAmountChanged(val);
    } else {
      // Revertir a la cantidad original si la entrada es inválida
      _controller.text = widget.resource.amount.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  String _getDaysSinceUpdate(String updatedAtStr) {
    try {
      final dt = DateTime.parse(updatedAtStr);
      final diff = DateTime.now().difference(dt).inDays;
      if (diff == 0) return 'hoy';
      if (diff == 1) return 'ayer';
      return 'hace $diff días';
    } catch (_) {}
    return 'hoy';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.resource.name,
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                ),
                Text(
                  'Act.: ${_getDaysSinceUpdate(widget.resource.updatedAt)}',
                  style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              onSubmitted: (_) => _submitValue(),
              decoration: InputDecoration(
                suffixText: ' ${widget.resource.unit}',
                suffixStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

