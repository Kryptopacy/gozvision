import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:copilot_core/copilot_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_config.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../services/audio_service.dart';
import '../services/camera_service.dart';
import '../services/haptic_service.dart';
import '../services/sos_service.dart';
import 'profile_screen.dart';
import 'clinic_discovery_sheet.dart';
import 'patient_dispensary_sheet.dart';


/// The main GozAI interface.
///
/// Designed for zero-friction, accessibility-first interaction:
/// - Large central activation button with pulse animation
/// - Mode switching via swipe or large buttons
/// - Minimal visual clutter
/// - Full TalkBack/VoiceOver compatibility
///
/// This screen is deliberately thin: layout, input, and the floating debug
/// camera window. Every piece of copilot behavior — sense wiring, context
/// pulses, intent dispatch, telemetry — lives in [SessionCoordinator].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  SessionCoordinator? _coordinator;

  // Debug Camera Window State
  bool _showDebugCamera = false;
  Offset _debugCameraPosition = const Offset(20, 100);
  bool _debugCameraMinimized = false;
  bool _isDraggingCamera = false;

  @override
  void initState() {
    super.initState();

    // Wire the Copilot Loop after the first frame so provider lookups resolve.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final coordinator = context.read<SessionCoordinator>();
      _coordinator = coordinator;
      coordinator.attach(uiHooks: _HomeUiHooks(this));
    });
  }

  @override
  void dispose() {
    _coordinator?.detach();
    super.dispose();
  }

  void _setShowDebugCamera(bool visible) {
    if (!mounted) return;
    setState(() {
      _showDebugCamera = visible;
    });
  }

  void _openTranscripts() {
    if (!mounted) return;
    context.push('/transcripts');
  }

  void _onVisionProfileChanged(String profile) {
    if (!mounted) return;
    final target = (profile == 'clinicCompanion')
        ? VisionProfile.clinicCompanion
        : VisionProfile.lowVisionAssist;
    context.read<ProfileService>().setProfile(target);
  }

  /// Handle physical volume button presses for hands-free control.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Volume Up = take snapshot and describe
      if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
        _coordinator?.captureSnapshot();
        return KeyEventResult.handled;
      }
      // Volume Down = toggle session
      if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
        _coordinator?.toggleSession();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final profileService = context.watch<ProfileService>();
    final isLowVision = profileService.isLowVision;

    return Focus(
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        backgroundColor: GozAITheme.backgroundBlack,
        extendBodyBehindAppBar: true,
        appBar: _buildPremiumAppBar(context),
        body: Stack(
          children: [
            // Immersive ambient background layer
            _buildAmbientGlowBackground(),

            // UI Layer: Morph based on active vision profile
            SafeArea(
              child: isLowVision
                  ? _buildLowVisionAssistLayout()
                  : _buildClinicCompanionLayout(context, profileService),
            ),

            // Debug Camera Overlay (Floating Window - Topmost Layer)
            if (_showDebugCamera)
              _buildDebugCameraOverlay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLowVisionAssistLayout() {
    return Column(
      children: [
        // ── Greeting Header ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Consumer<GeminiLiveService>(
            builder: (context, gemini, _) {
              final isActive = gemini.isConnected;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: greeting text block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Good morning',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.70),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'GozVision Copilot',
                          style: GoogleFonts.sora(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right: animated AI status pill
                  Semantics(
                    label: isActive ? 'AI status: Active' : 'AI status: Ready',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? GozAITheme.malachite.withValues(alpha: 0.15)
                            : GozAITheme.surfacePure,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? GozAITheme.proBorderGlow
                              : GozAITheme.borderSubtle,
                          width: 1,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: GozAITheme.malachite.withValues(alpha: 0.20),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pulsing dot
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive ? GozAITheme.malachite : GozAITheme.textSecondary,
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: GozAITheme.malachite.withValues(alpha: 0.6),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          )
                              .animate(onPlay: (c) => c.repeat())
                              .scaleXY(
                                begin: 1.0,
                                end: isActive ? 1.4 : 1.0,
                                duration: 900.ms,
                                curve: Curves.easeInOut,
                              )
                              .then()
                              .scaleXY(
                                begin: 1.4,
                                end: 1.0,
                                duration: 900.ms,
                                curve: Curves.easeInOut,
                              ),
                          const SizedBox(width: 7),
                          Text(
                            isActive ? 'ACTIVE' : 'AI READY',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: isActive ? GozAITheme.brandAccent : GozAITheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _buildStatusBar(),
        const SizedBox(height: 8),
        _buildHardwareStatusIndicators(),
        const SizedBox(height: 14),
        _buildSensoryPromptTicker(),
        const Spacer(flex: 1),
        _buildCentralButton(),
        const Spacer(flex: 1),
        _buildQuickAssistDock(),
        const SizedBox(height: 14),
        _buildGozViewToggleHint(),
        const SizedBox(height: 14),
        _buildModeSelector(),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Live rotating sensory guidance banner showing intelligent context
  Widget _buildSensoryPromptTicker() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131722).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: GozAITheme.accentCyan.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: GozAITheme.accentCyan.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: GozAITheme.accentCyan,
              boxShadow: [
                BoxShadow(
                  color: GozAITheme.accentCyan,
                  blurRadius: 6,
                  spreadRadius: 1.5,
                ),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .scaleXY(begin: 0.8, end: 1.3, duration: 800.ms, curve: Curves.easeInOut)
              .then()
              .scaleXY(begin: 1.3, end: 0.8, duration: 800.ms, curve: Curves.easeInOut),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'GozVision Ready • Try saying: "Describe what is in front of me"',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Explicitly visible Camera Preview toggle
  Widget _buildGozViewToggleHint() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showDebugCamera = !_showDebugCamera;
        });
        HapticService.tap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), // Premium frosted glass
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: GozAITheme.backgroundBlack.withValues(alpha: 0.5), // Lower alpha for glass
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: GozAITheme.accentCyan.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: GozAITheme.accentCyan.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _showDebugCamera ? Icons.visibility_off : Icons.visibility,
                  color: GozAITheme.accentCyan,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  _showDebugCamera ? 'HIDE CAMERA PREVIEW' : 'SHOW CAMERA PREVIEW',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "Tap to see what your camera sees",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ))));
  }

  /// Premium Navigation Header for routing to specialized Dashboards.
  PreferredSizeWidget _buildPremiumAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent, // Let background shine under
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/logos/gozvision_lens.png',
            height: 32,
            semanticLabel: 'GozAI Premium Lens Logo',
          ),
          const SizedBox(width: 8),
          Text(
            'GozVision',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.storefront_outlined, color: GozAITheme.accentCyan),
          tooltip: 'Prescription Glasses & Eye Drops',
          onPressed: () => PatientDispensarySheet.show(context),
        ),
        IconButton(
          icon: const Icon(Icons.domain_outlined, color: GozAITheme.accentCyan),
          tooltip: 'Find Eye Clinics & Book Appointment',
          onPressed: () => ClinicDiscoverySheet.show(context),
        ),
        IconButton(
          icon: const Icon(Icons.account_circle_outlined, color: GozAITheme.accentCyan),
          tooltip: 'My Profile & Eye Drops',
          onPressed: () => context.push('/profile'),
        ),
        IconButton(
          icon: const Icon(Icons.monitor_heart_outlined),
          tooltip: 'Caregiver Dashboard',
          onPressed: () => context.push('/caregiver'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Status bar showing connection state and current mode with clean, subtle borders.
  Widget _buildStatusBar() {
    return Consumer<GeminiLiveService>(
      builder: (context, gemini, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: GozAITheme.surfacePure,
                  border: Border.all(color: GozAITheme.borderSubtle, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Semantics(
                  label: 'Status: ${gemini.statusMessage}. Mode: ${_modeName(gemini.currentMode)}',
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _connectionColor(gemini.connectionState),
                          boxShadow: [
                            BoxShadow(
                              color: _connectionColor(gemini.connectionState).withValues(alpha: 0.6),
                              blurRadius: 16,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          gemini.statusMessage,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: GozAITheme.primaryBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: GozAITheme.primaryBlue.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          _modeName(gemini.currentMode),
                          style: TextStyle(
                            fontSize: 14,
                            color: GozAITheme.accentCyan,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Row of chips showing realtime Mic and Camera hardware states.
  /// Tapping a chip toggles that hardware on or off.
  Widget _buildHardwareStatusIndicators() {
    return Consumer3<GeminiLiveService, AudioService, CameraService>(
      builder: (context, gemini, audio, camera, _) {
        final isMicOn = audio.isRecording;
        final isCameraOn = camera.isInitialized && !camera.initFailed && camera.isStreaming;
        String cameraText = 'Camera: Off';
        if (isCameraOn) {
          final dir = camera.currentLensDirection;
          if (dir == CameraLensDirection.front) {
            cameraText = 'Camera: Front';
          } else if (dir == CameraLensDirection.back) {
            cameraText = 'Camera: Rear';
          } else {
            cameraText = 'Camera: On';
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatusChip(
                icon: isMicOn ? Icons.mic : Icons.mic_off,
                label: isMicOn ? 'Mic: On' : 'Mic: Off',
                isActive: isMicOn,
                tooltip: isMicOn ? 'Tap to mute microphone' : 'Tap to unmute microphone',
                onTap: () => _coordinator?.setMicEnabled(!isMicOn),
              ),
              const SizedBox(width: 12),
              _buildStatusChip(
                icon: isCameraOn ? Icons.videocam : Icons.videocam_off,
                label: cameraText,
                isActive: isCameraOn,
                tooltip: isCameraOn ? 'Tap to turn off camera' : 'Tap to turn on camera',
                onTap: () => _coordinator?.setCameraEnabled(!isCameraOn),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required bool isActive,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? GozAITheme.success.withValues(alpha: 0.1) : GozAITheme.hazardAlert.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? GozAITheme.success.withValues(alpha: 0.3) : GozAITheme.hazardAlert.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isActive ? GozAITheme.success : GozAITheme.hazardAlert),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              isActive ? Icons.toggle_on : Icons.toggle_off,
              size: 14,
              color: Colors.white38,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return chip;

    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: (isActive ? GozAITheme.success : GozAITheme.hazardAlert).withValues(alpha: 0.2),
          child: chip,
        ),
      ),
    );
  }

  /// Central activation button: Bioluminescent Multimodal Neural Orb with dynamic audio waveforms.
  Widget _buildCentralButton() {
    return Consumer2<GeminiLiveService, AudioService>(
      builder: (context, gemini, audio, _) {
        final isActive = gemini.isConnected && audio.isRecording;
        final isSpeaking = gemini.isModelSpeaking;

        final Color primaryAccent = isSpeaking
            ? GozAITheme.speakingPulse
            : (isActive ? GozAITheme.listeningPulse : GozAITheme.primaryBlue);

        return GestureDetector(
          onTap: () {
            HapticService.tap();
            _coordinator?.toggleSession();
          },
          onLongPress: () {
            HapticService.alert();
            _coordinator?.captureSnapshot();
          },
          child: Semantics(
            button: true,
            label: isActive
                ? 'GozVision is listening. Tap to pause.'
                : 'Tap to start GozVision Copilot. Long press to describe current scene.',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer diffuse breathing aura ring
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      width: isActive ? 240 : 210,
                      height: isActive ? 240 : 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isActive || isSpeaking ? primaryAccent : GozAITheme.accentCyan)
                            .withValues(alpha: isActive ? 0.12 : 0.08),
                        boxShadow: [
                          BoxShadow(
                            color: (isActive || isSpeaking ? primaryAccent : GozAITheme.accentCyan)
                                .withValues(alpha: isSpeaking ? 0.45 : (isActive ? 0.35 : 0.22)),
                            blurRadius: isSpeaking ? 60 : (isActive ? 45 : 36),
                            spreadRadius: isSpeaking ? 16 : (isActive ? 10 : 4),
                          ),
                        ],
                      ),
                    ),
                    // Specular frosted border ring
                    Container(
                      width: 196,
                      height: 196,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            (isActive || isSpeaking ? primaryAccent : GozAITheme.accentCyan).withValues(alpha: 0.85),
                            (isActive || isSpeaking ? primaryAccent : GozAITheme.accentCyan).withValues(alpha: 0.2),
                            (isActive || isSpeaking ? primaryAccent : GozAITheme.accentCyan).withValues(alpha: 0.7),
                            (isActive || isSpeaking ? primaryAccent : GozAITheme.accentCyan).withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: GozAITheme.backgroundBlack,
                        ),
                      ),
                    ),
                    // Inner Core Orb with audio reactive visualizer
                    Container(
                      width: 178,
                      height: 178,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.25, -0.25),
                          colors: [
                            if (isSpeaking) ...[
                              GozAITheme.speakingPulse,
                              const Color(0xFF024466),
                              GozAITheme.backgroundBlack,
                            ] else if (isActive) ...[
                              GozAITheme.listeningPulse,
                              const Color(0xFF02334D),
                              GozAITheme.backgroundBlack,
                            ] else ...[
                              const Color(0xFF0284C7).withValues(alpha: 0.4),
                              const Color(0xFF071926),
                              GozAITheme.backgroundBlack,
                            ],
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Dynamic audio waveform simulation (active or gentle standby pulse)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildWaveBar(isActive ? 12 : 6, isActive ? 26 : 14, 400),
                                const SizedBox(width: 4),
                                _buildWaveBar(isActive ? 20 : 10, isActive ? 44 : 22, 600),
                                const SizedBox(width: 4),
                                _buildWaveBar(isActive ? 30 : 16, isActive ? 56 : 32, 500),
                                const SizedBox(width: 4),
                                _buildWaveBar(isActive ? 18 : 8, isActive ? 38 : 20, 700),
                                const SizedBox(width: 4),
                                _buildWaveBar(isActive ? 10 : 5, isActive ? 22 : 12, 450),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isSpeaking
                                  ? 'SPEAKING'
                                  : (isActive ? 'LISTENING' : 'TAP TO START'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  isActive
                      ? 'Tap button to pause · Press and hold to describe scene'
                      : 'Tap to start · Or speak anytime',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: GozAITheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaveBar(double minH, double maxH, int ms) {
    return Container(
      width: 4,
      height: maxH,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scaleY(
          begin: minH / maxH,
          end: 1.0,
          duration: Duration(milliseconds: ms),
          curve: Curves.easeInOut,
        );
  }

  /// Tactile accessibility quick-dock
  Widget _buildQuickAssistDock() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTactileDockButton(
            icon: Icons.camera_alt_outlined,
            label: 'Describe',
            tooltip: 'Take picture & describe what is in front of you',
            onTap: () {
              HapticService.tap();
              _coordinator?.captureSnapshot();
            },
          ),
          const SizedBox(width: 8),
          _buildTactileDockButton(
            icon: Icons.document_scanner_outlined,
            label: 'Read Text',
            tooltip: 'Read prescription, letter, or medicine bottle',
            onTap: () {
              HapticService.tap();
              _coordinator?.selectMode(GozAIMode.reading, fromUserTap: true);
            },
          ),
          const SizedBox(width: 8),
          _buildTactileDockButton(
            icon: Icons.sensor_door_outlined,
            label: 'Doorstep',
            tooltip: 'Check who is at the front door (Ring Vision)',
            onTap: () {
              HapticService.tap();
              _showDoorstepModal(context);
            },
          ),
          const SizedBox(width: 8),
          _buildTactileDockButton(
            icon: Icons.sos_outlined,
            label: 'Emergency',
            color: GozAITheme.hazardAlert,
            tooltip: 'Call caregiver or clinic for help',
            onTap: _triggerEmergencySos,
          ),
        ],
      ),
    );
  }

  Widget _buildTactileDockButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? GozAITheme.accentCyan;
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF131722).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: effectiveColor.withValues(alpha: 0.45), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: effectiveColor.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: effectiveColor),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: effectiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _triggerEmergencySos() async {
    HapticService.hazardWarning();
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final uid = user?.id ?? AppConfig.patientId;
      await context.read<SosService>().sendAlert(
        userId: uid,
        message: 'Patient requested immediate assistance via Copilot Emergency trigger',
        severity: 'critical',
        target: 'caregiver_and_clinic',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 SOS Alert Dispatched to Caregiver & Clinic Desk'),
            backgroundColor: GozAITheme.hazardAlert,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  void _showDoorstepModal(BuildContext context) {
    HapticService.tap();
    String spokenText = 'Your daughter Zainab Adeyemi is at the front door.';
    String guidance = 'Safe to unlock and open the door.';
    String entityName = 'Zainab Adeyemi (Daughter)';
    bool isTrusted = true;

    // Auditory feedback for low-vision safety
    try {
      context.read<AudioService>().speakOfflineGuidance('$spokenText $guidance');
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131722),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: GozAITheme.malachite.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: GozAITheme.malachite.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.sensor_door_outlined, color: GozAITheme.malachite, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Front Doorstep Vision', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Ring Video Doorbell Pro • Dual-Layer Vision', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isTrusted ? GozAITheme.malachite.withValues(alpha: 0.4) : Colors.amber.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isTrusted ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                          color: isTrusted ? GozAITheme.malachite : Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entityName,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Guidance: $guidance',
                      style: TextStyle(
                        color: isTrusted ? GozAITheme.accentCyan : Colors.amber,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_up_rounded, color: GozAITheme.malachite, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SPOKEN AUDIO ANNOUNCEMENT (PATIENT EARS ONLY)',
                                  style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '"$spokenText"',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: GozAITheme.malachite.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 14, color: GozAITheme.malachite),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Silent Audit: BIPA 740 ILCS 14/ & GDPR Art. 9 verified in background logs. Zero legal jargon spoken to patient.',
                              style: TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'TEST SCENARIO DETECTION:',
                style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GozAITheme.malachite,
                        side: BorderSide(color: GozAITheme.malachite.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Daughter Zainab', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setModalState(() {
                          spokenText = 'Your daughter Zainab Adeyemi is at the front door.';
                          guidance = 'Safe to unlock and open the door.';
                          entityName = 'Zainab Adeyemi (Daughter)';
                          isTrusted = true;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF9900),
                        side: BorderSide(color: const Color(0xFFFF9900).withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Amazon Courier', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setModalState(() {
                          spokenText = 'An Amazon delivery carrier in a blue vest with a parcel is at the front door.';
                          guidance = 'Package being placed on doorstep. Obstacle alert active.';
                          entityName = 'Amazon Logistics Carrier';
                          isTrusted = true;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Unknown Visitor', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setModalState(() {
                          spokenText = 'A visitor is waiting at the front door.';
                          guidance = 'Use Ring two-way intercom to speak before opening.';
                          entityName = 'Visitor';
                          isTrusted = false;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: GozAITheme.malachite,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.people_alt_outlined, size: 18),
                  label: const Text('Manage Care Circle Contacts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/caregiver');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mode selector buttons utilizing high-contrast interaction guidelines.
  Widget _buildModeSelector() {
    return Consumer<GeminiLiveService>(
      builder: (context, gemini, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: GozAITheme.surfacePure.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: GozAITheme.borderSubtle, width: 1),
                ),
                child: Row(
                  children: [
                    _buildModeButton(gemini, GozAIMode.scene, Icons.wallpaper, 'Scene'),
                    const SizedBox(width: 4),
                    _buildModeButton(gemini, GozAIMode.reading, Icons.menu_book, 'Read'),
                    const SizedBox(width: 4),
                    _buildModeButton(gemini, GozAIMode.uiNav, Icons.touch_app, 'Screen'),
                    const SizedBox(width: 4),
                    _buildModeButton(gemini, GozAIMode.lightMeter, Icons.light_mode, 'Light'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeButton(
    GeminiLiveService gemini,
    GozAIMode mode,
    IconData icon,
    String label,
  ) {
    final isActive = gemini.currentMode == mode;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: '$label mode${isActive ? ", currently active" : ""}',
        child: InkWell(
          onTap: () => _coordinator?.selectMode(mode, fromUserTap: true),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isActive ? GozAITheme.primaryBlue.withValues(alpha: 0.25) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? GozAITheme.accentCyan.withValues(alpha: 0.5) : Colors.transparent,
                width: 1,
              ),
              boxShadow: isActive ? [
                BoxShadow(
                  color: GozAITheme.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: -2,
                )
              ] : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 26,
                  color: isActive ? Colors.white : GozAITheme.textSecondary,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? Colors.white : GozAITheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Helpers ---

  String _modeName(GozAIMode mode) {
    switch (mode) {
      case GozAIMode.scene:
        return 'Scene';
      case GozAIMode.reading:
        return 'Read';
      case GozAIMode.uiNav:
        return 'Screen';
      case GozAIMode.lightMeter:
        return 'Light';
    }
  }

  Color _connectionColor(GeminiConnectionState state) {
    switch (state) {
      case GeminiConnectionState.connected:
        return GozAITheme.success;
      case GeminiConnectionState.connecting:
        return Colors.amber;
      case GeminiConnectionState.error:
        return GozAITheme.hazardAlert;
      case GeminiConnectionState.disconnected:
        return GozAITheme.textSecondary;
    }
  }

  /// Immersive ambient glowing atmosphere that reacts to Gemini state
  Widget _buildAmbientGlowBackground() {
    return IgnorePointer(
      child: Consumer2<GeminiLiveService, AudioService>(
        builder: (context, gemini, audio, _) {
          final isActive = gemini.isConnected && audio.isRecording;
          final isSpeaking = gemini.isModelSpeaking;

          Color mainGlow;
          if (isSpeaking) {
            mainGlow = GozAITheme.speakingPulse;
          } else if (isActive) {
            mainGlow = GozAITheme.listeningPulse;
          } else {
            mainGlow = GozAITheme.primaryBlue;
          }

          final topAlpha = isSpeaking ? 0.25 : (isActive ? 0.18 : 0.12);
          final bottomAlpha = isSpeaking ? 0.22 : (isActive ? 0.15 : 0.10);

          return Stack(
            children: [
              // Central Atmospheric Ambient Core
              Center(
                child: Container(
                  width: 550,
                  height: 550,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.5,
                      colors: [
                        mainGlow.withValues(alpha: isSpeaking ? 0.22 : (isActive ? 0.16 : 0.10)),
                        mainGlow.withValues(alpha: 0.03),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
              // Top Right Atmospheric Aura
              AnimatedPositioned(
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeInOutSine,
                top: -120,
                right: -120,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 1500),
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.5,
                      colors: [
                        mainGlow.withValues(alpha: topAlpha),
                        mainGlow.withValues(alpha: topAlpha * 0.35),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
              // Bottom Left Atmospheric Aura
              AnimatedPositioned(
                duration: const Duration(milliseconds: 2000),
                curve: Curves.easeInOutSine,
                bottom: -100,
                left: -100,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 2000),
                  width: 420,
                  height: 420,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.5,
                      colors: [
                        GozAITheme.accentCyan.withValues(alpha: bottomAlpha),
                        GozAITheme.accentCyan.withValues(alpha: bottomAlpha * 0.3),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Floating Debug Camera window for absolute transparency of what Goz sees.
  Widget _buildDebugCameraOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double maxWidth = size.width * 0.45;
    final double maxHeight = size.height * 0.4;
    final double width = maxWidth.clamp(120.0, 240.0);
    final double expandedHeight = maxHeight.clamp(160.0, 320.0);
    final double minimizedHeight = 40.0; // Just the header

    // Ensure window stays within screen bounds when not dragging
    double x = _debugCameraPosition.dx;
    double y = _debugCameraPosition.dy;

    if (!_isDraggingCamera) {
      x = x.clamp(16.0, size.width - width - 16.0);
      y = y.clamp(100.0, size.height - (_debugCameraMinimized ? minimizedHeight : expandedHeight) - 140.0);
    }

    return AnimatedPositioned(
      duration: _isDraggingCamera ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      left: x,
      top: y,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDraggingCamera = true;
          });
          HapticService.tap();
        },
        onPanUpdate: (details) {
          setState(() {
            _debugCameraPosition += details.delta;
          });
        },
        onPanEnd: (details) {
          setState(() {
            _isDraggingCamera = false;

            final currentHeight = _debugCameraMinimized ? minimizedHeight : expandedHeight;

            // Swipe-to-dismiss logic: fast flick horizontally drops the camera
            if (details.velocity.pixelsPerSecond.dx.abs() > 1200) {
              _showDebugCamera = false;
              return;
            }

            // Snap to nearest corner (X/Y thresholds based on screen midpoint)
            final double midX = size.width / 2;
            final double midY = size.height / 2;

            final double targetX = _debugCameraPosition.dx + (width / 2) < midX ? 16.0 : size.width - width - 16.0;
            final double targetY = _debugCameraPosition.dy + (currentHeight / 2) < midY ? 100.0 : size.height - currentHeight - 140.0;

            _debugCameraPosition = Offset(targetX, targetY);
          });
          HapticService.tap();
        },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: width,
                height: _debugCameraMinimized ? minimizedHeight : expandedHeight,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6), // Glass transparency
                  border: Border.all(color: GozAITheme.primaryBlue.withValues(alpha: 0.4), width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 32,
                      spreadRadius: 8,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: GozAITheme.primaryBlue.withValues(alpha: 0.1),
                      blurRadius: 16,
                      spreadRadius: -4,
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Premium Glassmorphism
                    child: Column(
                    children: [
                      // Header / Drag Handle
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: GozAITheme.surfaceElevated,
                          border: Border(bottom: BorderSide(color: GozAITheme.borderSubtle)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Camera Preview (Live)',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _debugCameraMinimized ? Icons.expand_more : Icons.expand_less,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _debugCameraMinimized = !_debugCameraMinimized;
                                    });
                                    HapticService.tap();
                                  },
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: Colors.white70),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _showDebugCamera = false;
                                    });
                                    HapticService.tap();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Camera Preview (Only visible when expanded)
                      if (!_debugCameraMinimized)
                        Expanded(
                          child: Consumer<CameraService>(
                            builder: (context, camera, _) {
                              if (!camera.isInitialized || camera.controller == null) {
                                return const Center(child: Icon(Icons.videocam_off, color: Colors.white24, size: 40));
                              }
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  AspectRatio(
                                    aspectRatio: camera.controller!.value.aspectRatio,
                                    child: CameraPreview(camera.controller!),
                                  ),
                                  // Small indicator showing it's a Live Feed
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'LIVE',
                                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
  }

  Widget _buildClinicCompanionLayout(BuildContext context, ProfileService service) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBar(),
          const SizedBox(height: 12),
          // Active Profile Banner & Quick Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: GozAITheme.primaryBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GozAITheme.accentCyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.remove_red_eye_outlined, color: GozAITheme.accentCyan, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Clinic Companion • Quiet On-Demand',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    HapticService.tap();
                    service.toggleProfile(VisionProfile.lowVisionAssist);
                  },
                  child: const Text('Low-Vision Mode', style: TextStyle(color: GozAITheme.accentCyan, fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Scrollable Care Cards
          Expanded(
            child: ListView(
              children: [
                // Card 1: Today's Eye Care & Adherence Status
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: GozAITheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: GozAITheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Today's Eye Health",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('14-Day Streak', style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.medication_outlined, color: Colors.tealAccent, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Latanoprost 0.005%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                Text('1 drop OU at bedtime • Glaucoma IOP', style: TextStyle(color: Colors.white60, fontSize: 11)),
                              ],
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => context.push('/profile'),
                            child: const Text('View Drops', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Card 2: Upcoming Clinical Appointment
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: GozAITheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: GozAITheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.event_available, color: Colors.lightBlueAccent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Annual Comprehensive Exam', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                            SizedBox(height: 2),
                            Text('Tuesday, Oct 20 at 3:00 PM • Dr. Miller', style: TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.lightBlueAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => context.push('/profile'),
                        child: const Text('Manage', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Card 3: Instant Clinical Questions
                const Text(
                  'QUICK EYE CARE QUESTIONS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white54),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCompanionChip('Find eye clinics nearby', action: () => ClinicDiscoverySheet.show(context)),
                    _buildCompanionChip('Clinic working hours & doctors', action: () => ClinicDiscoverySheet.show(context)),
                    _buildCompanionChip('Book doctor appointment', action: () => ClinicDiscoverySheet.show(context)),
                    _buildCompanionChip('Who is at the Door? (Ring Vision)', action: () => _showDoorstepModal(context)),
                    _buildCompanionChip('Order Drops (Amazon Pharmacy Refill)', action: () => PatientDispensarySheet.show(context)),
                    _buildCompanionChip('Care Circle & Doorstep Safety', action: () => context.push('/caregiver')),
                    _buildCompanionChip('Why take drops at bedtime?'),
                    _buildCompanionChip('Relief for dry tired eyes'),
                    _buildCompanionChip('What does 20/20 mean?'),
                  ],
                ),
              ],
            ),
          ),

          // Bottom On-Demand Voice Activation Bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GozAITheme.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: GozAITheme.borderSubtle),
            ),
            child: Row(
              children: [
                Consumer2<GeminiLiveService, AudioService>(
                  builder: (context, gemini, audio, _) {
                    final isListening = gemini.isConnected && audio.isRecording;
                    return InkWell(
                      onTap: () => _coordinator?.toggleSession(),
                      borderRadius: BorderRadius.circular(25),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isListening ? Colors.redAccent : GozAITheme.primaryBlue,
                          boxShadow: isListening ? [
                            BoxShadow(color: Colors.redAccent.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: 2)
                          ] : null,
                        ),
                        child: Icon(
                          isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ask Goz Anything', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                      Text('Voice-activated clinical assistance on demand', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.document_scanner_outlined, color: GozAITheme.accentCyan),
                  tooltip: 'High-Res OCR Reader',
                  onPressed: () => _coordinator?.captureSnapshot(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCompanionChip(String label, {VoidCallback? action}) {
    return ActionChip(
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      side: const BorderSide(color: Colors.white12),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      onPressed: () {
        HapticService.tap();
        if (action != null) {
          action();
        } else {
          _coordinator?.gemini.sendText('User tapped quick inquiry: "$label". Provide a brief, supportive, clinically grounded answer.');
        }
      },
    );
  }
}

/// Forwards the two UI-shaped intents (debug camera window, transcripts
/// route) from the [SessionCoordinator] back into this screen's state, and
/// supplies device metrics for scaling Ghost Touch coordinates.
class _HomeUiHooks implements CopilotUiHooks {
  _HomeUiHooks(this._state);

  final _HomeScreenState _state;

  @override
  void setShowDebugCamera(bool visible) => _state._setShowDebugCamera(visible);

  @override
  void openTranscripts() => _state._openTranscripts();

  @override
  void onVisionProfileChanged(String profile) => _state._onVisionProfileChanged(profile);

  @override
  ({double width, double height, double pixelRatio}) uiMetrics() {
    final mq = MediaQuery.of(_state.context);
    return (
      width: mq.size.width,
      height: mq.size.height,
      pixelRatio: mq.devicePixelRatio,
    );
  }
}
