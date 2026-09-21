import 'package:flutter/material.dart';

import 'colores.dart';

export 'colores.dart';

/// Sistema visual de Previa.
///
/// El liston son las apps que la gente ya usa cada noche: Instagram, TikTok,
/// BeReal y Discord. De ahi salen las tres reglas que mandan sobre el resto:
/// la imagen ocupa el marco, las caras estan siempre presentes, y todo se
/// maneja con el pulgar. Nada de esto busca ser original: busca estar al
/// nivel de lo que el usuario ya tiene instalado.
abstract final class EspaciadoPrevia {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  /// Esquinas generosas: es lo que separa una tarjeta de una app social de
  /// una celda de hoja de calculo.
  static const radio = 16.0;
  static const radioGrande = 24.0;

  /// Para pastillas y avatares, que son redondos.
  static const pastilla = 999.0;
}

/// El tema, construido desde una paleta.
///
/// [caraDelSistema] solo lo usan las pruebas: la app deja que la plataforma
/// elija su propia cara, pero el entorno de goldens no carga ninguna y hay
/// que nombrarla para que el retrato sea fiel.
ThemeData construirTemaPrevia({
  Brightness brillo = Brightness.dark,
  String? caraDelSistema,
}) {
  final c = brillo == Brightness.dark
      ? ColoresPrevia.oscuro
      : ColoresPrevia.claro;

  final esquema = ColorScheme(
    brightness: brillo,
    primary: c.primario,
    onPrimary: c.sobrePrimario,
    secondary: c.secundario,
    onSecondary: c.sobrePrimario,
    tertiary: c.disponible,
    surface: c.superficie,
    onSurface: c.texto,
    error: c.error,
    onError: Colors.white,
    outline: c.borde,
  );

  final contorno = OutlineInputBorder(
    borderRadius: BorderRadius.circular(EspaciadoPrevia.radio - 4),
    borderSide: BorderSide(color: c.borde),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brillo,
    colorScheme: esquema,
    scaffoldBackgroundColor: c.fondo,
    splashFactory: InkSparkle.splashFactory,
    fontFamily: caraDelSistema,
    extensions: [c],

    appBarTheme: AppBarTheme(
      backgroundColor: c.fondo,
      foregroundColor: c.texto,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: caraDelSistema,
        color: c.texto,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),

    // La cara del sistema en todo. Las referencias no estrenan tipografia de
    // display: su caracter viene de la imagen y del color, no de la letra.
    textTheme: TextTheme(
      displaySmall: TextStyle(
        fontSize: 34,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: c.texto,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: c.texto,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: c.texto,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: c.texto,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: c.texto,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: c.textoSuave,
      ),
      labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: c.textoSuave,
      ),
    ),

    cardTheme: CardThemeData(
      color: c.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
      ),
      margin: EdgeInsets.zero,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primario,
        foregroundColor: c.sobrePrimario,
        disabledBackgroundColor: c.superficieActiva,
        disabledForegroundColor: c.textoTenue,
        minimumSize: const Size.fromHeight(50),
        padding: const EdgeInsets.symmetric(horizontal: EspaciadoPrevia.l),
        // Sin textStyle propio: heredan labelLarge del textTheme, que es
        // quien lleva la cara del sistema. Fijarlo aqui la perdia.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio - 4),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.texto,
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: c.borde),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio - 4),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.primarioTexto),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.superficie,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: EspaciadoPrevia.m,
        vertical: EspaciadoPrevia.m,
      ),
      hintStyle: TextStyle(color: c.textoTenue),
      labelStyle: TextStyle(color: c.textoSuave),
      prefixIconColor: c.textoTenue,
      suffixIconColor: c.textoTenue,
      border: contorno,
      enabledBorder: contorno.copyWith(
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: contorno.copyWith(
        borderSide: BorderSide(color: c.primarioTexto, width: 2),
      ),
      errorBorder: contorno.copyWith(borderSide: BorderSide(color: c.error)),
      focusedErrorBorder: contorno.copyWith(
        borderSide: BorderSide(color: c.error, width: 2),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: c.superficieAlta,
      selectedColor: c.primario,
      secondaryLabelStyle: TextStyle(
        fontFamily: caraDelSistema,
        color: c.sobrePrimario,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      labelStyle: TextStyle(
        fontFamily: caraDelSistema,
        color: c.texto,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.fondo,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 27,
          color: states.contains(WidgetState.selected) ? c.texto : c.textoTenue,
        ),
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.superficie,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(EspaciadoPrevia.radioGrande),
        ),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primario,
      foregroundColor: c.sobrePrimario,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.superficieAlta,
      contentTextStyle: TextStyle(color: c.texto),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio - 4),
      ),
    ),

    dividerTheme: DividerThemeData(color: c.borde, thickness: 1, space: 1),
  );
}

/// Estado de ocupacion de una previa.
enum Ocupacion {
  abierta,
  llenandose,
  completa;

  static Ocupacion desde(int libres) {
    if (libres <= 0) return Ocupacion.completa;
    if (libres <= 2) return Ocupacion.llenandose;
    return Ocupacion.abierta;
  }

  bool get viva => this != Ocupacion.completa;

  Color color(ColoresPrevia c) => switch (this) {
    Ocupacion.abierta => c.disponible,
    Ocupacion.llenandose => c.aviso,
    Ocupacion.completa => c.textoTenue,
  };
}
