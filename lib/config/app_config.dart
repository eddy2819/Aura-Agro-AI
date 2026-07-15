class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'development');

  static void validate() {
    if (supabaseUrl.isEmpty) {
      throw Exception('SUPABASE_URL no está configurado.');
    }

    if (supabaseAnonKey.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY no está configurado.');
    }
  }

  static bool get isProduction => appEnv == 'production';
}