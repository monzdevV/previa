import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:previa/app/tema.dart';

/// Ratio de contraste WCAG 2.1 entre dos colores opacos.
double _contraste(Color a, Color b) {
  double luminancia(Color c) {
    double canal(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
  }

  final la = luminancia(a);
  final lb = luminancia(b);
  final claro = math.max(la, lb);
  final oscuro = math.min(la, lb);
  return (claro + 0.05) / (oscuro + 0.05);
}

/// Estos tests fijan el contraste del tema para que un cambio futuro de
/// paleta no vuelva a dejar el texto secundario por debajo de AA sin que nadie
/// se dé cuenta (la auditoría lo encontró en ~3,5:1).
void main() {
  const fondos = {
    'fondo': ColoresPrevia.fondo,
    'superficie': ColoresPrevia.superficie,
    'superficieAlta': ColoresPrevia.superficieAlta,
  };

  group('Texto (AA, 4,5:1)', () {
    for (final entrada in fondos.entries) {
      test('textoTenue sobre ${entrada.key}', () {
        expect(_contraste(ColoresPrevia.textoTenue, entrada.value),
            greaterThanOrEqualTo(4.5));
      });
      test('textoSuave sobre ${entrada.key}', () {
        expect(_contraste(ColoresPrevia.textoSuave, entrada.value),
            greaterThanOrEqualTo(4.5));
      });
      test('texto sobre ${entrada.key}', () {
        expect(_contraste(ColoresPrevia.texto, entrada.value),
            greaterThanOrEqualTo(4.5));
      });
    }

    test('blanco sobre el botón principal', () {
      expect(_contraste(Colors.white, ColoresPrevia.primario),
          greaterThanOrEqualTo(4.5));
    });

    test('error sobre el fondo', () {
      expect(_contraste(ColoresPrevia.error, ColoresPrevia.fondo),
          greaterThanOrEqualTo(4.5));
    });
  });

  group('Componentes de interfaz (WCAG 1.4.11, 3:1)', () {
    test('el borde de los campos se distingue del fondo y de la superficie', () {
      expect(_contraste(ColoresPrevia.bordeCampo, ColoresPrevia.fondo),
          greaterThanOrEqualTo(3));
      expect(_contraste(ColoresPrevia.bordeCampo, ColoresPrevia.superficie),
          greaterThanOrEqualTo(3));
    });

    test('el tema usa ese borde en los campos de texto', () {
      final tema = construirTemaPrevia();
      final borde = tema.inputDecorationTheme.enabledBorder as OutlineInputBorder;
      expect(borde.borderSide.color, ColoresPrevia.bordeCampo);
    });
  });

  group('Objetivos táctiles', () {
    test('el tema fija 48 dp y densidad estándar', () {
      final tema = construirTemaPrevia();
      expect(tema.materialTapTargetSize, MaterialTapTargetSize.padded);
      expect(tema.visualDensity, VisualDensity.standard);
      final minimo = tema.textButtonTheme.style!.minimumSize!.resolve({});
      expect(minimo!.height, greaterThanOrEqualTo(48));
    });
  });
}
