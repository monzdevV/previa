import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:previa/data/models/previa.dart';
import 'package:previa/features/map/proveedores_mapa.dart';

Previa _previaCon({List<String> ambiente = const []}) => Previa(
  id: 'p1',
  titulo: 'Previa de prueba',
  zona: 'Centro',
  ubicacion: const LatLng(37.38, -6.0),
  empiezaEn: DateTime.now().add(const Duration(hours: 3)),
  plazasLibres: 3,
  anfitrionId: 'a1',
  anfitrionNombre: 'Ana',
  ambiente: ambiente,
);

void main() {
  group('Filtros.encaja', () {
    test('sin ambiente marcado, entra cualquier previa', () {
      const filtros = Filtros();
      expect(filtros.encaja(_previaCon()), isTrue);
      expect(filtros.encaja(_previaCon(ambiente: ['techno'])), isTrue);
    });

    test('basta con que coincida una etiqueta', () {
      const filtros = Filtros(ambiente: {'techno', 'terraza'});
      expect(filtros.encaja(_previaCon(ambiente: ['techno'])), isTrue);
      expect(filtros.encaja(_previaCon(ambiente: ['terraza', 'pop'])), isTrue);
    });

    test('no exige que coincidan todas', () {
      const filtros = Filtros(ambiente: {'techno', 'terraza'});
      expect(
        filtros.encaja(_previaCon(ambiente: ['techno'])),
        isTrue,
        reason: 'pedir dos ambientes es pedir un plan asi, no las dos cosas',
      );
    });

    test('descarta lo que no comparte ninguna etiqueta', () {
      const filtros = Filtros(ambiente: {'techno'});
      expect(filtros.encaja(_previaCon(ambiente: ['reggaeton'])), isFalse);
    });

    test('una previa sin ambiente no pasa un filtro con ambiente', () {
      const filtros = Filtros(ambiente: {'techno'});
      expect(filtros.encaja(_previaCon()), isFalse);
    });
  });

  group('Filtros.sonLosPorDefecto', () {
    test('unos filtros recien creados son los de por defecto', () {
      expect(const Filtros().sonLosPorDefecto, isTrue);
    });

    test('marcar un ambiente ya los cambia', () {
      expect(const Filtros(ambiente: {'pop'}).sonLosPorDefecto, isFalse);
    });

    test('cambiar el radio ya los cambia', () {
      expect(const Filtros(radioMetros: 1000).sonLosPorDefecto, isFalse);
    });
  });

  group('Filtros.radioLegible', () {
    test('por debajo del kilometro, en metros', () {
      expect(const Filtros(radioMetros: 800).radioLegible, '800 m');
    });

    test('kilometros exactos, sin decimales', () {
      expect(const Filtros(radioMetros: 5000).radioLegible, '5 km');
    });

    test('kilometros con resto, con un decimal', () {
      expect(const Filtros(radioMetros: 2500).radioLegible, '2.5 km');
    });
  });
}
