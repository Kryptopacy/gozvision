import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'adk_bridge_service.dart';
import 'copilot_delegate.dart';
import 'session_types.dart';
import 'service_contracts.dart';
import 'session_config.dart';

// Re-exported so consumers can keep importing the modes and
// connection state from this library.
export 'session_types.dart';

/// The core service managing the WebSocket connection to Gemini Multimodal Live API.
///
/// Handles bidirectional streaming of audio + video frames and receiving
/// audio responses + function calls from Gemini.
///
/// Tool-call intents are dispatched to the single [delegate] — see
/// [CopilotDelegate]. This module owns transport, protocol, the tool
/// registry, and dispatch; it knows nothing about devices.
class GeminiLiveService extends ChangeNotifier {
  GeminiLiveService({
    required this.config,
    required this.identity,
    required String Function(GozAIMode mode) buildSystemPrompt,
  }) : _buildSystemPrompt = buildSystemPrompt; // ignore: prefer_initializing_formals — named params cannot be private

  final SessionConfig config;
  final CopilotIdentity identity;
  final String Function(GozAIMode mode) _buildSystemPrompt;

  WebSocketChannel? _channel;
  GeminiConnectionState _connectionState = GeminiConnectionState.disconnected;
  GozAIMode _currentMode = GozAIMode.scene;
  String _statusMessage = 'Tap to connect';
  bool _isModelSpeaking = false;

  late final AdkBridgeService _adkBridge = AdkBridgeService(identity: identity, config: config);

  // Spatial Context Buffer — grounding Gemini with a running mental map.
  // Research basis: Seiple W. et al., TVST 14(1):3, 2025 (PMC11721483) —
  // AI assistive tools significantly improve spatial orientation and ADL
  // completion for people with vision loss.
  final List<String> _spatialContextHistory = [];
  static const int _maxSpatialContextItems = 5;

  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // Stream controllers for outbound data
  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();
  final StreamController<Uint8List> _audioOutputController =
      StreamController<Uint8List>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  /// The app-side handler for model intents (tool calls) — the one named
  /// seam between the session and the device. Implemented by
  /// [SessionCoordinator].
  CopilotDelegate? delegate;


  // Public getters
  GeminiConnectionState get connectionState => _connectionState;
  GozAIMode get currentMode => _currentMode;
  String get statusMessage => _statusMessage;
  bool get isModelSpeaking => _isModelSpeaking;
  bool get isConnected => _connectionState == GeminiConnectionState.connected;

  /// Stream of text transcripts from Gemini
  Stream<String> get transcriptStream => _transcriptController.stream;

  /// Stream of raw PCM audio data from Gemini
  Stream<Uint8List> get audioOutputStream => _audioOutputController.stream;

  /// Stream of status updates
  Stream<String> get statusStream => _statusController.stream;

  /// Connect to the Gemini Multimodal Live API via WebSocket.
  String? _pendingHardwareContext;

  Future<void> connect({String? hardwareContext}) async {
    _pendingHardwareContext = hardwareContext;
    if (_connectionState == GeminiConnectionState.connected ||
        _connectionState == GeminiConnectionState.connecting) {
      return;
    }

    _setConnectionState(GeminiConnectionState.connecting);
    _setStatus('Connecting to GozAI...');

    try {
      final wsUrl = config.geminiLiveWsUrl;
      debugPrint('GeminiLive: Connecting to $wsUrl');
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);

      // Wait for the WebSocket handshake to complete.
      // This throws if the handshake fails (e.g., 403 auth error).
      await _channel!.ready;

      _setConnectionState(GeminiConnectionState.connected);
      _setStatus('Connected');
      _reconnectAttempts = 0;

      // Send setup message with system prompt
      _sendSetupMessage();

      // Listen for incoming messages
      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('GeminiLive WebSocket error: $error (type: ${error.runtimeType})');
          _setConnectionState(GeminiConnectionState.error);
          _setStatus('Connection error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          final closeCode = _channel?.closeCode;
          final closeReason = _channel?.closeReason;
          debugPrint(
              'GeminiLive WebSocket closed. Code: $closeCode, Reason: $closeReason');
          _setConnectionState(GeminiConnectionState.disconnected);
          _setStatus('Disconnected (code: $closeCode)');
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (e, stack) {
      debugPrint('GeminiLive connection failed: $e');
      debugPrint('Stack: $stack');
      _setConnectionState(GeminiConnectionState.error);
      _setStatus('Failed to connect: $e');
      _scheduleReconnect();
    }
  }

  /// Attempt to reconnect using exponential backoff
  void _scheduleReconnect() {
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      final backoff = Duration(seconds: 2 * _reconnectAttempts);
      debugPrint('GeminiLive: Reconnecting in ${backoff.inSeconds} seconds (Attempt $_reconnectAttempts/$_maxReconnectAttempts)...');
      _setStatus('Reconnecting in ${backoff.inSeconds}s...');
      
      Future.delayed(backoff, () {
        if (_connectionState == GeminiConnectionState.disconnected || 
            _connectionState == GeminiConnectionState.error) {
          connect();
        }
      });
    } else {
      _setStatus('Failed to reconnect after $_maxReconnectAttempts attempts');
    }
  }

  /// Disconnect from the Gemini Live API.
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
    _setConnectionState(GeminiConnectionState.disconnected);
    _setStatus('Disconnected');
  }

  /// Send the initial setup message with system instructions and config.
  void _sendSetupMessage() {
    final systemInstruction = _composeSystemPrompt();

    final setupMessage = {
      'setup': {
        'model': config.geminiModel,
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': 'Aoede', // Clear, warm voice
              },
            },
          },
        },
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction},
          ],
        },
        'tools': [
          {
            'functionDeclarations': [
              {
                'name': 'switchCamera',
                'description': 'Switches or flips the user\'s camera (e.g., from front to back, or back to front). Call this when the user asks to switch the camera, flip the camera, or look at them.',
              },
              {
                'name': 'switchMode',
                'description': 'Switches the application mode (e.g., to scene, reading, screen, or light meter).',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'mode': {
                      'type': 'STRING',
                      'description': 'The mode to switch to. Must be one of: scene, reading, uiNav, lightMeter',
                      'enum': ['scene', 'reading', 'uiNav', 'lightMeter']
                    }
                  },
                  'required': ['mode']
                }
              },
              {
                'name': 'switchVisionProfile',
                'description': 'Switches the patient user profile and copilot assist level between "lowVisionAssist" (continuous scene descriptions, high haptics, obstacle detection) and "clinicCompanion" (silent on-demand assistant, subdued haptics, visual appointment hub). Call this when the user asks to switch to seeing mode, quiet mode, companion mode, or back to low-vision/assist mode.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'profile': {
                      'type': 'STRING',
                      'description': 'The target profile: "lowVisionAssist" or "clinicCompanion".',
                      'enum': ['lowVisionAssist', 'clinicCompanion']
                    }
                  },
                  'required': ['profile']
                }
              },
              {
                'name': 'captureSnapshot',
                'description': 'Takes a high-resolution snapshot photo for detailed analysis. Call this when the user explicitly asks to take a picture, snap a photo, or look closely at something.',
              },
              {
                'name': 'disconnectSession',
                'description': 'Gracefully hangs up and ends the current GozAI session. Call this when the user says goodbye, stop listening, or asks you to turn off.',
              },
              {
                'name': 'triggerHaptic',
                'description': 'Triggers a haptic vibration pattern on the device to communicate urgency non-visually. Call this proactively when you POSITIVELY detect a hazard (pattern: hazard), a person approaching (pattern: person), a navigation cue (pattern: navigate), a clear path (pattern: safe), or when you map the environment (pattern: environment_mapped).',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'pattern': {
                      'type': 'STRING',
                      'description': 'The haptic pattern to trigger. Must be one of: hazard, person, navigate, safe, environment_mapped',
                      'enum': ['hazard', 'person', 'navigate', 'safe', 'environment_mapped']
                    }
                  },
                  'required': ['pattern']
                }
              },
              {
                'name': 'clickUiElement',
                'description': 'Taps a specific UI element on the screen in UI NAVIGATOR mode. Use the x and y coordinates of the element you see in the screenshot. Coordinates should be relative to a standard 1080x1920 logical screen, though the relative position is most important. NOTE: This tool currently synthesizes taps within the Flutter app environment but is engineered with (x,y) arguments to bridge directly to OS accessibility services (e.g., Android AccessibilityNodeInfo or Windows UIAutomation) for arbitrary OS-level app control in the native architecture.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'x': {
                      'type': 'INTEGER',
                      'description': 'The X coordinate of the element to tap',
                    },
                    'y': {
                      'type': 'INTEGER',
                      'description': 'The Y coordinate of the element to tap',
                    },
                  },
                  'required': ['x', 'y'],
                }
              },
              {
                'name': 'toggleFlashlight',
                'description': 'Turns the device\'s hardware LED flashlight on or off. Use this autonomously if the camera feed is completely black and you cannot see, OR if the user explicitly asks you to turn on the light.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'on': {
                      'type': 'BOOLEAN',
                      'description': 'True to turn the flashlight ON. False to turn it OFF.',
                    }
                  },
                  'required': ['on'],
                }
              },
              {
                'name': 'requestHardwareAccess',
                'description': 'Requests the app to re-initialize and turn ON hardware, OR explicitly turn OFF hardware (camera or mic). Call this if the user asks you to turn a sensor ON or OFF. If the user asks you to turn a sensor OFF for privacy/security reasons, you MUST also send a mild SOS alert to their caregiver so they are aware the patient has intentionally gone dark.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'hardwareType': {
                      'type': 'STRING',
                      'description': 'The hardware to request: "camera" or "mic".',
                      'enum': ['camera', 'mic'],
                    },
                    'action': {
                      'type': 'STRING',
                      'description': 'Whether to turn the hardware "on" or "off".',
                      'enum': ['on', 'off'],
                    }
                  },
                  'required': ['hardwareType', 'action'],
                }
              },
              {
                'name': 'updateSpatialContext',
                'description': 'Stores a key landmark or spatial description in your running mental map of the user\'s environment. Call this when the user enters a new room, passes a major landmark (e.g., stairs, checkout counter, exit), or when the environment changes significantly.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'description': {
                      'type': 'STRING',
                      'description': 'A concise description of the spatial layout or landmark, relative to the user. (e.g., "Entrance is 10 feet behind you.")',
                    }
                  },
                  'required': ['description'],
                }
              },
              {
                'name': 'searchOptometryGuidelines',
                'description': 'Search curated optometry guidelines for safe, verified medical information. Use this when a user asks a specific eye health question. Do not attempt to diagnose.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'query': {
                      'type': 'STRING',
                      'description': 'The eye health question or condition to look up.',
                    }
                  },
                  'required': ['query'],
                }
              },
              {
                'name': 'getMedicationInfo',
                'description': 'Look up safe, verified medication information for common eye medications. Use this when a user asks about a specific eye drop or medication.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'medication_name': {
                      'type': 'STRING',
                      'description': 'The name of the medication to look up (e.g., Timolol, Latanoprost).',
                    }
                  },
                  'required': ['medication_name'],
                }
              },
              {
                'name': 'getLowVisionStatistics',
                'description': 'Provide clinical statistics and research findings on low vision. Use this when asked about the prevalence of vision impairment, or gaps in assistive technology.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'query': {
                      'type': 'STRING',
                      'description': 'The statistic topic to look up (e.g., global prevalence, tech abandonment).',
                    }
                  },
                  'required': ['query'],
                }
              },
              {
                'name': 'sendSosAlert',
                'description': 'Sends an emergency SOS alert to the user\'s designated caregiver via Firestore. Call this IMMEDIATELY if the user says they need help, are lost, feel unsafe, say "emergency", or if their speech sounds panicked or distressed. Do NOT ask for confirmation — act immediately.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'message': {
                      'type': 'STRING',
                      'description': 'A brief, clear description of the situation to send to the caregiver. E.g., "User says they are lost and scared."',
                    },
                    'severity': {
                      'type': 'STRING',
                      'description': 'Severity of the alert. Use "mild" for confusion/lost. Use "critical" for danger/injury.',
                      'enum': ['mild', 'critical'],
                    },
                    'target': {
                      'type': 'STRING',
                      'description': 'Target of the SOS alert. Use "caregiver" for general assistance or "doctor" for medical emergencies.',
                      'enum': ['caregiver', 'doctor'],
                    },
                  },
                  'required': ['message', 'severity', 'target'],
                }
              },
              {
                'name': 'rememberFact',
                'description': 'Saves an important fact about the user to persistent memory so you can recall it in future sessions. Call this when you learn something worth remembering: their name, a medication they take, their caregiver\'s name, a place they frequent, a food allergy, a preference, etc. Do NOT remember trivial conversational details.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'category': {
                      'type': 'STRING',
                      'description': 'Category of the fact. Use: medication, person, place, allergy, preference, health, or general.',
                      'enum': ['medication', 'person', 'place', 'allergy', 'preference', 'health', 'general'],
                    },
                    'fact': {
                      'type': 'STRING',
                      'description': 'The fact to remember. E.g., "User takes Metformin 500mg twice daily." or "Caregiver\'s name is Sarah."',
                    },
                  },
                  'required': ['category', 'fact'],
                }
              },
              {
                'name': 'toggleDebugCamera',
                'description': 'Toggles the visibility of the internal debug camera video feed window on the user\'s screen. Call this when the user asks to see what I see, open the video feed, hide the camera, or show the debug window.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'visible': {
                      'type': 'BOOLEAN',
                      'description': 'True to show the video feed, False to hide it.',
                    }
                  },
                  'required': ['visible'],
                }
              },
               {
                'name': 'openTranscripts',
                'description': 'Opens the hidden live transcript viewer on the screen. Call this ONLY when the user explicitly asks to read, see, or open the conversation transcripts or history.',
              },
              {
                'name': 'analyzeDocument',
                'description': 'Triggers the native device to take a high-resolution, auto-focused still image and extract dense text using ML Kit OCR. Use this instead of relying on the low-res video stream when the user asks you to read specific, tiny, or dense text like a pill bottle, a prescription label, mail, or a screen. The native app will capture the frame, parse the text, and inject it securely back into your context.',
              }
            ]
          }
        ],
      },
    };

    _sendJson(setupMessage);
    debugPrint('GeminiLive setup sent with mode: ${_currentMode.name}');
  }

  /// The system prompt is app content: the host supplies the persona and
  /// per-mode addenda; this module only decides when it is built (session
  /// setup, per current mode).
  String _composeSystemPrompt() => _buildSystemPrompt(_currentMode);

  /// Send raw audio data (PCM 16-bit mono 16kHz) to Gemini.
  void sendAudio(Uint8List pcmData) {
    if (!isConnected) return;

    final base64Audio = base64Encode(pcmData);
    final message = {
      'realtimeInput': {
        'mediaChunks': [
          {
            'mimeType': 'audio/pcm;rate=${config.audioInputSampleRate}',
            'data': base64Audio,
          },
        ],
      },
    };

    _sendJson(message);
  }

  /// Send a camera frame (JPEG bytes) to Gemini for scene analysis.
  void sendVideoFrame(Uint8List jpegData) {
    if (!isConnected) return;

    final base64Image = base64Encode(jpegData);
    final message = {
      'realtimeInput': {
        'mediaChunks': [
          {
            'mimeType': 'image/jpeg',
            'data': base64Image,
          },
        ],
      },
    };

    _sendJson(message);
  }

  /// Send a text message to Gemini (for typed input or mode commands).
  void sendText(String text) {
    if (!isConnected) return;

    final message = {
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': text},
            ],
          },
        ],
        'turnComplete': true,
      },
    };

    _sendJson(message);
  }

  /// Switch the current mode and reconnect with updated system prompt.
  Future<void> switchMode(GozAIMode mode) async {
    if (_currentMode == mode) return;
    _currentMode = mode;
    notifyListeners();

    // Reconnect with new system prompt
    if (isConnected) {
      await disconnect();
      await connect();
    }
  }

  /// Handle incoming WebSocket messages from Gemini.
  Future<void> _handleMessage(dynamic message) async {
    try {
      String messageStr;
      if (message is String) {
        messageStr = message;
      } else if (message is List<int>) {
        messageStr = utf8.decode(message);
      } else {
        debugPrint('GeminiLive: Unknown message type: ${message.runtimeType}');
        return;
      }
      
      final dynamic data;
      try {
        data = jsonDecode(messageStr);
      } catch (e) {
        final snippet = messageStr.length > 200 
            ? messageStr.substring(0, 200) 
            : messageStr;
        debugPrint('GeminiLiveService: JSON Parse Error: $e');
        debugPrint('Payload (first 200 chars): $snippet');
        return;
      }
      
      final Map<String, dynamic> dataMap = data as Map<String, dynamic>;
      // Handle setup complete
      if (dataMap.containsKey('setupComplete')) {
        debugPrint('GeminiLive setup complete');
        _setStatus('Ready');
        
        // Inject hardware context if provided
        if (_pendingHardwareContext != null) {
          debugPrint('GeminiLive: Injecting hardware context state.');
          sendText(_pendingHardwareContext!);
          _pendingHardwareContext = null;
        }
        
        return;
      }

      // Handle server content (audio response, text, etc.)
      if (dataMap.containsKey('serverContent')) {
        final serverContent = dataMap['serverContent'] as Map<String, dynamic>;

        // Check if model turn is complete
        if (serverContent['turnComplete'] == true) {
          _isModelSpeaking = false;
          notifyListeners();
          return;
        }

        // Check if this is an interruption acknowledgment
        if (serverContent['interrupted'] == true) {
          debugPrint('GeminiLive: Server acknowledged interruption.');
          _isModelSpeaking = false;
          delegate?.onInterrupted(); // Instantly fire barge-in
          notifyListeners();
          return;
        }

        // Process model turn parts
        final modelTurn = serverContent['modelTurn'] as Map<String, dynamic>?;
        if (modelTurn != null) {
          final parts = modelTurn['parts'] as List<dynamic>?;
          if (parts != null) {
            for (final part in parts) {
              final partMap = part as Map<String, dynamic>;

              // Text response — log only, do not surface to UI.
              // The model's text track contains chain-of-thought reasoning
              // which is meaningless to a blind user. All information is
              // delivered via audio. Keeping this in logs for debugging.
              if (partMap.containsKey('text')) {
                final text = partMap['text'] as String;
                debugPrint('GeminiLive [text]: $text');
                _transcriptController.add(text);
              }

              // Audio response (inline data)
              if (partMap.containsKey('inlineData')) {
                _isModelSpeaking = true;
                notifyListeners();

                final inlineData =
                    partMap['inlineData'] as Map<String, dynamic>;
                final audioBase64 = inlineData['data'] as String;
                final audioBytes = base64Decode(audioBase64);
                _audioOutputController.add(Uint8List.fromList(audioBytes));
              }
            }
          }
        }
      }

      // Handle tool calls (for ADK backend integration)
      if (data.containsKey('toolCall')) {
        await _handleToolCall(data['toolCall'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('GeminiLive message parse error: $e');
    }
  }

  /// Handle tool calls from Gemini (intent routing to Local App Actions or ADK backend).
  Future<void> _handleToolCall(Map<String, dynamic> toolCall) async {
    if (!toolCall.containsKey('functionCalls')) return;
    final functionCalls = toolCall['functionCalls'] as List<dynamic>;
    
    final functionResponses = [];

    for (final call in functionCalls) {
      final functionCallMap = call as Map<String, dynamic>;
      final callId = functionCallMap['id'] as String;
      final name = functionCallMap['name'] as String;
      final args = functionCallMap['args'] as Map<String, dynamic>? ?? {};

      debugPrint('GeminiLive: Executing tool call: $name');

      bool success = true;
      try {
        switch (name) {
          case 'switchCamera':
            delegate?.onSwitchCamera();
            break;
          case 'switchMode':
            final modeStr = args['mode'] as String?;
            final newMode = GozAIMode.values.firstWhere(
              (e) => e.name == modeStr,
              orElse: () => _currentMode,
            );
            delegate?.onSwitchMode(newMode);
            break;
          case 'switchVisionProfile':
            final profileStr = args['profile'] as String? ?? 'lowVisionAssist';
            delegate?.onSwitchVisionProfile(profileStr);
            break;
          case 'captureSnapshot':
            delegate?.onCaptureSnapshot();
            break;
          case 'disconnectSession':
            delegate?.onDisconnect();
            break;
          case 'triggerHaptic':
            final pattern = args['pattern'] as String? ?? 'navigate';
            delegate?.onTriggerHaptic(pattern);
            break;
          case 'updateSpatialContext':
            final desc = args['description'] as String?;
            if (desc != null && desc.isNotEmpty) {
               _spatialContextHistory.add(desc);
               if (_spatialContextHistory.length > _maxSpatialContextItems) {
                 _spatialContextHistory.removeAt(0);
               }
               delegate?.onSpatialUpdate(desc);
               debugPrint('GeminiLive: Spatial Context Updated -> \$desc');
            }
            break;
          case 'clickUiElement':
            final x = (args['x'] as num?)?.toDouble() ?? 0.0;
            final y = (args['y'] as num?)?.toDouble() ?? 0.0;
            // Route UI tap through the delegate and provide haptic feedback so
            // the user knows a tap was synthesized.
            delegate?.onClickUiElement(x, y);
            delegate?.onTriggerHaptic('tap');
            break;
          case 'sendSosAlert':
            final message = args['message'] as String? ?? 'User needs help.';
            final severity = args['severity'] as String? ?? 'mild';
            final target = args['target'] as String? ?? 'caregiver';
            delegate?.onSendSosAlert(message, severity, target);
            // Trigger urgent haptic pattern immediately so user feels the action
            delegate?.onTriggerHaptic('hazard');
            debugPrint('GeminiLive: SOS alert fired — severity: $severity, target: $target, message: $message');
            break;
          case 'toggleFlashlight':
            final on = args['on'] as bool? ?? false;
            delegate?.onToggleFlashlight(on);
            break;
          case 'requestHardwareAccess':
            final hardwareType = args['hardwareType'] as String? ?? 'camera';
            final action = args['action'] as String? ?? 'on';
            delegate?.onRequestHardwareAccess(hardwareType, action);
            break;
          case 'rememberFact':
            final category = args['category'] as String? ?? 'general';
            final fact = args['fact'] as String? ?? '';
            if (fact.isNotEmpty) {
              delegate?.onRememberFact(category, fact);
              debugPrint('GeminiLive: Remembering fact [$category]: $fact');
            }
            break;
          case 'toggleDebugCamera':
            final visible = args['visible'] as bool? ?? false;
            delegate?.onToggleDebugCamera(visible);
            break;
          case 'openTranscripts':
            delegate?.onOpenTranscripts();
            break;
          case 'analyzeDocument':
            delegate?.onAnalyzeDocument();
            break;
            
          // ADK Backend Delegated Tools
          case 'searchOptometryGuidelines':
            final query = args['query'] as String? ?? '';
            final responseStr = await _adkBridge.consultBackendAgent('Search optometry guidelines for: $query');
            functionResponses.add({
              'id': callId,
              'name': name,
              'response': {'result': responseStr}
            });
            continue; // Skip the default append below
            
          case 'getMedicationInfo':
            final medName = args['medication_name'] as String? ?? '';
            final responseStr = await _adkBridge.consultBackendAgent('Get medication info for: $medName');
            functionResponses.add({
              'id': callId,
              'name': name,
              'response': {'result': responseStr}
            });
            continue;
            
          case 'getLowVisionStatistics':
            final query = args['query'] as String? ?? '';
            final responseStr = await _adkBridge.consultBackendAgent('Get low vision statistics about: $query');
            functionResponses.add({
              'id': callId,
              'name': name,
              'response': {'result': responseStr}
            });
            continue;
            
          default:
            debugPrint('GeminiLive: Unknown tool call $name');
            success = false;
        }
      } catch (e) {
        debugPrint('GeminiLive: Error executing tool call $name: $e');
        success = false;
      }

      functionResponses.add({
        'id': callId,
        'name': name,
        'response': {
          'result': success ? 'Success' : 'Failed to execute tool',
        }
      });
    }

    // Send the tool execution results back to Gemini so it can resume speaking
    if (functionResponses.isNotEmpty) {
      _sendJson({
        'toolResponse': {
          'functionResponses': functionResponses,
        }
      });
    }
  }

  /// Send a JSON message over the WebSocket.
  /// Guards against sending on a closed/closing socket to avoid
  /// "WebSocket is already in CLOSING or CLOSED state" errors.
  void _sendJson(Map<String, dynamic> message) {
    if (_channel == null || !isConnected) return;
    _channel!.sink.add(jsonEncode(message));
  }

  /// Update connection state and notify listeners.
  void _setConnectionState(GeminiConnectionState state) {
    _connectionState = state;
    notifyListeners();
  }

  /// Update status message and notify listeners.
  void _setStatus(String status) {
    _statusMessage = status;
    _statusController.add(status);
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _transcriptController.close();
    _audioOutputController.close();
    _statusController.close();
    super.dispose();
  }
}
