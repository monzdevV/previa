import 'package:flutter/material.dart';

/// Identidad visual de Previa.
///
/// La aplicacion se usa de noche, casi siempre en la calle o en un piso con
/// poca luz, y a menudo con la pantalla al minimo de brillo. Por eso el tema
/// base es oscuro y no hay variante clara: no es una omision, es una decision.
abstract final class ColoresPrevia {
  /// Fondo principal. Casi negro, pero con un punto de azul para que no
  /// resulte plano.
  static const fondo = Color(0xFF0B0B12);

  /// Superficies elevadas: tarjetas, hojas inferiores, dialogos.
  static const superficie = Color(0xFF16161F);
  static const superficieAlta = Color(0xFF1F1F2B);

  /// Color de marca. Violeta electrico, el de los focos de una sala.
  static const primario = Color(0xFF7C4DFF);
  static const primarioSuave = Color(0xFF9E7BFF);

  /// Acento para lo que esta vivo: plazas libres, mensajes sin leer.
  static const acento = Color(0xFF00E5A0);

  /// Avisos y errores.
  static const aviso = Color(0xFFFFB340);
  static const error = Color(0xFFFF5470);

  /// Texto.
  static const texto = Color(0xFFF2F2F7);
  static const textoSuave = Color(0xFFA0A0B2);
  static const textoTenue = Color(0xFF6C6C80);

  static const borde = Color(0xFF2A2A38);
}

abstract final class EspaciadoPrevia {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  static const radio = 16.0;
  static const radioGrande = 24.0;
}

ThemeData construirTemaPrevia() {
  final esquema = ColorScheme.fromSeed(
    seedColor: ColoresPrevia.primario,
    brightness: Brightness.dark,
  ).copyWith(
    surface: ColoresPrevia.fondo,
    primary: ColoresPrevia.primario,
    secondary: ColoresPrevia.acento,
    error: ColoresPrevia.error,
    onSurface: ColoresPrevia.texto,
  );

  const fuente = 'Roboto';

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: esquema,
    scaffoldBackgroundColor: ColoresPrevia.fondo,
    fontFamily: fuente,

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: ColoresPrevia.texto,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    ),

    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        color: ColoresPrevia.texto,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: ColoresPrevia.texto,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ColoresPrevia.texto,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: ColoresPrevia.texto, height: 1.4),
      bodyMedium: TextStyle(fontSize: 14, color: ColoresPrevia.textoSuave, height: 1.4),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),

    cardTheme: CardThemeData(
      color: ColoresPrevia.superficie,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        side: const BorderSide(color: ColoresPrevia.borde),
      ),
      margin: EdgeInsets.zero,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ColoresPrevia.primario,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ColoresPrevia.texto,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: ColoresPrevia.borde),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ColoresPrevia.primarioSuave),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColoresPrevia.superficie,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: EspaciadoPrevia.m,
        vertical: EspaciadoPrevia.m,
      ),
      hintStyle: const TextStyle(color: ColoresPrevia.textoTenue),
      labelStyle: const TextStyle(color: ColoresPrevia.textoSuave),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        borderSide: const BorderSide(color: ColoresPrevia.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        borderSide: const BorderSide(color: ColoresPrevia.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        borderSide: const BorderSide(color: ColoresPrevia.primario, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        borderSide: const BorderSide(color: ColoresPrevia.error),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: ColoresPrevia.superficieAlta,
      labelStyle: const TextStyle(
        color: ColoresPrevia.texto,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      side: const BorderSide(color: ColoresPrevia.borde),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: ColoresPrevia.superficieAlta,
      contentTextStyle: const TextStyle(color: ColoresPrevia.texto),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
      ),
    ),

    dividerTheme: const DividerThemeData(color: ColoresPrevia.borde, thickness: 1),
  );
}
