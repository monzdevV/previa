import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../data/models/previa.dart';

/// Previas que se dibujan juntas en el mapa porque sus placas se pisarian.
class GrupoPrevias {
  const GrupoPrevias(this.previas, this.centro);

  final List<Previa> previas;

  /// Media de las posiciones (ya difuminadas) del grupo.
  final LatLng centro;

  bool get esAgrupado => previas.length > 1;
}

/// Lado de la celda de agrupado, en pixeles de pantalla. Una placa mide unos
/// 84 x 34: con celdas de 64 dos placas de la misma celda se pisarian.
const celdaDeAgrupado = 64.0;

/// Agrupa las previas cuyas placas se pisarian a este [zoom].
///
/// Rejilla en pixeles de Web Mercator (la proyeccion del mapa, teselas de
/// 256): al acercarse las celdas encogen en metros y los grupos se deshacen
/// solos. Se agrupan ya desde dos previas, y no desde tres, porque aqui cada
/// previa es una placa con cara y numero, no un punto: dos placas montadas
/// no se leen. Es una funcion pura para poder probarla sin mapa.
List<GrupoPrevias> agruparPrevias(
  List<Previa> previas,
  double zoom, {
  double celda = celdaDeAgrupado,
}) {
  if (previas.length < 2) {
    return [
      for (final p in previas) GrupoPrevias([p], p.ubicacion),
    ];
  }
  final escala = 256 * math.pow(2, zoom);
  final celdas = <(int, int), List<Previa>>{};
  for (final p in previas) {
    final (x, y) = _proyectar(p.ubicacion, escala.toDouble());
    celdas
        .putIfAbsent(((x / celda).floor(), (y / celda).floor()), () => [])
        .add(p);
  }
  return [
    for (final lista in celdas.values)
      if (lista.length == 1)
        GrupoPrevias(lista, lista.first.ubicacion)
      else
        GrupoPrevias(lista, _centroide(lista)),
  ];
}

/// Web Mercator: grados a pixeles del mundo a la escala dada.
(double, double) _proyectar(LatLng punto, double escala) {
  final lat = punto.latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180;
  final x = (punto.longitude + 180) / 360 * escala;
  final y =
      (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * escala;
  return (x, y);
}

LatLng _centroide(List<Previa> grupo) {
  var lat = 0.0;
  var lng = 0.0;
  for (final p in grupo) {
    lat += p.ubicacion.latitude;
    lng += p.ubicacion.longitude;
  }
  return LatLng(lat / grupo.length, lng / grupo.length);
}
