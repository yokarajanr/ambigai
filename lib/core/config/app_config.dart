/// Application configuration.
/// Replace placeholder values with your Supabase project credentials.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zcfoeralaoubjpxkyrry.supabase.co'
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjZm9lcmFsYW91YmpweGt5cnJ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkwODM0MDMsImV4cCI6MjA4NDY1OTQwM30.9dk5yZiPbUu8KTbLr_AUaAKyiicbTwMgR3dF12n_heE'
  );
}
