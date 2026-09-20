import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/entorno.dart';
import '../../data/models/previa.dart';
import '../../data/repositories/repositorio_previas.dart';
import '../../data/services/servicio_ubicacion.dart';

/// Donde esta mirando el usuario. Empieza en su posicion real y cambia si
/// arrastra el mapa, porque buscar en otra zona es un caso de uso legitimo:
/// "esta noche salgo por el centro aunque viva en las afueras".
class CentroBusqueda extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  void fijar(LatLng punto) => state = punto;
}

final centroBusquedaProvider =
    NotifierProvider<CentroBusqueda, LatLng?>(CentroBusqueda.new);

/// Posicion real del dispositivo. Se pide una vez al abrir el mapa.
final posicionDispositivoProvider = FutureProvider<LatLng>((ref) async {
  return ref.watch(servicioUbicacionProvider).posicionActual();
});

/// Criterios de filtrado que el usuario maneja desde la hoja de filtros.
class Filtros {
  const Filtros({
    this.radioMetros = Entorno.radioBusquedaPorDefecto,
    this.horas = Entorno.horasPorDefecto,
    this.plazasMinimas = 1,
  });

  final int radioMetros;
  final int horas;
  final int plazasMinimas;

  Filtros copiarCon({int? radioMetros, int? horas, int? plazasMinimas}) => Filtros(
        radioMetros: radioMetros ?? this.radioMetros,
        horas: horas ?? this.horas,
        plazasMinimas: plazasMinimas ?? this.plazasMinimas,
      );

  bool get sonLosPorDefecto =>
      radioMetros == Entorno.radioBusquedaPorDefecto &&
      horas == Entorno.horasPorDefecto &&
      plazasMinimas == 1;

  String get radioLegible => radioMetros >= 1000
      ? '${(radioMetros / 1000).toStringAsFixed(radioMetros % 1000 == 0 ? 0 : 1)} km'
      : '$radioMetros m';
}

class FiltrosNotifier extends Notifier<Filtros> {
  @override
  Filtros build() => const Filtros();

  void fijarRadio(int metros) => state = state.copiarCon(radioMetros: metros);
  void fijarHoras(int horas) => state = state.copiarCon(horas: horas);
  void fijarPlazas(int plazas) => state = state.copiarCon(plazasMinimas: plazas);
  void restablecer() => state = const Filtros();
}

final filtrosProvider =
    NotifierProvider<FiltrosNotifier, Filtros>(FiltrosNotifier.new);

/// Las previas que se pintan en el mapa.
///
/// Depende del centro y de los filtros: cuando cambia cualquiera de los dos,
/// Riverpod rehace la consulta solo.
final previasCercaProvider = FutureProvider<List<Previa>>((ref) async {
  final elegido = ref.watch(centroBusquedaProvider);
  final LatLng centro =
      elegido ?? await ref.watch(posicionDispositivoProvider.future);
  final filtros = ref.watch(filtrosProvider);

  return ref.watch(repositorioPreviasProvider).buscarCerca(
        FiltrosBusqueda(
          centro: centro,
          radioMetros: filtros.radioMetros,
          horas: filtros.horas,
          plazasMinimas: filtros.plazasMinimas,
        ),
      );
});

/// Las previas que organiza el propio usuario.
final misPreviasProvider = FutureProvider<List<Previa>>(
  (ref) => ref.watch(repositorioPreviasProvider).misPrevias(),
);
