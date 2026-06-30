import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/data_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'onboarding_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshPendingList();
  }

  Future<void> _refreshPendingList() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<DataProvider>(context, listen: false);
      await provider.loadPendingVeterinarians();
    } catch (e) {
      debugPrint("Error loading pending vets: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleApprove(String userId, String name) async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<DataProvider>(context, listen: false);
      await provider.approveVeterinarian(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dr. $name aprobado con éxito.', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aprobar: $e', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
            backgroundColor: AppColors.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleReject(String userId, String name) async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<DataProvider>(context, listen: false);
      await provider.rejectVeterinarian(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Solicitud de Dr. $name rechazada.', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
            backgroundColor: AppColors.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al rechazar: $e', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
            backgroundColor: AppColors.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DataProvider>(context);
    final pendingVets = provider.pendingVeterinarians;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Panel de Administración', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.logOut, color: AppColors.alertRed),
            onPressed: () async {
              await provider.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPendingList,
        color: AppColors.primaryGreen,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Banner de Bienvenida Admin
            Text('¡Bienvenido, Administrador!', style: AppTextStyles.h1),
            const SizedBox(height: 4),
            Text('Gestiona los accesos y valida solicitudes de veterinarios.', style: AppTextStyles.body),
            const SizedBox(height: 24),

            // Métricas Rápidas
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Vets Pendientes',
                    value: '${pendingVets.length}',
                    icon: LucideIcons.clock,
                    color: AppColors.alertOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Ganaderos Totales',
                    value: '142', // Mockup representativo del sistema
                    icon: LucideIcons.beef,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text('Solicitudes Pendientes', style: AppTextStyles.h2),
            const SizedBox(height: 12),

            if (_isLoading && pendingVets.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: CircularProgressIndicator(color: AppColors.primaryGreen),
                ),
              )
            else if (pendingVets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 64),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.border.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.checkCircle2, color: AppColors.textSecondary, size: 36),
                    ),
                    const SizedBox(height: 16),
                    Text('Al día. No hay solicitudes pendientes.', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 4),
                    Text('Tira hacia abajo para actualizar.', style: AppTextStyles.caption),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pendingVets.length,
                itemBuilder: (context, index) {
                  final vet = pendingVets[index];
                  final name = vet['owner_name'] ?? 'Veterinario';
                  final email = vet['email'] ?? 'Sin correo';
                  final license = vet['license_number'] ?? 'Sin cédula';
                  final userId = vet['user_id'] as String;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(LucideIcons.stethoscope, color: AppColors.primaryGreen, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Dr. $name', style: AppTextStyles.h3),
                                  Text(email, style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Registro / Cédula', style: AppTextStyles.caption.copyWith(fontSize: 10)),
                                Text(license, style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
                              ],
                            ),
                            Row(
                              children: [
                                // Botón Rechazar
                                TextButton.icon(
                                  onPressed: _isLoading ? null : () => _handleReject(userId, name),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.alertRed,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  icon: const Icon(LucideIcons.x, size: 16),
                                  label: Text('Rechazar', style: AppTextStyles.bodyBold.copyWith(color: AppColors.alertRed, fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                // Botón Aprobar
                                ElevatedButton.icon(
                                  onPressed: _isLoading ? null : () => _handleApprove(userId, name),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(LucideIcons.check, size: 16, color: Colors.white),
                                  label: Text('Aprobar', style: AppTextStyles.bodyBold.copyWith(color: Colors.white, fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.h1.copyWith(fontSize: 22, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
