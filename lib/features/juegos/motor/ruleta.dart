import 'dart:math';

/// Una sentencia de la ruleta. `{sorbos}` se sustituye por el número real de
/// sorbos al mostrarla (ver [AccionRuleta.texto]).
class AccionRuleta {
  const AccionRuleta(this.plantilla, [this.sorbos = 0]);
  final String plantilla;

  /// 0 = la acción no implica beber.
  final int sorbos;

  String texto({required bool sinAlcohol}) {
    if (sorbos == 0) return plantilla;
    final cantidad = sinAlcohol
        ? '$sorbos tragos de cualquier bebida'
        : (sorbos == 1 ? '1 sorbo' : '$sorbos sorbos');
    return plantilla.replaceAll('{sorbos}', cantidad);
  }
}

/// Tope de seguridad, el mismo que en las cartas: nunca más de 3 sorbos.
const int sorbosMaximosRuleta = 3;

const List<AccionRuleta> accionesRuleta = [
  AccionRuleta('Bebe {sorbos}.', 2),
  AccionRuleta('Reparte {sorbos} entre quien quieras.', 3),
  AccionRuleta('Elige a alguien: bebe {sorbos}.', 1),
  AccionRuleta('Bebe {sorbos} con la mano que no usas.', 1),
  AccionRuleta('Brinda por alguien del grupo con un discurso de 10 segundos.'),
  AccionRuleta('Libre: esta vez no pasa nada.'),
  AccionRuleta('Todos beben {sorbos}.', 1),
  AccionRuleta('Cuenta tu peor cita en 30 segundos o bebe {sorbos}.', 2),
  AccionRuleta('Imita a alguien del grupo hasta que lo adivinen.'),
  AccionRuleta('Haz un piropo exagerado a quien tengas a la derecha.'),
  AccionRuleta('Baila 15 segundos sin música o bebe {sorbos}.', 2),
  AccionRuleta('Habla en tercera persona hasta tu próximo turno.'),
  AccionRuleta('Elige un jugador: os intercambiáis el sitio.'),
  AccionRuleta('Di tres cosas buenas de quien tengas a la izquierda.'),
  AccionRuleta('Quien tenga menos batería en el móvil bebe {sorbos}.', 1),
  AccionRuleta('El último en tocarse la nariz bebe {sorbos}.', 2),
];

/// Índice del segmento que queda bajo el puntero, que está fijo arriba.
///
/// El segmento 0 empieza en el puntero y los siguientes siguen en el sentido
/// de las agujas del reloj. [giro] son los radianes girados en ese mismo
/// sentido; hay que reducirlo al rango [0, 2π) porque la ruleta da muchas
/// vueltas.
int segmentoBajoPuntero(double giro, int segmentos) {
  const vuelta = 2 * pi;
  final enRueda = ((-giro) % vuelta + vuelta) % vuelta;
  return (enRueda / (vuelta / segmentos)).floor() % segmentos;
}

/// Giro total (en radianes) con el que la ruleta termina en [ganador].
///
/// [dentro] (0..1) coloca la parada dentro del segmento: así no acaba
/// siempre justo en el centro, que se vería trucado, y nunca en el borde,
/// donde no estaría claro qué nombre señala.
double giroHasta({
  required int segmentos,
  required int ganador,
  required int vueltas,
  required double dentro,
}) {
  const vuelta = 2 * pi;
  final margen = dentro.clamp(0.15, 0.85);
  return vuelta * vueltas - (ganador + margen) * (vuelta / segmentos);
}
