import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:previa/app/tema.dart';
import 'package:previa/data/models/previa.dart';
import 'package:previa/features/chat/pantalla_chat.dart';
import 'package:previa/features/ratings/pantalla_valorar.dart';
import 'package:previa/features/requests/piezas_solicitudes.dart';
import 'package:previa/data/models/perfil.dart';
import 'package:previa/features/profile/reputacion.dart';
import 'package:previa/features/ratings/etiquetas_valoracion.dart';

Perfil _perfil(double? media, int n) => Perfil(
      id: 'x',
      username: 'u',
      nombre: 'Ana',
      onboarded: true,
      reputacion: media,
      numeroValoraciones: n,
    );

void main() {
  test('las etiquetas se guardan y se recuperan del comentario', () {
    final c = componerComentario(['puntual', 'buen rollo'], ' Gran noche ');
    expect(c, '[puntual, buen rollo] Gran noche');
    final d = descomponerComentario(c);
    expect(d.claves, ['puntual', 'buen rollo']);
    expect(d.texto, 'Gran noche');
  });

  test('sin etiquetas el comentario queda igual y nunca pasa de 300', () {
    expect(componerComentario([], ' hola '), 'hola');
    final largo = componerComentario(['puntual'], 'a' * 400);
    expect(largo.length <= maximoComentario, isTrue);
  });

  test('insignias segun numero y media', () {
    expect(insigniasDe(_perfil(null, 0)).single.texto, 'Recién llegada');
    expect(insigniasDe(_perfil(4.6, 3)).map((i) => i.texto),
        contains('Buena compañía'));
    expect(insigniasDe(_perfil(4.8, 10)).map((i) => i.texto),
        contains('Anfitrión fiable'));
    expect(insigniasDe(_perfil(5, 1)).single.texto, 'Tomando ritmo');
  });

  mainPantallas();
}

// --- Pantallas de la zona chat, solicitudes y valoraciones -----------------

Widget _envolver(Widget hijo, {List<Override> sobrescrituras = const []}) =>
    ProviderScope(
      overrides: sobrescrituras,
      child: MaterialApp(
        theme: construirTemaPrevia(),
        home: hijo,
      ),
    );

Mensaje _msj(String autor, DateTime cuando) => Mensaje(
      id: '$autor-${cuando.millisecondsSinceEpoch}',
      previaId: 'p',
      autorId: autor,
      texto: 'hola',
      enviadoEn: cuando,
    );

void mainPantallas() {
  test('el chat agrupa rafagas del mismo autor y corta a los cinco minutos',
      () {
    final t = DateTime(2026, 10, 1, 22);
    expect(mensajesAgrupados(_msj('a', t), _msj('a', t.add(_min(2)))), isTrue);
    expect(
      mensajesAgrupados(_msj('a', t), _msj('a', t.add(_min(6)))),
      isFalse,
    );
    expect(mensajesAgrupados(_msj('a', t), _msj('b', t)), isFalse);
    // Pasada la medianoche es otro dia aunque sean dos minutos.
    final casiMedianoche = DateTime(2026, 10, 1, 23, 59);
    expect(
      mensajesAgrupados(
        _msj('a', casiMedianoche),
        _msj('a', casiMedianoche.add(_min(2))),
      ),
      isFalse,
    );
  });

  testWidgets('valorar: las etiquetas salen al puntuar y se marcan',
      (tester) async {
    await tester.pumpWidget(
      _envolver(
        const PantallaValorar(previaId: 'p'),
        sobrescrituras: [
          companerosProvider.overrideWith(
            (ref, _) async => [
              {
                'profile_id': 'u1',
                'role': 'guest',
                'profiles': {'display_name': 'Lucía', 'avatar_url': null},
              },
            ],
          ),
          misValoracionesProvider.overrideWith((ref, _) async => {}),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lucía'), findsOneWidget);
    expect(find.text('Puntual'), findsNothing);

    await tester.tap(find.byTooltip('4 estrellas para Lucía'));
    await tester.pumpAndSettle();

    expect(find.text('MUY BIEN'), findsOneWidget);
    expect(find.text('Puntual'), findsOneWidget);

    final etiqueta = find.bySemanticsLabel('Puntual');
    expect(tester.getSemantics(etiqueta), isSemantics(isToggled: false));
    await tester.tap(find.text('Puntual'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(etiqueta), isSemantics(isToggled: true));

    // Objetivos tactiles de 48 dp en estrellas y etiquetas.
    expect(
      tester.getSize(find.byTooltip('1 estrella para Lucía')).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.ancestor(
        of: find.text('Puntual'),
        matching: find.byType(AnimatedContainer),
      )).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('la pastilla de estado escribe en el color del texto del tema',
      (tester) async {
    for (final brillo in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: construirTemaPrevia(brillo: brillo),
          home: const Scaffold(
            body: PastillaEstado(texto: 'Pendiente', color: Colors.orange),
          ),
        ),
      );
      // El cambio de tema se anima: se espera a que llegue al final.
      await tester.pumpAndSettle();
      final texto = tester.widget<Text>(find.text('PENDIENTE'));
      final esperado = brillo == Brightness.dark
          ? ColoresPrevia.oscuro.texto
          : ColoresPrevia.claro.texto;
      expect(texto.style?.color, esperado);
    }
  });
}

Duration _min(int n) => Duration(minutes: n);
