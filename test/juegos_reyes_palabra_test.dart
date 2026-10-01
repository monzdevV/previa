import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:previa/app/tema.dart';
import 'package:previa/features/juegos/modelo_juegos.dart';
import 'package:previa/features/juegos/motor/palabra_prohibida.dart';
import 'package:previa/features/juegos/motor/reyes.dart';
import 'package:previa/features/juegos/pantalla_hub_juegos.dart';
import 'package:previa/features/juegos/pantalla_palabra_prohibida.dart';
import 'package:previa/features/juegos/pantalla_preparacion_mini.dart';
import 'package:previa/features/juegos/pantalla_reyes.dart';

void main() {
  group('Reyes (motor)', () {
    test('la baraja tiene 52 cartas distintas y 4 reyes', () {
      final p = PartidaReyes(jugadores: ['Ana', 'Bea'], azar: Random(1));
      final vistas = <String>{};
      while (!p.terminada) {
        final c = p.robar()!;
        expect(vistas.add('${c.valor}-${c.palo}'), isTrue, reason: 'repetida');
      }
      expect(p.reyesSalidos, 4);
      expect(p.robadas, lessThanOrEqualTo(52));
    });

    test('termina exactamente al salir el cuarto rey y ya no roba', () {
      for (var semilla = 0; semilla < 30; semilla++) {
        final p = PartidaReyes(
          jugadores: ['Ana', 'Bea'],
          azar: Random(semilla),
        );
        var reyes = 0;
        while (!p.terminada) {
          final c = p.robar()!;
          if (c.esRey) reyes++;
          expect(p.terminada, reyes == 4);
        }
        expect(p.actual!.esRey, isTrue);
        expect(p.reglaActual, same(reglaUltimoRey));
        expect(p.robar(), isNull);
      }
    });

    test('el turno rota entre los jugadores', () {
      final p = PartidaReyes(jugadores: ['Ana', 'Bea', 'Cai'], azar: Random(3));
      final nombres = <String>[];
      for (var i = 0; i < 4 && !p.terminada; i++) {
        p.robar();
        nombres.add(p.jugadorActual);
      }
      expect(nombres.first, 'Ana');
      if (nombres.length > 1) expect(nombres[1], 'Bea');
    });

    test('hace falta más de un jugador', () {
      expect(() => PartidaReyes(jugadores: ['Ana']), throwsArgumentError);
    });

    test('hay una regla por valor y respetan el tope de seguridad', () {
      expect(reglasReyes, hasLength(13));
      for (final r in [...reglasReyes, reglaUltimoRey]) {
        expect(r.sorbos, inInclusiveRange(0, sorbosMaximosReyes));
        if (r.sorbos > 0) expect(r.plantilla, contains('{sorbos}'));
        final conAlcohol = r.texto(sinAlcohol: false);
        final sin = r.texto(sinAlcohol: true);
        for (final t in [conAlcohol, sin, r.titulo]) {
          expect(t.length, lessThanOrEqualTo(140), reason: t);
          expect(t.toLowerCase(), isNot(contains('chupito')));
          expect(t, isNot(contains('{')));
        }
        if (r.sorbos > 0) expect(sin, contains('cualquier bebida'));
      }
    });

    test('con alcohol habla de sorbos y sin alcohol de cualquier bebida', () {
      const r = ReglaRey('Prueba', 'Bebe {sorbos}.', 1);
      expect(r.texto(sinAlcohol: false), 'Bebe 1 sorbo.');
      expect(r.texto(sinAlcohol: true), 'Bebe 1 trago de cualquier bebida.');
    });
  });

  group('Palabra prohibida (motor)', () {
    test('hay al menos 60 cartas con 4 prohibidas y sin repetirse', () {
      expect(cartasTabu.length, greaterThanOrEqualTo(60));
      final objetivos = cartasTabu.map((c) => c.objetivo.toLowerCase());
      expect(objetivos.toSet().length, cartasTabu.length);
      for (final c in cartasTabu) {
        expect(c.prohibidas, hasLength(4), reason: c.objetivo);
        expect(c.prohibidas.toSet().length, 4, reason: c.objetivo);
        expect(
          c.prohibidas.map((p) => p.toLowerCase()),
          isNot(contains(c.objetivo.toLowerCase())),
        );
        final todo = '${c.objetivo} ${c.prohibidas.join(' ')}';
        expect(todo.length, lessThanOrEqualTo(140));
      }
    });

    test('los equipos reparten a todos, parejos y sin repetir a nadie', () {
      for (final n in [4, 5, 7, 12]) {
        final js = [for (var i = 0; i < n; i++) 'J$i'];
        final e = repartirEquipos(js, Random(n));
        expect(e, hasLength(2));
        expect([...e[0], ...e[1]]..sort(), [...js]..sort());
        expect((e[0].length - e[1].length).abs(), lessThanOrEqualTo(1));
      }
    });

    test('hacen falta 4 jugadores', () {
      expect(
        () => PartidaTabu(jugadores: ['A', 'B', 'C']),
        throwsArgumentError,
      );
    });

    test('marcador, turnos alternos y fin tras las rondas', () {
      final p = PartidaTabu(
        jugadores: ['A', 'B', 'C', 'D'],
        rondas: 2,
        azar: Random(5),
      );
      expect(p.turnosTotales, 4);
      expect(p.equipoActual, 0);
      p.empezarTurno();
      p.acierto();
      p.acierto();
      p.pasar();
      p.tabu();
      expect(p.puntos, [1, 0]);
      expect([p.aciertosTurno, p.tabusTurno, p.pasadasTurno], [2, 1, 1]);
      p.terminarTurno();
      expect(p.equipoActual, 1);
      expect(p.ronda, 1);
      p.empezarTurno();
      // Un tabú con 0 puntos no deja el marcador en negativo.
      p.tabu();
      expect(p.puntos, [1, 0]);
      p.terminarTurno();
      expect(p.ronda, 2);
      expect(p.terminada, isFalse);
      p.empezarTurno();
      expect(p.esUltimoTurno, isFalse);
      p.terminarTurno();
      expect(p.esUltimoTurno, isTrue);
      p.empezarTurno();
      p.terminarTurno();
      expect(p.terminada, isTrue);
      expect(p.ganador, 0);
    });

    test('las cartas no se repiten dentro de un turno largo', () {
      final p = PartidaTabu(jugadores: ['A', 'B', 'C', 'D'], azar: Random(2));
      p.empezarTurno();
      final vistas = <String>{p.carta!.objetivo};
      for (var i = 0; i < 40; i++) {
        p.pasar();
        expect(vistas.add(p.carta!.objetivo), isTrue);
      }
    });
  });

  group('pantallas', () {
    Widget app(Widget hijo, {double escala = 1}) => MaterialApp(
      theme: construirTemaPrevia(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
      home: hijo,
    );

    testWidgets('el hub ofrece Reyes y Palabra prohibida', (t) async {
      t.view.physicalSize = const Size(800, 6000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(app(const PantallaHubJuegos(conAtras: true)));
      expect(find.text('REYES'), findsOneWidget);
      expect(find.text('PALABRA PROHIBIDA'), findsOneWidget);
    });

    testWidgets('la preparación exige 4 jugadores en Palabra prohibida', (
      t,
    ) async {
      await t.pumpWidget(
        app(
          const PantallaPreparacionMini(
            juego: MiniJuego.palabraProhibida,
            jugadoresIniciales: ['Ana', 'Bea', 'Cai'],
          ),
        ),
      );
      await t.pump();
      expect(find.textContaining('al menos 4 jugadores'), findsOneWidget);
      expect(find.text('Rondas'), findsOneWidget);
      final boton = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Empezar'),
      );
      expect(boton.onPressed, isNull);
    });

    testWidgets('Reyes roba cartas hasta el cuarto rey', (t) async {
      await t.pumpWidget(
        app(
          PantallaReyes(
            jugadores: const ['Ana', 'Bea'],
            sinAlcohol: true,
            azar: Random(4),
          ),
        ),
      );
      expect(find.text('Robar carta'), findsOneWidget);
      var pasos = 0;
      while (find.text('Otra partida').evaluate().isEmpty && pasos < 60) {
        await t.tap(find.byType(FilledButton).first);
        await t.pump();
        pasos++;
      }
      expect(find.text('Otra partida'), findsOneWidget);
      expect(find.textContaining('Reyes: 4 de 4'), findsOneWidget);
      await t.tap(find.text('Otra partida'));
      await t.pump();
      expect(find.text('Robar carta'), findsOneWidget);
    });

    testWidgets('Reyes sin alcohol dice cualquier bebida', (t) async {
      await t.pumpWidget(
        app(
          PantallaReyes(
            jugadores: const ['Ana', 'Bea'],
            sinAlcohol: true,
            azar: Random(9),
          ),
        ),
      );
      // Se roba hasta encontrar una regla con bebida (casi todas la tienen).
      for (var i = 0; i < 10; i++) {
        await t.tap(find.byType(FilledButton).first);
        await t.pump();
        if (find.textContaining('cualquier bebida').evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.textContaining('cualquier bebida'), findsOneWidget);
      expect(find.textContaining('sorbo'), findsNothing);
    });

    testWidgets('Reyes con texto al 200% no desborda', (t) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        app(
          PantallaReyes(jugadores: const ['Ana', 'Bea'], azar: Random(4)),
          escala: 2,
        ),
      );
      await t.tap(find.text('Robar carta'));
      await t.pump();
      expect(t.takeException(), isNull);
    });

    testWidgets('Palabra prohibida: turno, marcador y final', (t) async {
      await t.pumpWidget(
        app(
          PantallaPalabraProhibida(
            jugadores: const ['Ana', 'Bea', 'Cai', 'Dan'],
            rondas: 1,
            duracionTurno: const Duration(seconds: 3),
            azar: Random(6),
          ),
        ),
      );
      expect(find.textContaining('TURNO DEL EQUIPO A'), findsOneWidget);
      await t.tap(find.text('Empezar turno'));
      await t.pump();
      expect(find.text('No puedes decir:'), findsOneWidget);
      await t.tap(find.text('Acierto'));
      await t.pump();
      await t.tap(find.text('Pasar'));
      await t.pump();
      await t.pump(const Duration(seconds: 3));
      expect(find.text('¡TIEMPO!'), findsOneWidget);
      expect(find.textContaining('1 acierto ·'), findsOneWidget);
      await t.tap(find.text('Siguiente'));
      await t.pump();
      expect(find.textContaining('TURNO DEL EQUIPO B'), findsOneWidget);
      await t.tap(find.text('Empezar turno'));
      await t.pump();
      await t.tap(find.text('Tabú'));
      await t.pump();
      await t.pump(const Duration(seconds: 3));
      expect(find.text('Ver resultado'), findsOneWidget);
      await t.tap(find.text('Ver resultado'));
      await t.pump();
      expect(find.text('¡GANA EL EQUIPO A!'), findsOneWidget);
      expect(find.text('Otra partida'), findsOneWidget);
    });

    testWidgets('Palabra prohibida con texto al 200% y botones >= 48 dp', (
      t,
    ) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        app(
          PantallaPalabraProhibida(
            jugadores: const ['Ana', 'Bea', 'Cai', 'Dan'],
            rondas: 1,
            azar: Random(6),
          ),
          escala: 2,
        ),
      );
      await t.tap(find.text('Empezar turno'));
      await t.pump();
      for (final b in ['Acierto', 'Pasar', 'Tabú']) {
        final alto = t
            .getSize(
              find.ancestor(
                of: find.text(b),
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              ),
            )
            .height;
        expect(alto, greaterThanOrEqualTo(48), reason: b);
      }
      expect(t.takeException(), isNull);
      // Se sale con el cronómetro en marcha: hay que dejarlo limpio.
      await t.pumpWidget(const SizedBox());
    });
  });
}
