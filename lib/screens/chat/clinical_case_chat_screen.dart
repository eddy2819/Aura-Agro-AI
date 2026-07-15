import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/data_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/navigation/top_app_bar.dart';

class ClinicalCaseChatScreen extends StatefulWidget {
  final Map<String, dynamic> chat;
  const ClinicalCaseChatScreen({super.key, required this.chat});

  @override
  State<ClinicalCaseChatScreen> createState() => _ClinicalCaseChatScreenState();
}

class _ClinicalCaseChatScreenState extends State<ClinicalCaseChatScreen> {
  final _controller = TextEditingController();

  static const _quickReplies = {
    'Solicitar temperatura':
        'Por favor registre la temperatura del animal y envíela por este chat.',
    'Solicitar foto':
        'Por favor envíe una foto clara del animal para revisar la información disponible.',
    'Solicitar alimentación':
        'Por favor indique qué consumió el animal durante las últimas 24 horas.',
    'Programar visita':
        'Considero necesario programar una visita veterinaria para revisar el caso.',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _controller.text.trim();
    if (text.isEmpty) return;
    await context.read<DataProvider>().sendClinicalMessage(
      chatId: widget.chat['id'] as String,
      caseId: widget.chat['case_id']?.toString(),
      message: text,
    );
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    final messages = provider.clinicalCaseMessages
        .where((m) => m['chat_id'] == widget.chat['id'])
        .toList();
    final isVet = provider.profile?['role'] == 'Veterinario';
    final linked = provider.vetFarmLinks.any(
      (link) =>
          link['farmer_id'] == widget.chat['farmer_id'] &&
          link['vet_id'] == widget.chat['vet_id'] &&
          link['status'] == 'accepted',
    );

    return Scaffold(
      appBar: AuraPageAppBar(
        title: 'Caso ${widget.chat['priority']?.toString().toUpperCase()}',
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: AppColors.alertOrangeSurface,
            child: Text(
              'Este chat apoya la comunicación y seguimiento. AURA no reemplaza al veterinario. En emergencias graves, contacta directamente al profesional.',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isVet)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                children: _quickReplies.entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(entry.key),
                          onPressed: linked ? () => _send(entry.value) : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text('Aún no hay mensajes.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (_, index) {
                      final message = messages[index];
                      final aura = message['ai_generated'] == 1;
                      final ownRole = provider.profile?['role']?.toString();
                      final mine = message['sender_role'] == ownRole;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 330),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: aura
                                ? AppColors.greenSurface
                                : (mine
                                      ? AppColors.primaryGreen
                                      : AppColors.surface),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message['sender_role'] ?? 'Usuario',
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: mine && !aura
                                      ? Colors.white
                                      : AppColors.primaryGreenDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message['message'] ?? '',
                                style: AppTextStyles.body.copyWith(
                                  color: mine && !aura
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    message['sync_status'] == 'synced'
                                        ? LucideIcons.checkCheck
                                        : LucideIcons.clock3,
                                    size: 12,
                                    color: mine && !aura
                                        ? Colors.white70
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    message['sync_status'] == 'synced'
                                        ? 'Sincronizado'
                                        : 'Pendiente',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 10,
                                      color: mine && !aura
                                          ? Colors.white70
                                          : AppColors.textSecondary,
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
          ),
          if (!linked)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Acceso revocado: este chat está en modo solo lectura.',
              ),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: 3,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _send,
                      icon: const Icon(LucideIcons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
