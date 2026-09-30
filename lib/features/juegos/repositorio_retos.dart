import 'datos/retos.dart';
import 'modelo_juegos.dart';
import 'motor/retos_de_prueba.dart';

/// Único punto por el que la app obtiene cartas. Así el contenido real
/// (datos/retos.dart, escrito aparte) se conecta en un solo sitio.
List<Reto> _fuente() => todosLosRetos;

/// Retos de un juego hasta el nivel elegido (incluye los inferiores).
/// Si el contenido real no tuviera nada para esa combinación, se cae a las
/// cartas de prueba para no dejar una partida sin cartas.
List<Reto> retosPara(
  TipoJuego juego,
  NivelReto nivel, {
  List<Reto>? fuente,
}) {
  List<Reto> filtrar(List<Reto> l) => l
      .where((r) => r.juego == juego && r.nivel.index <= nivel.index)
      .toList();
  final res = filtrar(fuente ?? _fuente());
  return res.isNotEmpty ? res : filtrar(retosDePrueba);
}
