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
  final _fullName = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _isRegister = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _demoLogin() async {
    _email.text = 'practitioner@gozvision.demo';
    _password.text = 'gozvision-demo';
    await _submit();
  }

  Future<void> _submit() async {
    final emailText = _email.text.trim();
    final passText = _password.text;

    if (emailText.isEmpty && passText.isEmpty && !_isRegister) {
      _email.text = 'practitioner@gozvision.demo';
      _password.text = 'gozvision-demo';
    } else if (emailText.isEmpty || passText.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      if (_isRegister) {
        final res = await client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {'name': _fullName.text.trim().isNotEmpty ? _fullName.text.trim() : 'Practitioner'},
        );
        if (res.user != null) {
          try {
            await client.from('profiles').upsert({
              'id': res.user!.id,
              'email': _email.text.trim(),
              'name': _fullName.text.trim().isNotEmpty ? _fullName.text.trim() : 'Attending Optometrist',
              'role': 'Practitioner',
              'clinic_id': 'a3450a9b-6820-40dd-be8e-25c7a2deb360',
              'assigned_patients': [],
            });
          } catch (_) {}
        }
      } else {
        await client.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      // Auth state stream in main.dart routes into the shell.
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
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
      final redirect = kIsWeb
          ? '${Uri.base.origin}/clinic/'
          : 'io.supabase.gozvision://login-callback';
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirect,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
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
                      if (_isRegister) ...[
                        TextField(
                          controller: _fullName,
                          decoration: InputDecoration(
                            labelText: 'Practitioner Full Name',
                            hintText: 'e.g. Dr. O.D. Adegoke, O.D.',
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
                        ),
                        const SizedBox(height: 16),
                      ],
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
                        onSubmitted: (_) => _submit(),
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
                        onPressed: _busy ? null : _submit,
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
                            : Text(
                                _isRegister ? 'Create Practice Account' : 'Sign In to Practice',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isRegister = !_isRegister;
                              _error = null;
                            });
                          },
                          child: Text(
                            _isRegister
                                ? 'Already have an account? Sign In'
                                : 'New practice? Register Account',
                            style: const TextStyle(
                              color: ClinicTheme.brandAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (!_isRegister) ...[
                        const SizedBox(height: 4),
                        Center(
                          child: TextButton.icon(
                            onPressed: _demoLogin,
                            icon: const Icon(Icons.flash_on_rounded, size: 14, color: ClinicTheme.warningAmber),
                            label: const Text(
                              'Fill Demo Credentials (Dr. O.D. Adegoke)',
                              style: TextStyle(color: ClinicTheme.warningAmber, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
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
