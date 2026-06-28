// lib/theme/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color primary    = Color(0xFF880E4F);
  static const Color primaryDk  = Color(0xFF6A0B3D);
  static const Color primaryLt  = Color(0xFFFCE4EC);
  static const Color bg         = Color(0xFFF7F7F9);
  static const Color card       = Colors.white;
  static const Color textDark   = Color(0xFF1A1A2E);
  static const Color textGrey   = Color(0xFF888888);
  static const Color textMuted  = Color(0xFFBBBBBB);
  static const Color border     = Color(0xFFEEEEEE);
  static const Color success    = Color(0xFF2E7D32);
  static const Color successLt  = Color(0xFFE8F5E9);
  static const Color warning    = Color(0xFFE65100);
  static const Color warningLt  = Color(0xFFFFF3E0);
  static const Color danger     = Color(0xFFC62828);
  static const Color dangerLt   = Color(0xFFFFEBEE);
  static const Color info       = Color(0xFF1565C0);
  static const Color infoLt     = Color(0xFFE3F2FD);

  // ── Theme ────────────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
    ),
    scaffoldBackgroundColor: bg,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
    ),
    // FIX: Replaced CardTheme with CardThemeData to match updated Material specifications
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: Color(0xFFF0F0F0)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFF0F0F0), thickness: 1, space: 0),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primary,
      unselectedItemColor: textGrey,
      elevation: 12,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
  );
}