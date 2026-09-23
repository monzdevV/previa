import 'package:flutter_test/flutter_test.dart';
import 'package:previa/data/models/reto.dart';

void main() {
  group('Reto.desdeJson', () {
    test('lee la fila de mi_reto tal como la devuelve la base de datos', () {
      final reto = Reto.desdeJson({
        'id': 'r1',
        'texto': 'Busca a Hugo y haceos una foto.',
        'origen': 'ia',
        'creado_en': '2026-09-23T21:27:06.337121+00:00',
        'objetivo_id': 'p1',
        'objetivo_usuario': 'hugo',
        'objetivo_nombre': 'Hugo',
        'objetivo_avatar': null,
        'objetivo_bio': null,
        'retos_restantes': 7,
      });

      expect(reto.deIa, isTrue);
      expect(reto.objetivoUsuario, 'hugo');
      expect(reto.objetivoAvatar, isNull);
      expect(reto.restantes, 7);
    });

    test('un reto de plantilla no se presenta como de la IA', () {
      final reto = Reto.desdeJson({
        'id': 'r1',
        'texto': 'x',
        'origen': 'plantilla',
        'objetivo_id': 'p1',
        'objetivo_usuario': 'u',
        'objetivo_nombre': 'U',
      });
      expect(reto.deIa, isFalse);
      expect(reto.restantes, 0);
    });
  });

  group('MotivoSinReto', () {
    test('cada codigo de la base de datos tiene su mensaje propio', () {
      const codigos = [
        'NO_VAS',
        'NO_ESTAS_AQUI',
        'SIN_UBICACION',
        'YA_TIENES_RETO',
        'LIMITE_NOCHE',
        'NO_HAY_NADIE',
        'SIN_SESION',
      ];
      final motivos = codigos.map(MotivoSinReto.desdeCodigo).toSet();

      expect(motivos, hasLength(codigos.length));
      expect(motivos, isNot(contains(MotivoSinReto.desconocido)));
    });

    test('lo que no se conoce cae en un mensaje generico', () {
      expect(MotivoSinReto.desdeCodigo('ERROR'), MotivoSinReto.desconocido);
      expect(MotivoSinReto.desdeCodigo(null), MotivoSinReto.desconocido);
    });
  });
}
