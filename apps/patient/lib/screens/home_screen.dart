import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:copilot_core/copilot_core.dart';
import '../core/theme.dart';
import '../services/audio_service.dart';
import '../services/camera_service.dart';

import '../services/haptic_service.dart';
import 'profile_screen.dart';


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

            // UI Layer
            SafeArea(
              child: Column(
                children: [
                  _buildStatusBar(),
                  const SizedBox(height: 8),
                  _buildHardwareStatusIndicators(),
                  const Spacer(flex: 1),
                  _buildCentralButton(),
                  const Spacer(flex: 2),
                  _buildGozViewToggleHint(),
                  const SizedBox(height: 24),
                  _buildModeSelector(),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Debug Camera Overlay (Floating Window - Topmost Layer)
            if (_showDebugCamera)
              _buildDebugCameraOverlay(context),
          ],
        ),
      ),
    );
  }

  /// Explicitly visible Goz View toggle with Voice Command hints
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
                  _showDebugCamera ? 'HIDE GOZ VIEW' : 'SHOW GOZ VIEW',
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
              "Tap here or say 'Toggle Goz View'",
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
          icon: const Icon(Icons.account_circle_outlined, color: GozAITheme.accentCyan),
          tooltip: 'Patient Profile & Care Hub',
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

  /// Central activation button with high-end premium pulse glow.
  Widget _buildCentralButton() {
    return Consumer2<GeminiLiveService, AudioService>(
      builder: (context, gemini, audio, _) {
        final isActive = gemini.isConnected && audio.isRecording;
        final isSpeaking = gemini.isModelSpeaking;

        return GestureDetector(
          onTap: () => _coordinator?.toggleSession(),
          onLongPress: () => _coordinator?.captureSnapshot(),
          child: Semantics(
            button: true,
            label: isActive
                ? 'GozAI is listening. Double-tap to stop.'
                : 'Start GozAI. Double-tap to activate.',
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    if (isSpeaking) ...[
                      GozAITheme.speakingPulse.withValues(alpha: 0.9),
                      GozAITheme.speakingPulse.withValues(alpha: 0.4),
                    ] else if (isActive) ...[
                      GozAITheme.listeningPulse.withValues(alpha: 0.9),
                      GozAITheme.listeningPulse.withValues(alpha: 0.4),
                    ] else ...[
                      GozAITheme.surfaceElevated,
                      GozAITheme.surfacePure,
                    ],
                  ],
                ),
                boxShadow: [
                  if (isActive || isSpeaking)
                    BoxShadow(
                      color: (isSpeaking ? GozAITheme.speakingPulse : GozAITheme.listeningPulse)
                          .withValues(alpha: 0.6),
                      blurRadius: isActive ? 60 : 40,
                      spreadRadius: isActive ? 20 : 15,
                    )
                  else
                    BoxShadow(
                      color: GozAITheme.primaryBlue.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                ],
                border: Border.all(
                  color: isActive ? Colors.transparent : GozAITheme.borderSubtle,
                  width: 1,
                ),
              ),
              child: Icon(
                isActive ? Icons.graphic_eq : Icons.power_settings_new_rounded,
                size: 80,
                color: isActive ? Colors.white : GozAITheme.textPrimary,
                semanticLabel: isActive ? 'Listening' : 'Start',
              ),
            )
            // Spring activation scaling
            .animate(target: isActive ? 1 : 0)
            .scaleXY(end: 1.15, curve: Curves.easeOutBack, duration: 600.ms)
            .shimmer(duration: 1500.ms, color: Colors.white24)
            // Reactive pulse for AI speaking state
            .animate(
              target: isSpeaking ? 1 : 0,
              onPlay: (controller) => controller.repeat(reverse: true),
            )
            .scaleXY(end: 1.05, curve: Curves.easeInOutSine, duration: 800.ms)
            .tint(color: GozAITheme.speakingPulse.withValues(alpha: 0.3), duration: 400.ms),
          ),
        );
      },
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

  /// Immersive ambient glowing orbs that react to Gemini state
  Widget _buildAmbientGlowBackground() {
    return Consumer2<GeminiLiveService, AudioService>(
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

        return Stack(
          children: [
            // Top Right Orb
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeInOutSine,
              top: isActive ? 20 : -100,
              right: isActive ? -20 : -150,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 1500),
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mainGlow.withValues(alpha: 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: mainGlow.withValues(alpha: 0.2),
                      blurRadius: 120,
                      spreadRadius: 40,
                    )
                  ],
                ),
              ),
            ),
            // Bottom Left Orb
            AnimatedPositioned(
              duration: const Duration(milliseconds: 2000),
              curve: Curves.easeInOutSine,
              bottom: isSpeaking ? 0 : -80,
              left: isSpeaking ? -30 : -100,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 2000),
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GozAITheme.accentCyan.withValues(alpha: isSpeaking ? 0.2 : 0.05),
                  boxShadow: [
                    BoxShadow(
                      color: GozAITheme.accentCyan.withValues(alpha: isSpeaking ? 0.2 : 0.05),
                      blurRadius: 100,
                      spreadRadius: 30,
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
                              'Goz View (Live Feed)',
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
