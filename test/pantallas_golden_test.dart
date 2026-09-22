import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:previa/data/models/previa.dart';
import 'package:previa/data/repositories/repositorio_auth.dart';
import 'package:previa/data/models/publicacion.dart';
import 'package:previa/data/repositories/repositorio_previas.dart';
import 'package:previa/data/repositories/repositorio_social.dart';
import 'package:previa/data/services/servicio_ubicacion.dart';
import 'package:previa/features/feed/pantalla_feed.dart';
import 'package:previa/features/map/pantalla_inicio.dart';
import 'package:previa/features/map/pantalla_mapa.dart';
import 'package:previa/features/map/proveedores_mapa.dart';
import 'package:previa/features/party/pantalla_detalle_previa.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'apoyo_visual.dart';

/// Repositorio de muestra.
///
/// Extiende el real en lugar de implementarlo para no tener que declarar los
/// veinticinco metodos que no se usan aqui. El cliente que recibe nunca llega
/// a usarse: todos los metodos que tocan estas pruebas estan sobrescritos.
/// Cliente sin refresco automatico de sesion.
///
/// El cliente normal arranca un temporizador para renovar el token y eso deja
/// la prueba con un timer vivo despues de tirar el arbol de widgets.
SupabaseClient _clienteInerte() => SupabaseClient(
  'https://ejemplo.supabase.co',
  'clave-de-prueba',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _RepoDeMuestra extends RepositorioPrevias {
  _RepoDeMuestra() : super(_clienteInerte());

  @override
  Future<List<Previa>> buscarCerca(FiltrosBusqueda filtros) async =>
      previasDeMuestra();

  @override
  Future<List<Previa>> misPrevias() async =>
      previasDeMuestra().take(1).toList();

  @override
  Future<Previa> detalle(String previaId) async => previasDeMuestra().first;

  /// Falso a proposito: el estado que hay que retratar es el de quien todavia
  /// no tiene plaza, que es cuando la direccion se ve retenida.
  @override
  Future<bool> soyMiembro(String previaId) async => false;

  @override
  Future<Solicitud?> miSolicitudEn(String previaId) async => null;

  @override
  Future<List<Map<String, dynamic>>> miembrosDe(String previaId) async => [];
}

/// Publicaciones de muestra para retratar el feed.
///
/// Las imagenes no cargan en una prueba porque no hay red, asi que el golden
/// sirve para juzgar la estructura del renglon y no la foto.
class _RepoSocialDeMuestra extends RepositorioSocial {
  _RepoSocialDeMuestra() : super(_clienteInerte());

  /// Sin avisos: la chincheta no sale y el golden no depende de la red.
  @override
  Stream<int> flujoDeAvisos() => Stream.value(0);

  @override
  Future<List<Publicacion>> feed({
    String? zona,
    int limite = 30,
    int desplazamiento = 0,
  }) async => [
    Publicacion(
      id: '1',
      autorId: 'a',
      autorNombre: 'Marta Ruiz',
      autorUsuario: 'martaruiz',
      mediaUrl: 'https://ejemplo.test/1.jpg',
      esVideo: false,
      texto: 'La previa de ayer se fue de las manos.',
      zona: 'Zaragoza',
      likes: 24,
      leDiLike: true,
      leSigo: true,
      creadaEn: DateTime(2026, 6, 12, 23, 30),
    ),
    Publicacion(
      id: '2',
      autorId: 'b',
      autorNombre: 'Diego Sanz',
      autorUsuario: 'dsanz',
      mediaUrl: 'https://ejemplo.test/2.mp4',
      esVideo: true,
      texto: 'Nos vemos en el Kembo.',
      zona: 'Zaragoza',
      likes: 3,
      creadaEn: DateTime(2026, 6, 12, 21, 0),
    ),
  ];
}

class _UbicacionFija extends ServicioUbicacion {
  @override
  Future<LatLng> posicionActual() async => const LatLng(40.4258, -3.7038);
}

Widget _app(
  Widget pantalla, {
  required EdgeInsets margen,
  TargetPlatform? plataforma,
  double escalaDeTexto = 1.0,
  Brightness brillo = Brightness.dark,
}) => ProviderScope(
  overrides: [
    // El cliente real exige Supabase.initialize; uno suelto basta porque
    // ningun metodo que se toque aqui llega a usarlo.
    clienteSupabaseProvider.overrideWithValue(_clienteInerte()),
    repositorioPreviasProvider.overrideWithValue(_RepoDeMuestra()),
    servicioUbicacionProvider.overrideWithValue(_UbicacionFija()),
    proveedorTeselasProvider.overrideWithValue(_TeselaDePrueba()),
    repositorioSocialProvider.overrideWithValue(_RepoSocialDeMuestra()),
  ],
  child: MaterialApp(
    theme: temaDePrueba(plataforma: plataforma, brillo: brillo),
    home: pantalla,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: margen,
        textScaler: TextScaler.linear(escalaDeTexto),
      ),
      child: child!,
    ),
  ),
);

Future<void> _asentar(WidgetTester tester) async {
  // El mapa pide teselas por red, que en una prueba nunca llegan; se deja
  // avanzar el reloj en lugar de esperar a que el arbol quede quieto.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 350));
  }
}

/// Tesela opaca de un pixel.
///
/// Lo que se juzga en estos goldens son las celdas tenidas y las placas, que
/// las dibuja la app encima del mapa base; el mapa base solo tiene que estar
/// y no pedir red.
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

void main() {
  setUpAll(() async {
    simularCarpetasDelSistema();
    await cargarTipografias();
    await initializeDateFormatting('es_ES');
  });

  testWidgets('el primer viewport respeta el area segura de iOS', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        const PantallaInicio(),
        margen: margenIOS,
        plataforma: TargetPlatform.iOS,
      ),
    );
    await _asentar(tester);

    await expectLater(
      find.byType(PantallaInicio),
      matchesGoldenFile('goldens/inicio_ios.png'),
    );
  });

  testWidgets('el primer viewport respeta el area segura de Android', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        const PantallaInicio(),
        margen: margenAndroid,
        plataforma: TargetPlatform.android,
      ),
    );
    await _asentar(tester);

    await expectLater(
      find.byType(PantallaInicio),
      matchesGoldenFile('goldens/inicio_android.png'),
    );
  });

  testWidgets('el renglon aguanta la letra del sistema agrandada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        const PantallaInicio(),
        margen: margenAndroid,
        plataforma: TargetPlatform.android,
        // Equivale a font_scale 1.3 en Android y a un Dynamic Type grande
        // en iOS: es donde el renglon se cortaba por el dato.
        escalaDeTexto: 1.3,
      ),
    );
    await _asentar(tester);

    await expectLater(
      find.byType(PantallaInicio),
      matchesGoldenFile('goldens/inicio_letra_grande.png'),
    );
  });

  testWidgets('el feed pinta las publicaciones con su autor y sus likes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(const PantallaFeed(), margen: margenAndroid),
    );
    await _asentar(tester);

    await expectLater(
      find.byType(PantallaFeed),
      matchesGoldenFile('goldens/feed.png'),
    );
  });

  testWidgets('el feed tambien se lee en modo claro', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        const PantallaFeed(),
        margen: margenAndroid,
        brillo: Brightness.light,
      ),
    );
    await _asentar(tester);

    await expectLater(
      find.byType(PantallaFeed),
      matchesGoldenFile('goldens/feed_claro.png'),
    );
  });

  testWidgets('el mapa dibuja celdas tenidas y ninguna chincheta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const PantallaMapa(), margen: margenAndroid));
    await _asentar(tester);

    await expectLater(
      find.byType(PantallaMapa),
      matchesGoldenFile('goldens/mapa.png'),
    );
  });

  testWidgets('la ficha ensena la direccion retenida a quien no tiene plaza', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        const PantallaDetallePrevia(previaId: 'Previa en Malasaña'),
        margen: margenAndroid,
      ),
    );
    await _asentar(tester);

    // La direccion vive abajo del todo de la ficha.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await _asentar(tester);

    await expectLater(
      find.byType(PantallaDetallePrevia),
      matchesGoldenFile('goldens/detalle_direccion_retenida.png'),
    );
  });
}
