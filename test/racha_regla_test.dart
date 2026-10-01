import 'package:flutter_test/flutter_test.dart';
import 'package:previa/domain/racha/regla_de_racha.dart';

/// Fechas de referencia: el jueves 1-10-2026 cae en la semana que empieza el
/// lunes 28-9. Las anteriores empiezan el 21-9, 14-9, 7-9, 31-8 y 24-8.
DateTime d(int a, int m, int dia) => DateTime.utc(a, m, dia);

/// Jueves 1-oct-2026 a las 12:00 en Madrid (10:00 UTC, horario de verano).
final jueves = DateTime.utc(2026, 10, 1, 10);

void main() {
  group('nocheActual (Europe/Madrid, corte a las 6:00)', () {
    test('a las 3:00 del domingo sigue siendo la noche del sábado', () {
      // 03:00 en Madrid en septiembre (UTC+2) = 01:00 UTC.
      expect(nocheActual(DateTime.utc(2026, 9, 27, 1)), d(2026, 9, 26));
    });

    test('a las 6:00 ya es el día nuevo', () {
      expect(nocheActual(DateTime.utc(2026, 9, 27, 4)), d(2026, 9, 27));
    });

    test('en invierno el desfase es de una hora, no de dos', () {
      expect(nocheActual(DateTime.utc(2026, 1, 10, 5, 30)), d(2026, 1, 10));
      expect(nocheActual(DateTime.utc(2026, 1, 10, 4, 30)), d(2026, 1, 9));
    });

    test('el cambio de hora cae en domingo a la 01:00 UTC', () {
      // Último domingo de marzo de 2026: el 29. Antes, UTC+1.
      expect(nocheActual(DateTime.utc(2026, 3, 29, 0, 30)), d(2026, 3, 28));
      // Último de octubre: el 25. Desde la 01:00 UTC ya es UTC+1.
      expect(nocheActual(DateTime.utc(2026, 10, 25, 4, 30)), d(2026, 10, 24));
      expect(nocheActual(DateTime.utc(2026, 10, 25, 5, 30)), d(2026, 10, 25));
    });

    test('la zona horaria del teléfono no cambia el resultado', () {
      final local = DateTime.utc(2026, 9, 27, 1).toLocal();
      expect(nocheActual(local), d(2026, 9, 26));
    });
  });

  group('calcularRacha', () {
    test('sin noches no hay racha', () {
      expect(calcularRacha([], ahora: jueves), const Racha());
    });

    test('una noche esta semana: 1 semana y salí esta semana', () {
      final r = calcularRacha([d(2026, 9, 29)], ahora: jueves);
      expect(r.semanas, 1);
      expect(r.saliEstaSemana, isTrue);
      expect(r.enRiesgo, isFalse);
    });

    test('dos noches la misma semana cuentan como una', () {
      final r = calcularRacha([
        d(2026, 9, 25),
        d(2026, 9, 26),
        d(2026, 9, 27),
      ], ahora: jueves);
      expect(r.semanas, 1);
    });

    test('semanas consecutivas suman', () {
      final r = calcularRacha([
        d(2026, 9, 12),
        d(2026, 9, 19),
        d(2026, 9, 26),
      ], ahora: jueves);
      expect(r.semanas, 3);
      expect(r.enRiesgo, isTrue, reason: 'esta semana aún no has salido');
    });

    test('la semana en curso sin salir no rompe la racha', () {
      final r = calcularRacha([
        d(2026, 9, 26),
      ], ahora: DateTime.utc(2026, 9, 28, 10));
      expect(r.semanas, 1);
      expect(r.enRiesgo, isTrue);
    });

    test('lunes a las 3:00 aún es la noche del domingo: misma semana', () {
      final r = calcularRacha([
        d(2026, 9, 26),
      ], ahora: DateTime.utc(2026, 9, 28, 1));
      expect(r.saliEstaSemana, isTrue);
      expect(r.semanas, 1);
    });

    test('una semana saltada se perdona con el comodín y no suma', () {
      // Semanas del 31-8, 14-9 y 21-9; la del 7-9 queda vacía.
      final r = calcularRacha([
        d(2026, 9, 5),
        d(2026, 9, 19),
        d(2026, 9, 26),
      ], ahora: jueves);
      expect(r.semanas, 3);
      expect(r.comodinGastado, isTrue);
    });

    test('dos semanas saltadas seguidas rompen la racha', () {
      final r = calcularRacha([
        d(2026, 8, 29),
        d(2026, 8, 30),
        d(2026, 9, 19),
        d(2026, 9, 26),
      ], ahora: jueves);
      expect(r.semanas, 2);
      expect(r.mejor, 2);
    });

    test('el comodín solo se usa una vez por racha', () {
      final r = calcularRacha([
        d(2026, 8, 29), // semana del 24-8
        d(2026, 9, 12), // semana del 7-9 (31-8 perdonada)
        d(2026, 9, 26), // semana del 21-9 (14-9 vacía: rompe)
      ], ahora: jueves);
      expect(r.semanas, 1);
    });

    test('la semana vacía recién terminada se perdona si queda comodín', () {
      // Última noche en la semana del 14-9; la del 21-9 pasó vacía.
      final r = calcularRacha([d(2026, 9, 12), d(2026, 9, 15)], ahora: jueves);
      expect(r.semanas, 2);
      expect(r.comodinGastado, isTrue);
      expect(r.enRiesgo, isTrue);
    });

    test('con el comodín ya gastado, una semana vacía cerrada rompe', () {
      final r = calcularRacha([
        d(2026, 8, 29), // 24-8
        d(2026, 9, 12), // 7-9 (31-8 perdonada)
        // 14-9 vacía y 21-9 vacía hasta hoy
      ], ahora: jueves);
      expect(r.semanas, 0);
      expect(r.mejor, 2);
    });

    test('dos semanas vacías tras la última rompen, pero el récord queda', () {
      final r = calcularRacha([
        d(2026, 8, 29),
        d(2026, 9, 5),
        d(2026, 9, 12),
      ], ahora: jueves);
      expect(r.semanas, 0);
      expect(r.viva, isFalse);
      expect(r.mejor, 3);
    });

    test('cambio de año: el 29-12 (lunes) a 4-1 es una sola semana', () {
      final r = calcularRacha([
        d(2025, 12, 20),
        d(2025, 12, 27),
        d(2026, 1, 3),
        d(2026, 1, 10),
      ], ahora: DateTime.utc(2026, 1, 12, 10));
      expect(r.semanas, 4);
    });

    test('el 29-12 y el 1-1 son la misma semana', () {
      final r = calcularRacha([
        d(2025, 12, 29),
        d(2026, 1, 1),
      ], ahora: DateTime.utc(2026, 1, 2, 10));
      expect(r.semanas, 1);
    });

    test('las noches futuras no cuentan', () {
      final r = calcularRacha([d(2026, 10, 2), d(2026, 10, 10)], ahora: jueves);
      expect(r.semanas, 0);
    });

    test('las fechas repetidas (voy y foto) no suman dos veces', () {
      final r = calcularRacha([d(2026, 9, 26), d(2026, 9, 26)], ahora: jueves);
      expect(r.semanas, 1);
    });

    test('un DateTime con hora cuenta solo por su fecha', () {
      final r = calcularRacha([DateTime(2026, 9, 29, 23, 59)], ahora: jueves);
      expect(r.semanas, 1);
    });

    test('el cambio de hora de octubre (domingo de 25 horas) no descuadra', () {
      final r = calcularRacha([
        d(2026, 10, 24),
        d(2026, 10, 31),
      ], ahora: DateTime.utc(2026, 11, 2, 10));
      expect(r.semanas, 2);
    });
  });

  group('hitos y progreso', () {
    Racha con(int s) => Racha(semanas: s, mejor: s, saliEstaSemana: true);

    test('siguiente hito y semanas que faltan', () {
      expect(con(0).siguienteHito, 3);
      expect(con(2).semanasParaHito, 1);
      expect(con(3).siguienteHito, 5);
      expect(con(5).siguienteHito, 10);
      expect(con(19).siguienteHito, 20);
      expect(con(20).siguienteHito, isNull);
      expect(con(25).semanasParaHito, 0);
    });

    test('el progreso se mide desde el hito anterior', () {
      expect(con(0).progreso, 0);
      expect(con(1).progreso, closeTo(1 / 3, 1e-9));
      expect(con(3).progreso, 0);
      expect(con(4).progreso, closeTo(0.5, 1e-9));
      expect(con(5).progreso, 0);
      expect(con(7).progreso, closeTo(0.4, 1e-9));
      expect(con(20).progreso, 1);
    });

    test('hitoAlcanzado es el mayor superado', () {
      expect(con(2).hitoAlcanzado, isNull);
      expect(con(3).hitoAlcanzado, 3);
      expect(con(9).hitoAlcanzado, 5);
      expect(con(30).hitoAlcanzado, 20);
    });

    test('hitoPorCelebrar solo devuelve hitos nuevos y el mayor', () {
      expect(hitoPorCelebrar(con(2), celebrado: 0), isNull);
      expect(hitoPorCelebrar(con(3), celebrado: 0), 3);
      expect(hitoPorCelebrar(con(3), celebrado: 3), isNull);
      expect(
        hitoPorCelebrar(con(10), celebrado: 3),
        10,
        reason: 'si se salta el 5 se celebra solo el 10',
      );
      expect(
        hitoPorCelebrar(con(5), celebrado: 5),
        isNull,
        reason: 'racha rota y rehecha: no se repite un hito ya celebrado',
      );
    });
  });
}
