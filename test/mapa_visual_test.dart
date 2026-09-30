import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:previa/app/tema.dart';
import 'package:previa/data/models/previa.dart';
import 'package:previa/features/map/agrupacion_mapa.dart';
import 'package:previa/features/map/esqueleto_carga.dart';
import 'package:previa/features/map/filtros_rapidos.dart';
import 'package:previa/features/map/pantalla_mapa.dart';
import 'package:previa/features/map/proveedores_mapa.dart';

const _centro = LatLng(40.4168, -3.7038);

Previa _previa(String id, LatLng donde) => Previa(
      id: id,
      titulo: 'Previa $id',
      zona: 'Centro',
      ubicacion: donde,
      empiezaEn: DateTime.now().add(const Duration(hours: 1)),
      plazasLibres: 2,
      anfitrionId: 'a',
      anfitrionNombre: 'Ana',
    );

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  group('agruparPrevias', () {
    final cercanas = [
      for (var i = 0; i < 4; i++)
        _previa('c$i', LatLng(_centro.latitude + i * 0.0001, _centro.longitude)),
    ];

    test('junta las cercanas cuando el zoom es bajo', () {
      final grupos = agruparPrevias(cercanas, 13);
      expect(grupos, hasLength(1));
      expect(grupos.single.previas, hasLength(4));
    });

    test('no agrupa al acercarse', () {
      expect(agruparPrevias(cercanas, 16), hasLength(4));
    });

    test('no agrupa si hay menos del minimo', () {
      expect(agruparPrevias(cercanas.take(2).toList(), 12), hasLength(2));
    });

    test('las lejanas quedan sueltas', () {
      final lejos = [
        ...cercanas.take(2),
        _previa('x', const LatLng(41.4, -3.7)),
        _previa('y', const LatLng(39.4, -3.7)),
      ];
      expect(agruparPrevias(lejos, 13), hasLength(4));
    });
  });

  group('FiltrosRapidos', () {
    testWidgets('Ahora y Cerca cambian los filtros y se pueden deshacer',
        (tester) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: construirTemaPrevia(),
          home: const Scaffold(body: FiltrosRapidos()),
        ),
      ));
      final contenedor = ProviderScope.containerOf(
          tester.element(find.byType(FiltrosRapidos)));

      await tester.tap(find.text('Ahora'));
      await tester.pump();
      expect(contenedor.read(filtrosProvider).horas, FiltrosRapidos.horasAhora);
      await tester.tap(find.text('Ahora'));
      await tester.pump();
      expect(contenedor.read(filtrosProvider).hayFiltrosAparteDelRadio, isFalse);

      await tester.tap(find.text('Cerca'));
      await tester.pump();
      expect(contenedor.read(filtrosProvider).radioMetros,
          FiltrosRapidos.radioCerca);

      await tester.ensureVisible(find.text('techno'));
      await tester.tap(find.text('techno'));
      await tester.pump();
      expect(contenedor.read(filtrosProvider).ambiente, {'techno'});
    });

    testWidgets('los chips miden al menos 48 dp de alto', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: construirTemaPrevia(),
          home: const Scaffold(body: FiltrosRapidos()),
        ),
      ));
      final chip = tester.getSize(find.byType(FilterChip).first);
      expect(chip.height, greaterThanOrEqualTo(48));
    });
  });

  testWidgets('el esqueleto se anuncia como "Cargando"', (tester) async {
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: construirTemaPrevia(),
      home: const Scaffold(body: EsqueletoPrevias()),
    ));
    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
    // Desmontar detiene la animacion infinita antes de terminar el test.
    await tester.pumpWidget(const SizedBox());
    semantica.dispose();
  });

  testWidgets('con muchas previas cercanas el mapa muestra un grupo',
      (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantica = tester.ensureSemantics();
    final lista = [
      for (var i = 0; i < 4; i++)
        _previa('m$i', LatLng(_centro.latitude + i * 0.0001, _centro.longitude)),
    ];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        posicionDispositivoProvider.overrideWith((ref) async => _centro),
        previasCercaProvider.overrideWith((ref) async => lista),
      ],
      child: MaterialApp(
        theme: construirTemaPrevia(),
        home: const PantallaMapa(conTeselas: false),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('4 previas en esta zona'), findsOneWidget);
    semantica.dispose();
  });
}
