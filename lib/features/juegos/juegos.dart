import 'package:flutter/material.dart';

import 'pantalla_hub_juegos.dart';

export 'modelo_juegos.dart';
export 'pantalla_hub_juegos.dart' show PantallaHubJuegos;

/// Abre el hub de juegos de previa desde cualquier pantalla.
///
/// [jugadoresIniciales] (p. ej. los asistentes de la previa) rellena la lista
/// de la preparación; si viene vacía se usa la última lista recordada.
/// Se usa el Navigator directamente y no una ruta con parámetros porque la
/// lista de nombres no cabe bien en una URL y los juegos no necesitan enlace.
Future<void> abrirJuegos(
  BuildContext context, {
  List<String> jugadoresIniciales = const [],
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PantallaHubJuegos(
        jugadoresIniciales: jugadoresIniciales,
        conAtras: true,
      ),
    ),
  );
}
