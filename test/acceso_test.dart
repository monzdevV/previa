import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:previa/data/repositories/repositorio_auth.dart';
import 'package:previa/features/auth/pantalla_bienvenida.dart';
import 'package:previa/features/auth/pantalla_entrar.dart';
import 'package:previa/features/auth/pantalla_registro.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'apoyo_visual.dart';

/// Las puertas de la app: bienvenida, registro por pasos y entrada.
///
/// Se prueban en el movil mas pequeno que se da por bueno (360x640) y con el
/// teclado abierto, que es donde un formulario suele reventar.

const _pequeno = Size(360, 640);

/// Alto tipico del teclado de Android en un movil de 360 de ancho.
const _teclado = 280.0;

Widget _app(Widget pantalla) => ProviderScope(
  overrides: [
    // Ninguna prueba llega a llamar al servidor; basta con un cliente suelto
    // sin refresco para que no quede un temporizador vivo.
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
    home: pantalla,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(padding: margenAndroid),
      child: child!,
    ),
  ),
);

Future<void> _asentar(WidgetTester tester) async {
  // La marquesina no para nunca, asi que no vale esperar a que se quede quieto.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void _movilPequeno(WidgetTester tester, {bool conTeclado = false}) {
  tester.view.physicalSize = _pequeno;
  tester.view.devicePixelRatio = 1.0;
  if (conTeclado) {
    tester.view.viewInsets = const FakeViewPadding(bottom: _teclado);
  }
  addTearDown(tester.view.reset);
}

FilledButton _boton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  setUpAll(() async {
    simularCarpetasDelSistema();
    await cargarTipografias();
    await initializeDateFormatting('es_ES');
  });

  group('usernameDesde', () {
    final formato = RegExp(r'^[a-z0-9_]{3,20}$');

    test('quita tildes, espacios y simbolos', () {
      final u = RepositorioAuth.usernameDesde(
        'José Ángel Muñoz!',
        azar: Random(1),
      );
      expect(u, startsWith('jose_angel_munoz'));
      expect(u, matches(formato));
    });

    test('recorta los nombres largos para que quepa el sufijo', () {
      final u = RepositorioAuth.usernameDesde(
        'Maximiliana de los Santos Inocentes',
        azar: Random(2),
      );
      expect(u.length, lessThanOrEqualTo(20));
      expect(u, matches(formato));
    });

    test('un nombre sin letras aprovechables usa la marca', () {
      final u = RepositorioAuth.usernameDesde('🥚🥚', azar: Random(3));
      expect(u, startsWith('previa'));
      expect(u, matches(formato));
    });

    test('cambia el sufijo entre intentos', () {
      final azar = Random(4);
      final a = RepositorioAuth.usernameDesde('Lucía', azar: azar);
      final b = RepositorioAuth.usernameDesde('Lucía', azar: azar);
      expect(a, isNot(b));
    });
  });

  testWidgets('la bienvenida cabe en un movil pequeño', (tester) async {
    _movilPequeno(tester);
    await tester.pumpWidget(_app(const PantallaBienvenida()));
    await _asentar(tester);

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(PantallaBienvenida),
      matchesGoldenFile('goldens/acceso_bienvenida.png'),
    );
  });

  testWidgets('el registro avanza paso a paso y no se salta la edad', (
    tester,
  ) async {
    _movilPequeno(tester);
    // Con "hoy" fijo la rueda arranca siempre en la misma fecha y la captura
    // del paso 2 no cambia cada dia (por eso fallaba antes).
    await tester.pumpWidget(_app(PantallaRegistro(hoy: DateTime(2026, 6, 15))));
    await _asentar(tester);

    // Paso 1: el boton no se enciende hasta que hay un nombre.
    expect(_boton(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Lucía');
    await tester.pump();
    expect(_boton(tester).onPressed, isNotNull);
    await tester.tap(find.text('SIGUIENTE'));
    await _asentar(tester);

    // Paso 2: la rueda arranca en los 18 justos, pero hay que tocarla.
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(_boton(tester).onPressed, isNull);
    await expectLater(
      find.byType(PantallaRegistro),
      matchesGoldenFile('goldens/acceso_registro_fecha.png'),
    );

    // Hacia arriba en la columna del año: mas joven, y la app lo frena.
    final rueda = tester.getRect(find.byType(CupertinoDatePicker));
    await tester.dragFrom(
      Offset(rueda.right - 40, rueda.center.dy),
      const Offset(0, -120),
    );
    await _asentar(tester);
    expect(
      find.text('Previa es solo para mayores de 18 años.'),
      findsOneWidget,
    );
    expect(_boton(tester).onPressed, isNull);

    // Hacia abajo: unos años mas, y ya se puede seguir.
    await tester.dragFrom(
      Offset(rueda.right - 40, rueda.center.dy),
      const Offset(0, 300),
    );
    await _asentar(tester);
    expect(_boton(tester).onPressed, isNotNull);
    await tester.tap(find.text('SIGUIENTE'));
    await _asentar(tester);

    // Paso 3: correo, contraseña y la casilla, que nunca viene marcada.
    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), 'lucia@ejemplo.com');
    await tester.enterText(campos.at(1), 'secreta1');
    await tester.pump();
    expect(_boton(tester).onPressed, isNull);
    await tester.tap(find.byType(Checkbox));
    await _asentar(tester);
    expect(_boton(tester).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(PantallaRegistro),
      matchesGoldenFile('goldens/acceso_registro_cuenta.png'),
    );
  });

  testWidgets('con el teclado abierto el registro no se desborda', (
    tester,
  ) async {
    _movilPequeno(tester, conTeclado: true);
    await tester.pumpWidget(_app(const PantallaRegistro()));
    await _asentar(tester);

    expect(tester.takeException(), isNull);
    // El boton sigue a la vista, justo encima del teclado.
    final boton = tester.getRect(find.byType(FilledButton));
    expect(boton.bottom, lessThanOrEqualTo(_pequeno.height - _teclado));
    await expectLater(
      find.byType(PantallaRegistro),
      matchesGoldenFile('goldens/acceso_registro_teclado.png'),
    );
  });

  testWidgets('entrar cabe con el teclado abierto', (tester) async {
    _movilPequeno(tester, conTeclado: true);
    await tester.pumpWidget(_app(const PantallaEntrar()));
    await _asentar(tester);

    expect(tester.takeException(), isNull);
    expect(_boton(tester).onPressed, isNull);
    final boton = tester.getRect(find.byType(FilledButton));
    expect(boton.bottom, lessThanOrEqualTo(_pequeno.height - _teclado));
  });

  testWidgets('entrar en un movil pequeño', (tester) async {
    _movilPequeno(tester);
    await tester.pumpWidget(_app(const PantallaEntrar()));
    await _asentar(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('¿Olvidaste la contraseña?'), findsOneWidget);
    await expectLater(
      find.byType(PantallaEntrar),
      matchesGoldenFile('goldens/acceso_entrar.png'),
    );
  });
}
