import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:copilot_core/copilot_core.dart';
import '../core/theme.dart';

class TranscriptsScreen extends StatelessWidget {
  const TranscriptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final geminiService = context.read<GeminiLiveService>();

    return Scaffold(
      backgroundColor: GozAITheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Live Transcripts'),
        backgroundColor: GozAITheme.surfacePure,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GozAITheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GozAITheme.borderSubtle),
                ),
                child: const Text(
                  'These are the raw, unedited transcripts from your current session with GozAI. '
                  'They are NOT saved to the cloud permanently for your privacy, unless you take a screenshot.',
                  style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<String>(
                  stream: geminiService.transcriptStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData && geminiService.statusMessage.isNotEmpty) {
                      return Center(
                        child: Text(
                          'Waiting for conversation to begin...',
                          style: TextStyle(color: GozAITheme.textSecondary),
                        ),
                      );
                    }

                    // We just display the live stream chunks as they arrive for now,
                    // or rather, we append them to a list if we had a stateful widget.
                    // For a lightweight viewer, we can just show the latest chunk.
                    return SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: GozAITheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: GozAITheme.accentCyan.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          snapshot.data ?? '...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
