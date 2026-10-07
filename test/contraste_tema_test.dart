import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:previa/app/tema.dart';

/// Ratio de contraste WCAG 2.1 entre dos colores opacos.
double _contraste(Color a, Color b) {
  double luminancia(Color c) {
    double canal(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
  }

  final la = luminancia(a);
  final lb = luminancia(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Fija el contraste de la paleta en los DOS temas para que un cambio futuro
/// no deje texto por debajo de AA sin que nadie se de cuenta. Viene de la
/// auditoria de GitHub, adaptado a los tokens de lib/app/colores.dart.
void main() {
  const temas = {
    'oscuro': (ColoresPrevia.oscuro, Brightness.dark),
    'claro': (ColoresPrevia.claro, Brightness.light),
  };

  for (final MapEntry(key: nombre, value: (c, brillo)) in temas.entries) {
    final fondos = {
      'fondo': c.fondo,
      'superficie': c.superficie,
      'superficieAlta': c.superficieAlta,
    };

    group('Tema $nombre · texto (AA, 4,5:1)', () {
      final textos = {
        'texto': c.texto,
        'textoSuave': c.textoSuave,
        'textoTenue': c.textoTenue,
        'primarioTexto': c.primarioTexto,
        'error': c.error,
        'acento': c.acento,
        'aviso': c.aviso,
      };
      for (final t in textos.entries) {
        for (final f in fondos.entries) {
          test('${t.key} sobre ${f.key}', () {
            expect(_contraste(t.value, f.value), greaterThanOrEqualTo(4.5));
          });
        }
      }

      test('negro sobre el amarillo y sobre el verde', () {
        expect(
          _contraste(c.sobrePrimario, c.primario),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contraste(c.sobrePrimario, c.disponible),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('lo que va encima del error', () {
        final tema = construirTemaPrevia(brillo: brillo);
        expect(
          _contraste(tema.colorScheme.onError, tema.colorScheme.error),
          greaterThanOrEqualTo(4.5),
        );
      });
    });

    group('Tema $nombre · controles (WCAG 1.4.11, 3:1)', () {
      test('el borde de los campos se distingue del fondo y la superficie', () {
        expect(_contraste(c.bordeCampo, c.fondo), greaterThanOrEqualTo(3));
        expect(_contraste(c.bordeCampo, c.superficie), greaterThanOrEqualTo(3));
      });

      test('el tema usa ese borde en los campos de texto', () {
        final tema = construirTemaPrevia(brillo: brillo);
        final borde =
            tema.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
        expect(borde.borderSide.color, c.bordeCampo);
      });

      test('el foco del campo se ve (3:1)', () {
        expect(
          _contraste(c.primarioTexto, c.superficie),
          greaterThanOrEqualTo(3),
        );
      });
    });
  }

  group('Bloques de color', () {
    const nombres = ['amarillo', 'menta', 'azul', 'rojo', 'lila'];
    for (final (i, bloque) in BloquesPrevia.todos.indexed) {
      test('tinta sobre el bloque ${nombres[i]}', () {
        expect(
          _contraste(BloquesPrevia.tintaSobreBloque, bloque),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });

  group('Objetivos táctiles y foco', () {
    for (final brillo in Brightness.values) {
      test('el tema ${brillo.name} fija 48 dp y densidad estándar', () {
        final tema = construirTemaPrevia(brillo: brillo);
        expect(tema.materialTapTargetSize, MaterialTapTargetSize.padded);
        expect(tema.visualDensity, VisualDensity.standard);
        for (final estilo in [
          tema.textButtonTheme.style!,
          tema.iconButtonTheme.style!,
        ]) {
          final minimo = estilo.minimumSize!.resolve({})!;
          expect(minimo.height, greaterThanOrEqualTo(48));
        }
        expect(
          tema.filledButtonTheme.style!.minimumSize!.resolve({})!.height,
          greaterThanOrEqualTo(48),
        );
      });

      test('los botones del tema ${brillo.name} pintan anillo con foco', () {
        final tema = construirTemaPrevia(brillo: brillo);
        for (final estilo in [
          tema.filledButtonTheme.style!,
          tema.outlinedButtonTheme.style!,
          tema.textButtonTheme.style!,
        ]) {
          final conFoco = estilo.side!.resolve({WidgetState.focused})!;
          expect(conFoco.width, greaterThanOrEqualTo(2));
        }
      });
    }
  });

  testWidgets('Pulsable responde al teclado y enseña el foco', (t) async {
    var pulsado = 0;
    final foco = FocusNode();
    addTearDown(foco.dispose);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    await t.pumpWidget(
      MaterialApp(
        theme: construirTemaPrevia(),
        home: Center(
          child: Focus(
            focusNode: foco,
            skipTraversal: true,
            child: Pulsable(
              onTap: () => pulsado++,
              child: const SizedBox.square(dimension: 48),
            ),
          ),
        ),
      ),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(
      find.byWidgetPredicate(
        (w) => w is DecoratedBox && w.position == DecorationPosition.foreground,
      ),
      findsOneWidget,
    );
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(pulsado, 1);
  });
}
