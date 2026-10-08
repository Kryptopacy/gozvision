import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/clinic_theme.dart';
import 'data/clinic_scope.dart';
import 'screens/clinic_shell.dart';
import 'screens/login_screen.dart';
import 'services/bachs_payment_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/app.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const ClinicApp());
}

/// GozVision Clinic Suite (B2B) — the Low Vision Hub, Front Desk, Scribe,
/// and Insights for optometry practices. Multi-tenant by clinic_id
/// (docs/DATA_MODEL.md).
class ClinicApp extends StatelessWidget {
  const ClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GozVision Clinic',
      debugShowCheckedModeBanner: false,
      theme: ClinicTheme.theme,
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _Booting();
          }
          final user = snapshot.data?.session?.user;
          if (user == null) return const LoginScreen();
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ClinicScope()..resolve(user.id)),
              ChangeNotifierProvider(create: (_) => BachsPaymentService()),
            ],
            child: const ClinicShell(),
          );
        },
      ),
    );
  }
}

class _Booting extends StatelessWidget {
  const _Booting();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: ClinicTheme.malachite)),
    );
  }
}
