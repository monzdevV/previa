import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:previa/features/juegos/datos/retos.dart';
import 'package:previa/features/juegos/modelo_juegos.dart';
import 'package:previa/features/juegos/motor/partida.dart';
import 'package:previa/features/juegos/motor/retos_de_prueba.dart';
import 'package:previa/features/juegos/repositorio_retos.dart';

Partida nueva({
  int? rondas = 10,
  List<String> jugadores = const ['Ana', 'Beto', 'Cris'],
  NivelReto nivel = NivelReto.sinFiltro,
  TipoJuego juego = TipoJuego.noHayHuevos,
  List<Reto>? retos,
  int seed = 1,
}) {
  return Partida(
    config: ConfiguracionPartida(
      juego: juego,
      jugadores: jugadores,
      nivel: nivel,
      rondas: rondas,
    ),
    retos: retos ?? retosPara(juego, nivel, fuente: retosDePrueba),
    azar: Random(seed),
  );
}

/// Responde saltando la confirmación de contacto, como haría el grupo.
void jugar(Partida p, Respuesta r) {
  if (p.contactoPendiente) p.confirmarContacto();
  p.responder(r);
}

void main() {
  group('repositorio', () {
    test('incluye niveles inferiores y filtra por juego', () {
      final suave = retosPara(
        TipoJuego.noHayHuevos,
        NivelReto.suave,
        fuente: retosDePrueba,
      );
      expect(suave.every((r) => r.nivel == NivelReto.suave), isTrue);
      final atrevido = retosPara(
        TipoJuego.noHayHuevos,
        NivelReto.atrevido,
        fuente: retosDePrueba,
      );
      expect(atrevido.any((r) => r.nivel == NivelReto.suave), isTrue);
      expect(atrevido.any((r) => r.nivel == NivelReto.atrevido), isTrue);
      expect(atrevido.any((r) => r.nivel == NivelReto.sinFiltro), isFalse);
      expect(atrevido.every((r) => r.juego == TipoJuego.noHayHuevos), isTrue);
    });

    test('el contenido real cubre todos los juegos y niveles', () {
      for (final j in TipoJuego.values) {
        expect(
          retosPara(j, NivelReto.suave, fuente: todosLosRetos),
          isNotEmpty,
        );
      }
      final ids = todosLosRetos.map((r) => r.id).toSet();
      expect(ids.length, todosLosRetos.length, reason: 'ids repetidos');
      expect(
        todosLosRetos.every((r) => r.sorbos >= 1 && r.sorbos <= 3),
        isTrue,
      );
    });
  });

  group('cartas', () {
    test('no se repite ninguna carta hasta agotar la baraja', () {
      final p = nueva(rondas: null, nivel: NivelReto.atrevido);
      final total = p.retoActual.juego == TipoJuego.noHayHuevos
          ? retosPara(
              TipoJuego.noHayHuevos,
              NivelReto.atrevido,
              fuente: retosDePrueba,
            ).length
          : 0;
      final vistas = <String>{};
      for (var i = 0; i < total; i++) {
        expect(vistas.add(p.retoActual.id), isTrue, reason: 'repetida');
        jugar(p, Respuesta.cumplido);
        if (p.pausaPendiente) p.terminarPausa();
      }
      expect(vistas.length, total);
    });

    test('al agotar la baraja no abre con la ultima carta vista', () {
      for (var seed = 0; seed < 40; seed++) {
        final p = nueva(rondas: null, nivel: NivelReto.suave, seed: seed);
        String? anterior;
        for (var i = 0; i < 30; i++) {
          expect(p.retoActual.id, isNot(anterior));
          anterior = p.retoActual.id;
          jugar(p, Respuesta.pasar);
          if (p.pausaPendiente) p.terminarPausa();
        }
      }
    });

    test('ids duplicados en la fuente solo cuentan una vez', () {
      const r = Reto(
        id: 'x',
        juego: TipoJuego.noHayHuevos,
        nivel: NivelReto.suave,
        texto: 'a',
      );
      final p = nueva(retos: [r, r, r], rondas: null);
      expect(p.retoActual.id, 'x');
    });

    test('sin retos falla con un error claro', () {
      expect(() => nueva(retos: const []), throwsArgumentError);
    });

    test('formatea el texto segun el juego', () {
      expect(
        formatearTextoCarta(TipoJuego.noHayHuevos, 'baila'),
        '¿A que no hay huevos a... baila?',
      );
      expect(
        formatearTextoCarta(TipoJuego.yoNunca, 'he ido'),
        'Yo nunca he ido',
      );
      expect(
        formatearTextoCarta(TipoJuego.masProbable, 'llegue tarde'),
        '¿Quién es más probable que llegue tarde?',
      );
      expect(
        formatearTextoCarta(TipoJuego.verdadOReto, 'Reto: canta'),
        'Reto: canta',
      );
    });
  });

  group('{otro}', () {
    test('nunca sustituye por el jugador en turno y no deja marcador', () {
      for (var seed = 0; seed < 60; seed++) {
        final p = nueva(
          rondas: null,
          seed: seed,
          retos: const [
            Reto(
              id: 'o',
              juego: TipoJuego.noHayHuevos,
              nivel: NivelReto.suave,
              texto: 'abraza a {otro} y a {otro}',
              necesitaOtraPersona: true,
            ),
            Reto(
              id: 'o2',
              juego: TipoJuego.noHayHuevos,
              nivel: NivelReto.suave,
              texto: 'saluda a {otro}',
              necesitaOtraPersona: true,
            ),
          ],
        );
        for (var i = 0; i < 6; i++) {
          final turno = p.jugadorEnTurno.nombre;
          expect(p.textoActual.contains('{otro}'), isFalse);
          expect(p.textoActual.contains(turno), isFalse);
          jugar(p, Respuesta.pasar);
          if (p.pausaPendiente) p.terminarPausa();
        }
      }
    });

    test('retos con {otro} se descartan si juega una sola persona', () {
      final p = nueva(jugadores: const ['Sola']);
      final pool = <String>{};
      for (var i = 0; i < 30; i++) {
        pool.add(p.retoActual.id);
        expect(p.retoActual.necesitaOtraPersona, isFalse);
        jugar(p, Respuesta.pasar);
        if (p.pausaPendiente) p.terminarPausa();
      }
    });
  });

  group('turnos y puntuacion', () {
    test('rota los turnos en orden', () {
      final p = nueva(rondas: null);
      final orden = <String>[];
      for (var i = 0; i < 6; i++) {
        orden.add(p.jugadorEnTurno.nombre);
        jugar(p, Respuesta.cumplido);
        if (p.pausaPendiente) p.terminarPausa();
      }
      expect(orden, ['Ana', 'Beto', 'Cris', 'Ana', 'Beto', 'Cris']);
    });

    test('cumplido suma puntos; no hay huevos bebe sorbos con tope 3', () {
      const r = Reto(
        id: 'tope',
        juego: TipoJuego.noHayHuevos,
        nivel: NivelReto.suave,
        texto: 'algo',
        sorbos: 9, // un contenido mal escrito no debe saltarse el limite
      );
      final p = nueva(retos: const [r], rondas: null);
      expect(p.sorbosActuales, Partida.sorbosMaximos);
      final bebidos = p.responder(Respuesta.noHayHuevos);
      expect(bebidos, 3);
      expect(p.jugadores[0].sorbos, 3);
      expect(p.jugadores[0].rechazos, 1);
      p.responder(Respuesta.cumplido);
      expect(p.jugadores[1].puntos, 3);
      expect(p.jugadores[1].cumplidos, 1);
    });

    test('ranking y titulos divertidos', () {
      const r = Reto(
        id: 'u',
        juego: TipoJuego.noHayHuevos,
        nivel: NivelReto.suave,
        texto: 'algo',
        sorbos: 1,
      );
      final p = nueva(retos: const [r], rondas: null);
      expect(p.valiente, isNull);
      expect(p.gallina, isNull);
      // Ana cumple, Beto rechaza, Cris rechaza; vuelta 2: Ana cumple, Beto
      // cumple, Cris rechaza.
      for (final x in [
        Respuesta.cumplido,
        Respuesta.noHayHuevos,
        Respuesta.noHayHuevos,
        Respuesta.cumplido,
        Respuesta.cumplido,
        Respuesta.noHayHuevos,
      ]) {
        p.responder(x);
        if (p.pausaPendiente) p.terminarPausa();
      }
      expect(p.ranking.first.nombre, 'Ana');
      expect(p.valiente!.nombre, 'Ana');
      expect(p.gallina!.nombre, 'Cris');
    });
  });

  group('rondas, pausas y seguridad', () {
    test('termina al llegar al limite de rondas', () {
      final p = nueva(rondas: 3);
      for (var i = 0; i < 3; i++) {
        expect(p.terminada, isFalse);
        jugar(p, Respuesta.cumplido);
      }
      expect(p.terminada, isTrue);
      expect(p.resueltas, 3);
    });

    test('pausa obligatoria cada 10 cartas y bloquea responder', () {
      final p = nueva(rondas: null);
      for (var i = 0; i < 9; i++) {
        jugar(p, Respuesta.pasar);
        expect(p.pausaPendiente, isFalse);
      }
      jugar(p, Respuesta.pasar);
      expect(p.pausaPendiente, isTrue);
      final antes = p.resueltas;
      p.responder(Respuesta.cumplido);
      expect(p.resueltas, antes, reason: 'no se juega durante la pausa');
      p.terminarPausa();
      expect(p.pausaPendiente, isFalse);
      for (var i = 0; i < 10; i++) {
        jugar(p, Respuesta.pasar);
      }
      expect(p.pausaPendiente, isTrue);
    });

    test('no pide pausa justo al terminar la partida', () {
      final p = nueva(rondas: 10);
      for (var i = 0; i < 10; i++) {
        jugar(p, Respuesta.pasar);
      }
      expect(p.terminada, isTrue);
      expect(p.pausaPendiente, isFalse);
    });

    test('contacto fisico: no se puede responder sin confirmar; saltar cambia carta', () {
      const contacto = Reto(
        id: 'c',
        juego: TipoJuego.noHayHuevos,
        nivel: NivelReto.atrevido,
        texto: 'abraza',
        contactoFisico: true,
      );
      const normal = Reto(
        id: 'n',
        juego: TipoJuego.noHayHuevos,
        nivel: NivelReto.suave,
        texto: 'canta',
      );
      final p = nueva(retos: const [contacto, normal], rondas: null);
      if (p.retoActual.id != 'c') {
        jugar(p, Respuesta.pasar); // llega a la de contacto
      }
      expect(p.retoActual.id, 'c');
      expect(p.contactoPendiente, isTrue);
      final r = p.resueltas;
      p.responder(Respuesta.cumplido);
      expect(p.resueltas, r);
      final turno = p.jugadorEnTurno;
      p.saltar();
      expect(p.retoActual.id, 'n');
      expect(p.jugadorEnTurno, turno);
      expect(p.resueltas, r);
      expect(p.contactoPendiente, isFalse);
    });

    test('parar termina conservando el marcador', () {
      final p = nueva(rondas: null);
      jugar(p, Respuesta.cumplido);
      p.parar();
      expect(p.terminada, isTrue);
      expect(p.jugadores[0].puntos, greaterThan(0));
    });
  });

  test('limpiarNombres recorta, deduplica y respeta el maximo', () {
    expect(limpiarNombres([' Ana ', 'ana', '', 'Beto']), ['Ana', 'Beto']);
    final muchos = limpiarNombres([for (var i = 0; i < 20; i++) 'J$i']);
    expect(muchos.length, maxJugadores);
  });
}
