import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/data_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'main_navigation_screen.dart';
import '../services/supabase_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  // Step 3 (Role) State
  String? _selectedRole;
  bool _isVetRequestMode = false;

  // Step 4 (Farm info) State
  final _nameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _farmController = TextEditingController();
  final _locationController = TextEditingController();
  final _animalsController = TextEditingController();

  // Supabase Auth State
  String _authMode = SupabaseService.instance.isEnabled ? 'login' : 'local';
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isAuthLoading = false;
  String? _authError;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<DataProvider>(context, listen: false);
    _currentPage = provider.isOnboardingShown ? 3 : 0;
    _pageController = PageController(initialPage: _currentPage);
    _selectedRole = 'Ganadero';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _farmController.dispose();
    _locationController.dispose();
    _animalsController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipToFarmConfig() {
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishOnboarding(DataProvider provider) async {
    final name = _nameController.text.trim();
    final isComprador = _selectedRole == 'Comprador';
    final farm = _isVetRequestMode 
        ? 'Consultorio Veterinario' 
        : (isComprador ? 'Mercado' : _farmController.text.trim());
    final location = _locationController.text.trim().isEmpty 
        ? 'Ecuador' 
        : _locationController.text.trim();
    final animalCount = (_isVetRequestMode || isComprador) ? 0 : int.tryParse(_animalsController.text.trim());
    final role = _selectedRole ?? 'Ganadero';
    final licenseNumber = _isVetRequestMode ? _licenseController.text.trim() : null;

    // Guardar en SQLite y SharedPreferences
    await provider.completeOnboarding(
      ownerName: name,
      farmName: farm,
      location: location,
      animalCount: animalCount,
      role: role,
      status: 'active', // Auto-aprobación local para pruebas
      licenseNumber: licenseNumber,
    );

    if (mounted) {
      // Transición personalizada: Desvanecimiento + Desplazamiento
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.1); // Desplazamiento leve hacia arriba
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
          transitionDuration: const Duration(milliseconds: 600),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _handleSupabaseAuth(DataProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isAuthLoading = true;
      _authError = null;
    });

    try {
      if (_authMode == 'login') {
        final email = _emailController.text.trim();
        final password = _passwordController.text;

        await provider.loginWithSupabase(email: email, password: password);
      } else if (_authMode == 'register') {
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        final name = _nameController.text.trim();
        final isComprador = _selectedRole == 'Comprador';
        final farm = _isVetRequestMode 
            ? 'Consultorio Veterinario' 
            : (isComprador ? 'Mercado' : _farmController.text.trim());
        final location = _locationController.text.trim().isEmpty ? 'Ecuador' : _locationController.text.trim();
        final animalCount = (_isVetRequestMode || isComprador) ? 0 : int.tryParse(_animalsController.text.trim());
        final role = _selectedRole ?? 'Ganadero';
        final licenseNumber = _isVetRequestMode ? _licenseController.text.trim() : null;
        final status = _isVetRequestMode ? 'pending' : 'active';

        await provider.registerWithSupabase(
          email: email,
          password: password,
          ownerName: name,
          farmName: farm,
          location: location,
          animalCount: animalCount,
          role: role,
          licenseNumber: licenseNumber,
          status: status,
        );
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 0.1);
              const end = Offset.zero;
              const curve = Curves.easeOutCubic;
              return SlideTransition(
                position: animation.drive(Tween(begin: begin, end: end).chain(CurveTween(curve: curve))),
                child: FadeTransition(
                  opacity: animation.drive(Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve))),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _authError = e.toString().replaceAll("Exception: ", "");
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAuthLoading = false;
        });
      }
    }
  }

  Widget _buildAuthModeButton(String mode, String label) {
    final isSelected = _authMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _authMode = mode;
            _authError = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.bodyBold.copyWith(
              color: isSelected ? Colors.white : const Color(0xFF5D5B56),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DataProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: _currentPage == 1 || _currentPage == 2, // No safe area en la portada ni en el login para extender el fondo
        bottom: true,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(), // Navegación controlada únicamente por botones
          onPageChanged: (page) {
            setState(() {
              _currentPage = page;
            });
            if (page == 3) {
              final provider = Provider.of<DataProvider>(context, listen: false);
              if (!provider.isOnboardingShown) {
                provider.setOnboardingShown(true);
              }
            }
          },
          children: [
            _buildWelcomePage(),
            _buildWhatWeDoPage(),
            _buildRoleSelectionPage(),
            _buildFarmConfigPage(provider),
          ],
        ),
      ),
    );
  }

  // --- CABECERA DE PROGRESO (PANTALLAS 2, 3, 4) ---
  Widget _buildHeader(int activeSegment, {bool showSkip = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: List.generate(2, (index) {
                final isActive = index <= activeSegment;
                return Expanded(
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primaryGreen : AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ),
          if (showSkip) ...[
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _skipToFarmConfig,
              child: Text(
                'Omitir',
                style: AppTextStyles.bodyBold.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ] else
            const SizedBox(width: 50), // Espaciador para centrar visualmente
        ],
      ),
    );
  }

  // ==========================================
  // PANTALLA 1 — BIENVENIDA
  // ==========================================
  Widget _buildWelcomePage() {
    return Stack(
      children: [
        // Fondo: gradiente verde
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primaryGreenDark, AppColors.primaryGreen],
            ),
          ),
        ),

        // Ilustración del campo ecuatoriano de fondo sutil
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.28,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: 0.15,
            child: Icon(
              LucideIcons.leaf,
              size: 280,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ),

        // Contenido superior y central
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Logo AURA
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.leaf, color: Colors.white, size: 42),
                  const SizedBox(width: 8),
                  Text(
                    'AURA',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Sub-logo
              Text(
                'Agro AI',
                style: GoogleFonts.poppins(
                  color: AppColors.primaryGreenLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 24),
              // Título
              Text(
                'Bienvenido a AURA',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // Subtítulo
              Text(
                'Tu finca inteligente empieza aquí.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 120), // Espacio para el panel inferior
            ],
          ),
        ),

        // Parte inferior (30% de la pantalla)
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.32,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 4),
                Text(
                  'La plataforma ganadera con IA diseñada para el campo ecuatoriano',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Comenzar',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      'Sin tarjeta de crédito · Funciona sin internet',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PANTALLA 2 — QUÉ HACE AURA
  // ==========================================
  Widget _buildWhatWeDoPage() {
    return Column(
      children: [
        _buildHeader(0, showSkip: true),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  '¿Qué puedes hacer con AURA?',
                  style: AppTextStyles.h1.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 24),

                // Lista de 3 cards horizontales
                Expanded(
                  child: ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildActionCard(
                        icon: LucideIcons.heartPulse,
                        title: 'Previene enfermedades',
                        description: 'La IA detecta señales de riesgo antes de que sean visibles.',
                      ),
                      const SizedBox(height: 14),
                      _buildActionCard(
                        icon: LucideIcons.sparkles,
                        title: 'Optimiza la alimentación',
                        description: 'Dietas calculadas con lo que ya tienes en tu finca.',
                      ),
                      const SizedBox(height: 14),
                      _buildActionCard(
                        icon: LucideIcons.store,
                        title: 'Vende directo y mejor',
                        description: 'Publica con historial certificado. Sin intermediarios.',
                      ),
                    ],
                  ),
                ),

                // Footer de botones
                Column(
                  children: [
                    TextButton(
                      onPressed: _previousPage,
                      child: Text(
                        '← Atrás',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Siguiente →',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenSurface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primaryGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.body.copyWith(fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PANTALLA 3 — SELECCIÓN DE ROL
  // ==========================================
  Widget _buildRoleSelectionPage() {
    final roles = [
      (
        key: 'Ganadero',
        icon: LucideIcons.beef,
        title: 'Ganadero / Productora',
        desc: 'Gestiono mi propio hato'
      ),
      (
        key: 'Comprador',
        icon: LucideIcons.shoppingBag,
        title: 'Comprador / Comercializador',
        desc: 'Busco comprar ganado y productos'
      ),
    ];

    final isRoleSelected = _selectedRole != null;

    return Column(
      children: [
        _buildHeader(1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  '¿Cómo usarás AURA?',
                  style: AppTextStyles.h1.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  'Selecciona un perfil para continuar.',
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 24),

                // Grid 2x2
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: roles.length,
                    itemBuilder: (context, index) {
                      final item = roles[index];
                      final isSelected = _selectedRole == item.key;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedRole = item.key;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.greenSurface : AppColors.surface,
                            border: Border.all(
                              color: isSelected ? AppColors.primaryGreen : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primaryGreen.withOpacity(0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : [],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                item.icon,
                                color: isSelected ? AppColors.primaryGreenDark : AppColors.textSecondary,
                                size: 28,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                item.title,
                                style: AppTextStyles.bodyBold.copyWith(
                                  color: isSelected ? AppColors.primaryGreenDark : AppColors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.desc,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 10,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Footer de botones
                Column(
                  children: [
                    TextButton(
                      onPressed: _previousPage,
                      child: Text(
                        '← Atrás',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isRoleSelected ? _nextPage : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRoleSelected 
                              ? AppColors.primaryGreen 
                              : AppColors.border,
                          disabledBackgroundColor: AppColors.border,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Siguiente →',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: isRoleSelected ? Colors.white : AppColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PANTALLA 4 — CONFIGURACIÓN DE FINCA
  // ==========================================
  Widget _buildFarmConfigPage(DataProvider provider) {
    final isSupabaseEnabled = SupabaseService.instance.isEnabled;
    final double headerHeight = 220.0 + MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // Dark green header background at the top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: headerHeight,
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.primaryGreenDark, AppColors.primaryGreen],
                  ),
                ),
              ),
              // Waves / decorative circles
              Positioned(
                top: -50,
                right: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2E6545).withOpacity(0.12),
                  ),
                ),
              ),
              Positioned(
                bottom: -60,
                left: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2E6545).withOpacity(0.08),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back Button
                          GestureDetector(
                            onTap: () {
                              if (_isVetRequestMode) {
                                setState(() {
                                  _isVetRequestMode = false;
                                  _selectedRole = 'Ganadero';
                                  _authMode = 'login';
                                });
                              } else {
                                _previousPage();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.15),
                              ),
                              child: const Icon(
                                LucideIcons.arrowLeft,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          // Ver Demo Button
                          if (provider.isOnboardingShown)
                            GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  0,
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.white.withOpacity(0.15),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.playCircle,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Ver demo',
                                      style: AppTextStyles.bodyBold.copyWith(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E6545),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              LucideIcons.leaf,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AURA',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                'AGRO AI',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF7CB88F),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tu finca, organizada por inteligencia artificial.',
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Scrollable white card body overlaps the header
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(top: headerHeight - 24),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Auth selector capsule (login, register, local)
                      if (isSupabaseEnabled) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F3ED),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              _buildAuthModeButton('login', 'Iniciar sesión'),
                              _buildAuthModeButton('register', 'Registrarse'),
                              _buildAuthModeButton('local', 'Modo local'),
                            ],
                          ),
                        ),
                      ],

                      // Auth error banner
                      if (_authError != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.alertRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.alertRed.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.alertCircle, color: AppColors.alertRed, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _authError!,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.alertRed,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // --- FORMULARIO DE INICIO DE SESIÓN ---
                      if (_authMode == 'login') ...[
                        _buildInputField(
                          controller: _emailController,
                          label: 'Correo electrónico',
                          placeholder: 'usuario@auraagro.ai',
                          inputType: TextInputType.emailAddress,
                          isRequired: true,
                          prefixIcon: LucideIcons.mail,
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contraseña',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: AppTextStyles.bodyBold,
                              decoration: InputDecoration(
                                hintText: 'Mínimo 6 caracteres',
                                hintStyle: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary.withOpacity(0.4),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: const Icon(LucideIcons.lock, color: Color(0xFF5D5B56), size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFE6E4DF)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.alertRed),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.alertRed, width: 2),
                                ),
                              ),
                              validator: (value) => value == null || value.trim().length < 6
                                  ? 'La contraseña debe tener al menos 6 caracteres'
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              // Opcional: mostrar diálogo de recuperar contraseña
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              '¿Olvidaste tu contraseña?',
                              style: AppTextStyles.bodyBold.copyWith(
                                color: AppColors.primaryGreen,
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ]

                      // --- FORMULARIO DE REGISTRO ---
                      else if (_authMode == 'register') ...[
                        _buildInputField(
                          controller: _emailController,
                          label: 'Correo electrónico',
                          placeholder: _isVetRequestMode ? 'veterinario@auraagro.ai' : 'usuario@auraagro.ai',
                          inputType: TextInputType.emailAddress,
                          isRequired: true,
                          prefixIcon: LucideIcons.mail,
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contraseña',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: AppTextStyles.bodyBold,
                              decoration: InputDecoration(
                                hintText: 'Mínimo 6 caracteres',
                                hintStyle: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary.withOpacity(0.4),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: const Icon(LucideIcons.lock, color: Color(0xFF5D5B56), size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFE6E4DF)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.alertRed),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.alertRed, width: 2),
                                ),
                              ),
                              validator: (value) => value == null || value.trim().length < 6
                                  ? 'La contraseña debe tener al menos 6 caracteres'
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _nameController,
                          label: _isVetRequestMode ? 'Nombre completo' : '¿Cómo te llamamos?',
                          placeholder: _isVetRequestMode ? 'Ej: Dr. Fernando Quizhpe' : 'Ej: Rosa, Juan, Dr. Quizhpe',
                          capitalization: TextCapitalization.words,
                          isRequired: true,
                          prefixIcon: LucideIcons.user,
                        ),
                        const SizedBox(height: 16),
                        if (!_isVetRequestMode) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rol de usuario',
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _selectedRole == 'Veterinario' ? 'Ganadero' : (_selectedRole ?? 'Ganadero'),
                                style: AppTextStyles.bodyBold,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(LucideIcons.users, color: Color(0xFF5D5B56), size: 20),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE6E4DF)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Ganadero', child: Text('Ganadero')),
                                  DropdownMenuItem(value: 'Comprador', child: Text('Comprador')),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedRole = val;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_isVetRequestMode) ...[
                          _buildInputField(
                            controller: _licenseController,
                            label: 'Cédula o Licencia Profesional',
                            placeholder: 'Ej: REG-VET-45920',
                            isRequired: true,
                            prefixIcon: LucideIcons.fileText,
                          ),
                        ] else if (_selectedRole != 'Comprador') ...[
                          _buildInputField(
                            controller: _farmController,
                            label: '¿Cómo se llama tu finca?',
                            placeholder: 'Ej: Finca El Paraíso',
                            capitalization: TextCapitalization.words,
                            isRequired: true,
                            prefixIcon: LucideIcons.warehouse,
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _locationController,
                          label: '¿Dónde está ubicada tu finca?',
                          placeholder: 'Ej: Taquil, Loja',
                          capitalization: TextCapitalization.words,
                          isRequired: false,
                          prefixIcon: LucideIcons.mapPin,
                        ),
                        if (!_isVetRequestMode && _selectedRole != 'Comprador') ...[
                          const SizedBox(height: 16),
                          _buildInputField(
                            controller: _animalsController,
                            label: '¿Cuántos animales tienes aprox.?',
                            placeholder: 'Ej: 15',
                            inputType: TextInputType.number,
                            isRequired: false,
                            prefixIcon: LucideIcons.binary,
                          ),
                        ],
                      ]

                      // --- MODO LOCAL ---
                      else ...[
                        _buildInputField(
                          controller: _nameController,
                          label: _isVetRequestMode ? 'Nombre completo' : '¿Cómo te llamamos?',
                          placeholder: _isVetRequestMode ? 'Ej: Dr. Fernando Quizhpe' : 'Ej: Rosa, Juan, Dr. Quizhpe',
                          capitalization: TextCapitalization.words,
                          isRequired: true,
                          prefixIcon: LucideIcons.user,
                        ),
                        const SizedBox(height: 16),
                        if (!_isVetRequestMode) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rol de usuario',
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _selectedRole == 'Veterinario' ? 'Ganadero' : (_selectedRole ?? 'Ganadero'),
                                style: AppTextStyles.bodyBold,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(LucideIcons.users, color: Color(0xFF5D5B56), size: 20),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE6E4DF)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Ganadero', child: Text('Ganadero')),
                                  DropdownMenuItem(value: 'Comprador', child: Text('Comprador')),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedRole = val;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_isVetRequestMode) ...[
                          _buildInputField(
                            controller: _licenseController,
                            label: 'Cédula o Licencia Profesional',
                            placeholder: 'Ej: REG-VET-45920',
                            isRequired: true,
                            prefixIcon: LucideIcons.fileText,
                          ),
                        ] else if (_selectedRole != 'Comprador') ...[
                          _buildInputField(
                            controller: _farmController,
                            label: '¿Cómo se llama tu finca?',
                            placeholder: 'Ej: Finca El Paraíso',
                            capitalization: TextCapitalization.words,
                            isRequired: true,
                            prefixIcon: LucideIcons.warehouse,
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _locationController,
                          label: '¿Dónde está ubicada tu finca?',
                          placeholder: 'Ej: Taquil, Loja',
                          capitalization: TextCapitalization.words,
                          isRequired: false,
                          prefixIcon: LucideIcons.mapPin,
                        ),
                        if (!_isVetRequestMode && _selectedRole != 'Comprador') ...[
                          const SizedBox(height: 16),
                          _buildInputField(
                            controller: _animalsController,
                            label: '¿Cuántos animales tienes aprox.?',
                            placeholder: 'Ej: 15',
                            inputType: TextInputType.number,
                            isRequired: false,
                            prefixIcon: LucideIcons.binary,
                          ),
                        ],
                      ],

                      const SizedBox(height: 24),

                      // Sync / Local mode information banner
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.greenSurface,
                                AppColors.greenSurface.withOpacity(0.6),
                              ],
                            ),
                            border: Border.all(
                              color: AppColors.primaryGreen.withOpacity(0.12),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: -15,
                                bottom: -20,
                                child: Transform.rotate(
                                  angle: 0.35,
                                  child: Icon(
                                    LucideIcons.leaf,
                                    size: 90,
                                    color: AppColors.primaryGreen.withOpacity(0.06),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Icon(
                                      _authMode == 'local' ? LucideIcons.wifiOff : LucideIcons.cloud,
                                      color: AppColors.primaryGreenDark,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _authMode == 'local'
                                            ? 'Tus datos se guardan en tu celular. Funcionan sin internet.'
                                            : 'Tus datos se sincronizan con Supabase y quedan disponibles sin conexión.',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.primaryGreenDark,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const Divider(color: Color(0xFFE6E4DF), height: 48),

                      // Large dark green action button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isAuthLoading
                              ? null
                              : () {
                                  if (_authMode == 'local') {
                                    _finishOnboarding(provider);
                                  } else {
                                    _handleSupabaseAuth(provider);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            disabledBackgroundColor: AppColors.border,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isAuthLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _authMode == 'login'
                                          ? 'Iniciar sesión'
                                          : _authMode == 'register'
                                              ? 'Crear cuenta y empezar'
                                              : 'Empezar a usar AURA',
                                      style: AppTextStyles.bodyBold.copyWith(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      LucideIcons.arrowRight,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      if (_authMode == 'login') ...[
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedRole = 'Veterinario';
                                _isVetRequestMode = true;
                                _authMode = 'register';
                              });
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.stethoscope,
                                  color: AppColors.primaryGreen,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                RichText(
                                  text: TextSpan(
                                    style: AppTextStyles.body.copyWith(fontSize: 12),
                                    children: const [
                                      TextSpan(
                                        text: '¿Eres veterinario? ',
                                        style: TextStyle(color: Color(0xFF5D5B56)),
                                      ),
                                      TextSpan(
                                        text: 'Solicita tu cuenta',
                                        style: TextStyle(
                                          color: AppColors.primaryGreen,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType inputType = TextInputType.text,
    required bool isRequired,
    IconData? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(color: AppColors.alertRed, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: 56),
          child: TextFormField(
            controller: controller,
            textCapitalization: capitalization,
            keyboardType: inputType,
            style: AppTextStyles.bodyBold,
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary.withOpacity(0.4),
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: prefixIcon != null 
                  ? Icon(prefixIcon, color: const Color(0xFF5D5B56), size: 20) 
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE6E4DF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.alertRed),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.alertRed, width: 2),
              ),
            ),
            validator: isRequired
                ? (value) => value == null || value.trim().isEmpty 
                    ? 'Este campo es obligatorio' 
                    : null
                : null,
          ),
        ),
      ],
    );
  }
}
