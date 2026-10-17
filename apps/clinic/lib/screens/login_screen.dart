import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/clinic_theme.dart';

/// Clinic Suite sign-in. Roles (Owner/Practitioner/Staff) are resolved
/// against the user's profiles row after auth; see ClinicScope.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _demoLogin() async {
    _email.text = 'practitioner@gozvision.demo';
    _password.text = 'gozvision-demo';
    await _signIn();
  }

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty && _password.text.isEmpty) {
      _email.text = 'practitioner@gozvision.demo';
      _password.text = 'gozvision-demo';
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      // Auth state stream in main.dart routes into the shell.
    } on AuthApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.gozvision://login-callback',
      );
    } on AuthApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClinicTheme.obsidian,
      body: Stack(
        children: [
          // Subtle atmospheric background halo
          Center(
            child: IgnorePointer(
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ClinicTheme.malachite.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    radius: 0.5,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0F17),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 48,
                        spreadRadius: 4,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: ClinicTheme.brandAccent.withValues(alpha: 0.25),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              'assets/gozvision_lens.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'GozVision',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Eye Clinic Practice Portal',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ClinicTheme.textSecondary,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _email,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'doctor@clinic.com or gmail',
                          labelStyle: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13),
                          fillColor: const Color(0xFF06090F),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ClinicTheme.malachite, width: 1.5),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _password,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13),
                          fillColor: const Color(0xFF06090F),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ClinicTheme.malachite, width: 1.5),
                          ),
                        ),
                        obscureText: true,
                        onSubmitted: (_) => _signIn(),
                      ),
                      const SizedBox(height: 22),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: ClinicTheme.hazardAlert, fontSize: 13),
                          ),
                        ),
                      FilledButton(
                        onPressed: _busy ? null : _signIn,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF08090D),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF08090D),
                                ),
                              )
                            : const Text(
                                'Sign In to Practice',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.08))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: ClinicTheme.textSecondary.withValues(alpha: 0.6),
                                fontSize: 11,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.08))),
                        ],
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton(
                        onPressed: _busy ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.02),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.g_mobiledata_rounded, size: 28),
                            SizedBox(width: 8),
                            Text(
                              'Continue with Google',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            context.read<ClinicScope>().enterDemoMode(DemoPersona.doctor);
                          },
                          icon: const Icon(Icons.science_outlined, size: 15, color: ClinicTheme.brandAccent),
                          label: const Text(
                            'Explore Interactive Clinical Sandbox →',
                            style: TextStyle(
                              color: ClinicTheme.brandAccent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: ClinicTheme.brandAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
