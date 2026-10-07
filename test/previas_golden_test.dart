import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:previa/data/models/previa.dart';
import 'package:previa/data/repositories/repositorio_auth.dart';
import 'package:previa/data/repositories/repositorio_previas.dart';
import 'package:previa/data/services/servicio_ubicacion.dart';
import 'package:previa/features/map/proveedores_mapa.dart';
import 'package:previa/features/party/hoja_solicitar_plaza.dart';
import 'package:previa/features/party/pantalla_crear_previa.dart';
import 'package:previa/features/party/pantalla_detalle_previa.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'apoyo_visual.dart';

// Goldens de las pantallas de previas: el cartel de la ficha, el primer paso
// de abrir una previa y la hoja de pedir plaza. La direccion retenida sigue
// en pantallas_golden_test.dart.

SupabaseClient _clienteInerte() => SupabaseClient(
  'https://ejemplo.supabase.co',
  'clave-de-prueba',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _RepoDeMuestra extends RepositorioPrevias {
  _RepoDeMuestra() : super(_clienteInerte());

  @override
  Future<Previa> detalle(String previaId) async => previasDeMuestra().first;

  @override
  Future<bool> soyMiembro(String previaId) async => false;

  @override
  Future<Solicitud?> miSolicitudEn(String previaId) async => null;
}

class _UbicacionFija extends ServicioUbicacion {
  @override
  Future<LatLng> posicionActual() async => const LatLng(40.4258, -3.7038);
}

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

Widget _app(Widget pantalla, {Brightness brillo = Brightness.dark}) =>
    ProviderScope(
      overrides: [
        clienteSupabaseProvider.overrideWithValue(_clienteInerte()),
        repositorioPreviasProvider.overrideWithValue(_RepoDeMuestra()),
        servicioUbicacionProvider.overrideWithValue(_UbicacionFija()),
        proveedorTeselasProvider.overrideWithValue(_TeselaDePrueba()),
        miPerfilProvider.overrideWith((_) async => null),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaDePrueba(brillo: brillo),
        home: pantalla,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: margenAndroid),
          child: child!,
        ),
      ),
    );

Future<void> _asentar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 350));
  }
}

void main() {
  setUpAll(() async {
    simularCarpetasDelSistema();
    await cargarTipografias();
    await initializeDateFormatting('es_ES');
  });

  testWidgets('la ficha abre con el cartel del ambiente y la accion abajo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(const PantallaDetallePrevia(previaId: 'Previa en Malasaña')),
    );
    await _asentar(tester);

    expect(find.text('SOLICITAR PLAZA'), findsOneWidget);
    await expectLater(
      find.byType(PantallaDetallePrevia),
      matchesGoldenFile('goldens/detalle_cartel.png'),
    );
  });

  testWidgets('la ficha tambien se lee en modo claro', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        const PantallaDetallePrevia(previaId: 'Previa en Malasaña'),
        brillo: Brightness.light,
      ),
    );
    await _asentar(tester);

    await expectLater(
      find.byType(PantallaDetallePrevia),
      matchesGoldenFile('goldens/detalle_cartel_claro.png'),
    );
  });

  testWidgets('abrir previa va por pasos y valida antes de avanzar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const PantallaCrearPrevia()));
    await _asentar(tester);

    expect(find.text('PASO 1 DE 3'), findsOneWidget);
    await expectLater(
      find.byType(PantallaCrearPrevia),
      matchesGoldenFile('goldens/crear_previa_paso1.png'),
    );

    // Sin titulo ni zona no se pasa al siguiente paso.
    await tester.tap(find.text('SIGUIENTE'));
    await _asentar(tester);
    expect(find.text('PASO 1 DE 3'), findsOneWidget);
    expect(find.text('Escribe la zona'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Previa en casa');
    await tester.enterText(find.byType(TextFormField).at(1), 'Delicias');
    await tester.tap(find.text('SIGUIENTE'));
    await _asentar(tester);
    expect(find.text('PASO 2 DE 3'), findsOneWidget);
    expect(find.text('Atrás'), findsOneWidget);

    // Lo escrito sobrevive al ir y volver.
    await tester.tap(find.text('Atrás'));
    await _asentar(tester);
    expect(find.text('PASO 1 DE 3'), findsOneWidget);
    expect(find.text('Previa en casa'), findsWidgets);
  });

  testWidgets('la hoja de pedir plaza', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (c) => Center(
              child: TextButton(
                onPressed: () => mostrarHojaSolicitarPlaza(
                  c,
                  previaId: 'p',
                  plazasLibres: 5,
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await _asentar(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/hoja_solicitar_plaza.png'),
    );
  });
}
