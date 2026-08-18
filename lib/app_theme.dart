// lib/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  // Heinz brand colors
  static const Color azulPrincipal = Color(0xFF003087);
  static const Color azulOscuro = Color(0xFF001E5A);
  static const Color azulClaro = Color(0xFF1A4BA0);
  static const Color rojo = Color(0xFFCE1126);
  static const Color rojoClaro = Color(0xFFE53030);
  static const Color verde = Color(0xFF00AA44);
  static const Color verdeClaro = Color(0xFF00CC55);
  static const Color amarillo = Color(0xFFFFCC00);
  static const Color grisClaro = Color(0xFFF5F6FA);
  static const Color grisMedio = Color(0xFFE0E3EC);
  static const Color grisTexto = Color(0xFF8492A6);
  static const Color blanco = Color(0xFFFFFFFF);
  static const Color negro = Color(0xFF1A1F36);

  static ThemeData get theme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: azulPrincipal,
          primary: azulPrincipal,
          secondary: rojo,
          surface: blanco,
          background: grisClaro,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: azulPrincipal,
          foregroundColor: blanco,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: blanco,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: azulPrincipal,
            foregroundColor: blanco,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            elevation: 2,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: blanco,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: grisMedio),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: grisMedio, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: azulPrincipal, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cardTheme: CardThemeData(
          color: blanco,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          shadowColor: azulPrincipal.withOpacity(0.1),
        ),
        scaffoldBackgroundColor: grisClaro,
      );
}

// Reutilizable: botón primario azul
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppTheme.azulPrincipal,
          foregroundColor: AppTheme.blanco,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 2,
        ),
        icon: icon != null ? Icon(icon, size: 20) : const SizedBox.shrink(),
        label: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// Badge de estado ERU
class EruBadge extends StatelessWidget {
  final double eruPct;

  const EruBadge({super.key, required this.eruPct});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    if (eruPct >= 98) {
      color = AppTheme.verde;
      label = '✓ OK';
    } else if (eruPct >= 95) {
      color = AppTheme.amarillo;
      label = '⚠ REGULAR';
    } else {
      color = AppTheme.rojo;
      label = '✗ CRITICO';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}