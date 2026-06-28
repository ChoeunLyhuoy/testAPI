// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('ការកំណត់'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person,
                    color: AppTheme.primary, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('អ្នកគ្រប់គ្រង',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textDark)),
                    Text('sambathsamrang@gmail.com',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.textGrey)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          _GroupLabel('ទូទៅ'),
          _Tile(Icons.person_outline,    'ប្រវត្តិរូប',    AppTheme.primary, () {}),
          _Tile(Icons.language,          'ភាសា',           Colors.blue,     () {}),
          _Tile(Icons.notifications_outlined, 'ការជូនដំណឹង', Colors.orange, () {}),
          const SizedBox(height: 16),

          _GroupLabel('សុវត្ថិភាព'),
          _Tile(Icons.lock_outline,      'ផ្លាស់ប្ដូរលេខសំងាត់', Colors.green, () {}),
          _Tile(Icons.security_outlined, 'ការផ្ទៀងផ្ទាត់ពីរជំហាន', Colors.teal, () {}),
          const SizedBox(height: 16),

          _GroupLabel('ជំនួយ'),
          _Tile(Icons.help_outline,      'ជំនួយ & FAQ',   Colors.indigo, () {}),
          _Tile(Icons.info_outline,      'អំពី KOK POS',  Colors.grey,   () {}),
          const SizedBox(height: 24),

          // Logout
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.dangerLt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.logout,
                    color: AppTheme.danger, size: 20),
              ),
              title: const Text('ចាកចេញ',
                  style: TextStyle(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.bold)),
              onTap: () {
                context.read<AuthProvider>().logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          const Center(
            child: Text('KOK POS v2.0.0',
                style:
                    TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textGrey,
            letterSpacing: .8),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Tile(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppTheme.textDark)),
        trailing: const Icon(Icons.chevron_right,
            color: AppTheme.textMuted, size: 20),
        onTap: onTap,
      ),
    );
  }
}
