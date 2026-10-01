import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:previa/data/models/local.dart';
import 'package:previa/features/social/pantalla_locales.dart';

void main() {
  // La plaza del Pilar, en Zaragoza.
  const pilar = LatLng(41.6566, -0.8784);

  Local local(String id, {double? lat, double? lng}) =>
      Local(id: id, nombre: id, ciudad: 'Zaragoza', lat: lat, lng: lng);

  group('ordenarPorCercania', () {
    test('pone primero lo mas cerca y al final lo que no tiene sitio', () {
      final lista = [
        local('lejos', lat: 41.6700, lng: -0.9200),
        local('sin_sitio'),
        local('cerca', lat: 41.6560, lng: -0.8790),
      ];
      final orden = ordenarPorCercania(lista, pilar);
      expect(orden.map((e) => e.$1.id), ['cerca', 'lejos', 'sin_sitio']);
      expect(orden.first.$2, lessThan(200));
      expect(orden.last.$2, isNull);
    });

    test('sin posicion respeta el orden del servidor', () {
      final lista = [
        local('a', lat: 41.7, lng: -0.9),
        local('b', lat: 41.6, lng: -0.8),
      ];
      final orden = ordenarPorCercania(lista, null);
      expect(orden.map((e) => e.$1.id), ['a', 'b']);
      expect(orden.every((e) => e.$2 == null), isTrue);
    });
  });

  test('la distancia se escribe como en la calle', () {
    expect(textoDistancia(731), '730 m');
    expect(textoDistancia(1000), '1 km');
    expect(textoDistancia(1460), '1,5 km');
    expect(textoDistancia(74200), '74 km');
  });

  group('Local.desdeJson', () {
    test('tolera el servidor sin foto, logo ni coordenadas', () {
      final l = Local.desdeJson({
        'id': '1',
        'name': 'Oasis',
        'city': 'Zaragoza',
        'instagram': 'oasis',
        'van': 3,
        'voy': true,
      });
      expect(l.portadaUrl, isNull);
      expect(l.logoUrl, isNull);
      expect(l.metrosHasta(pilar.latitude, pilar.longitude), isNull);
      expect(l.lema, '@oasis');
      expect(l.miEstado, EstadoNoche.voy);
    });

    test('lee foto, logo, eslogan y sitio cuando llegan', () {
      final l = Local.desdeJson({
        'id': '1',
        'name': 'Oasis',
        'city': 'Zaragoza',
        'cover_url': 'https://x.test/portada.jpg',
        'logo_url': '  ',
        'tagline': 'Tu finde empieza aquí',
        'lat': 41.65,
        'lng': -0.88,
      });
      expect(l.portadaUrl, 'https://x.test/portada.jpg');
      // Una URL en blanco no debe pedir una imagen vacia.
      expect(l.logoUrl, isNull);
      expect(l.lema, 'Tu finde empieza aquí');
      // Cambiar tu respuesta no puede perder la foto ni el sitio.
      final cambiado = l.conMiEstado(EstadoNoche.voy);
      expect(cambiado.portadaUrl, l.portadaUrl);
      expect(cambiado.lat, l.lat);
    });
  });
}
