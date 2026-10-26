import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLogin = true;
  String _selectedRole = 'Patient';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final uri = Uri.base;
    final isDemoCaregiver = uri.queryParameters['demo'] == 'caregiver' ||
        uri.queryParameters['role'] == 'caregiver' ||
        uri.fragment.contains('demo=caregiver') ||
        uri.fragment.contains('caregiver');
    if (isDemoCaregiver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _emailController.text = 'caregiver@gozvision.demo';
        _passwordController.text = 'gozvision-demo';
        _submitAuth();
      });
    }
  }

  Future<void> _submitAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();
      
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Please enter email and password.');
      }
      
      if (!_isLogin && name.isEmpty) {
        throw Exception('Please enter your full name for registration.');
      }

      final client = Supabase.instance.client;

      if (_isLogin) {
        await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        final effectiveRole = email.toLowerCase() == 'kryptopacy@gmail.com' ? 'Developer' : _selectedRole;
        await client.auth.signUp(
          email: email,
          password: password,
          data: {
            'name': name,
            'role': effectiveRole,
          },
        );
        // Fallback upsert for environments without trigger (RLS: own row only).
        if (client.auth.currentUser != null) {
          await client.from('profiles').upsert({
            'id': client.auth.currentUser!.id,
            'email': email,
            'name': name,
            'role': effectiveRole,
            'assigned_patients': [],
          });
        }
      }

      final profile = await client
          .from('profiles')
          .select('role')
          .eq('id', client.auth.currentUser!.id)
          .maybeSingle();

      final role = (profile?['role'] as String?) ?? 'Patient';

      if (!mounted) return;

      // Dynamic routing based on RBAC (clinic staff use the Clinic Suite app)
      if (role == 'Caregiver') {
        context.go('/caregiver');
      } else {
        context.go('/');
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final redirect = kIsWeb
          ? '${Uri.base.origin}/patient/'
          : 'io.supabase.gozvision://login-callback';
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirect,
      );
      // On OAuth completion, auth state listener navigates, and Postgres
      // on_auth_user_created trigger automatically provisions the profile row.
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: GozAITheme.proTheme, // Utilize the premium dashboard theme
      child: Scaffold(
        backgroundColor: GozAITheme.obsidian,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.8, -0.6),
              radius: 2.0,
              colors: [
                GozAITheme.malachite.withValues(alpha: 0.15),
                GozAITheme.obsidian,
                const Color(0xFF000000),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 48,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: GozAITheme.malachite,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(color: GozAITheme.malachite.withValues(alpha: 0.8), blurRadius: 16),
                        ],
                      ),
                    ).animate().scaleY(begin: 0, duration: 800.ms, curve: Curves.easeOutCirc),
                    
                    Text(
                      'Goz AI.',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: GozAITheme.textPrimary,
                        letterSpacing: -2.0,
                        height: 1.0,
                      ),
                    ).animate().fade(duration: 600.ms).slideX(begin: -0.1),
                    
                    const SizedBox(height: 12),
                    Text(
                      'Secure Clinical Authentication Portal',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        letterSpacing: 1.0,
                      ),
                    ).animate().fade(delay: 200.ms),
                    
                    const SizedBox(height: 64),

                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: GozAITheme.hazardAlert.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: GozAITheme.hazardAlert.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: GozAITheme.hazardAlert, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_errorMessage!, style: const TextStyle(color: GozAITheme.hazardAlert))),
                          ],
                        ),
                      ).animate().fade().slideY(begin: 0.1),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: GozAITheme.obsidian.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: GozAITheme.proBorder, width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!_isLogin) ...[
                                Text(
                                  'FULL NAME',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: GozAITheme.textSecondary, fontSize: 11),
                                ),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _nameController,
                                  icon: Icons.person_outline,
                                  isObscure: false,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'SELECT YOUR ROLE',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: GozAITheme.textSecondary, fontSize: 11),
                                ),
                                const SizedBox(height: 8),
                                _buildRoleDropdown(),
                                const SizedBox(height: 24),
                              ],
                              Text(
                                'EMAIL',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: GozAITheme.textSecondary, fontSize: 11),
                              ),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _emailController,
                                icon: Icons.email_outlined,
                                isObscure: false,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'PASSWORD',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: GozAITheme.textSecondary, fontSize: 11),
                              ),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _passwordController,
                                icon: Icons.lock_outline_rounded,
                                isObscure: true,
                              ),
                              const SizedBox(height: 40),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submitAuth,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: GozAITheme.malachite,
                                    foregroundColor: Colors.black,
                                    shadowColor: GozAITheme.malachite.withValues(alpha: 0.5),
                                    elevation: 8,
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: _isLoading 
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                    : Text(_isLogin ? 'AUTHENTICATE' : 'CREATE ACCOUNT', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: Divider(color: GozAITheme.proBorder)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'OR',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: GozAITheme.textSecondary,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: GozAITheme.proBorder)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _isLoading ? null : _signInWithGoogle,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: GozAITheme.proBorder, width: 1.5),
                                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.g_mobiledata_rounded, size: 28, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(
                                        'CONTINUE WITH GOOGLE',
                                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isLogin = !_isLogin;
                                      _errorMessage = null;
                                    });
                                  },
                                  child: Text(
                                    _isLogin ? 'Need an account? Register here' : 'Already have an account? Log in',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: GozAITheme.malachite,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              if (_isLogin) ...[
                                const SizedBox(height: 6),
                                Center(
                                  child: TextButton.icon(
                                    onPressed: () {
                                      _emailController.text = 'caregiver@gozvision.demo';
                                      _passwordController.text = 'gozvision-demo';
                                      _submitAuth();
                                    },
                                    icon: const Icon(Icons.flash_on_rounded, size: 14, color: GozAITheme.patientAccent),
                                    label: const Text(
                                      'Fill Demo Caregiver Credentials (Ngozi Balogun)',
                                      style: TextStyle(color: GozAITheme.patientAccent, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ).animate().fade(delay: 400.ms).slideY(begin: 0.1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required bool isObscure,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: GozAITheme.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.03),
        prefixIcon: Icon(icon, color: GozAITheme.malachite, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: GozAITheme.malachite.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GozAITheme.proBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GozAITheme.malachite, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GozAITheme.proBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          dropdownColor: GozAITheme.obsidian,
          icon: const Icon(Icons.arrow_drop_down, color: GozAITheme.malachite),
          isExpanded: true,
          style: const TextStyle(color: GozAITheme.textPrimary, fontSize: 16),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _selectedRole = newValue);
            }
          },
          items: <String>['Patient', 'Caregiver']
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Row(
                children: [
                  Icon(
                    value == 'Caregiver' ? Icons.handshake_rounded : Icons.accessibility_new_rounded,
                    color: GozAITheme.malachite,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(value),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
