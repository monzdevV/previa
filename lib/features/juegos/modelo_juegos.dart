// Modelos compartidos por todos los juegos de Previa.
//
// Viven aparte del motor y del contenido para que ambos se puedan escribir
// y probar por separado: el contenido solo construye [Reto]s y el motor solo
// los consume.

/// Nombre del juego estrella. El huevo es un emoji a proposito: es la gracia
/// del nombre y lo que lo hace reconocible como sticker. Es el mismo en las
/// cartas de la previa y en el reto del local (ver no_hay_huevos.dart).
const nombreDelJuego = 'No hay 🥚';

/// Los juegos disponibles. [noHayHuevos] es el principal; el resto son
/// complementos para rellenar una previa.
enum TipoJuego {
  noHayHuevos(nombreDelJuego, 'Cumple el reto o bebe.'),
  yoNunca('Yo nunca', 'Quien lo haya hecho, bebe.'),
  masProbable('¿Quién es más probable?', 'Señalad a la vez. Vota el grupo.'),
  verdadOReto('Verdad o reto', 'Confiesa o cúmplelo.');

  const TipoJuego(this.titulo, this.descripcion);
  final String titulo;
  final String descripcion;

  /// El titulo para el lector de pantalla: el emoji se leeria "huevo" en
  /// singular y sin gracia.
  String get tituloLeido => titulo.replaceAll('🥚', 'huevos');
}

/// Intensidad del contenido. El grupo la elige al empezar y solo se mezclan
/// niveles iguales o inferiores: nadie recibe un reto "sin filtro" por
/// sorpresa en una partida "suave".
enum NivelReto {
  suave('Suave', 'Para romper el hielo.'),
  atrevido('Atrevido', 'Sube el pulso, sin pasarse.'),
  sinFiltro('Sin filtro', 'Solo si todos estáis cómodos.');

  const NivelReto(this.etiqueta, this.descripcion);
  final String etiqueta;
  final String descripcion;
}

/// Una carta del juego.
class Reto {
  const Reto({
    required this.id,
    required this.juego,
    required this.nivel,
    required this.texto,
    this.sorbos = 2,
    this.contactoFisico = false,
    this.necesitaOtraPersona = false,
  });

  /// Identificador estable (p. ej. `nhh-suave-001`); sirve para no repetir
  /// cartas durante una partida.
  final String id;
  final TipoJuego juego;
  final NivelReto nivel;

  /// Texto de la carta. Admite el marcador `{otro}`, que el motor sustituye
  /// por el nombre de otra persona del grupo elegida al azar.
  final String texto;

  /// Penalizacion si se rechaza: SORBOS, nunca chupitos. Es un limite de
  /// seguridad deliberado. Entre 1 y 3.
  final int sorbos;

  /// El reto implica tocar a otra persona: el motor pide un "¿todos de
  /// acuerdo?" antes de ensenarlo.
  final bool contactoFisico;

  /// El reto usa el marcador `{otro}`.
  final bool necesitaOtraPersona;
}
