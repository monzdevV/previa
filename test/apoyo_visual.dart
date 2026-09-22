import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:previa/app/tema.dart';
import 'package:previa/data/models/previa.dart';

/// Apoyo comun de las pruebas visuales.
///
/// Los goldens solo valen si la tipografia es la de produccion. La app usa la
/// cara del sistema, que el entorno de pruebas no carga, asi que hay que
/// registrarla a mano junto con los iconos de Material.

/// La cache de imagenes pide una carpeta temporal al sistema, y en una
/// prueba ese canal no existe. Sin esto, cualquier pantalla con imagenes de
/// red revienta antes de pintarse.
void simularCarpetasDelSistema() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => Directory.systemTemp.createTempSync('previa').path,
      );
}

Future<void> cargarTipografias() async {
  // El ejecutable de las pruebas cuelga de bin/cache, pero a distinta
  // profundidad segun el motor, asi que se sube hasta dar con la carpeta.
  Directory? fuentes;
  var nivel = Directory(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    final candidata = Directory('${nivel.path}/artifacts/material_fonts');
    if (candidata.existsSync()) {
      fuentes = candidata;
      break;
    }
    if (nivel.parent.path == nivel.path) break;
    nivel = nivel.parent;
  }
  if (fuentes == null) return;

  final sistema = FontLoader('Roboto');
  for (final nombre in const [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
  ]) {
    final fichero = File('${fuentes.path}/$nombre');
    if (!fichero.existsSync()) continue;
    final bytes = await fichero.readAsBytes();
    sistema.addFont(
      Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
    );
  }
  await sistema.load();

  // Sin esto cada icono sale como un cuadrado vacio y el golden no sirve
  // para juzgar si la pantalla se lee.
  final iconos = File('${fuentes.path}/materialicons-regular.otf');
  if (iconos.existsSync()) {
    final cargador = FontLoader('MaterialIcons');
    final bytes = await iconos.readAsBytes();
    cargador.addFont(
      Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
    );
    await cargador.load();
  }
}

/// El tema de produccion deja el cuerpo en la cara del sistema, que en una
/// prueba no existe; aqui se nombra la misma que pondria Android.
ThemeData temaDePrueba({
  TargetPlatform? plataforma,
  Brightness brillo = Brightness.dark,
}) => construirTemaPrevia(
  brillo: brillo,
  caraDelSistema: 'Roboto',
).copyWith(platform: plataforma);

/// Margenes de sistema de cada plataforma.
///
/// Sin emulador, esta es la forma honesta de comprobar que el primer viewport
/// respeta area segura, barra de estado y zona del gesto de vuelta.
const margenIOS = EdgeInsets.only(top: 47, bottom: 34);
const margenAndroid = EdgeInsets.only(top: 24, bottom: 24);

Previa previaDeMuestra({
  required String titulo,
  required int plazasLibres,
  required int hora,
  double desplazamiento = 0,
}) => Previa(
  id: titulo,
  titulo: titulo,
  zona: 'Malasaña',
  ubicacion: LatLng(40.4258 + desplazamiento, -3.7038 + desplazamiento),
  // Fecha fija: un golden no puede depender de cuando se ejecuta.
  empiezaEn: DateTime(2026, 6, 12, hora, 30),
  plazasLibres: plazasLibres,
  anfitrionId: 'anfitrion',
  anfitrionNombre: 'Marta Ruiz',
  anfitrionReputacion: 4.8,
  descripcion: 'Piso grande con terraza, ponemos nosotros el equipo.',
  ambiente: const ['techno', 'tranquila'],
  distanciaMetros: 450,
);

List<Previa> previasDeMuestra() => [
  previaDeMuestra(titulo: 'Previa en Malasaña', plazasLibres: 5, hora: 23),
  previaDeMuestra(
    titulo: 'Antes del Mondo',
    plazasLibres: 2,
    hora: 22,
    desplazamiento: 0.004,
  ),
  previaDeMuestra(
    titulo: 'Cumple de Ana',
    plazasLibres: 0,
    hora: 21,
    desplazamiento: -0.005,
  ),
];
