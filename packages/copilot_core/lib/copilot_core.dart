/// The Goz Copilot Loop — shared by every GozVision host app.
///
/// - [CopilotDelegate] — the intent seam (session → app)
/// - [SessionCoordinator] — the loop brain (senses in, intents out)
/// - [SystemTags] — the context-pulse contract
/// - [GeminiLiveService] — the Live API transport + tool registry
/// - [service_contracts] — the device-facing contracts hosts implement
///
/// See CONTEXT.md at the repo root for the vocabulary.
library;

export 'src/copilot_delegate.dart';
export 'src/session_types.dart';
export 'src/gemini_live_service.dart';
export 'src/service_contracts.dart';
export 'src/session_config.dart';
export 'src/session_coordinator.dart';
export 'src/system_tags.dart';
