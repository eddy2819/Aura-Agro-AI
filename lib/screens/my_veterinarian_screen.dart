import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/data_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'chat/clinical_case_chat_screen.dart';
import 'sos_screen.dart';

class MyVeterinarianScreen extends StatelessWidget {
  const MyVeterinarianScreen({super.key});

  Future<void> _invite(BuildContext context) async {
    final controller = TextEditingController();
    final provider = context.read<DataProvider>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invitar veterinario'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'ID o código del veterinario',
            helperText: 'El veterinario deberá aceptar la invitación.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enviar invitación'),
          ),
        ],
      ),
    );
    if (accepted == true && controller.text.trim().isNotEmpty) {
      await provider.inviteVeterinarian(
        vetId: controller.text.trim(),
        farmId:
            provider.profile?['farm_id']?.toString() ??
            provider.profile?['farm_name']?.toString() ??
            'default_farm',
        permissions: const [
          'view_animals',
          'view_clinical_history',
          'create_treatment',
          'validate_treatment',
          'validate_nutrition',
          'view_inventory',
          'view_sos_cases',
          'schedule_visits',
          'generate_reports',
          'use_emergency_chat',
          'view_reproduction',
        ],
      );
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    final links = provider.vetFarmLinks;
    final active = links.where((l) => l['status'] == 'accepted').toList();
    final chats = provider.clinicalCaseChats;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Veterinario')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (active.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      LucideIcons.stethoscope,
                      size: 44,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aún no tienes un veterinario autorizado.',
                      style: AppTextStyles.h3,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Invita uno para recibir seguimiento profesional desde la app.',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _invite(context),
                      icon: const Icon(LucideIcons.userPlus),
                      label: const Text('Invitar veterinario'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...active.map(
              (link) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Veterinario conectado',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 4),
                      Text('${link['vet_id']}', style: AppTextStyles.h3),
                      const SizedBox(height: 4),
                      const Text('Estado: Activo'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: chats.isEmpty
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ClinicalCaseChatScreen(
                                        chat: chats.first,
                                      ),
                                    ),
                                  ),
                            icon: const Icon(LucideIcons.messageCircle),
                            label: const Text('Abrir chat'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SosScreen(),
                              ),
                            ),
                            icon: const Icon(LucideIcons.shieldAlert),
                            label: const Text('Enviar SOS'),
                          ),
                          TextButton(
                            onPressed: () => provider.updateVetFarmLinkStatus(
                              link['id'] as String,
                              'revoked',
                            ),
                            child: const Text('Revocar acceso'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (links.any((l) => l['status'] == 'pending')) ...[
            const SizedBox(height: 16),
            Text('Solicitudes pendientes', style: AppTextStyles.h3),
            ...links
                .where((l) => l['status'] == 'pending')
                .map(
                  (l) => ListTile(
                    leading: const Icon(LucideIcons.clock3),
                    title: Text('${l['vet_id']}'),
                    subtitle: const Text('Esperando aceptación'),
                  ),
                ),
          ],
          if (chats.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Casos enviados', style: AppTextStyles.h3),
            ...chats.map(
              (chat) => ListTile(
                leading: const Icon(
                  LucideIcons.messagesSquare,
                  color: AppColors.primaryGreen,
                ),
                title: Text('Caso ${chat['case_id']}'),
                subtitle: Text('${chat['status']} · ${chat['priority']}'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClinicalCaseChatScreen(chat: chat),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'AURA Agro AI no reemplaza al médico veterinario. La evaluación clínica y las decisiones de tratamiento corresponden al profesional.',
            style: AppTextStyles.caption.copyWith(color: AppColors.alertOrange),
          ),
        ],
      ),
    );
  }
}
