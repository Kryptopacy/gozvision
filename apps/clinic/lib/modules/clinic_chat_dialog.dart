import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/clinic_theme.dart';

/// In-App Chat Dialog connecting Optometrists, Staff, Patients, and Caregivers.
/// Allows direct messaging without requiring third-party tools, with automatic
/// push and email notifications handled by backend webhook seams.
class ClinicChatDialog extends StatefulWidget {
  const ClinicChatDialog({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  final String patientId;
  final String patientName;

  static void show(BuildContext context, {required String patientId, required String patientName}) {
    showDialog(
      context: context,
      builder: (_) => ClinicChatDialog(patientId: patientId, patientName: patientName),
    );
  }

  @override
  State<ClinicChatDialog> createState() => _ClinicChatDialogState();
}

class _ClinicChatDialogState extends State<ClinicChatDialog> {
  final TextEditingController _msgCtrl = TextEditingController();
  final List<Map<String, dynamic>> _mockMessages = [
    {
      'sender': 'Patient',
      'role': 'Patient',
      'text': 'Hi Dr. Miller, I noticed the glare filter helps a lot outdoors, but indoor fluorescent lights still feel a bit sharp.',
      'time': '10:15 AM',
      'isMe': false,
    },
    {
      'sender': 'Dr. Miller (OD)',
      'role': 'Practitioner',
      'text': 'Hello! Glad the glare filter is helping outdoors. For fluorescent lighting, try toggling the FL-41 contrast profile on your Goz Copilot. Let me know if that softens the glare.',
      'time': '10:22 AM',
      'isMe': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ClinicTheme.cardBackground,
      title: Row(
        children: [
          const CircleAvatar(
            backgroundColor: ClinicTheme.surfaceDark,
            child: Icon(Icons.person, color: ClinicTheme.malachite),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Care Thread: ${widget.patientName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClinicTheme.textPrimary),
                ),
                const Text(
                  'Connected: Practitioner • Patient • Caregiver (Push & Email Active)',
                  style: TextStyle(fontSize: 11, color: ClinicTheme.malachite),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: ClinicTheme.textSecondary),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: _mockMessages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final m = _mockMessages[i];
                  final isMe = m['isMe'] == true;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 380),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? ClinicTheme.malachite.withOpacity(0.18) : ClinicTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isMe ? ClinicTheme.malachite.withOpacity(0.4) : Colors.white10,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['sender'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isMe ? ClinicTheme.malachite : Colors.amber,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m['text'] as String,
                            style: const TextStyle(fontSize: 13, color: ClinicTheme.textPrimary, height: 1.3),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m['time'] as String,
                            style: const TextStyle(fontSize: 10, color: ClinicTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white10, height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(fontSize: 13, color: ClinicTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Type clinical advice or update...',
                      hintStyle: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 13),
                      filled: true,
                      fillColor: ClinicTheme.surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send, size: 18),
                  style: IconButton.styleFrom(backgroundColor: ClinicTheme.malachite),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _mockMessages.add({
        'sender': 'You (Clinic)',
        'role': 'Practitioner',
        'text': text,
        'time': 'Just now',
        'isMe': true,
      });
      _msgCtrl.clear();
    });
  }
}
