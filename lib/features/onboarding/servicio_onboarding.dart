import 'package:shared_preferences/shared_preferences.dart';

/// Recuerda si la persona ya ha pasado por el onboarding de este dispositivo.
///
/// Todo va envuelto en try/catch por una razon: si el almacenamiento falla
/// (disco lleno, plugin no disponible), el onboarding es un extra. Nunca debe
/// dejar a alguien fuera de la app ni provocar que se le enseñe en bucle.
abstract final class ServicioOnboarding {
  static const _clave = 'onboarding_visto_v1';

  /// Cache en memoria: el guardia de rutas lo consulta en cada redireccion y
  /// no hay motivo para ir al disco cada vez una vez sabemos que esta visto.
  static bool _vistoEnMemoria = false;

  /// True si ya se vio, o si no podemos saberlo. Ante la duda se asume
  /// "visto": es mejor saltarse una explicacion que atrapar al usuario.
  static Future<bool> yaVisto() async {
    if (_vistoEnMemoria) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _vistoEnMemoria = prefs.getBool(_clave) ?? false;
      return _vistoEnMemoria;
    } catch (_) {
      return true;
    }
  }

  static Future<void> marcarVisto() async {
    // Se marca en memoria primero: aunque falle el disco, en esta sesion no
    // volvera a aparecer.
    _vistoEnMemoria = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_clave, true);
    } catch (_) {
      // Sin persistencia: como mucho se vera otra vez en la proxima apertura.
    }
  }

  /// Solo para pruebas: olvida el estado en memoria.
  static void reiniciarParaPruebas() => _vistoEnMemoria = false;
}
