import 'package:copilot_core/copilot_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/system_prompt.dart';
import 'core/theme.dart';
import 'screens/caregiver_dashboard.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/transcripts_screen.dart';
import 'services/app_haptics.dart';
import 'services/audio_service.dart';
import 'services/barcode_service.dart';
import 'services/camera_service.dart';
import 'services/clinical_telemetry_service.dart';
import 'services/light_meter_service.dart';
import 'services/ocr_service.dart';
import 'services/platform_monitor.dart';
import 'services/product_lookup_service.dart';
import 'services/screen_capture_service.dart';
import 'services/sos_service.dart';
import 'services/user_identity_service.dart';
import 'services/user_memory_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment configuration FIRST (assets/app.env — see README).
  await dotenv.load(fileName: 'assets/app.env');

  // Supabase: auth + Postgres (ADR-0003).
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  // Validate configuration
  if (!AppConfig.isConfigured) {
    debugPrint('ERROR: Missing GEMINI_API_KEY in .env file');
  }

  // Zero-UI demo flow: establish the demo patient session (no-op when real
  // credentials are absent) before anything reads the identity.
  final identity = UserIdentityService();
  await identity.ensureSignedIn();

  runApp(GozVisionApp(identity: identity));
}

/// GozVision — Premium Navigation Router
final GoRouter _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final user = Supabase.instance.client.auth.currentUser;
    final isGoingToProtected = state.matchedLocation == '/caregiver';

    // If unauthenticated and trying to access pro dashboards, route to login wall
    if (user == null && isGoingToProtected) {
      return '/login';
    }

    return null; // Return null to proceed
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/caregiver',
      builder: (context, state) => CaregiverDashboard(patientUid: AppConfig.patientId),
    ),
    GoRoute(
      path: '/transcripts',
      builder: (context, state) => const TranscriptsScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const PatientProfileScreen(),
    ),
  ],
);

/// GozVision — Goz, the AI Accessibility Copilot for Low-Vision Patients
class GozVisionApp extends StatelessWidget {
  const GozVisionApp({super.key, required this.identity});

  /// One identity instance for the whole app — the Gemini session's backend
  /// calls and every store write resolve through it.
  final UserIdentityService identity;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileService()),
        ChangeNotifierProvider(create: (_) => GeminiLiveService(
          config: SessionConfig(
            geminiLiveWsUrl: AppConfig.geminiLiveWsUrl,
            geminiModel: AppConfig.geminiModel,
            audioInputSampleRate: AppConfig.audioInputSampleRate,
            demoPatientId: AppConfig.patientId,
            adkBackendUrl: AppConfig.adkBackendUrl,
            adkAgentName: AppConfig.adkAgentName,
          ),
          identity: identity,
          buildSystemPrompt: GozAISystemPrompt.build,
        )),
        ChangeNotifierProvider(create: (_) => CameraService()),
        ChangeNotifierProvider(create: (_) => AudioService()),
        ChangeNotifierProvider(create: (_) => OcrService()),
        ChangeNotifierProvider(create: (_) => LightMeterService()),
        ChangeNotifierProvider(create: (_) => ScreenCaptureService()),
        ChangeNotifierProvider(create: (_) => ClinicalTelemetryService()),
        ChangeNotifierProvider(create: (_) => UserMemoryService()),
        ChangeNotifierProvider.value(value: identity),
        Provider(create: (_) => SosService()),
        Provider(create: (_) => BarcodeService()),
        Provider(create: (_) => ProductLookupService()),
        Provider(create: (_) => const AppHaptics()),
        // The Copilot Loop's brain — wired from the services above.
        Provider(
          create: (context) => SessionCoordinator(
            gemini: context.read<GeminiLiveService>(),
            camera: context.read<CameraService>(),
            audio: context.read<AudioService>(),
            ocr: context.read<OcrService>(),
            screenCapture: context.read<ScreenCaptureService>(),
            lightMeter: context.read<LightMeterService>(),
            telemetry: context.read<ClinicalTelemetryService>(),
            memory: context.read<UserMemoryService>(),
            sos: context.read<SosService>(),
            barcode: context.read<BarcodeService>(),
            productLookup: context.read<ProductLookupService>(),
            identity: context.read<UserIdentityService>(),
            haptics: context.read<AppHaptics>(),
            platformMonitor: PlatformMonitor(),
          ),
        ),
      ],
      child: Consumer<ScreenCaptureService>(
        builder: (context, screenCapture, child) {
          return MaterialApp.router(
            title: 'GozVision',
            debugShowCheckedModeBanner: false,
            theme: GozAITheme.darkTheme,
            routerConfig: _router,

            // Accessibility configuration
            builder: (context, routerChild) {
              final content = MediaQuery(
                // Enforce minimum text scaling for accessibility
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    MediaQuery.of(context).textScaler.scale(1.0).clamp(1.0, 2.0),
                  ),
                ),
                child: routerChild!,
              );

              // Wrap the entire app UI in the screen capture boundary
              return RepaintBoundary(
                key: screenCapture.globalKey,
                child: content,
              );
            },
          );
        },
      ),
    );
  }
}
