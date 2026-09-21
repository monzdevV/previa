import 'package:flutter/material.dart';

/// La paleta, resuelta segun el tema claro u oscuro.
///
/// Va como extension del tema y no como constantes sueltas porque una
/// constante no puede cambiar con el modo: con `static const fondo` el modo
/// claro es imposible por construccion.
///
/// Se lee con `context.colores.fondo`.
@immutable
class ColoresPrevia extends ThemeExtension<ColoresPrevia> {
  const ColoresPrevia({
    required this.fondo,
    required this.fondoProfundo,
    required this.superficie,
    required this.superficieAlta,
    required this.superficieActiva,
    required this.primario,
    required this.primarioSuave,
    required this.primarioTexto,
    required this.secundario,
    required this.disponible,
    required this.sobrePrimario,
    required this.texto,
    required this.textoSuave,
    required this.textoTenue,
    required this.borde,
    required this.error,
  });

  final Color fondo;
  final Color fondoProfundo;
  final Color superficie;
  final Color superficieAlta;
  final Color superficieActiva;

  /// Amarillo de marca. Es el relleno de los botones, no el color del texto.
  final Color primario;
  final Color primarioSuave;

  /// El amarillo sobre blanco es ilegible, asi que en claro el texto y los
  /// iconos de marca usan un ambar oscuro. En oscuro coincide con [primario].
  final Color primarioTexto;

  final Color secundario;
  final Color disponible;

  /// Lo que se escribe encima del amarillo y del verde: siempre negro.
  final Color sobrePrimario;

  final Color texto;
  final Color textoSuave;
  final Color textoTenue;
  final Color borde;
  final Color error;

  Color get navegacion => texto;
  Color get acento => disponible;
  Color get aviso => secundario;

  /// Degradado de marca. Solo en la accion principal, nunca tras texto.
  LinearGradient get degradado => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primario, secundario],
  );

  static const oscuro = ColoresPrevia(
    // Negro puro: el contenido es media a sangre y cualquier gris de base le
    // roba contraste.
    fondo: Color(0xFF000000),
    fondoProfundo: Color(0xFF000000),
    superficie: Color(0xFF0E0E0E),
    superficieAlta: Color(0xFF1A1A1A),
    superficieActiva: Color(0xFF262626),
    primario: Color(0xFFFFE500),
    primarioSuave: Color(0xFFFFF27A),
    primarioTexto: Color(0xFFFFE500),
    secundario: Color(0xFFFF9F1C),
    disponible: Color(0xFF35E07F),
    sobrePrimario: Color(0xFF000000),
    texto: Color(0xFFFFFFFF),
    textoSuave: Color(0xFFB0B0B0),
    textoTenue: Color(0xFF7A7A7A),
    borde: Color(0xFF262626),
    error: Color(0xFFFF4757),
  );

  static const claro = ColoresPrevia(
    fondo: Color(0xFFFFFFFF),
    fondoProfundo: Color(0xFFFFFFFF),
    superficie: Color(0xFFF5F5F7),
    superficieAlta: Color(0xFFEDEDF0),
    superficieActiva: Color(0xFFE0E0E6),
    primario: Color(0xFFFFE500),
    primarioSuave: Color(0xFFFFF27A),
    // Ambar oscuro: el amarillo de marca sobre blanco no llega ni de lejos
    // al contraste minimo para texto.
    primarioTexto: Color(0xFF8A6D00),
    secundario: Color(0xFFE08600),
    disponible: Color(0xFF00A055),
    sobrePrimario: Color(0xFF000000),
    texto: Color(0xFF0A0A0B),
    textoSuave: Color(0xFF56565E),
    textoTenue: Color(0xFF7C7C85),
    borde: Color(0xFFE0E0E6),
    error: Color(0xFFD62839),
  );

  @override
  ColoresPrevia copyWith({
    Color? fondo,
    Color? fondoProfundo,
    Color? superficie,
    Color? superficieAlta,
    Color? superficieActiva,
    Color? primario,
    Color? primarioSuave,
    Color? primarioTexto,
    Color? secundario,
    Color? disponible,
    Color? sobrePrimario,
    Color? texto,
    Color? textoSuave,
    Color? textoTenue,
    Color? borde,
    Color? error,
  }) => ColoresPrevia(
    fondo: fondo ?? this.fondo,
    fondoProfundo: fondoProfundo ?? this.fondoProfundo,
    superficie: superficie ?? this.superficie,
    superficieAlta: superficieAlta ?? this.superficieAlta,
    superficieActiva: superficieActiva ?? this.superficieActiva,
    primario: primario ?? this.primario,
    primarioSuave: primarioSuave ?? this.primarioSuave,
    primarioTexto: primarioTexto ?? this.primarioTexto,
    secundario: secundario ?? this.secundario,
    disponible: disponible ?? this.disponible,
    sobrePrimario: sobrePrimario ?? this.sobrePrimario,
    texto: texto ?? this.texto,
    textoSuave: textoSuave ?? this.textoSuave,
    textoTenue: textoTenue ?? this.textoTenue,
    borde: borde ?? this.borde,
    error: error ?? this.error,
  );

  @override
  ColoresPrevia lerp(ThemeExtension<ColoresPrevia>? otro, double t) {
    if (otro is! ColoresPrevia) return this;
    return ColoresPrevia(
      fondo: Color.lerp(fondo, otro.fondo, t)!,
      fondoProfundo: Color.lerp(fondoProfundo, otro.fondoProfundo, t)!,
      superficie: Color.lerp(superficie, otro.superficie, t)!,
      superficieAlta: Color.lerp(superficieAlta, otro.superficieAlta, t)!,
      superficieActiva: Color.lerp(superficieActiva, otro.superficieActiva, t)!,
      primario: Color.lerp(primario, otro.primario, t)!,
      primarioSuave: Color.lerp(primarioSuave, otro.primarioSuave, t)!,
      primarioTexto: Color.lerp(primarioTexto, otro.primarioTexto, t)!,
      secundario: Color.lerp(secundario, otro.secundario, t)!,
      disponible: Color.lerp(disponible, otro.disponible, t)!,
      sobrePrimario: Color.lerp(sobrePrimario, otro.sobrePrimario, t)!,
      texto: Color.lerp(texto, otro.texto, t)!,
      textoSuave: Color.lerp(textoSuave, otro.textoSuave, t)!,
      textoTenue: Color.lerp(textoTenue, otro.textoTenue, t)!,
      borde: Color.lerp(borde, otro.borde, t)!,
      error: Color.lerp(error, otro.error, t)!,
    );
  }
}

extension ContextoDeColores on BuildContext {
  /// La paleta del tema activo.
  ColoresPrevia get colores =>
      Theme.of(this).extension<ColoresPrevia>() ?? ColoresPrevia.oscuro;
}
