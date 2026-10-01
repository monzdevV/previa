import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:previa/app/tema.dart';
import 'package:previa/features/juegos/motor/impostor.dart';
import 'package:previa/features/juegos/motor/ruleta.dart';
import 'package:previa/features/juegos/pantalla_hub_juegos.dart';
import 'package:previa/features/juegos/pantalla_impostor.dart';
import 'package:previa/features/juegos/pantalla_ruleta.dart';

void main() {
  group('El impostor', () {
    test('hay un solo impostor y la palabra es de la categoría', () {
      for (var semilla = 0; semilla < 50; semilla++) {
        final r = RondaImpostor(
          jugadores: const ['Ana', 'Bea', 'Cai', 'Dan'],
          categoria: categoriasImpostor.first,
          azar: Random(semilla),
        );
        final impostores = [
          for (var i = 0; i < 4; i++)
            if (r.esImpostor(i)) i,
        ];
        expect(impostores, hasLength(1));
        expect(categoriasImpostor.first.palabras, contains(r.palabra));
        expect(r.primero, inInclusiveRange(0, 3));
      }
    });

    test('acusar al impostor acierta y a otro no', () {
      final r = RondaImpostor(
        jugadores: const ['Ana', 'Bea', 'Cai'],
        categoria: categoriasImpostor.first,
        azar: Random(1),
      );
      expect(r.acierta(r.impostor), isTrue);
      expect(r.acierta((r.impostor + 1) % 3), isFalse);
    });

    test('la palabra a evitar no se repite entre rondas', () {
      for (var semilla = 0; semilla < 50; semilla++) {
        final r = RondaImpostor(
          jugadores: const ['Ana', 'Bea', 'Cai'],
          categoria: categoriasImpostor.first,
          azar: Random(semilla),
          evitar: categoriasImpostor.first.palabras.first,
        );
        expect(r.palabra, isNot(categoriasImpostor.first.palabras.first));
      }
    });

    test('con menos de tres jugadores no se puede jugar', () {
      expect(
        () => RondaImpostor(
          jugadores: const ['Ana', 'Bea'],
          categoria: categoriasImpostor.first,
        ),
        throwsArgumentError,
      );
    });

    test('las categorías tienen palabras suficientes y sin repetir', () {
      for (final c in categoriasImpostor) {
        expect(c.palabras.length, greaterThanOrEqualTo(10), reason: c.nombre);
        expect(c.palabras.toSet().length, c.palabras.length, reason: c.nombre);
      }
    });
  });

  group('La ruleta', () {
    test('el giro calculado termina en el segmento elegido', () {
      final azar = Random(7);
      for (final n in [2, 3, 5, 8, 12]) {
        for (var g = 0; g < n; g++) {
          final giro = giroHasta(
            segmentos: n,
            ganador: g,
            vueltas: 5 + azar.nextInt(3),
            dentro: azar.nextDouble(),
          );
          expect(segmentoBajoPuntero(giro, n), g, reason: 'n=$n ganador=$g');
          // Sumar vueltas enteras no cambia el resultado.
          expect(segmentoBajoPuntero(giro + 4 * pi, n), g);
        }
      }
    });

    test('las acciones respetan el tope de sorbos', () {
      for (final a in accionesRuleta) {
        expect(a.sorbos, inInclusiveRange(0, sorbosMaximosRuleta));
        if (a.sorbos > 0) expect(a.plantilla, contains('{sorbos}'));
      }
    });

    test('el texto cambia con y sin alcohol', () {
      const a = AccionRuleta('Bebe {sorbos}.', 2);
      expect(a.texto(sinAlcohol: false), 'Bebe 2 sorbos.');
      expect(a.texto(sinAlcohol: true), contains('cualquier bebida'));
      const b = AccionRuleta('Libre.');
      expect(b.texto(sinAlcohol: false), 'Libre.');
    });
  });

  group('pantallas', () {
    Widget app(Widget hijo) =>
        MaterialApp(theme: construirTemaPrevia(), home: hijo);

    testWidgets('el hub ofrece los juegos de cartas y los minijuegos', (
      t,
    ) async {
      t.view.physicalSize = const Size(800, 4000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(app(const PantallaHubJuegos(conAtras: true)));
      expect(find.text('EL IMPOSTOR'), findsOneWidget);
      expect(find.text('LA RULETA'), findsOneWidget);
      expect(find.text('¿PREFIERES...?'), findsOneWidget);
    });

    testWidgets('el impostor reparte en secreto y llega a votar', (t) async {
      await t.pumpWidget(
        app(
          const PantallaImpostor(
            jugadores: ['Ana', 'Bea', 'Cai'],
            duracionDebate: Duration(seconds: 5),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        expect(find.textContaining('PÁSALE EL MÓVIL'), findsOneWidget);
        await t.tap(find.text('Ver mi palabra'));
        await t.pump();
        expect(find.textContaining('Ocultar'), findsOneWidget);
        await t.tap(find.textContaining('Ocultar'));
        await t.pump();
      }
      expect(find.textContaining('Empieza'), findsOneWidget);
      await t.tap(find.text('Votar ya'));
      await t.pump();
      expect(find.text('¿QUIÉN ES EL IMPOSTOR?'), findsOneWidget);
      await t.tap(find.text('Ana'));
      await t.pump();
      expect(find.text('Otra ronda'), findsOneWidget);
      expect(find.textContaining('La palabra era'), findsOneWidget);
    });

    testWidgets('la ruleta gira y señala a un jugador', (t) async {
      await t.pumpWidget(
        app(
          const PantallaRuleta(
            jugadores: ['Ana', 'Bea', 'Cai'],
            duracion: Duration(milliseconds: 300),
          ),
        ),
      );
      await t.tap(find.text('Girar'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.textContaining('LE TOCA A'), findsOneWidget);
      expect(find.text('Girar otra vez'), findsOneWidget);
    });
  });
}
