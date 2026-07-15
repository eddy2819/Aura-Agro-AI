import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/data_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/navigation/top_app_bar.dart';
import '../widgets/veterinario/clinical_alert_card.dart';
import '../widgets/veterinario/vet_profile_card.dart';
import 'chat/clinical_case_chat_screen.dart';

class VeterinarioScreen extends StatefulWidget {
  const VeterinarioScreen({super.key});

  @override
  State<VeterinarioScreen> createState() => _VeterinarioScreenState();
}

class _VeterinarioScreenState extends State<VeterinarioScreen> {
  final _tabs = const ['Alertas', 'Tratamientos', 'Chats', 'Vacunas', 'Fincas'];

  void _showAddVaccineDialog(BuildContext context, DataProvider provider) {
    if (provider.animals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Registre primero un animal en la sección "Ganado"',
            style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.alertOrange,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    String? selectedAnimalId = provider.animals.first.id;
    final nameController = TextEditingController();
    final doseController = TextEditingController(text: '5 ml');
    final dateController = TextEditingController(
      text: DateTime.now().toIso8601String().split('T')[0],
    );
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Registrar Vacuna', style: AppTextStyles.h2),
                          IconButton(
                            icon: const Icon(LucideIcons.x),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Dropdown de animales
                      DropdownButtonFormField<String>(
                        value: selectedAnimalId,
                        style: AppTextStyles.bodyBold,
                        decoration: InputDecoration(
                          labelText: 'Seleccionar Animal',
                          labelStyle: AppTextStyles.caption,
                          prefixIcon: const Icon(
                            LucideIcons.beef,
                            size: 20,
                            color: AppColors.primaryGreen,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: provider.animals.map((a) {
                          return DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.name} (${a.tag})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedAnimalId = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Nombre de la vacuna
                      TextFormField(
                        controller: nameController,
                        style: AppTextStyles.bodyBold,
                        decoration: InputDecoration(
                          labelText: 'Nombre de la Vacuna (Ej: Fiebre Aftosa)',
                          labelStyle: AppTextStyles.caption,
                          prefixIcon: const Icon(
                            LucideIcons.syringe,
                            size: 20,
                            color: AppColors.primaryGreen,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryGreen,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Ingrese la vacuna'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Fecha
                      TextFormField(
                        controller: dateController,
                        readOnly: true,
                        style: AppTextStyles.bodyBold,
                        decoration: InputDecoration(
                          labelText: 'Fecha de Aplicación',
                          labelStyle: AppTextStyles.caption,
                          prefixIcon: const Icon(
                            LucideIcons.calendar,
                            size: 20,
                            color: AppColors.primaryGreen,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppColors.primaryGreen,
                                    onPrimary: Colors.white,
                                    onSurface: AppColors.textPrimary,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setModalState(() {
                              dateController.text = picked
                                  .toIso8601String()
                                  .split('T')[0];
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Dosis
                      TextFormField(
                        controller: doseController,
                        style: AppTextStyles.bodyBold,
                        decoration: InputDecoration(
                          labelText: 'Dosis (Ej: 5 ml, 2 ml)',
                          labelStyle: AppTextStyles.caption,
                          prefixIcon: const Icon(
                            LucideIcons.droplets,
                            size: 20,
                            color: AppColors.primaryGreen,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryGreen,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Ingrese la dosis'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Notas
                      TextFormField(
                        controller: notesController,
                        style: AppTextStyles.body,
                        decoration: InputDecoration(
                          labelText: 'Observaciones / Notas',
                          labelStyle: AppTextStyles.caption,
                          prefixIcon: const Icon(
                            LucideIcons.clipboard,
                            size: 20,
                            color: AppColors.primaryGreen,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryGreen,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Registrar
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              await provider.addVaccine(
                                animalId: selectedAnimalId!,
                                name: nameController.text.trim(),
                                dateApplied: dateController.text,
                                dose: doseController.text.trim(),
                                notes: notesController.text.trim(),
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Vacuna registrada y estado actualizado',
                                      style: AppTextStyles.bodyBold.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: AppColors.primaryGreen,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Guardar Vacuna',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, provider, child) {
        final role = provider.profile?['role'] ?? 'Veterinario';

        if (provider.isLoading) {
          return Scaffold(
            appBar: AuraTopBar(role: role),
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          );
        }

        final alerts = provider.alerts;
        final vaccines = provider.vaccines;
        final tab = provider.activeVetTab;

        return Scaffold(
          appBar: AuraTopBar(role: role),
          floatingActionButton: tab == 3
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddVaccineDialog(context, provider),
                  backgroundColor: AppColors.primaryGreen,
                  icon: const Icon(LucideIcons.plus, color: Colors.white),
                  label: Text(
                    'Registrar Vacuna',
                    style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
                  ),
                )
              : null,
          floatingActionButtonLocation: const _AboveBottomNavFabLocation(),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              Text('Panel Veterinario', style: AppTextStyles.h1),
              const SizedBox(height: 14),
              const VetProfileCard(),
              const SizedBox(height: 18),

              // Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_tabs.length, (i) {
                    final selected = tab == i;
                    final showBadge = i == 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        labelPadding: EdgeInsets.zero,
                        label: showBadge
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_tabs[i]),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Colors.white.withValues(alpha: 0.25)
                                          : AppColors.alertOrange,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${alerts.length}',
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Text(_tabs[i]),
                        selected: selected,
                        onSelected: (_) => provider.setActiveVetTab(i),
                        selectedColor: AppColors.primaryGreen,
                        backgroundColor: AppColors.surface,
                        labelStyle: AppTextStyles.caption.copyWith(
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: BorderSide(
                            color: selected
                                ? AppColors.primaryGreen
                                : AppColors.border,
                          ),
                        ),
                        showCheckmark: false,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // Alertas Clínicas
              if (tab == 0) ...[
                if (alerts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No hay alertas sanitarias activas',
                        style: AppTextStyles.body,
                      ),
                    ),
                  )
                else
                  ...alerts.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ClinicalAlertCard(
                        alert: a,
                        onRegisterTreatment: () {
                          // Si es por vacuna vencida, llevar al tab de vacunas
                          if (a.title.toLowerCase().contains('vacuna')) {
                            provider.setActiveVetTab(3);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Usa el botón "Registrar Vacuna" para inmunizar al animal',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            // Cualquier otro tratamiento
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Tratamiento para ${a.animalName} registrado en historial clínico',
                                ),
                                backgroundColor: AppColors.primaryGreen,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
              ]
              // Vacunas
              else if (tab == 2) ...[
                if (provider.clinicalCaseChats.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No hay chats clínicos asignados',
                        style: AppTextStyles.body,
                      ),
                    ),
                  )
                else
                  ...provider.clinicalCaseChats.map((chat) {
                    final priority = chat['priority']?.toString() ?? 'green';
                    final color = priority == 'urgent' || priority == 'red'
                        ? AppColors.alertRed
                        : priority == 'yellow'
                        ? AppColors.alertOrange
                        : AppColors.primaryGreen;
                    final pending = provider.clinicalCaseMessages
                        .where((m) => m['chat_id'] == chat['id'])
                        .length;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: .12),
                          child: Icon(LucideIcons.messagesSquare, color: color),
                        ),
                        title: Text(
                          'Caso ${chat['case_id']}',
                          style: AppTextStyles.bodyBold,
                        ),
                        subtitle: Text('${chat['status']} · $pending mensajes'),
                        trailing: const Icon(LucideIcons.chevronRight),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClinicalCaseChatScreen(chat: chat),
                          ),
                        ),
                      ),
                    );
                  }),
              ]
              // Vacunas
              else if (tab == 3) ...[
                if (vaccines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No hay vacunas registradas en la base de datos',
                        style: AppTextStyles.body,
                      ),
                    ),
                  )
                else
                  ...vaccines.map((v) {
                    final animalName = v['animal_name'] ?? 'Desconocido';
                    final animalTag = v['animal_tag'] ?? '';
                    final vaccineName = v['name'] ?? 'Vacuna';
                    final date = v['date_applied'] ?? '';
                    final dose = v['dose'] ?? '';
                    final notes = v['notes'] ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                LucideIcons.syringe,
                                color: AppColors.primaryGreen,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(vaccineName, style: AppTextStyles.h3),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Aplicada a: $animalName ($animalTag)',
                                    style: AppTextStyles.bodyBold.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (notes.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Nota: $notes',
                                      style: AppTextStyles.body.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.calendar,
                                        size: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(date, style: AppTextStyles.caption),
                                      const SizedBox(width: 16),
                                      const Icon(
                                        LucideIcons.droplet,
                                        size: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(dose, style: AppTextStyles.caption),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ] else if (tab == 4) ...[
                if (provider.vetFarmLinks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No tienes invitaciones de fincas',
                        style: AppTextStyles.body,
                      ),
                    ),
                  )
                else
                  ...provider.vetFarmLinks.map(
                    (link) => Card(
                      child: ListTile(
                        leading: const Icon(
                          LucideIcons.house,
                          color: AppColors.primaryGreen,
                        ),
                        title: Text(
                          '${link['farm_id']}',
                          style: AppTextStyles.bodyBold,
                        ),
                        subtitle: Text('Estado: ${link['status']}'),
                        trailing: link['status'] == 'pending'
                            ? Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'Rechazar',
                                    onPressed: () =>
                                        provider.updateVetFarmLinkStatus(
                                          link['id'] as String,
                                          'rejected',
                                        ),
                                    icon: const Icon(
                                      LucideIcons.x,
                                      color: AppColors.alertRed,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Aceptar',
                                    onPressed: () =>
                                        provider.updateVetFarmLinkStatus(
                                          link['id'] as String,
                                          'accepted',
                                        ),
                                    icon: const Icon(
                                      LucideIcons.check,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ),
              ]
              // Otros Tabs (Tratamientos, Fincas) - Placeholders
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'Sección "${_tabs[tab]}" — contenido próximamente',
                      style: AppTextStyles.body,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AboveBottomNavFabLocation extends FloatingActionButtonLocation {
  const _AboveBottomNavFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabWidth = scaffoldGeometry.floatingActionButtonSize.width;
    final double fabHeight = scaffoldGeometry.floatingActionButtonSize.height;

    final double contentWidth = scaffoldGeometry.scaffoldSize.width;
    final double contentHeight = scaffoldGeometry.scaffoldSize.height;

    // Bottom nav sits 16px above bottom + height 72 + extra space 16 = 104px
    double x = contentWidth - fabWidth - 16;
    double y = contentHeight - fabHeight - 104;
    return Offset(x, y);
  }
}
