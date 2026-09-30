import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:previa/app/tema.dart';
import 'package:previa/data/models/previa.dart';
import 'package:previa/features/party/componentes_previa.dart';
import 'package:previa/features/party/hoja_solicitar_plaza.dart';
import 'package:previa/features/party/tarjeta_previa.dart';

Previa _previa({List<String> ambiente = const ['techno', 'terraza']}) => Previa(
      id: 'p1',
      titulo: 'Previa con un título bastante largo para forzar dos líneas',
      zona: 'Malasaña',
      ubicacion: const LatLng(40.42, -3.70),
      empiezaEn: DateTime.now().add(const Duration(hours: 3)),
      plazasLibres: 4,
      anfitrionId: 'h',
      anfitrionNombre: 'Lucía',
      descripcion: 'Sitio de sobra y altavoz.',
      ambiente: ambiente,
      distanciaMetros: 450,
    );

Widget _app(Widget hijo, {double texto = 1}) => ProviderScope(
      child: MaterialApp(
        theme: construirTemaPrevia(),
        builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(texto)),
          child: w!,
        ),
        home: Scaffold(body: SingleChildScrollView(child: hijo)),
      ),
    );

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  test('el estilo de ambiente usa la primera etiqueta conocida o el de marca', () {
    expect(estiloDeAmbiente(['zzz', 'techno']).icono, Icons.graphic_eq);
    expect(estiloDeAmbiente(const []).icono, Icons.nightlife);
  });

  testWidgets('la tarjeta con texto al 200 % no desborda', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(
      TarjetaPrevia(previa: _previa(), onTap: () {}),
      texto: 2,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('4 plazas'), findsOneWidget);
  });

  testWidgets('la hoja de solicitar: +/- respeta el tope de plazas', (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(Builder(
      builder: (c) => TextButton(
        onPressed: () =>
            mostrarHojaSolicitarPlaza(c, previaId: 'p1', plazasLibres: 2),
        child: const Text('abrir'),
      ),
    )));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Pedir mi plaza'), findsOneWidget);
    await tester.tap(find.byTooltip('Una persona más'));
    await tester.pumpAndSettle();
    expect(find.text('Pedir 2 plazas'), findsOneWidget);

    // Con 2 plazas libres no se puede pasar de 2.
    final mas = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add));
    expect(mas.onPressed, isNull);

    await tester.tap(find.byTooltip('Una persona menos'));
    await tester.pumpAndSettle();
    expect(find.text('Pedir mi plaza'), findsOneWidget);
  });
}
