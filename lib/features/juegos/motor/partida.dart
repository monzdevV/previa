import 'dart:math';

import '../modelo_juegos.dart';

/// Lo que puede hacer el jugador en turno con la carta.
enum Respuesta { cumplido, noHayHuevos, pasar }

/// Un jugador y sus cuentas. Es mutable a propósito: el motor es el único que
/// lo toca y así no se reconstruye la lista en cada carta.
class Jugador {
  Jugador(this.nombre);
  final String nombre;
  int puntos = 0;
  int cumplidos = 0;
  int rechazos = 0;
  int sorbos = 0;
}

/// Límites del grupo. 12 es lo que cabe en un sofá; 2 es lo mínimo para que
/// "otra persona" y el ranking tengan sentido.
const int minJugadores = 2;
const int maxJugadores = 12;
const int maxLongitudNombre = 16;

/// Limpia una lista de nombres: recorta, descarta vacíos y repetidos
/// (sin distinguir mayúsculas) y respeta el máximo. Vive aquí para que
/// preparación, persistencia y motor usen exactamente la misma regla.
List<String> limpiarNombres(Iterable<String> nombres) {
  final vistos = <String>{};
  final salida = <String>[];
  for (final crudo in nombres) {
    var n = crudo.trim();
    if (n.length > maxLongitudNombre) n = n.substring(0, maxLongitudNombre);
    if (n.isEmpty || !vistos.add(n.toLowerCase())) continue;
    salida.add(n);
    if (salida.length == maxJugadores) break;
  }
  return salida;
}

/// Fórmula de cada juego delante del texto guardado en [Reto.texto].
String formatearTextoCarta(TipoJuego juego, String texto) => switch (juego) {
  TipoJuego.noHayHuevos => '¿A que no hay huevos a... $texto?',
  TipoJuego.yoNunca => 'Yo nunca $texto',
  TipoJuego.masProbable => '¿Quién es más probable que $texto?',
  TipoJuego.verdadOReto => texto,
  TipoJuego.preferirias => '¿Prefieres $texto?',
};

class ConfiguracionPartida {
  const ConfiguracionPartida({
    required this.juego,
    required this.jugadores,
    this.nivel = NivelReto.suave,
    this.rondas = 10,
    this.sinAlcohol = false,
  });

  final TipoJuego juego;
  final List<String> jugadores;
  final NivelReto nivel;

  /// Cartas a jugar; `null` = sin límite (se para cuando el grupo quiera).
  final int? rondas;
  final bool sinAlcohol;
}

extension TipoJuegoPuntua on TipoJuego {
  /// Solo estos juegos tienen "cumplir o rechazar" y por tanto marcador.
  /// En Yo nunca o Más probable beben otros, no el jugador en turno.
  bool get puntua =>
      this == TipoJuego.noHayHuevos || this == TipoJuego.verdadOReto;
}

/// Motor de una partida: lógica pura, sin Flutter, para poder probarla sin
/// pantallas. La UI solo pregunta estado y llama a los métodos.
class Partida {
  Partida({
    required this.config,
    required List<Reto> retos,
    Random? azar,
    this.cartasEntrePausas = 10,
  }) : _azar = azar ?? Random() {
    // Por id: si el contenido trajera duplicados, no deben salir dos veces.
    final porId = <String, Reto>{};
    for (final r in retos) {
      // Red de seguridad: ni otro juego ni un nivel superior al elegido.
      if (r.juego != config.juego || r.nivel.index > config.nivel.index) {
        continue;
      }
      // Un reto con {otro} no se puede jugar a solas.
      if (r.necesitaOtraPersona && config.jugadores.length < 2) continue;
      porId.putIfAbsent(r.id, () => r);
    }
    _retos = porId.values.toList();
    if (_retos.isEmpty) {
      throw ArgumentError('No hay retos para esta partida.');
    }
    if (config.jugadores.isEmpty) {
      throw ArgumentError('Hacen falta jugadores.');
    }
    jugadores = config.jugadores.map(Jugador.new).toList();
    _robar();
  }

  /// Tope de seguridad: nunca más de 3 sorbos, diga lo que diga la carta.
  static const int sorbosMaximos = 3;

  final ConfiguracionPartida config;
  final int cartasEntrePausas;
  final Random _azar;
  late final List<Reto> _retos;
  late final List<Jugador> jugadores;

  final List<Reto> _cola = [];
  String? _ultimoId;

  int _turno = 0;
  late Reto _reto;
  late String _texto;
  bool _contactoPendiente = false;
  bool _pausaPendiente = false;
  bool _terminada = false;
  int _resueltas = 0;
  int _version = 0;

  Reto get retoActual => _reto;

  /// Texto ya con {otro} sustituido.
  String get textoActual => _texto;

  /// Texto tal y como se lee en la carta. El contenido guarda solo la parte
  /// variable (convención del fichero de datos), así que aquí se antepone la
  /// fórmula de cada juego. Verdad o reto ya viene completo.
  String get textoMostrado => formatearTextoCarta(config.juego, _texto);

  Jugador get jugadorEnTurno => jugadores[_turno];
  bool get contactoPendiente => _contactoPendiente;
  bool get pausaPendiente => _pausaPendiente;
  bool get terminada => _terminada;

  /// Cartas ya resueltas (las saltadas por contacto no cuentan).
  int get resueltas => _resueltas;

  /// Cambia con cada carta nueva o cada revelado; la UI lo usa como clave
  /// para animar el giro.
  int get version => _version;

  /// Número de carta actual, empezando en 1.
  int get ronda => min(_resueltas + 1, config.rondas ?? _resueltas + 1);

  /// Sorbos reales de la carta actual, con el tope de seguridad aplicado.
  int get sorbosActuales => _reto.sorbos.clamp(1, sorbosMaximos);

  void _robar() {
    if (_cola.isEmpty) _rebarajar();
    _reto = _cola.removeLast();
    _ultimoId = _reto.id;
    _texto = _componer(_reto);
    _contactoPendiente = _reto.contactoFisico;
    _version++;
  }

  void _rebarajar() {
    final nueva = List<Reto>.of(_retos)..shuffle(_azar);
    // Al agotar la baraja, la última carta vista no debe abrir la siguiente.
    // Se roba por el final de la lista, así que es ahí donde se vigila.
    if (nueva.length > 1 && nueva.last.id == _ultimoId) {
      final t = nueva.first;
      nueva[0] = nueva.last;
      nueva[nueva.length - 1] = t;
    }
    _cola.addAll(nueva);
  }

  String _componer(Reto r) {
    if (!r.texto.contains('{otro}')) return r.texto;
    final candidatos = [
      for (var i = 0; i < jugadores.length; i++)
        if (i != _turno) jugadores[i].nombre,
    ];
    final otro = candidatos.isEmpty
        ? 'alguien'
        : candidatos[_azar.nextInt(candidatos.length)];
    return r.texto.replaceAll('{otro}', otro);
  }

  /// El grupo ha dicho que sí al contacto físico: se enseña la carta.
  void confirmarContacto() {
    if (!_contactoPendiente) return;
    _contactoPendiente = false;
    _version++;
  }

  /// El grupo no está de acuerdo: otra carta, mismo jugador, sin penalizar.
  void saltar() {
    if (_terminada || _pausaPendiente) return;
    _robar();
  }

  /// Aplica la respuesta y avanza. Devuelve los sorbos que toca beber.
  int responder(Respuesta respuesta) {
    if (_terminada || _pausaPendiente || _contactoPendiente) return 0;
    final j = jugadorEnTurno;
    var sorbos = 0;
    switch (respuesta) {
      case Respuesta.cumplido:
        j.cumplidos++;
        // Más riesgo, más puntos: una carta de 3 sorbos vale 3.
        j.puntos += sorbosActuales;
      case Respuesta.noHayHuevos:
        j.rechazos++;
        sorbos = sorbosActuales;
        j.sorbos += sorbos;
      case Respuesta.pasar:
        break;
    }
    _resueltas++;
    final limite = config.rondas;
    if (limite != null && _resueltas >= limite) {
      _terminada = true;
      _version++;
      return sorbos;
    }
    _turno = (_turno + 1) % jugadores.length;
    _robar();
    // Pausa tras cada bloque de cartas; no se pide justo al acabar (arriba).
    if (_resueltas % cartasEntrePausas == 0) _pausaPendiente = true;
    return sorbos;
  }

  void terminarPausa() {
    if (!_pausaPendiente) return;
    _pausaPendiente = false;
    _version++;
  }

  /// Cierra la partida ya ("Parar"): sin juicio y conservando el marcador.
  void parar() {
    _terminada = true;
    _pausaPendiente = false;
    _version++;
  }

  /// Orden del marcador: más puntos primero; a igualdad, menos rechazos.
  List<Jugador> get ranking {
    final l = List<Jugador>.of(jugadores);
    l.sort((a, b) {
      final p = b.puntos.compareTo(a.puntos);
      if (p != 0) return p;
      final r = a.rechazos.compareTo(b.rechazos);
      if (r != 0) return r;
      return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    });
    return l;
  }

  /// "Valiente del día": el que más puntos suma (si alguien ha sumado).
  Jugador? get valiente {
    final r = ranking.first;
    return r.puntos > 0 ? r : null;
  }

  /// "La gallina de la noche": quien más ha dicho "No hay huevos", sin ser
  /// a la vez el valiente (los dos títulos en una persona no tienen gracia).
  Jugador? get gallina {
    final v = valiente;
    final l = jugadores.where((j) => j.rechazos > 0 && j != v).toList()
      ..sort((a, b) {
        final r = b.rechazos.compareTo(a.rechazos);
        return r != 0 ? r : a.puntos.compareTo(b.puntos);
      });
    return l.isEmpty ? null : l.first;
  }
}
