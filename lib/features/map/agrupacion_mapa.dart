import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../data/models/previa.dart';

/// Conjunto de previas que se dibujan juntas en el mapa.
class GrupoPrevias {
  const GrupoPrevias(this.previas, this.centro);

  final List<Previa> previas;

  /// Media de las posiciones (ya difuminadas) del grupo.
  final LatLng centro;

  bool get esAgrupado => previas.length > 1;
}

/// Zoom a partir del cual ya no se agrupa: las previas se ven sueltas.
const zoomSinAgrupar = 15.5;

/// Minimo de previas en una celda para sustituirlas por una burbuja unica.
/// Con 2 es mejor verlas por separado: agrupar dos no ahorra ruido.
const minimoParaAgrupar = 3;

/// Agrupa las previas por celdas de rejilla cuyo tamano depende del zoom
/// (~72 px en pantalla), de modo que al acercarse los grupos se deshacen
/// solos. Es una rejilla y no un algoritmo de distancias porque con <=50
/// previas es instantaneo, determinista y facil de testear.
List<GrupoPrevias> agruparPrevias(List<Previa> previas, double zoom) {
  if (zoom >= zoomSinAgrupar || previas.length < minimoParaAgrupar) {
    return [
      for (final p in previas) GrupoPrevias([p], p.ubicacion),
    ];
  }
  final celda = 360 / math.pow(2, zoom) * (72 / 256);
  final celdas = <(int, int), List<Previa>>{};
  for (final p in previas) {
    final clave = (
      (p.ubicacion.longitude / celda).floor(),
      (p.ubicacion.latitude / celda).floor(),
    );
    celdas.putIfAbsent(clave, () => []).add(p);
  }

  final grupos = <GrupoPrevias>[];
  for (final lista in celdas.values) {
    if (lista.length >= minimoParaAgrupar) {
      final lat = lista
          .map((p) => p.ubicacion.latitude)
          .reduce((a, b) => a + b);
      final lng = lista
          .map((p) => p.ubicacion.longitude)
          .reduce((a, b) => a + b);
      grupos.add(
        GrupoPrevias(lista, LatLng(lat / lista.length, lng / lista.length)),
      );
    } else {
      grupos.addAll([
        for (final p in lista) GrupoPrevias([p], p.ubicacion),
      ]);
    }
  }
  return grupos;
}
