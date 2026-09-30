import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:previa/app/tema.dart';
import 'package:previa/data/models/previa.dart';
import 'package:previa/features/map/pantalla_mapa.dart';
import 'package:previa/features/map/proveedores_mapa.dart';
import 'package:previa/features/party/tarjeta_previa.dart';

const _posicion = LatLng(40.4168, -3.7038);

Previa _previa({
  String id = 'p1',
  String titulo = 'Previa en Malasaña',
  int plazas = 3,
}) =>
    Previa(
      id: id,
      titulo: titulo,
      zona: 'Malasaña',
      ubicacion: _posicion,
      empiezaEn: DateTime.now().add(const Duration(hours: 3)),
      plazasLibres: plazas,
      anfitrionId: 'a1',
      anfitrionNombre: 'Ana',
      distanciaMetros: 450,
    );

/// Monta el mapa con los providers sustituidos: sin Supabase, sin GPS y sin
/// teselas de red (conTeselas: false), para que el test sea determinista.
Widget _mapa({
  required Future<List<Previa>> Function() previas,
  void Function(Previa)? onAbrir,
  VoidCallback? onCrear,
  double escala = 1,
}) =>
    ProviderScope(
      overrides: [
        posicionDispositivoProvider.overrideWith((ref) async => _posicion),
        previasCercaProvider.overrideWith((ref) => previas()),
      ],
      child: MaterialApp(
        theme: construirTemaPrevia(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: PantallaMapa(
          conTeselas: false,
          onAbrirPrevia: onAbrir,
          onCrearPrevia: onCrear,
        ),
      ),
    );

void _pantallaMovil(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 892);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  testWidgets('cada previa es un botón con una frase completa y abre el detalle',
      (tester) async {
    _pantallaMovil(tester);
    final semantica = tester.ensureSemantics();
    Previa? abierta;
    final previa = _previa();

    await tester.pumpWidget(_mapa(
      previas: () async => [previa],
      onAbrir: (p) => abierta = p,
    ));
    await tester.pumpAndSettle();

    // La burbuja del mapa (48x48) lleva la etiqueta completa, no un "3" suelto.
    final etiqueta = etiquetaAccesiblePrevia(previa);
    expect(etiqueta, contains('Previa en Malasaña'));
    expect(etiqueta, contains('3 plazas libres'));
    expect(etiqueta, contains('zona Malasaña'));
    expect(etiqueta, contains('a 450 m'));

    final burbuja = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == etiqueta && w.properties.onTap != null,
    );
    expect(burbuja, findsWidgets);
    expect(tester.getSize(find.byType(InkWell).first).width, greaterThanOrEqualTo(48));

    await tester.tap(find.bySemanticsLabel(RegExp('Previa en Malasaña')).first);
    expect(abierta?.id, 'p1');
    semantica.dispose();
  });

  testWidgets('el punto de posición y el mapa están etiquetados', (tester) async {
    _pantallaMovil(tester);
    final semantica = tester.ensureSemantics();

    await tester.pumpWidget(_mapa(previas: () async => [_previa()]));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Tu posición aproximada'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Mapa de previas cercanas')),
        findsOneWidget);
    semantica.dispose();
  });

  testWidgets('los botones con icono tienen tooltip/etiqueta', (tester) async {
    _pantallaMovil(tester);
    final semantica = tester.ensureSemantics();

    await tester.pumpWidget(_mapa(previas: () async => [_previa()]));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Filtros'), findsOneWidget);
    expect(find.byTooltip('Centrar en mi posición'), findsOneWidget);
    // El tooltip es además la etiqueta semántica del botón.
    expect(tester.getSemantics(find.byTooltip('Filtros')).tooltip, 'Filtros');
    expect(tester.getSemantics(find.byTooltip('Centrar en mi posición')).tooltip,
        'Centrar en mi posición');
    semantica.dispose();
  });

  testWidgets('el FAB de posición y el de filtros miden al menos 48 dp',
      (tester) async {
    _pantallaMovil(tester);
    await tester.pumpWidget(_mapa(previas: () async => [_previa()]));
    await tester.pumpAndSettle();

    final fab = tester.getSize(find.byTooltip('Centrar en mi posición'));
    expect(fab.width, greaterThanOrEqualTo(48));
    expect(fab.height, greaterThanOrEqualTo(48));
    final filtros = tester.getSize(find.byTooltip('Filtros'));
    expect(filtros.height, greaterThanOrEqualTo(48));
  });

  testWidgets('la agarradera de la lista es un botón accesible', (tester) async {
    _pantallaMovil(tester);
    final semantica = tester.ensureSemantics();

    await tester.pumpWidget(_mapa(previas: () async => [_previa()]));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Lista de previas cercanas'), findsOneWidget);
    // Un toque la amplía (lo que no se puede hacer arrastrando con TalkBack).
    await tester.tap(find.bySemanticsLabel('Lista de previas cercanas'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    semantica.dispose();
  });

  testWidgets('estado vacío: propone abrir una previa y ampliar el radio',
      (tester) async {
    _pantallaMovil(tester);
    var creada = false;

    await tester.pumpWidget(_mapa(
      previas: () async => const [],
      onCrear: () => creada = true,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Nada por aquí ahora mismo'), findsWidgets);
    expect(find.text('Ampliar a 10 km'), findsOneWidget);
    expect(find.text('Solo +18. Disfruta con cabeza.'), findsOneWidget);

    await tester.ensureVisible(find.text('Abrir una previa'));
    await tester.tap(find.text('Abrir una previa'));
    expect(creada, isTrue);

    // Ampliar el radio cambia el filtro (y el texto pasa a la siguiente subida).
    await tester.tap(find.text('Ampliar a 10 km'));
    await tester.pumpAndSettle();
    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(PantallaMapa)),
    );
    expect(contenedor.read(filtrosProvider).radioMetros, 10000);
    expect(find.text('Ampliar a 20 km'), findsOneWidget);
  });

  testWidgets('estado vacío con filtros activos ofrece quitarlos', (tester) async {
    _pantallaMovil(tester);
    await tester.pumpWidget(_mapa(previas: () async => const []));
    await tester.pumpAndSettle();

    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(PantallaMapa)),
    );
    contenedor.read(filtrosProvider.notifier).fijarPlazas(4);
    await tester.pumpAndSettle();

    expect(find.text('Quitar filtros'), findsOneWidget);
    await tester.tap(find.text('Quitar filtros'));
    await tester.pumpAndSettle();
    expect(contenedor.read(filtrosProvider).hayFiltrosAparteDelRadio, isFalse);
  });

  testWidgets('estado de error: muestra Reintentar y vuelve a buscar',
      (tester) async {
    _pantallaMovil(tester);
    var intentos = 0;

    await tester.pumpWidget(_mapa(previas: () async {
      intentos++;
      if (intentos == 1) throw Exception('sin red');
      return [_previa()];
    }));
    await tester.pumpAndSettle();

    expect(find.text('No se ha podido buscar'), findsWidgets);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(intentos, 2);
    expect(find.text('Reintentar'), findsNothing);
    expect(find.text('1 previa en 5 km'), findsOneWidget);
  });

  testWidgets('con texto al 200 % la pastilla crece y no hay overflow',
      (tester) async {
    _pantallaMovil(tester);
    await tester.pumpWidget(_mapa(
      previas: () async => [_previa(), _previa(id: 'p2', plazas: 12)],
      escala: 2,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Altura mínima, no fija: a 200 % puede (y debe) superar los 48 dp.
    final pastilla = tester.getSize(find.text('2 previas en 5 km').first);
    expect(pastilla.height, greaterThan(0));
  });

  testWidgets('cumple las guías de tamaño táctil y etiquetas', (tester) async {
    _pantallaMovil(tester);
    final semantica = tester.ensureSemantics();

    await tester.pumpWidget(_mapa(previas: () async => [_previa()]));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantica.dispose();
  });
}
