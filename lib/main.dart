import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/data_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_colors.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/supabase_service.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.validate();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  
  // Cargar variables de entorno
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Advertencia: No se pudo cargar el archivo .env: $e");
  }

  // Inicializar Supabase (se maneja fallback a offline internamente)
  await SupabaseService.instance.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => DataProvider(),
      child: const AuraAgroApp(),
    ),
  );
}

class AuraAgroApp extends StatelessWidget {
  const AuraAgroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          );
        }

        return MaterialApp(
          title: 'AURA Agro AI',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          home: provider.isOnboardingCompleted
              ? const MainNavigationScreen()
              : const OnboardingScreen(),
        );
      },
    );
  }
}
