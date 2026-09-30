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

  /// Texto secundario (pistas, notas al pie). Antes era #6C6C80 (~3,5:1 sobre
  /// las superficies, suspende AA); #8A8AA0 da >=4,5:1 sobre fondo, superficie
  /// y superficieAlta y sigue leyéndose como "apagado" frente a textoSuave.
  static const textoTenue = Color(0xFF8A8AA0);

  /// Bordes DECORATIVOS (tarjetas, separadores): casi invisibles a propósito.
  /// No usar en controles interactivos, para eso está [bordeCampo].
  static const borde = Color(0xFF2A2A38);

  /// Borde de componentes de interfaz (campos de texto, chips, botones con
  /// contorno). WCAG 1.4.11 exige >=3:1 frente al fondo contiguo; #6C6C80
  /// lo cumple sobre fondo y sobre superficie sin romper lo oscuro del tema.
  static const bordeCampo = Color(0xFF6C6C80);
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
    // Explícitos para que un cambio futuro del tema no encoja los objetivos
    // táctiles sin darnos cuenta.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,

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
        side: const BorderSide(color: ColoresPrevia.bordeCampo),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ColoresPrevia.primarioSuave,
        // Objetivo táctil mínimo de 48 dp (WCAG 2.5.5 / guía de Material).
        minimumSize: const Size(64, 48),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),

    // El FAB pequeño de Material mide 40 dp; se sube a 48 para el botón
    // "Mi posición" sin cambiar su aspecto de botón secundario.
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      smallSizeConstraints: BoxConstraints.tightFor(width: 48, height: 48),
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
      // Borde con contraste >=3:1 (WCAG 1.4.11): sin él el campo vacío no
      // se distingue del fondo para quien tiene baja visión.
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        borderSide: const BorderSide(color: ColoresPrevia.bordeCampo),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        borderSide: const BorderSide(color: ColoresPrevia.bordeCampo),
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
      side: const BorderSide(color: ColoresPrevia.bordeCampo),
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
