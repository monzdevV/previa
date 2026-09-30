import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

/// Identidad visual de Previa.
///
/// La aplicacion se usa de noche, casi siempre en la calle o en un piso con
/// poca luz, y a menudo con la pantalla al minimo de brillo. Por eso el tema
/// base es oscuro y no hay variante clara: no es una omision, es una decision.
/// La paleta es calida (marrones y coral, como una sala a media luz) y no
/// azulada: el azul frio cansa la vista de madrugada y se ve "de oficina".
abstract final class ColoresPrevia {
  /// Fondo principal. Casi negro con un punto de marron calido para que no
  /// resulte frio ni plano.
  static const fondo = Color(0xFF14110F);

  /// Superficies elevadas: tarjetas, hojas inferiores, dialogos. Cada nivel
  /// es un escalon mas claro: en oscuro la elevacion se ve por el tono.
  static const superficie = Color(0xFF1E1A17);
  static const superficieAlta = Color(0xFF29241F);

  /// Color de marca y UNICO color de accion. Coral profundo: todo lo pulsable
  /// importante lo lleva y nada mas, asi se sabe donde tocar. Es lo bastante
  /// oscuro para que el texto blanco encima cumpla AA (>=4,5:1).
  static const primario = Color(0xFFC93C55);

  /// Version clara del primario para texto e iconos sobre fondo oscuro
  /// (enlaces, botones de texto), donde el primario puro no daria contraste.
  static const primarioSuave = Color(0xFFFF8A9B);

  /// Acento para lo que esta vivo: plazas libres, mensajes sin leer, la previa
  /// seleccionada. Es de estado, no de accion.
  static const acento = Color(0xFF4FD8A0);

  /// Avisos y errores.
  static const aviso = Color(0xFFFFB347);
  static const error = Color(0xFFFF6B7A);

  /// Texto.
  static const texto = Color(0xFFF6F0EA);
  static const textoSuave = Color(0xFFBDB2A9);

  /// Texto secundario (pistas, notas al pie). Debe dar >=4,5:1 sobre fondo,
  /// superficie y superficieAlta (lo fija test/contraste_tema_test.dart) y
  /// seguir leyendose como "apagado" frente a textoSuave.
  static const textoTenue = Color(0xFF9A8F86);

  /// Bordes DECORATIVOS (tarjetas, separadores): casi invisibles a proposito.
  /// No usar en controles interactivos, para eso esta [bordeCampo].
  static const borde = Color(0xFF332D27);

  /// Borde de componentes de interfaz (campos de texto, chips, botones con
  /// contorno). WCAG 1.4.11 exige >=3:1 frente al fondo contiguo.
  static const bordeCampo = Color(0xFF7A7269);
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

/// Duraciones y curvas de movimiento, centralizadas para que toda la app se
/// sienta igual: cortas (nunca hay que esperar) y con salida suave, que a poca
/// luz resulta menos brusca que un corte seco.
abstract final class MovimientoPrevia {
  static const rapido = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 280);
  static const curva = Curves.easeOutCubic;
}

/// Sombras por nivel. En un tema oscuro la sombra casi no se nota, asi que la
/// elevacion se expresa sobre todo con el tono de la superficie; la sombra
/// solo ayuda a separar del mapa los elementos que flotan encima.
abstract final class ElevacionPrevia {
  static const flotante = [
    BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const hoja = [
    BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, -4)),
  ];
}

ThemeData construirTemaPrevia() {
  final esquema = ColorScheme.fromSeed(
    seedColor: ColoresPrevia.primario,
    brightness: Brightness.dark,
  ).copyWith(
    surface: ColoresPrevia.fondo,
    primary: ColoresPrevia.primario,
    onPrimary: Colors.white,
    secondary: ColoresPrevia.acento,
    error: ColoresPrevia.error,
    onSurface: ColoresPrevia.texto,
    surfaceContainer: ColoresPrevia.superficie,
    surfaceContainerHigh: ColoresPrevia.superficieAlta,
  );

  const fuente = 'Roboto';

  RoundedRectangleBorder forma(double radio) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radio));

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

    // Sin esto Android usa el zoom por defecto del sistema, que a veces es
    // brusco. Desvanecer con un ligero avance es mas calmado y no marea.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: ColoresPrevia.texto,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    ),

    // Escala tipografica: pocos tamaños, con saltos claros. Titulo > cuerpo
    // > apoyo, y el peso (no solo el tamaño) marca la jerarquia.
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        height: 1.1,
        color: ColoresPrevia.texto,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.2,
        color: ColoresPrevia.texto,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.25,
        color: ColoresPrevia.texto,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: ColoresPrevia.texto,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: ColoresPrevia.texto, height: 1.4),
      bodyMedium: TextStyle(fontSize: 14, color: ColoresPrevia.textoSuave, height: 1.4),
      bodySmall: TextStyle(fontSize: 12, color: ColoresPrevia.textoTenue, height: 1.35),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),

    // Tarjeta limpia: sin borde marcado, solo un escalon de tono sobre el
    // fondo; el borde decorativo queda como hilo casi invisible.
    cardTheme: CardThemeData(
      color: ColoresPrevia.superficie,
      elevation: 0,
      shadowColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
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
        elevation: 0,
        shape: forma(EspaciadoPrevia.radio),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ColoresPrevia.texto,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: ColoresPrevia.bordeCampo),
        shape: forma(EspaciadoPrevia.radio),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ColoresPrevia.primarioSuave,
        // Objetivo táctil mínimo de 48 dp (WCAG 2.5.5 / guía de Material).
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),

    // El FAB pequeño de Material mide 40 dp; se sube a 48 para el botón
    // "Mi posición" sin cambiar su aspecto de botón secundario.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      smallSizeConstraints: const BoxConstraints.tightFor(width: 48, height: 48),
      elevation: 2,
      highlightElevation: 4,
      extendedTextStyle:
          const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      shape: forma(EspaciadoPrevia.radio),
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
        borderSide: const BorderSide(color: ColoresPrevia.primarioSuave, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        borderSide: const BorderSide(color: ColoresPrevia.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        borderSide: const BorderSide(color: ColoresPrevia.error, width: 2),
      ),
    ),

    // Chip seleccionado = color de accion relleno, blanco encima (AA). Asi
    // "activo" se distingue sin depender solo del borde.
    chipTheme: ChipThemeData(
      backgroundColor: ColoresPrevia.superficieAlta,
      selectedColor: ColoresPrevia.primario,
      checkmarkColor: Colors.white,
      labelStyle: const TextStyle(
        color: ColoresPrevia.texto,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      side: const BorderSide(color: ColoresPrevia.bordeCampo),
      shape: forma(EspaciadoPrevia.radioGrande),
      showCheckmark: true,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ColoresPrevia.superficie,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: ColoresPrevia.bordeCampo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(EspaciadoPrevia.radioGrande),
        ),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: ColoresPrevia.superficieAlta,
      surfaceTintColor: Colors.transparent,
      shape: forma(EspaciadoPrevia.radioGrande),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ColoresPrevia.primarioSuave,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: ColoresPrevia.superficieAlta,
      contentTextStyle: const TextStyle(color: ColoresPrevia.texto, fontSize: 14),
      actionTextColor: ColoresPrevia.primarioSuave,
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      shape: forma(EspaciadoPrevia.radio),
    ),

    dividerTheme: const DividerThemeData(color: ColoresPrevia.borde, thickness: 1),
  );
}
