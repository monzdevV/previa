import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

final servicioUbicacionProvider = Provider<ServicioUbicacion>(
  (ref) => const ServicioUbicacion(),
);

/// Por que ha fallado la ubicacion. Cada caso necesita un mensaje y una
/// accion distintos, asi que no vale con un booleano.
enum FalloUbicacion {
  /// El GPS del telefono esta apagado.
  servicioApagado,

  /// El usuario ha dicho que no, pero se le puede volver a preguntar.
  permisoDenegado,

  /// El usuario ha dicho que no para siempre: hay que ir a los ajustes.
  permisoDenegadoParaSiempre,

  /// El telefono no ha devuelto posicion a tiempo.
  sinRespuesta,
}

class ErrorUbicacion implements Exception {
  const ErrorUbicacion(this.causa);
  final FalloUbicacion causa;

  String get mensaje => switch (causa) {
    FalloUbicacion.servicioApagado =>
      'Tienes la ubicación desactivada en el teléfono.',
    FalloUbicacion.permisoDenegado =>
      'Necesitamos tu ubicación para enseñarte previas cerca.',
    FalloUbicacion.permisoDenegadoParaSiempre =>
      'Has bloqueado la ubicación. Actívala en los ajustes del teléfono.',
    FalloUbicacion.sinRespuesta =>
      'No hemos podido situarte. Inténtalo de nuevo.',
  };

  @override
  String toString() => mensaje;
}

/// Acceso a la posicion del dispositivo.
///
/// Dos decisiones deliberadas:
///
/// 1. Precision media, no maxima. Para buscar previas en un radio de
///    kilometros sobra, y gasta bastante menos bateria.
/// 2. La posicion no se guarda en ningun sitio. Se usa en memoria para hacer
///    la consulta y se descarta. Lo unico que se almacena de forma permanente
///    es el punto de una previa que alguien publica a proposito.
class ServicioUbicacion {
  const ServicioUbicacion();

  /// Centro de reserva cuando no hay ubicacion: Puerta del Sol.
  /// Asi el mapa siempre tiene algo que enseñar en vez de quedarse en blanco.
  static const centroPorDefecto = LatLng(40.4168, -3.7038);

  Future<LatLng> posicionActual() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ErrorUbicacion(FalloUbicacion.servicioApagado);
    }

    var permiso = await Geolocator.checkPermission();

    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    if (permiso == LocationPermission.deniedForever) {
      throw const ErrorUbicacion(FalloUbicacion.permisoDenegadoParaSiempre);
    }
    if (permiso == LocationPermission.denied) {
      throw const ErrorUbicacion(FalloUbicacion.permisoDenegado);
    }

    try {
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(posicion.latitude, posicion.longitude);
    } catch (_) {
      // Si no llega posicion nueva, sirve la ultima conocida.
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima != null) return LatLng(ultima.latitude, ultima.longitude);
      throw const ErrorUbicacion(FalloUbicacion.sinRespuesta);
    }
  }

  Future<void> abrirAjustes() => Geolocator.openAppSettings();
}
