import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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

import 'apoyo_visual.dart';

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

/// Tesela opaca de un pixel: el mapa base esta, pero no pide red.
class _TeselaDePrueba extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4'
          '2mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        ),
      );
}

Widget _mapa(List<Previa> previas, {VoidCallback? onCrearPrevia}) =>
    ProviderScope(
      overrides: [
        posicionDispositivoProvider.overrideWith((ref) async => _centro),
        previasCercaProvider.overrideWith((ref) async => previas),
        proveedorTeselasProvider.overrideWithValue(_TeselaDePrueba()),
      ],
      child: MaterialApp(
        theme: construirTemaPrevia(),
        home: PantallaMapa(onCrearPrevia: onCrearPrevia),
      ),
    );

/// El mapa nunca queda quieto del todo (teselas, camara): se avanza el reloj
/// en vez de esperar a que se asiente.
Future<void> _asentar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

ProviderContainer _contenedor(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PantallaMapa)));

void main() {
  setUpAll(() async {
    simularCarpetasDelSistema();
    await cargarTipografias();
    await initializeDateFormatting('es_ES');
  });

  group('agruparPrevias', () {
    final cercanas = [
      for (var i = 0; i < 4; i++)
        _previa(
          'c$i',
          LatLng(_centro.latitude + i * 0.0001, _centro.longitude),
        ),
    ];

    test('junta las que se pisarian a este zoom', () {
      final grupos = agruparPrevias(cercanas, 13);
      expect(grupos, hasLength(1));
      expect(grupos.single.previas, hasLength(4));
      expect(grupos.single.esAgrupado, isTrue);
    });

    test('al acercarse los grupos se deshacen', () {
      expect(agruparPrevias(cercanas, 22), hasLength(4));
    });

    test('dos placas montadas ya se agrupan', () {
      final grupos = agruparPrevias(cercanas.take(2).toList(), 13);
      expect(grupos, hasLength(1));
    });

    test('las lejanas quedan sueltas y en su sitio', () {
      final lejos = [
        _previa('x', const LatLng(41.4, -3.7)),
        _previa('y', const LatLng(39.4, -3.7)),
      ];
      final grupos = agruparPrevias(lejos, 13);
      expect(grupos, hasLength(2));
      expect(grupos.every((g) => !g.esAgrupado), isTrue);
      expect(grupos.first.centro, lejos.first.ubicacion);
    });

    test('el centro de un grupo es la media de sus previas', () {
      final grupo = agruparPrevias(cercanas, 13).single;
      expect(grupo.centro.latitude, closeTo(_centro.latitude + 0.00015, 1e-9));
    });
  });

  group('FiltrosRapidos', () {
    Widget app() => ProviderScope(
      child: MaterialApp(
        theme: construirTemaPrevia(),
        home: const Scaffold(body: FiltrosRapidos()),
      ),
    );

    testWidgets('Ahora y A pie se ponen y se quitan con un toque', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      final contenedor = ProviderScope.containerOf(
        tester.element(find.byType(FiltrosRapidos)),
      );

      await tester.tap(find.text('Ahora'));
      await tester.pump();
      expect(contenedor.read(filtrosProvider).horas, FiltrosRapidos.horasAhora);
      await tester.tap(find.text('Ahora'));
      await tester.pump();
      expect(contenedor.read(filtrosProvider).sonLosPorDefecto, isTrue);

      await tester.tap(find.text('A pie'));
      await tester.pump();
      expect(
        contenedor.read(filtrosProvider).radioMetros,
        FiltrosRapidos.radioAPie,
      );
    });

    testWidgets('los atajos miden al menos 48 dp de alto', (tester) async {
      await tester.pumpWidget(app());
      final chip = tester.getSize(find.byType(FilterChip).first);
      expect(chip.height, greaterThanOrEqualTo(48));
    });
  });

  testWidgets('el esqueleto se anuncia como "Buscando previas"', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: construirTemaPrevia(),
        home: const Scaffold(
          body: SizedBox(height: 132, child: EsqueletoTarjetaMapa()),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Buscando previas'), findsOneWidget);
    // Desmontar para la animacion infinita del brillo.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    semantica.dispose();
  });

  group('PantallaMapa', () {
    testWidgets('previas montadas se ven como un grupo con nombre', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantica = tester.ensureSemantics();
      final lista = [
        for (var i = 0; i < 4; i++)
          _previa(
            'm$i',
            LatLng(_centro.latitude + i * 0.0001, _centro.longitude),
          ),
      ];

      await tester.pumpWidget(_mapa(lista));
      await _asentar(tester);

      expect(find.bySemanticsLabel('4 previas juntas'), findsOneWidget);
      // El carrusel cuenta la primera previa en una sola frase.
      expect(find.bySemanticsLabel(RegExp('Previa m0. Abre Ana')), findsOne);
      semantica.dispose();
    });

    testWidgets('sin nada y con filtros, ofrece quitarlos sin tocar el radio', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_mapa(const [], onCrearPrevia: () {}));
      await _asentar(tester);
      final contenedor = _contenedor(tester);
      contenedor.read(filtrosProvider.notifier)
        ..fijarRadio(2000)
        ..fijarHoras(2);
      await _asentar(tester);

      expect(find.text('NADA CON ESTOS FILTROS'), findsOneWidget);
      expect(find.text('Abrir una'), findsOneWidget);
      await tester.tap(find.text('QUITAR FILTROS'));
      await _asentar(tester);

      final filtros = contenedor.read(filtrosProvider);
      expect(filtros.hayFiltrosAparteDelRadio, isFalse);
      expect(filtros.radioMetros, 2000);
    });

    testWidgets('sin nada y sin filtros, ofrece buscar mas lejos', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_mapa(const []));
      await _asentar(tester);

      expect(find.text('NADA POR AQUÍ'), findsOneWidget);
      await tester.tap(find.text('Ampliar a 10 km'));
      await _asentar(tester);
      expect(_contenedor(tester).read(filtrosProvider).radioMetros, 10000);
    });
  });
}
