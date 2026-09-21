import 'package:flutter/material.dart';

/// Sistema visual de Previa.
///
/// El liston son las apps que la gente ya usa cada noche: Instagram, TikTok,
/// BeReal y Discord. De ahi salen las tres reglas que mandan sobre el resto:
/// la imagen ocupa el marco, las caras estan siempre presentes, y todo se
/// maneja con el pulgar. Nada de esto busca ser original: busca estar al
/// nivel de lo que el usuario ya tiene instalado.
abstract final class ColoresPrevia {
  // Negro puro de fondo: el contenido es media a sangre y cualquier gris de
  // base le roba contraste. Los grises solo aparecen en lo que se eleva.
  static const fondo = Color(0xFF000000);
  static const fondoProfundo = Color(0xFF000000);
  static const superficie = Color(0xFF0E0E0E);
  static const superficieAlta = Color(0xFF1A1A1A);
  static const superficieActiva = Color(0xFF262626);

  /// Amarillo: la marca y todo lo que se puede tocar. Sobre el siempre va
  /// texto negro, nunca blanco.
  static const primario = Color(0xFFFFE500);
  static const primarioSuave = Color(0xFFFFF27A);

  /// El segundo extremo del degradado de marca, hacia el ambar.
  static const secundario = Color(0xFFFF9F1C);

  /// Verde de disponible: el mismo codigo que usa cualquier app para decir
  /// "esta abierto, puedes entrar".
  static const disponible = Color(0xFF35E07F);

  /// Lo que se escribe encima del amarillo y del verde.
  static const sobrePrimario = Color(0xFF000000);

  static const navegacion = primario;
  static const acento = disponible;
  static const aviso = secundario;
  static const error = Color(0xFFFF4757);

  static const texto = Color(0xFFFFFFFF);
  static const textoSuave = Color(0xFFB0B0B0);
  static const textoTenue = Color(0xFF7A7A7A);
  static const borde = Color(0xFF262626);

  /// Degradado de marca. Se usa en la accion principal; nunca detras de
  /// texto corrido.
  static const degradado = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primario, secundario],
  );
}

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

/// [caraDelSistema] solo lo usan las pruebas: la app deja que la plataforma
/// elija su propia cara, pero el entorno de goldens no carga ninguna y hay
/// que nombrarla para que el retrato sea fiel.
ThemeData construirTemaPrevia({String? caraDelSistema}) {
  const esquema = ColorScheme.dark(
    primary: ColoresPrevia.primario,
    onPrimary: ColoresPrevia.sobrePrimario,
    secondary: ColoresPrevia.secundario,
    onSecondary: ColoresPrevia.sobrePrimario,
    tertiary: ColoresPrevia.disponible,
    surface: ColoresPrevia.superficie,
    onSurface: ColoresPrevia.texto,
    error: ColoresPrevia.error,
    onError: Colors.white,
    outline: ColoresPrevia.borde,
  );

  final contorno = OutlineInputBorder(
    borderRadius: BorderRadius.circular(EspaciadoPrevia.radio - 4),
    borderSide: const BorderSide(color: ColoresPrevia.borde),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: esquema,
    scaffoldBackgroundColor: ColoresPrevia.fondo,
    splashFactory: InkSparkle.splashFactory,
    fontFamily: caraDelSistema,

    appBarTheme: const AppBarTheme(
      backgroundColor: ColoresPrevia.fondo,
      foregroundColor: ColoresPrevia.texto,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: ColoresPrevia.texto,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),

    // La cara del sistema en todo. Las referencias no estrenan tipografia de
    // display: su caracter viene de la imagen y del color, no de la letra.
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 34,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: ColoresPrevia.texto,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: ColoresPrevia.texto,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: ColoresPrevia.texto,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: ColoresPrevia.texto,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: ColoresPrevia.texto,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: ColoresPrevia.textoSuave,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: ColoresPrevia.textoSuave,
      ),
    ),

    cardTheme: CardThemeData(
      color: ColoresPrevia.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
      ),
      margin: EdgeInsets.zero,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ColoresPrevia.primario,
        foregroundColor: ColoresPrevia.sobrePrimario,
        disabledBackgroundColor: ColoresPrevia.superficieActiva,
        disabledForegroundColor: ColoresPrevia.textoTenue,
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
        foregroundColor: ColoresPrevia.texto,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: ColoresPrevia.borde),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio - 4),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ColoresPrevia.primario,
      ),
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
      prefixIconColor: ColoresPrevia.textoTenue,
      suffixIconColor: ColoresPrevia.textoTenue,
      border: contorno,
      enabledBorder: contorno.copyWith(
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: contorno.copyWith(
        borderSide: const BorderSide(color: ColoresPrevia.primario, width: 2),
      ),
      errorBorder: contorno.copyWith(
        borderSide: const BorderSide(color: ColoresPrevia.error),
      ),
      focusedErrorBorder: contorno.copyWith(
        borderSide: const BorderSide(color: ColoresPrevia.error, width: 2),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: ColoresPrevia.superficieAlta,
      selectedColor: ColoresPrevia.primario,
      secondaryLabelStyle: const TextStyle(
        color: ColoresPrevia.sobrePrimario,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      labelStyle: const TextStyle(
        color: ColoresPrevia.texto,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ColoresPrevia.fondo,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 27,
          color: states.contains(WidgetState.selected)
              ? ColoresPrevia.texto
              : ColoresPrevia.textoTenue,
        ),
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: ColoresPrevia.superficie,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: ColoresPrevia.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(EspaciadoPrevia.radioGrande),
        ),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ColoresPrevia.primario,
      foregroundColor: ColoresPrevia.sobrePrimario,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: ColoresPrevia.superficieAlta,
      contentTextStyle: const TextStyle(color: ColoresPrevia.texto),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio - 4),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: ColoresPrevia.borde,
      thickness: 1,
      space: 1,
    ),
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

  Color get color => switch (this) {
    Ocupacion.abierta => ColoresPrevia.disponible,
    Ocupacion.llenandose => ColoresPrevia.aviso,
    Ocupacion.completa => ColoresPrevia.textoTenue,
  };
}
