import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// El plano de fondo de todos los mapas de la app.
///
/// Son las teselas "Canvas" de Esri: gris oscuro o claro segun el tema, sin
/// clave de API ni cuenta. Antes eran las de CARTO, pero en septiembre de
/// 2026 empezaron a servir las gratuitas con "API KEY REQUIRED" impreso
/// encima. Vive en un solo sitio para que el siguiente cambio de proveedor
/// sea tocar este fichero y no tres pantallas.
///
/// Van en dos capas porque Esri sirve aparte los nombres de calles: asi el
/// plano queda apagado y los circulos de las previas mandan.
///
/// [conAtribucion] es falso en el mapa principal, que ya lleva su propia
/// atribucion desplegable.
List<Widget> capasBaseDelMapa(
  BuildContext context, {
  TileProvider? proveedor,
  bool conAtribucion = true,
}) {
  final tono = Theme.of(context).brightness == Brightness.light
      ? 'Light_Gray'
      : 'Dark_Gray';

  TileLayer capa(String servicio) => TileLayer(
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/'
        'World_$servicio/MapServer/tile/{z}/{y}/{x}',
    // Por encima de 16 Esri ya no tiene detalle y devuelve teselas vacias;
    // flutter_map amplia las del 16.
    maxNativeZoom: 16,
    userAgentPackageName: 'com.previa.previa',
    tileProvider: proveedor,
  );

  return [
    capa('${tono}_Base'),
    capa('${tono}_Reference'),
    if (conAtribucion) const _Atribucion(),
  ];
}

/// Esri pide que se cite la fuente del plano.
class _Atribucion extends StatelessWidget {
  const _Atribucion();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.bottomLeft,
    child: Padding(
      padding: EdgeInsets.all(4),
      child: Text(
        '© Esri, OpenStreetMap',
        style: TextStyle(fontSize: 9, color: Color(0x99888888)),
      ),
    ),
  );
}
