import 'dart:math';

import 'ruleta.dart';

/// Tope de seguridad, el mismo que en las cartas y la ruleta: nunca más de
/// 3 sorbos y jamás un chupito.
const int sorbosMaximosReyes = 3;

const int minJugadoresReyes = 2;

/// Palos de la baraja. Solo cambian el dibujo de la carta: la regla depende
/// únicamente del valor.
const List<String> simbolosPalo = ['♠', '♥', '♦', '♣'];
const List<String> nombresPalo = [
  'picas',
  'corazones',
  'diamantes',
  'tréboles',
];

/// Una carta de la baraja: [valor] de 1 (as) a 13 (rey) y [palo] de 0 a 3.
class CartaReyes {
  const CartaReyes(this.valor, this.palo);
  final int valor;
  final int palo;

  bool get esRey => valor == 13;

  String get nombreValor => switch (valor) {
    1 => 'A',
    11 => 'J',
    12 => 'Q',
    13 => 'K',
    _ => '$valor',
  };

  String get simboloPalo => simbolosPalo[palo];

  /// Lo que lee el lector de pantalla: el símbolo del palo no se lee bien.
  String get nombreLeido {
    final v = switch (valor) {
      1 => 'As',
      11 => 'Jota',
      12 => 'Reina',
      13 => 'Rey',
      _ => '$valor',
    };
    return '$v de ${nombresPalo[palo]}';
  }
}

/// Regla de un valor. Reutiliza [AccionRuleta] para el texto con sorbos, así
/// "sin alcohol" y el tope de seguridad se comportan igual en todo el juego.
class ReglaRey {
  const ReglaRey(this.titulo, this.plantilla, [this.sorbos = 0]);
  final String titulo;
  final String plantilla;
  final int sorbos;

  String texto({required bool sinAlcohol}) =>
      AccionRuleta(plantilla, sorbos).texto(sinAlcohol: sinAlcohol);
}

/// Reglas por valor (índice = valor - 1). Textos de menos de 140 caracteres,
/// sin personas reales ni contenido sexual.
const List<ReglaRey> reglasReyes = [
  ReglaRey('Cascada suave', 'Todos beben {sorbos}, empezando por ti.', 1),
  ReglaRey('Tú eliges', 'Elige a alguien: bebe {sorbos}.', 1),
  ReglaRey('Yo bebo', 'Bebes tú {sorbos}.', 1),
  ReglaRey('Suelo', 'Todos tocan el suelo. El último bebe {sorbos}.', 1),
  ReglaRey(
    'Pulgar',
    'Pon el pulgar en la mesa. El último en copiarte bebe {sorbos}.',
    1,
  ),
  ReglaRey(
    'Categoría',
    'Di una categoría y turnaos con ejemplos. Quien falle bebe {sorbos}.',
    2,
  ),
  ReglaRey('Cielo', 'Todos levantan la mano. El último bebe {sorbos}.', 1),
  ReglaRey(
    'Compañero',
    'Elige un compañero: cuando bebas tú, bebe también. Dura hasta el '
        'próximo 8.',
  ),
  ReglaRey(
    'Rima',
    'Di una palabra y turnaos rimando. Quien se quede sin rima bebe '
        '{sorbos}.',
    2,
  ),
  ReglaRey(
    'Nunca he',
    'Di algo que nunca has hecho. Quien sí lo haya hecho bebe {sorbos}.',
    1,
  ),
  ReglaRey(
    'Regla nueva',
    'Inventa una regla. Quien la incumpla bebe {sorbos}.',
    1,
  ),
  ReglaRey(
    'Preguntas',
    'Haz una pregunta a alguien y seguid. Quien conteste sin preguntar '
        'bebe {sorbos}.',
    2,
  ),
  ReglaRey(
    'Rey',
    'El rey manda: elige a alguien y bebe {sorbos} con esa persona.',
    2,
  ),
];

/// Regla del cuarto rey: cierra la partida.
const ReglaRey reglaUltimoRey = ReglaRey(
  'Último rey',
  'Se acabó la baraja. Brinda con todos: bebe {sorbos}.',
  3,
);

/// Una partida de Reyes. Lógica pura, sin Flutter, para poder probarla.
class PartidaReyes {
  PartidaReyes({required List<String> jugadores, Random? azar})
    : jugadores = List.unmodifiable(jugadores) {
    if (jugadores.length < minJugadoresReyes) {
      throw ArgumentError('Hacen falta al menos $minJugadoresReyes.');
    }
    _mazo = [
      for (var p = 0; p < 4; p++)
        for (var v = 1; v <= 13; v++) CartaReyes(v, p),
    ]..shuffle(azar ?? Random());
  }

  final List<String> jugadores;
  late final List<CartaReyes> _mazo;
  int _robadas = 0;
  int _reyes = 0;

  CartaReyes? actual;

  int get robadas => _robadas;
  int get reyesSalidos => _reyes;
  int get cartasRestantes => _mazo.length - _robadas;

  /// Terminan los 4 reyes. Siempre ocurre antes de agotar la baraja porque
  /// los 4 reyes están dentro de ella.
  bool get terminada => _reyes >= 4;

  /// A quién le toca: se rota por la lista en el orden en que se escribió.
  String get jugadorActual => jugadores[(_robadas - 1) % jugadores.length];

  ReglaRey get reglaActual {
    final c = actual!;
    if (c.esRey && _reyes == 4) return reglaUltimoRey;
    return reglasReyes[c.valor - 1];
  }

  /// Roba la siguiente carta. No hace nada si la partida ya terminó.
  CartaReyes? robar() {
    if (terminada) return null;
    final c = _mazo[_robadas++];
    if (c.esRey) _reyes++;
    actual = c;
    return c;
  }
}
