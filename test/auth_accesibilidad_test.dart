import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:previa/data/repositories/repositorio_auth.dart';
import 'package:previa/features/auth/fuerza_contrasena.dart';
import 'package:previa/features/auth/pantalla_bienvenida.dart';
import 'package:previa/features/auth/pantalla_entrar.dart';
import 'package:previa/features/auth/pantalla_registro.dart';
import 'package:previa/features/party/estados_pantalla.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'apoyo_visual.dart';

/// Accesibilidad de las puertas de la app: objetivos de 48, etiquetas,
/// texto al 200 % y lo que oye quien usa lector de pantalla.
///
/// Viene de la version de GitHub, adaptada al registro por pasos de aqui
/// (alli era un formulario largo con validacion al enviar).

Widget _app(Widget pantalla, {double escala = 1}) => ProviderScope(
  overrides: [
    clienteSupabaseProvider.overrideWithValue(
      SupabaseClient(
        'https://ejemplo.supabase.co',
        'clave-de-prueba',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    ),
  ],
  child: MaterialApp(
    theme: temaDePrueba(),
    locale: const Locale('es', 'ES'),
    supportedLocales: const [Locale('es', 'ES')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
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

/// La marquesina no para nunca: se deja pasar el tiempo de las entradas.
Future<void> _asentar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

FilledButton _boton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton).last);

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  group('Entrar', () {
    testWidgets('el botón de mostrar contraseña tiene tooltip y lo cambia', (
      tester,
    ) async {
      _movil(tester);
      await tester.pumpWidget(_app(const PantallaEntrar()));
      await _asentar(tester);

      expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();
      expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
    });

    testWidgets('recuperar la contraseña no deja mandar un correo a medias', (
      tester,
    ) async {
      _movil(tester);
      await tester.pumpWidget(_app(const PantallaEntrar()));
      await _asentar(tester);

      await tester.tap(find.text('¿Olvidaste la contraseña?'));
      await _asentar(tester);
      final campo = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(campo, 'ana@');
      await tester.pump();
      expect(_boton(tester).onPressed, isNull);

      await tester.enterText(campo, 'ana@ejemplo.com');
      await tester.pump();
      expect(_boton(tester).onPressed, isNotNull);
    });

    testWidgets('guías de accesibilidad: tamaño táctil y etiquetas', (
      tester,
    ) async {
      _movil(tester);
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(_app(const PantallaEntrar()));
      await _asentar(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantica.dispose();
    });

    testWidgets('con texto al 200 % no hay desbordamiento', (tester) async {
      _movil(tester);
      await tester.pumpWidget(_app(const PantallaEntrar(), escala: 2));
      await _asentar(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('Registro', () {
    testWidgets('la fecha de nacimiento se anuncia con su estado', (
      tester,
    ) async {
      _movil(tester);
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(PantallaRegistro(hoy: DateTime(2026, 6, 15))),
      );
      await _asentar(tester);

      await tester.enterText(find.byType(TextField), 'Lucía');
      await tester.pump();
      await tester.tap(find.text('SIGUIENTE'));
      await _asentar(tester);

      expect(
        find.bySemanticsLabel(
          'Fecha de nacimiento, sin elegir. Mueve la rueda.',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Paso 2 de 3'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('el paso de la edad recuerda el mensaje de consumo', (
      tester,
    ) async {
      _movil(tester);
      await tester.pumpWidget(
        _app(PantallaRegistro(hoy: DateTime(2026, 6, 15))),
      );
      await _asentar(tester);
      await tester.enterText(find.byType(TextField), 'Lucía');
      await tester.pump();
      await tester.tap(find.text('SIGUIENTE'));
      await _asentar(tester);

      expect(find.text(mensajeResponsable), findsOneWidget);
    });

    testWidgets('con texto al 200 % no hay desbordamiento', (tester) async {
      _movil(tester);
      await tester.pumpWidget(_app(const PantallaRegistro(), escala: 2));
      await _asentar(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('guías de accesibilidad: tamaño táctil y etiquetas', (
      tester,
    ) async {
      _movil(tester);
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(_app(const PantallaRegistro()));
      await _asentar(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantica.dispose();
    });
  });

  group('Indicador de contraseña', () {
    testWidgets('dice el mínimo, lo que falta y luego la seguridad', (
      tester,
    ) async {
      final control = TextEditingController();
      addTearDown(control.dispose);
      await tester.pumpWidget(
        _app(Scaffold(body: IndicadorFuerzaContrasena(controlador: control))),
      );

      expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
      control.text = 'abc';
      await tester.pump();
      expect(find.text('Faltan 3 caracteres'), findsOneWidget);
      control.text = 'Abcdefg1';
      await tester.pump();
      expect(find.text('Buena'), findsOneWidget);
    });
  });

  group('Bienvenida', () {
    testWidgets('muestra el mensaje de edad y consumo', (tester) async {
      _movil(tester);
      await tester.pumpWidget(_app(const PantallaBienvenida()));
      await _asentar(tester);
      expect(find.text(mensajeResponsable), findsOneWidget);
    });

    testWidgets('con texto al 200 % se puede desplazar y no desborda', (
      tester,
    ) async {
      _movil(tester);
      await tester.pumpWidget(_app(const PantallaBienvenida(), escala: 2));
      await _asentar(tester);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Ya tengo cuenta'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ya tengo cuenta'), findsOneWidget);
    });

    testWidgets('guías de accesibilidad: tamaño táctil y etiquetas', (
      tester,
    ) async {
      _movil(tester);
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(_app(const PantallaBienvenida()));
      await _asentar(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });
  });
}
