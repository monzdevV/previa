import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:previa/app/tema.dart';
import 'package:previa/features/auth/validadores.dart';
import 'package:previa/features/party/estados_pantalla.dart';

Widget _app(Widget hijo, {double escala = 1}) => MaterialApp(
      theme: construirTemaPrevia(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(escala),
        ),
        child: child!,
      ),
      home: Scaffold(body: hijo),
    );

void main() {
  group('EstadoError', () {
    testWidgets('muestra el mensaje y un botón Reintentar que funciona',
        (tester) async {
      var reintentos = 0;
      await tester.pumpWidget(_app(EstadoError(
        mensaje: 'No se ha podido buscar',
        detalle: 'Comprueba tu conexión.',
        onReintentar: () => reintentos++,
      )));

      expect(find.text('No se ha podido buscar'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(reintentos, 1);
    });

    testWidgets('se anuncia como región viva para el lector de pantalla',
        (tester) async {
      await tester.pumpWidget(_app(EstadoError(
        mensaje: 'No se ha podido buscar',
        onReintentar: () {},
      )));

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('con texto al 200 % no hay desbordamiento', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(
        EstadoError(
          mensaje: 'No se han podido cargar las solicitudes',
          detalle: 'Comprueba tu conexión e inténtalo otra vez.',
          onReintentar: () {},
        ),
        escala: 2,
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('cumple las guías de accesibilidad de Flutter', (tester) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(_app(EstadoError(
        mensaje: 'No se ha podido buscar',
        onReintentar: () {},
      )));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantica.dispose();
    });
  });

  group('EstadoVacio', () {
    testWidgets('ofrece las acciones sugeridas', (tester) async {
      var abierta = false;
      await tester.pumpWidget(_app(EstadoVacio(
        icono: Icons.nightlife_outlined,
        titulo: 'Nada por aquí ahora mismo',
        detalle: 'Sé la primera persona en abrir una previa.',
        acciones: [
          FilledButton(
            onPressed: () => abierta = true,
            child: const Text('Abrir una previa'),
          ),
        ],
      )));

      expect(find.text('Nada por aquí ahora mismo'), findsOneWidget);
      await tester.tap(find.text('Abrir una previa'));
      expect(abierta, isTrue);
    });

    testWidgets('con texto al 200 % no hay desbordamiento', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(
        EstadoVacio(
          icono: Icons.history,
          titulo: 'Todavía no has ido a ninguna previa',
          detalle: 'Cuando vayas a una y termine, podrás valorar a la gente.',
          acciones: [
            FilledButton(onPressed: () {}, child: const Text('Buscar previas')),
            const MensajeResponsable(),
          ],
        ),
        escala: 2,
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('IndicadorCarga', () {
    testWidgets('lleva etiqueta "Cargando" para el lector', (tester) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(_app(const IndicadorCarga()));
      expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
      semantica.dispose();
    });
  });

  group('AvisoError', () {
    testWidgets('muestra el mensaje con icono y texto', (tester) async {
      await tester.pumpWidget(_app(const AvisoError('Correo o contraseña mal')));
      expect(find.text('Correo o contraseña mal'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  test('el mensaje de edad y consumo es el acordado', () {
    expect(mensajeResponsable, 'Solo +18. Disfruta con cabeza.');
  });

  group('esCorreoValido', () {
    test('acepta correos normales', () {
      expect(esCorreoValido('ana@correo.es'), isTrue);
      expect(esCorreoValido(' ana.lopez+previa@mail.co.uk '), isTrue);
    });

    test('rechaza lo que antes pasaba por contener una arroba', () {
      expect(esCorreoValido('a@'), isFalse);
      expect(esCorreoValido('@b.com'), isFalse);
      expect(esCorreoValido('a@b'), isFalse);
      expect(esCorreoValido('a b@c.com'), isFalse);
      expect(esCorreoValido(null), isFalse);
      expect(esCorreoValido(''), isFalse);
    });
  });
}
