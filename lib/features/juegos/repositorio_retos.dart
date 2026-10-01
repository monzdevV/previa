import 'datos/retos.dart';
import 'modelo_juegos.dart';
import 'motor/retos_de_prueba.dart';

/// Único punto por el que la app obtiene cartas. Así el contenido real
/// (datos/retos.dart, escrito aparte) se conecta en un solo sitio.
List<Reto> _fuente() => todosLosRetos;

/// Retos de un juego hasta el nivel elegido (incluye los inferiores).
/// Si el contenido real no tuviera nada para esa combinación, se cae a las
/// cartas de prueba para no dejar una partida sin cartas.
List<Reto> retosPara(TipoJuego juego, NivelReto nivel, {List<Reto>? fuente}) {
  List<Reto> filtrar(List<Reto> l) =>
      l.where((r) => r.juego == juego && r.nivel.index <= nivel.index).toList();
  final res = filtrar(fuente ?? _fuente());
  return res.isNotEmpty ? res : filtrar(retosDePrueba);
}

/// Máximos de las cartas del grupo: pocas y cortas, para que sigan siendo
/// una sorpresa dentro de la baraja y no la sustituyan.
const int maxCartasPropias = 20;
const int maxLongitudCartaPropia = 140;

/// Convierte lo que escribió el grupo en cartas del juego. Entran en nivel
/// suave a propósito: así salen en cualquier partida y nadie recibe por
/// sorpresa algo más fuerte de lo que eligió. El texto se recorta y se
/// descartan los vacíos y repetidos, igual que con los nombres.
List<Reto> retosPropios(TipoJuego juego, Iterable<String> textos) {
  final vistos = <String>{};
  final salida = <Reto>[];
  for (final crudo in textos) {
    var t = crudo.trim();
    if (t.length > maxLongitudCartaPropia) {
      t = t.substring(0, maxLongitudCartaPropia);
    }
    if (t.isEmpty || !vistos.add(t.toLowerCase())) continue;
    salida.add(
      Reto(
        id: 'propia-${juego.name}-${salida.length + 1}',
        juego: juego,
        nivel: NivelReto.suave,
        texto: t,
      ),
    );
    if (salida.length == maxCartasPropias) break;
  }
  return salida;
}
