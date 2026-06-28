// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) return;
    final ok = await context.read<AuthProvider>().login(
      _emailCtrl.text.trim(),
      _passCtrl.text.trim(),
    );
    if (ok && mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    // keyboardHeight > 0 when keyboard is open
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    final screenH   = MediaQuery.of(context).size.height;
    final topPad    = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.primary,
      // Let Scaffold push content up when keyboard opens
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        // Prevent rubber-banding; scroll only when keyboard forces it
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          // Always at least full screen tall so hero fills space when keyboard
          // is closed; shrinks naturally when keyboard is open
          constraints: BoxConstraints(
            minHeight: screenH,
          ),
          child: IntrinsicHeight(
            child: Column(
              children: [
                // ── Hero Banner ──────────────────────────────────────────
                // Shrinks when keyboard is open so card stays visible
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: double.infinity,
                  // When keyboard is open, hero collapses to a compact strip
                  height: keyboardH > 0
                      ? topPad + 90   // just logo + title visible
                      : screenH * 0.40,
                  color: AppTheme.primary,
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo badge
                        Container(
                          width: keyboardH > 0 ? 52 : 88,
                          height: keyboardH > 0 ? 52 : 88,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                keyboardH > 0 ? 16 : 24),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.35),
                                width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                                keyboardH > 0 ? 14 : 22),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(height: keyboardH > 0 ? 6 : 16),
                        Text(
                          'KOK POS',
                          style: TextStyle(
                            fontSize: keyboardH > 0 ? 18 : 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        if (keyboardH == 0) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'ប្រព័ន្ធគ្រប់គ្រងការលក់',
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                fontWeight: FontWeight.w400),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Point of Sale System',
                            style: TextStyle(
                                fontSize: 13, color: Colors.white54),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Login Card ─────────────────────────────────────────
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      28,
                      32,
                      28,
                      // Extra bottom padding so button isn't hidden behind nav bar
                      MediaQuery.of(context).padding.bottom + 24,
                    ),
                    child: Consumer<AuthProvider>(
                      builder: (_, auth, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Welcome text
                          const Text(
                            'សូមស្វាគមន៍!',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'ចូលប្រើប្រាស់គណនីរបស់អ្នក',
                            style: TextStyle(
                                fontSize: 13, color: AppTheme.textGrey),
                          ),
                          const SizedBox(height: 24),

                          // Error banner
                          if (auth.state == AuthState.error) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(auth.errorMessage,
                                      style: const TextStyle(
                                          color: Colors.red, fontSize: 13)),
                                ),
                              ]),
                            ),
                          ],

                          // Email field
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => auth.clearError(),
                            decoration: InputDecoration(
                              labelText: 'អ៊ីមែល (Email)',
                              prefixIcon: const Icon(Icons.email_outlined,
                                  color: AppTheme.primary, size: 20),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Password field
                          TextField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _login(),
                            onChanged: (_) => auth.clearError(),
                            decoration: InputDecoration(
                              labelText: 'លេខសំងាត់ (Password)',
                              prefixIcon: const Icon(Icons.lock_outline,
                                  color: AppTheme.primary, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: AppTheme.textGrey,
                                    size: 20),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: const Text(
                                'ភ្លេចលេខសំងាត់?',
                                style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _login,
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Text(
                                      'ចូលប្រើប្រាស់',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Version
                          Center(
                            child: Text(
                              'KOK POS v2.0.0',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[400]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
