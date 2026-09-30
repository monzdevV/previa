import 'package:flutter_test/flutter_test.dart';
import 'package:previa/data/models/perfil.dart';
import 'package:previa/features/profile/reputacion.dart';
import 'package:previa/features/ratings/etiquetas_valoracion.dart';

Perfil _perfil(double? media, int n) => Perfil(
      id: 'x',
      username: 'u',
      nombre: 'Ana',
      onboarded: true,
      reputacion: media,
      numeroValoraciones: n,
    );

void main() {
  test('las etiquetas se guardan y se recuperan del comentario', () {
    final c = componerComentario(['puntual', 'buen rollo'], ' Gran noche ');
    expect(c, '[puntual, buen rollo] Gran noche');
    final d = descomponerComentario(c);
    expect(d.claves, ['puntual', 'buen rollo']);
    expect(d.texto, 'Gran noche');
  });

  test('sin etiquetas el comentario queda igual y nunca pasa de 300', () {
    expect(componerComentario([], ' hola '), 'hola');
    final largo = componerComentario(['puntual'], 'a' * 400);
    expect(largo.length <= maximoComentario, isTrue);
  });

  test('insignias segun numero y media', () {
    expect(insigniasDe(_perfil(null, 0)).single.texto, 'Recién llegada');
    expect(insigniasDe(_perfil(4.6, 3)).map((i) => i.texto),
        contains('Buena compañía'));
    expect(insigniasDe(_perfil(4.8, 10)).map((i) => i.texto),
        contains('Anfitrión fiable'));
    expect(insigniasDe(_perfil(5, 1)).single.texto, 'Tomando ritmo');
  });
}
