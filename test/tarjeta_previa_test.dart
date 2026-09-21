import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:previa/app/tema.dart';
import 'package:previa/features/auth/pantalla_bienvenida.dart';
import 'package:previa/features/party/tarjeta_previa.dart';

import 'apoyo_visual.dart';

void main() {
  setUpAll(() async {
    await cargarTipografias();
    await initializeDateFormatting('es_ES');
  });

  testWidgets('la tarjeta distingue las tres condiciones de ocupacion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final muestras = previasDeMuestra();

    await tester.pumpWidget(
      MaterialApp(
        theme: temaDePrueba(),
        home: Scaffold(
          body: ListView.separated(
            padding: const EdgeInsets.all(EspaciadoPrevia.m),
            itemCount: muestras.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: EspaciadoPrevia.m),
            itemBuilder: (_, i) => TarjetaPrevia(previa: muestras[i]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ListView),
      matchesGoldenFile('goldens/tarjetas_previa.png'),
    );
  });

  testWidgets('la bienvenida abre con la marca y la accion principal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: temaDePrueba(), home: const PantallaBienvenida()),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PantallaBienvenida),
      matchesGoldenFile('goldens/bienvenida.png'),
    );
  });

  test('la ocupacion se deriva solo de las plazas libres', () {
    expect(Ocupacion.desde(5), Ocupacion.abierta);
    expect(Ocupacion.desde(2), Ocupacion.llenandose);
    expect(Ocupacion.desde(1), Ocupacion.llenandose);
    expect(Ocupacion.desde(0), Ocupacion.completa);
    expect(Ocupacion.desde(0).viva, isFalse);
    expect(Ocupacion.desde(3).viva, isTrue);
  });
}
