import 'package:flutter_test/flutter_test.dart';
import 'package:previa/features/juegos/datos/retos.dart';
import 'package:previa/features/juegos/modelo_juegos.dart';

/// Fragmentos que ninguna carta puede contener (limites duros de la app).
const _prohibidas = <String>[
  'desnud',
  'beso',
  'besa',
  'chupit',
  'conduc',
  'coche',
  'droga',
  'porro',
  'pasti',
  'cocaina',
  'cocaína',
  'alcohol',
  'mezcl',
  'sexo',
  'sexual',
  'porno',
  'orgasmo',
  'menor de',
  'trepa',
  'salta ',
  'apnea',
  'aguanta la respiraci',
  'de un trago',
  'hasta vomitar',
  'chino',
  'gitano',
  'maricon',
  'marica',
];

int _cuenta(TipoJuego j, [NivelReto? n]) => todosLosRetos
    .where((r) => r.juego == j && (n == null || r.nivel == n))
    .length;

void main() {
  test('conteos minimos por juego', () {
    expect(_cuenta(TipoJuego.noHayHuevos), greaterThanOrEqualTo(160));
    expect(_cuenta(TipoJuego.yoNunca), greaterThanOrEqualTo(70));
    expect(_cuenta(TipoJuego.masProbable), greaterThanOrEqualTo(70));
    expect(_cuenta(TipoJuego.verdadOReto), greaterThanOrEqualTo(60));
  });

  test('No hay huevos: reparto por nivel', () {
    expect(_cuenta(TipoJuego.noHayHuevos, NivelReto.suave),
        greaterThanOrEqualTo(55));
    expect(_cuenta(TipoJuego.noHayHuevos, NivelReto.atrevido),
        greaterThanOrEqualTo(60));
    expect(_cuenta(TipoJuego.noHayHuevos, NivelReto.sinFiltro),
        greaterThanOrEqualTo(45));
  });

  test('los demas juegos mezclan los tres niveles', () {
    for (final j in [
      TipoJuego.yoNunca,
      TipoJuego.masProbable,
      TipoJuego.verdadOReto,
    ]) {
      for (final n in NivelReto.values) {
        expect(_cuenta(j, n), greaterThanOrEqualTo(15),
            reason: '${j.name}/${n.name}');
      }
    }
  });

  test('ids unicos y con el prefijo de su juego', () {
    final ids = todosLosRetos.map((r) => r.id).toList();
    expect(ids.toSet().length, ids.length);
    const prefijos = {
      TipoJuego.noHayHuevos: 'nhh-',
      TipoJuego.yoNunca: 'yn-',
      TipoJuego.masProbable: 'mp-',
      TipoJuego.verdadOReto: 'vr-',
    };
    for (final r in todosLosRetos) {
      expect(r.id.startsWith(prefijos[r.juego]!), isTrue, reason: r.id);
    }
  });

  test('textos unicos y de 1 a 140 caracteres', () {
    final vistos = <String>{};
    for (final r in todosLosRetos) {
      expect(r.texto.trim(), isNotEmpty, reason: r.id);
      expect(r.texto.length, lessThanOrEqualTo(140), reason: r.id);
      expect(vistos.add('${r.juego.name}|${r.texto.toLowerCase()}'), isTrue,
          reason: 'duplicado: ${r.id}');
    }
  });

  test('sorbos entre 1 y 3', () {
    for (final r in todosLosRetos) {
      expect(r.sorbos, inInclusiveRange(1, 3), reason: r.id);
    }
  });

  test('{otro} coherente con necesitaOtraPersona', () {
    for (final r in todosLosRetos) {
      expect(r.texto.contains('{otro}'), r.necesitaOtraPersona,
          reason: r.id);
    }
  });

  test('contactoFisico solo en retos con {otro}', () {
    for (final r in todosLosRetos.where((r) => r.contactoFisico)) {
      expect(r.necesitaOtraPersona, isTrue, reason: r.id);
    }
  });

  test('ninguna carta contiene palabras prohibidas', () {
    for (final r in todosLosRetos) {
      final t = r.texto.toLowerCase();
      for (final p in _prohibidas) {
        expect(t.contains(p), isFalse, reason: '${r.id} contiene "$p"');
      }
    }
  });
}
