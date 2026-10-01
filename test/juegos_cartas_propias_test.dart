import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:previa/app/tema.dart';
import 'package:previa/features/juegos/almacen_jugadores.dart';
import 'package:previa/features/juegos/modelo_juegos.dart';
import 'package:previa/features/juegos/motor/partida.dart';
import 'package:previa/features/juegos/pantalla_preparacion.dart';
import 'package:previa/features/juegos/repositorio_retos.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('retosPropios', () {
    test('limpia, recorta y descarta vacíos y repetidos', () {
      final r = retosPropios(TipoJuego.yoNunca, [
        '  hecho surf ',
        '',
        '   ',
        'HECHO SURF',
        'x' * 300,
      ]);
      expect(r.map((c) => c.texto).first, 'hecho surf');
      expect(r, hasLength(2));
      expect(r.last.texto.length, maxLongitudCartaPropia);
    });

    test('respeta el máximo y los ids son únicos', () {
      final r = retosPropios(TipoJuego.yoNunca, [
        for (var i = 0; i < 50; i++) 'carta $i',
      ]);
      expect(r, hasLength(maxCartasPropias));
      expect(r.map((c) => c.id).toSet(), hasLength(maxCartasPropias));
    });

    test('entran en nivel suave y con el juego pedido', () {
      final r = retosPropios(TipoJuego.masProbable, ['llegue tarde']);
      expect(r.single.nivel, NivelReto.suave);
      expect(r.single.juego, TipoJuego.masProbable);
    });

    test('el motor acepta las cartas propias en la baraja', () {
      final retos = retosPropios(TipoJuego.yoNunca, ['hecho surf']);
      final p = Partida(
        config: const ConfiguracionPartida(
          juego: TipoJuego.yoNunca,
          jugadores: ['Ana', 'Bea'],
        ),
        retos: retos,
      );
      expect(p.textoMostrado, 'Yo nunca hecho surf');
    });
  });

  test('el almacén guarda y recuerda las cartas por juego', () async {
    await AlmacenJugadores.guardarCartasPropias(TipoJuego.yoNunca, ['a', 'b']);
    expect(await AlmacenJugadores.leerCartasPropias(TipoJuego.yoNunca), [
      'a',
      'b',
    ]);
    expect(
      await AlmacenJugadores.leerCartasPropias(TipoJuego.masProbable),
      isEmpty,
    );
  });

  testWidgets('se añade una carta en la preparación y se recuerda', (t) async {
    t.view.physicalSize = const Size(900, 2400);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: construirTemaPrevia(),
        home: const PantallaPreparacion(juego: TipoJuego.yoNunca),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Añade tus propias cartas'));
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextField, 'Nueva carta'),
      'hecho surf',
    );
    await t.tap(find.byTooltip('Añadir carta'));
    await t.pumpAndSettle();
    expect(find.text('Tus cartas (1)'), findsOneWidget);
    expect(find.text('hecho surf'), findsOneWidget);
    expect(await AlmacenJugadores.leerCartasPropias(TipoJuego.yoNunca), [
      'hecho surf',
    ]);

    await t.tap(find.byTooltip('Quitar la carta'));
    await t.pumpAndSettle();
    expect(find.text('Añade tus propias cartas'), findsOneWidget);
    expect(
      await AlmacenJugadores.leerCartasPropias(TipoJuego.yoNunca),
      isEmpty,
    );
  });
}
