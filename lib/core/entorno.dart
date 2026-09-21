import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuracion que no debe vivir en el codigo fuente.
///
/// Los valores se leen del fichero `.env`, que esta excluido del repositorio.
/// Para preparar un equipo nuevo se copia `.env.example` a `.env` y se
/// rellenan los valores.
abstract final class Entorno {
  static String get supabaseUrl => _leer('SUPABASE_URL');

  /// Clave publicable. Es publica por diseño: no da ningun acceso por si
  /// sola, porque quien manda son las politicas de seguridad de la base de
  /// datos. Aun asi se mantiene fuera del repositorio para no atarlo a un
  /// proyecto de Supabase concreto.
  static String get supabasePublishableKey => _leer('SUPABASE_PUBLISHABLE_KEY');

  /// Radio por defecto de la busqueda en el mapa, en metros.
  static const int radioBusquedaPorDefecto = 5000;

  /// Ventana temporal por defecto: previas que empiezan en las proximas horas.
  static const int horasPorDefecto = 12;

  /// Desplazamiento aplicado a la ubicacion publica, en metros.
  /// Solo informativo: el difuminado real lo hace la base de datos.
  static const int metrosDeDifuminado = 300;

  static String _leer(String clave) {
    final valor = dotenv.env[clave];
    if (valor == null || valor.isEmpty) {
      throw StateError(
        'Falta $clave en el fichero .env. '
        'Copia .env.example a .env y rellena los valores.',
      );
    }
    return valor;
  }
}
