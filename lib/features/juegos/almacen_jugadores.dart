import 'package:shared_preferences/shared_preferences.dart';

import 'modelo_juegos.dart';
import 'motor/partida.dart';

/// Recuerda la última lista de jugadores y el nivel para no reescribirlos en
/// cada previa. Todo es opcional: si el almacenamiento falla, se juega igual.
abstract final class AlmacenJugadores {
  static const _claveJugadores = 'juegos_jugadores';
  static const _claveNivel = 'juegos_nivel';

  static Future<List<String>> leerJugadores() async {
    try {
      final p = await SharedPreferences.getInstance();
      return limpiarNombres(p.getStringList(_claveJugadores) ?? const []);
    } catch (_) {
      return const [];
    }
  }

  static Future<NivelReto?> leerNivel() async {
    try {
      final p = await SharedPreferences.getInstance();
      final i = p.getInt(_claveNivel);
      if (i == null || i < 0 || i >= NivelReto.values.length) return null;
      return NivelReto.values[i];
    } catch (_) {
      return null;
    }
  }

  static Future<void> guardar(List<String> jugadores, NivelReto nivel) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_claveJugadores, jugadores);
      await p.setInt(_claveNivel, nivel.index);
    } catch (_) {
      // Sin persistencia no pasa nada: solo habra que reescribir los nombres.
    }
  }
}
