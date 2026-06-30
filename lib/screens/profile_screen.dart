import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/data_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'onboarding_screen.dart';
import '../services/supabase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _farmController;
  late TextEditingController _locationController;
  late TextEditingController _emailController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<DataProvider>(context, listen: false);
    final profile = provider.profile ?? {};
    final supabaseEmail = SupabaseService.instance.currentUser?.email;
    _nameController = TextEditingController(text: profile['owner_name'] ?? 'Eddy');
    _farmController = TextEditingController(text: profile['farm_name'] ?? 'Finca El Paraíso');
    _locationController = TextEditingController(text: profile['location'] ?? 'Loja, Ecuador');
    _emailController = TextEditingController(text: supabaseEmail ?? profile['email'] ?? 'usuario@auraagro.ai');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _farmController.dispose();
    _locationController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<DataProvider>(context, listen: false);
      await provider.updateProfile(
        ownerName: _nameController.text.trim(),
        farmName: _farmController.text.trim(),
        location: _locationController.text.trim(),
        email: _emailController.text.trim(),
      );
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Perfil actualizado correctamente',
              style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _handleLogout(BuildContext context, DataProvider provider) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('¿Cerrar sesión?', style: AppTextStyles.h2),
        content: Text(
          'Volverás a la pantalla de bienvenida y podrás configurar una nueva finca.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: AppTextStyles.bodyBold.copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Cerrar diálogo
              await provider.logout();

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(-1.0, 0.0); // Deslizar desde la izquierda al cerrar sesión
                      const end = Offset.zero;
                      const curve = Curves.easeOutCubic;
                      final slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                      final fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
                      return SlideTransition(
                        position: animation.drive(slideTween),
                        child: FadeTransition(
                          opacity: animation.drive(fadeTween),
                          child: child,
                        ),
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 500),
                  ),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Cerrar Sesión', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mi Perfil',
          style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isEditing ? LucideIcons.save : LucideIcons.userCheck,
              color: AppColors.primaryGreen,
            ),
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
          }

          final animals = provider.animals;
          final alertsCount = provider.alerts.length;
          
          // Calcular estadísticas
          final totalAnimals = animals.length;
          final avgWeight = totalAnimals > 0 
              ? animals.map((a) => a.weightKg).reduce((a, b) => a + b) / totalAnimals 
              : 0.0;
          final avgScore = totalAnimals > 0 
              ? (animals.map((a) => a.score).reduce((a, b) => a + b) / totalAnimals).round() 
              : 0;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Cabecera del perfil (Avatar e info rápida)
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGreen.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'U',
                          style: AppTextStyles.scoreNumber.copyWith(color: Colors.white, fontSize: 32),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _nameController.text,
                        style: AppTextStyles.h1,
                      ),
                      Text(
                        _farmController.text,
                        style: AppTextStyles.body.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: SupabaseService.instance.isAuthenticated
                              ? AppColors.primaryGreen.withOpacity(0.08)
                              : AppColors.textSecondary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: SupabaseService.instance.isAuthenticated
                                ? AppColors.primaryGreen.withOpacity(0.2)
                                : AppColors.textSecondary.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              SupabaseService.instance.isAuthenticated
                                  ? LucideIcons.cloudCheck
                                  : LucideIcons.database,
                              size: 12,
                              color: SupabaseService.instance.isAuthenticated
                                  ? AppColors.primaryGreen
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              SupabaseService.instance.isAuthenticated
                                  ? 'Sincronizado con la Nube'
                                  : 'Modo Local - Sin Cuenta',
                              style: AppTextStyles.caption.copyWith(
                                color: SupabaseService.instance.isAuthenticated
                                    ? AppColors.primaryGreen
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Formulario de datos
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Datos de la Finca', style: AppTextStyles.h3),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _nameController,
                        label: 'Nombre del Propietario',
                        icon: LucideIcons.user,
                        enabled: _isEditing,
                        validator: (value) => value == null || value.trim().isEmpty ? 'Ingrese un nombre' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _farmController,
                        label: 'Nombre de la Finca',
                        icon: LucideIcons.leaf,
                        enabled: _isEditing,
                        validator: (value) => value == null || value.trim().isEmpty ? 'Ingrese el nombre de la finca' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _locationController,
                        label: 'Ubicación',
                        icon: LucideIcons.mapPin,
                        enabled: _isEditing,
                        validator: (value) => value == null || value.trim().isEmpty ? 'Ingrese la ubicación' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Correo Electrónico',
                        icon: LucideIcons.mail,
                        enabled: _isEditing,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Ingrese un correo';
                          if (!value.contains('@')) return 'Ingrese un correo válido';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Grid de estadísticas calculadas dinámicamente
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estadísticas del Hato (Real)', style: AppTextStyles.h3),
                      const SizedBox(height: 16),
                      GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.8,
                        ),
                        children: [
                          _buildStatCard('Ganado', '$totalAnimals', LucideIcons.beef, AppColors.primaryGreen),
                          _buildStatCard('Alertas', '$alertsCount', LucideIcons.alertTriangle, AppColors.alertOrange),
                          _buildStatCard('Peso Prom.', '${avgWeight.toStringAsFixed(0)} kg', LucideIcons.scale, AppColors.earthBrown),
                          _buildStatCard('Score Prom.', '$avgScore%', LucideIcons.heartPulse, AppColors.primaryGreenDark),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                if (_isEditing)
                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text('Guardar Cambios', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _handleLogout(context, provider),
                      icon: const Icon(LucideIcons.logOut, color: AppColors.alertRed, size: 20),
                      label: Text(
                        'Cerrar Sesión',
                        style: AppTextStyles.bodyBold.copyWith(color: AppColors.alertRed),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.alertRed, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: AppTextStyles.bodyBold.copyWith(
        color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, size: 20, color: enabled ? AppColors.primaryGreen : AppColors.textSecondary),
        disabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryGreen, width: 2)),
        filled: !enabled,
        fillColor: Colors.transparent,
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
