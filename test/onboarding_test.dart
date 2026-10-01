import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:previa/app/tema.dart';
import 'package:previa/features/auth/fuerza_contrasena.dart';
import 'package:previa/features/onboarding/pantalla_onboarding.dart';
import 'package:previa/features/onboarding/servicio_onboarding.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget pantalla, {double escala = 1}) => MaterialApp(
      theme: construirTemaPrevia(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
      home: pantalla,
    );

void _movil(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 892);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ServicioOnboarding.reiniciarParaPruebas();
  });

  group('ServicioOnboarding', () {
    test('no visto al principio, visto tras marcarlo', () async {
      expect(await ServicioOnboarding.yaVisto(), isFalse);
      await ServicioOnboarding.marcarVisto();
      expect(await ServicioOnboarding.yaVisto(), isTrue);

      ServicioOnboarding.reiniciarParaPruebas();
      expect(await ServicioOnboarding.yaVisto(), isTrue,
          reason: 'debe persistir en shared_preferences');
    });
  });

  group('PantallaOnboarding', () {
    testWidgets('recorre las tarjetas y termina pidiendo el permiso',
        (tester) async {
      _movil(tester);
      var pedido = false;
      var terminado = false;
      await tester.pumpWidget(_app(PantallaOnboarding(
        solicitarPermiso: () async => pedido = true,
        alTerminar: () => terminado = true,
      )));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Previas cerca de ti'), findsOneWidget);
      expect(find.text('Saltar'), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Siguiente'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('¿Para qué tu ubicación?'), findsOneWidget);
      expect(find.text('Saltar').hitTestable(), findsNothing);

      await tester.tap(find.text('Activar ubicación'));
      await tester.pump();
      await tester.pump();

      expect(pedido, isTrue);
      expect(terminado, isTrue);
      expect(await ServicioOnboarding.yaVisto(), isTrue);
    });

    testWidgets('Saltar marca como visto sin pedir el permiso',
        (tester) async {
      _movil(tester);
      var pedido = false;
      var terminado = false;
      await tester.pumpWidget(_app(PantallaOnboarding(
        solicitarPermiso: () async => pedido = true,
        alTerminar: () => terminado = true,
      )));

      await tester.tap(find.text('Saltar'));
      await tester.pump();
      await tester.pump();

      expect(pedido, isFalse);
      expect(terminado, isTrue);
    });

    testWidgets('si falla el permiso igualmente termina', (tester) async {
      _movil(tester);
      var terminado = false;
      await tester.pumpWidget(_app(PantallaOnboarding(
        solicitarPermiso: () async => throw Exception('sin plugin'),
        alTerminar: () => terminado = true,
      )));
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Siguiente'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.tap(find.text('Activar ubicación'));
      await tester.pump();
      await tester.pump();
      expect(terminado, isTrue);
    });

    testWidgets('guías de accesibilidad y texto al 200 %', (tester) async {
      _movil(tester);
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(_app(
        PantallaOnboarding(alTerminar: () {}),
        escala: 2,
      ));
      await tester.pump(const Duration(milliseconds: 600));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(find.bySemanticsLabel('Paso 1 de 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantica.dispose();
    });
  });

  group('nivelDeContrasena', () {
    test('clasifica de menos a más segura', () {
      expect(nivelDeContrasena(''), NivelContrasena.vacia);
      expect(nivelDeContrasena('abc'), NivelContrasena.muyCorta);
      expect(nivelDeContrasena('abcdef'), NivelContrasena.debil);
      expect(nivelDeContrasena('abcdefg1'), NivelContrasena.media);
      expect(nivelDeContrasena('Abcdefg1'), NivelContrasena.buena);
      expect(nivelDeContrasena('Abcdefghijk1!'), NivelContrasena.fuerte);
    });
  });
}
