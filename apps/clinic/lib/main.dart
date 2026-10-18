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
/// and Insights for optometry practices. Multi-tenant by clinic_id.
class ClinicApp extends StatefulWidget {
  const ClinicApp({super.key});

  @override
  State<ClinicApp> createState() => _ClinicAppState();
}

class _ClinicAppState extends State<ClinicApp> {
  final _scope = ClinicScope();

  @override
  void initState() {
    super.initState();
    // Detect evaluator sandbox entry via query parameter (?demo=true) or fragment (#demo / #sandbox)
    final uri = Uri.base;
    final isDemoRequested = uri.queryParameters['demo'] == 'true' ||
        uri.fragment.contains('demo') ||
        uri.fragment.contains('sandbox');
    if (isDemoRequested) {
      _scope.enterDemoMode(DemoPersona.doctor);
    }
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ClinicScope>.value(value: _scope),
        ChangeNotifierProvider(create: (_) => BachsPaymentService()),
      ],
      child: Consumer<ClinicScope>(
        builder: (context, scope, _) {
          return MaterialApp(
            title: 'GozVision Clinic',
            debugShowCheckedModeBanner: false,
            theme: ClinicTheme.theme,
            home: scope.isDemoMode
                ? const ClinicShell()
                : StreamBuilder<AuthState>(
                    stream: Supabase.instance.client.auth.onAuthStateChange,
                    builder: (context, snapshot) {
                      final currentAuthUser = Supabase.instance.client.auth.currentUser;
                      if (!snapshot.hasData && currentAuthUser == null) {
                        return const _Booting();
                      }
                      final user = snapshot.data?.session?.user ?? currentAuthUser;
                      if (user == null) {
                        return const LoginScreen();
                      }
                      if (!scope.resolved) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!scope.resolved) {
                            scope.resolve(user.id);
                          }
                        });
                      }
                      return const ClinicShell();
                    },
                  ),
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
