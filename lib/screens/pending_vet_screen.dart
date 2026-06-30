import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/data_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/sync_service.dart';
import 'onboarding_screen.dart';

class PendingVetScreen extends StatefulWidget {
  const PendingVetScreen({super.key});

  @override
  State<PendingVetScreen> createState() => _PendingVetScreenState();
}

class _PendingVetScreenState extends State<PendingVetScreen> {
  bool _isChecking = false;

  Future<void> _checkStatus(BuildContext context, DataProvider provider) async {
    setState(() => _isChecking = true);
    
    try {
      // Forzar una sincronización para bajar el estado actualizado del perfil
      await SyncService.instance.sync();
      await provider.loadData();
      
      if (context.mounted) {
        final currentProfile = provider.profile;
        final status = currentProfile?['status'] ?? 'pending';
        
        if (status == 'active') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Tu cuenta ha sido aprobada! Cargando panel...', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
              backgroundColor: AppColors.primaryGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tu solicitud sigue en revisión por el administrador.', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
              backgroundColor: AppColors.alertOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al conectar con el servidor: $e', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
            backgroundColor: AppColors.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DataProvider>(context);
    final profile = provider.profile ?? {};
    final name = profile['owner_name'] ?? 'Veterinario';
    final license = profile['license_number'] ?? 'No registrada';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Icono animado/destacado de revisión
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryGreen.withOpacity(0.15), width: 2),
                ),
                child: const Icon(
                  LucideIcons.stethoscope,
                  color: AppColors.primaryGreen,
                  size: 64,
                ),
              ),
              const SizedBox(height: 32),
              
              // Estado visual de pendiente
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.alertOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.alertOrange.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.clock, size: 14, color: AppColors.alertOrange),
                    const SizedBox(width: 6),
                    Text(
                      'SOLICITUD EN REVISIÓN',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.alertOrange,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Hola, Dr. $name',
                style: AppTextStyles.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Hemos recibido tu solicitud para unirte a AURA. Para evitar perfiles falsos y garantizar la seguridad sanitaria, nuestro equipo está validando tu licencia profesional:',
                style: AppTextStyles.body.copyWith(height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Tarjeta con Cédula/Licencia
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      'Licencia / Cédula Profesional',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      license,
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 16, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Botón para verificar estado
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : () => _checkStatus(context, provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isChecking
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.refreshCw, size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Revisar Estado',
                              style: AppTextStyles.bodyBold.copyWith(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                ),
              ),
              const Spacer(),

              // Botón para Cerrar Sesión
              TextButton.icon(
                onPressed: () async {
                  await provider.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(LucideIcons.logOut, size: 18, color: AppColors.alertRed),
                label: Text(
                  'Cerrar Sesión',
                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.alertRed),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
