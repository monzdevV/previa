import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Claro, oscuro o lo que diga el sistema.
///
/// Por defecto sigue al sistema: quien tiene el movil en claro espera que una
/// aplicacion recien instalada tambien lo este. Quien prefiera otra cosa lo
/// cambia en Ajustes y se recuerda.
class ModoDeTema extends Notifier<ThemeMode> {
  static const _clave = 'modo_de_tema';

  @override
  ThemeMode build() {
    _cargar();
    return ThemeMode.system;
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_clave);
    if (guardado == null) return;
    state = ThemeMode.values.firstWhere(
      (m) => m.name == guardado,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> fijar(ThemeMode modo) async {
    state = modo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, modo.name);
  }
}

final modoDeTemaProvider = NotifierProvider<ModoDeTema, ThemeMode>(
  ModoDeTema.new,
);

extension NombreDelModo on ThemeMode {
  String get enEspanol => switch (this) {
    ThemeMode.system => 'El del sistema',
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Oscuro',
  };

  IconData get icono => switch (this) {
    ThemeMode.system => Icons.brightness_auto_rounded,
    ThemeMode.light => Icons.light_mode_rounded,
    ThemeMode.dark => Icons.dark_mode_rounded,
  };
}
