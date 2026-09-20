import 'package:flutter_test/flutter_test.dart';
import 'package:previa/data/repositories/repositorio_auth.dart';

/// La comprobacion de mayoria de edad del cliente.
///
/// Sirve para dar un mensaje inmediato al usuario; la barrera que de verdad
/// manda es el disparador de la base de datos, que se prueba aparte en
/// supabase/tests/seguridad.sql.
void main() {
  group('esMayorDeEdad', () {
    final hoy = DateTime.now();

    test('acepta a quien tiene claramente mas de 18', () {
      expect(RepositorioAuth.esMayorDeEdad(DateTime(hoy.year - 25, 6, 15)), isTrue);
    });

    test('rechaza a quien tiene claramente menos de 18', () {
      expect(RepositorioAuth.esMayorDeEdad(DateTime(hoy.year - 15, 6, 15)), isFalse);
    });

    test('acepta a quien cumple 18 justo hoy', () {
      final cumpleHoy = DateTime(hoy.year - 18, hoy.month, hoy.day);
      expect(RepositorioAuth.esMayorDeEdad(cumpleHoy), isTrue);
    });

    test('rechaza a quien cumple 18 manana', () {
      final manana = hoy.add(const Duration(days: 1));
      final cumpleManana = DateTime(manana.year - 18, manana.month, manana.day);
      expect(RepositorioAuth.esMayorDeEdad(cumpleManana), isFalse);
    });

    test('rechaza a quien cumplio 17 este ano', () {
      expect(
        RepositorioAuth.esMayorDeEdad(DateTime(hoy.year - 17, 1, 1)),
        isFalse,
      );
    });
  });
}
