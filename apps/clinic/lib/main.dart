import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/clinic_theme.dart';
import 'core/firebase_options.dart';
import 'data/clinic_scope.dart';
import 'screens/clinic_shell.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/app.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ClinicApp());
}

/// GozVision Clinic Suite (B2B) — the Low Vision Hub, Front Desk, Scribe,
/// and Insights for optometry practices. Multi-tenant by clinicId
/// (docs/DATA_MODEL.md).
class ClinicApp extends StatelessWidget {
  const ClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GozVision Clinic',
      debugShowCheckedModeBanner: false,
      theme: ClinicTheme.theme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _Booting();
          }
          final user = snapshot.data;
          if (user == null) return const LoginScreen();
          return ChangeNotifierProvider(
            create: (_) => ClinicScope()..resolve(user.uid),
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
