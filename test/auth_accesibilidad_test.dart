import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:previa/app/tema.dart';
import 'package:previa/features/auth/pantalla_bienvenida.dart';
import 'package:previa/features/auth/pantalla_entrar.dart';
import 'package:previa/features/auth/pantalla_registro.dart';
import 'package:previa/features/map/proveedores_mapa.dart';

Widget _app(Widget pantalla, {double escala = 1}) => ProviderScope(
      child: MaterialApp(
        theme: construirTemaPrevia(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: pantalla,
      ),
    );

void _movil(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 892);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  group('Entrar', () {
    testWidgets('el botón de mostrar contraseña tiene tooltip y lo cambia',
        (tester) async {
      _movil(tester);
      await tester.pumpWidget(_app(const PantallaEntrar()));

      expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();
      expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
    });

    testWidgets('rechaza un correo a medias', (tester) async {
      _movil(tester);
      await tester.pumpWidget(_app(const PantallaEntrar()));

      await tester.enterText(find.byType(TextFormField).first, 'ana@');
      await tester.enterText(find.byType(TextFormField).last, 'secreta');
      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(find.text('Escribe un correo válido'), findsOneWidget);
    });

    testWidgets('guías de accesibilidad: tamaño táctil y etiquetas',
        (tester) async {
      _movil(tester);
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(_app(const PantallaEntrar()));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantica.dispose();
    });
  });

  group('Registro', () {
    testWidgets('el botón de mostrar contraseña tiene tooltip', (tester) async {
      _movil(tester);
      await tester.pumpWidget(_app(const PantallaRegistro()));
      expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);
    });

    testWidgets('la fecha de nacimiento se anuncia como botón con su valor',
        (tester) async {
      _movil(tester);
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(_app(const PantallaRegistro()));

      expect(find.bySemanticsLabel('Fecha de nacimiento, sin elegir'),
          findsOneWidget);
      semantica.dispose();
    });

    testWidgets('muestra el mensaje de edad y consumo', (tester) async {
      _movil(tester);
      await tester.pumpWidget(_app(const PantallaRegistro()));
      await tester.scrollUntilVisible(
        find.text('Solo +18. Disfruta con cabeza.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Solo +18. Disfruta con cabeza.'), findsOneWidget);
    });

    testWidgets('con texto al 200 % no hay desbordamiento', (tester) async {
      _movil(tester);
      await tester.pumpWidget(_app(const PantallaRegistro(), escala: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('guías de accesibilidad: tamaño táctil y etiquetas',
        (tester) async {
      _movil(tester);
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(_app(const PantallaRegistro()));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantica.dispose();
    });
  });

  group('Bienvenida', () {
    testWidgets('muestra "Solo +18. Disfruta con cabeza."', (tester) async {
      _movil(tester);
      await tester.pumpWidget(_app(const PantallaBienvenida()));
      expect(find.text('Solo +18. Disfruta con cabeza.'), findsOneWidget);
    });

    testWidgets('con texto al 200 % se puede desplazar y no desborda',
        (tester) async {
      _movil(tester);
      await tester.pumpWidget(_app(const PantallaBienvenida(), escala: 2));
    });
  });

  group('Filtros', () {
    test('hayFiltrosAparteDelRadio ignora la distancia', () {
      expect(const Filtros().hayFiltrosAparteDelRadio, isFalse);
      expect(const Filtros(radioMetros: 10000).hayFiltrosAparteDelRadio, isFalse);
      expect(const Filtros(plazasMinimas: 3).hayFiltrosAparteDelRadio, isTrue);
      expect(const Filtros(ambiente: {'pop'}).hayFiltrosAparteDelRadio, isTrue);
    });

    test('quitarFiltrosSalvoRadio conserva la distancia ampliada', () {
      final contenedor = ProviderContainer();
      addTearDown(contenedor.dispose);
      final n = contenedor.read(filtrosProvider.notifier);

      n.fijarRadio(10000);
      n.fijarPlazas(4);
      n.quitarFiltrosSalvoRadio();

      final f = contenedor.read(filtrosProvider);
      expect(f.radioMetros, 10000);
      expect(f.plazasMinimas, 1);
    });
  });
}
