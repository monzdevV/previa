/// Regla de la racha de fiestas. Dart puro: sin Flutter, sin red, sin reloj
/// escondido, para poder probarla con fechas fijas y defenderla en el TFG.
///
/// La regla, en cinco líneas:
///
/// 1. Una SEMANA es de lunes a domingo. Cuenta si hay al menos una noche
///    registrada en ella (un "voy" o una foto). Dos noches la misma semana
///    valen lo mismo que una: se premia la constancia, no el exceso.
/// 2. La racha son las semanas CONSECUTIVAS con noche, contando hacia atrás
///    desde la última.
/// 3. La semana en curso nunca rompe la racha mientras no acabe: si hoy es
///    jueves y aún no has salido, la racha sigue viva ("en riesgo"). Si no,
///    se caería cada lunes por la mañana, que es el peor momento para
///    castigar a nadie.
/// 4. COMODÍN: cada racha perdona UNA semana vacía suelta (no suma, pero
///    tampoco rompe). Una semana mala (examen, gripe, viaje) no debería
///    borrar tres meses; dos seguidas, o una segunda vez, sí rompen.
/// 5. Hitos a las 3, 5, 10 y 20 semanas. Pasado el 20 no hay más: el récord
///    sigue contando, pero un objetivo inalcanzable desmotiva.
///
/// Por qué cualquier noche y no solo "el finde": el servidor ya valida que
/// la noche sea la de ayer, hoy o mañana, y una noche de jueves de
/// universitarios es una noche de fiesta. Contar solo viernes y sábado
/// excluiría a quien trabaja esos días.
library;

/// Semanas de racha en las que se celebra algo.
const hitosDeRacha = [3, 5, 10, 20];

/// Semanas vacías sueltas que una racha perdona.
const comodinesPorRacha = 1;

/// Lo que se sabe de la racha de alguien en un instante.
class Racha {
  const Racha({
    this.semanas = 0,
    this.mejor = 0,
    this.saliEstaSemana = false,
    this.comodinGastado = false,
  });

  /// Semanas con noche en la racha viva (0 si está rota).
  final int semanas;

  /// Récord histórico. Nunca baja: es lo que se enseña cuando se rompe.
  final int mejor;

  final bool saliEstaSemana;

  /// La racha viva ya usó su semana de perdón, así que otra semana vacía
  /// la rompe. Sirve para avisar con más urgencia.
  final bool comodinGastado;

  bool get viva => semanas > 0;

  /// La tienes, pero esta semana aún no has salido.
  bool get enRiesgo => viva && !saliEstaSemana;

  /// El mayor hito ya alcanzado por la racha viva, o nulo si aún no hay.
  int? get hitoAlcanzado {
    int? alcanzado;
    for (final h in hitosDeRacha) {
      if (semanas >= h) alcanzado = h;
    }
    return alcanzado;
  }

  /// El siguiente objetivo, o nulo si ya se pasó el último (20).
  int? get siguienteHito {
    for (final h in hitosDeRacha) {
      if (semanas < h) return h;
    }
    return null;
  }

  /// Cuántas semanas faltan para el siguiente hito; 0 si no queda ninguno.
  int get semanasParaHito {
    final h = siguienteHito;
    return h == null ? 0 : h - semanas;
  }

  /// Avance entre el hito anterior y el siguiente, de 0 a 1. La barra se
  /// mide desde el hito anterior y no desde cero: de 5 a 10 la barra
  /// arranca vacía, y se nota que has pasado de nivel.
  double get progreso {
    final h = siguienteHito;
    if (h == null) return 1;
    final base = hitoAlcanzado ?? 0;
    return ((semanas - base) / (h - base)).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      other is Racha &&
      other.semanas == semanas &&
      other.mejor == mejor &&
      other.saliEstaSemana == saliEstaSemana &&
      other.comodinGastado == comodinGastado;

  @override
  int get hashCode =>
      Object.hash(semanas, mejor, saliEstaSemana, comodinGastado);

  @override
  String toString() =>
      'Racha(semanas: $semanas, mejor: $mejor, saliEstaSemana: '
      '$saliEstaSemana, comodinGastado: $comodinGastado)';
}

/// El hito que toca celebrar ahora: el mayor alcanzado que aún no se ha
/// celebrado. Si se saltan dos de golpe (se abre la app tras recuperar datos)
/// se celebra solo el mayor, no dos mensajes seguidos. Nulo si no hay nada
/// nuevo.
int? hitoPorCelebrar(Racha racha, {required int celebrado}) {
  final h = racha.hitoAlcanzado;
  if (h == null || h <= celebrado) return null;
  return h;
}

/// Calcula la racha a partir de las fechas de las noches registradas.
///
/// [noches] son fechas de calendario (solo cuentan año, mes y día), las
/// mismas que guarda la base en `night`: ese día ya viene en hora de Madrid
/// y con el corte de las 6:00. [ahora] es el instante actual; se pasa de
/// fuera para que la prueba no dependa del reloj.
Racha calcularRacha(Iterable<DateTime> noches, {required DateTime ahora}) {
  final hoy = _dia(nocheActual(ahora));
  final semanaActual = _semanaDe(hoy);

  // Se ignora el futuro: decir "voy" mañana no es haber salido. Y se
  // deduplica por semana, que es la regla 1.
  final semanas = <int>{
    for (final n in noches)
      if (_dia(n) <= hoy) _semanaDe(_dia(n)),
  }.toList()..sort();
  if (semanas.isEmpty) return const Racha();

  var mejor = 0;
  var cuenta = 0;
  var gastado = false;
  int? anterior;
  for (final s in semanas) {
    if (anterior == null) {
      cuenta = 1;
    } else {
      final vacias = s - anterior - 1;
      if (vacias == 0) {
        cuenta++;
      } else if (vacias <= comodinesPorRacha && !gastado) {
        // La semana perdonada no suma: la racha cuenta semanas salidas.
        cuenta++;
        gastado = true;
      } else {
        cuenta = 1;
        gastado = false;
      }
    }
    if (cuenta > mejor) mejor = cuenta;
    anterior = s;
  }

  final ultima = anterior!;
  // Semanas ya cerradas y vacías entre la última con noche y la actual.
  final vaciasHastaHoy = semanaActual - ultima - 1;
  final saliEstaSemana = ultima == semanaActual;

  var viva = true;
  var comodinFinal = gastado;
  if (vaciasHastaHoy > 0) {
    if (vaciasHastaHoy <= comodinesPorRacha && !gastado) {
      comodinFinal = true; // La semana vacía que acaba de pasar se perdona.
    } else {
      viva = false;
    }
  }

  return Racha(
    semanas: viva ? cuenta : 0,
    mejor: mejor,
    saliEstaSemana: saliEstaSemana,
    comodinGastado: viva && comodinFinal,
  );
}

/// La noche que corresponde a un instante, como en `privado.noche_actual()`
/// del servidor: hora de Madrid menos 6 horas, así la fiesta de las 3:00 del
/// domingo sigue siendo la noche del sábado. Debe coincidir con el servidor
/// o la racha saldría distinta en el móvil y en la base.
DateTime nocheActual(DateTime instante) {
  final utc = instante.toUtc();
  final madrid = utc.add(Duration(hours: _esHorarioDeVerano(utc) ? 2 : 1));
  final ajustada = madrid.subtract(const Duration(hours: 6));
  return DateTime.utc(ajustada.year, ajustada.month, ajustada.day);
}

/// Horario de verano de la UE: del último domingo de marzo al último de
/// octubre, ambos a la 01:00 UTC. Se calcula a mano para no añadir un
/// paquete de zonas horarias solo por esto, y porque no depende de la zona
/// del teléfono (alguien de viaje sigue saliendo "en Madrid" para la regla).
bool _esHorarioDeVerano(DateTime utc) {
  final inicio = _ultimoDomingo(utc.year, 3);
  final fin = _ultimoDomingo(utc.year, 10);
  return !utc.isBefore(inicio) && utc.isBefore(fin);
}

DateTime _ultimoDomingo(int anio, int mes) {
  final ultimo = DateTime.utc(anio, mes + 1, 0);
  final retroceso = ultimo.weekday % 7; // domingo = 7 -> 0
  return DateTime.utc(anio, mes, ultimo.day - retroceso, 1);
}

/// Días desde 1970-01-01 de una fecha de calendario. Trabajar con enteros
/// evita que el cambio de hora de marzo y octubre (días de 23 y 25 horas)
/// descuadre una resta de fechas.
int _dia(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

/// Índice de semana de lunes a domingo. El 1-1-1970 fue jueves, de ahí el +3.
int _semanaDe(int dia) => (dia + 3) ~/ 7;
