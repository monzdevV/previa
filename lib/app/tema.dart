import 'package:flutter/material.dart';

import 'colores.dart';

export '../data/models/cara.dart';
export 'avatar.dart';
export 'colores.dart';
export 'componentes.dart';
export 'cristal.dart';
export 'movimiento.dart';

/// Sistema visual de Previa.
///
/// El liston son las apps que la gente ya usa cada noche: Instagram, TikTok,
/// BeReal y Discord. De ahi salen las tres reglas que mandan sobre el resto:
/// la imagen ocupa el marco, las caras estan siempre presentes, y todo se
/// maneja con el pulgar.
///
/// La voz sale del mundo de las discotecas (la referencia fijada es Nyxell):
/// titulares enormes en mayusculas con una letra gorda y redondeada, bloques
/// de color plano, cintas de texto que corren y botones en pastilla.
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

/// La letra de los titulares. Gorda y redondeada, va siempre en mayusculas
/// (ver `Titular`) y nunca en parrafos: el cuerpo es la del sistema.
abstract final class LetraPrevia {
  static const titular = 'Rubik';
}

/// Bloques de color plano para secciones y fichas, como carteles pegados.
///
/// Son los mismos en claro y en oscuro: un bloque es un objeto de color, no
/// un fondo que tenga que adaptarse. Encima siempre va [tintaSobreBloque],
/// que en todos ellos pasa el contraste de texto.
abstract final class BloquesPrevia {
  static const amarillo = Color(0xFFFFE500);
  static const menta = Color(0xFF3DD6B5);
  static const azul = Color(0xFF4B93FF);
  static const rojo = Color(0xFFFF5A4E);
  static const lila = Color(0xFFB794FF);

  static const todos = [amarillo, menta, azul, rojo, lila];

  static const tintaSobreBloque = Color(0xFF120F12);

  /// El color de un elemento de una lista, rotando para que dos seguidos
  /// nunca se repitan.
  static Color deIndice(int i) => todos[i % todos.length];
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
    borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
    borderSide: BorderSide(color: c.borde),
  );

  TextStyle titular(double tamano, {FontWeight peso = FontWeight.w900}) =>
      TextStyle(
        fontFamily: LetraPrevia.titular,
        fontSize: tamano,
        height: 1.0,
        fontWeight: peso,
        letterSpacing: -0.02 * tamano,
        color: c.texto,
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
      titleTextStyle: titular(24),
    ),

    // Titulares en Rubik; lo que se lee de corrido, en la del sistema.
    textTheme: TextTheme(
      displayLarge: titular(64),
      displayMedium: titular(48),
      displaySmall: titular(36),
      headlineMedium: titular(28),
      titleLarge: titular(19, peso: FontWeight.w800).copyWith(height: 1.15),
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
      labelLarge: const TextStyle(
        fontFamily: LetraPrevia.titular,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
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
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: EspaciadoPrevia.l),
        // Sin textStyle propio: heredan labelLarge del textTheme, que ya
        // lleva la letra de titulares. Fijarlo aqui la perdia.
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.texto,
        minimumSize: const Size.fromHeight(52),
        // Contorno grueso en el color del texto: la pastilla vacia es la
        // pareja del boton relleno, no un boton de segunda.
        side: BorderSide(color: c.texto, width: 2),
        shape: const StadiumBorder(),
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
        fontFamily: LetraPrevia.titular,
        color: c.sobrePrimario,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      labelStyle: TextStyle(
        fontFamily: LetraPrevia.titular,
        color: c.texto,
        fontSize: 13,
        fontWeight: FontWeight.w700,
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
      dragHandleColor: c.superficieActiva,
      dragHandleSize: const Size(36, 4),
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

    // Flotante, con borde y separada del filo: el aviso de Sonner que usan
    // los otros proyectos del autor, no la franja pegada abajo de Material.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.superficieAlta,
      contentTextStyle: TextStyle(
        fontFamily: caraDelSistema,
        color: c.texto,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(
        EspaciadoPrevia.m,
        0,
        EspaciadoPrevia.m,
        EspaciadoPrevia.m,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        side: BorderSide(color: c.borde),
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

extension HolguraDeLaBarra on BuildContext {
  /// Relleno inferior para lo que se desplaza en una pestaña principal.
  ///
  /// La barra de pestañas flota encima del contenido (es de vidrio y deja
  /// pasar el feed por debajo), asi que el final de cada lista tiene que
  /// dejarle sitio o el ultimo elemento queda tapado.
  double get holguraInferior =>
      MediaQuery.paddingOf(this).bottom + EspaciadoPrevia.m;
}
