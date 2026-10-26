import 'package:flutter/material.dart';

/// Cores do Condexpress. Cada cor de status tem sempre o mesmo significado
/// em todo o app (heurística de consistência).
class Cores {
  // Identidade visual (cores da logo)
  static const primaria = Color(0xFF008484); // verde-água "COND"
  static const primariaEscura = Color(0xFF005F5F);
  static const destaque = Color(0xFFCC4818); // laranja "EXPRESS"
  static const amarelo = Color(0xFFE8A632); // caixa da logo
  static const maoClara = Color(0xFF66C6C2); // mão da logo

  // Status: sempre com o mesmo significado (heurística de consistência)
  static const ok = Color(0xFF1F9D55); // entregue / concluído
  static const alerta = Color(0xFFB26B00); // na portaria / pendente
  static const info = Color(0xFF2563EB); // grande porte / informação
  static const erro = Color(0xFFD92D20); // frágil / erro
  static const estrela = Color(0xFFF5A623);
}

class TemaCondexpress {
  static ThemeData claro() => _criar(Brightness.light);
  static ThemeData escuro() => _criar(Brightness.dark);

  static ThemeData _criar(Brightness brilho) {
    final escuro = brilho == Brightness.dark;
    final esquema = ColorScheme.fromSeed(
      seedColor: Cores.primaria,
      brightness: brilho,
      primary: Cores.primaria,
      onPrimary: Colors.white,
      surface: escuro ? const Color(0xFF18181B) : Colors.white,
    );
    final raio = BorderRadius.circular(12);
    // No escuro, o verde-água fica mais claro para manter o contraste dos textos
    final corTexto = escuro ? const Color(0xFF34BDB4) : Cores.primaria;
    final borda = escuro ? const Color(0xFF2E2E33) : const Color(0xFFEBEBEB);

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: escuro ? const Color(0xFF0E0E10) : const Color(0xFFF7F7F7),
      dividerColor: borda,
      appBarTheme: AppBarTheme(
        backgroundColor: esquema.surface,
        foregroundColor: esquema.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: esquema.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: raio),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          foregroundColor: corTexto,
          side: BorderSide(color: borda, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: raio),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: corTexto)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: escuro ? const Color(0xFF111113) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: raio, borderSide: BorderSide(color: borda, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: raio, borderSide: BorderSide(color: borda, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: raio, borderSide: const BorderSide(color: Cores.primaria, width: 2)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: esquema.surface,
        indicatorColor: Cores.primaria.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((estados) => TextStyle(
              fontSize: 12,
              fontWeight: estados.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: estados.contains(WidgetState.selected) ? Cores.primaria : esquema.onSurfaceVariant,
            )),
        iconTheme: WidgetStateProperty.resolveWith((estados) => IconThemeData(
              color: estados.contains(WidgetState.selected) ? Cores.primaria : esquema.onSurfaceVariant,
            )),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: raio),
      ),
    );
  }
}
