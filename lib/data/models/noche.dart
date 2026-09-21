/// La racha de findes.
///
/// Un finde es una semana en la que saliste al menos una noche. La racha no
/// se rompe el lunes: mientras la semana en curso no acabe, sigue viva aunque
/// todavia no hayas salido, porque si no se caeria cada lunes por la mañana.
class Racha {
  const Racha({
    this.semanas = 0,
    this.mejor = 0,
    this.saliEstaSemana = false,
  });

  final int semanas;
  final int mejor;
  final bool saliEstaSemana;

  bool get viva => semanas > 0;

  /// Si la racha está en juego: la tienes, pero esta semana aún no has salido.
  bool get enRiesgo => viva && !saliEstaSemana;

  factory Racha.desdeJson(Map<String, dynamic> json) => Racha(
    semanas: (json['racha'] as num?)?.toInt() ?? 0,
    mejor: (json['mejor'] as num?)?.toInt() ?? 0,
    saliEstaSemana: json['sali_esta_semana'] as bool? ?? false,
  );
}

/// Lo que dio de si una noche. Es lo que se enseña en la tarjeta del final.
class ResumenDeNoche {
  const ResumenDeNoche({
    required this.noche,
    this.sitios = const [],
    this.fotos = 0,
    this.conQuien = 0,
    this.previas = 0,
    this.desde,
    this.hasta,
  });

  final DateTime noche;

  /// Los locales en los que dijiste que estabas.
  final List<String> sitios;

  final int fotos;

  /// Con cuánta gente coincidiste: quien fue a los mismos sitios esa noche.
  final int conQuien;

  final int previas;

  /// Primera y última foto de la noche. Es la única hora fiable que hay.
  final DateTime? desde;
  final DateTime? hasta;

  bool get hayAlgo =>
      sitios.isNotEmpty || fotos > 0 || previas > 0 || conQuien > 0;

  /// Cuánto duró la noche, medido entre la primera y la última foto.
  String? get duracion {
    final a = desde;
    final b = hasta;
    if (a == null || b == null) return null;
    final d = b.difference(a);
    if (d.inMinutes < 30) return null;
    if (d.inHours < 1) return '${d.inMinutes} min';
    final horas = d.inHours;
    final minutos = d.inMinutes % 60;
    return minutos == 0 ? '$horas h' : '$horas h $minutos min';
  }

  factory ResumenDeNoche.desdeJson(Map<String, dynamic> json, DateTime noche) =>
      ResumenDeNoche(
        noche: noche,
        sitios: (json['sitios'] as List?)?.cast<String>() ?? const [],
        fotos: (json['fotos'] as num?)?.toInt() ?? 0,
        conQuien: (json['con_quien'] as num?)?.toInt() ?? 0,
        previas: (json['previas'] as num?)?.toInt() ?? 0,
        desde: json['desde'] == null
            ? null
            : DateTime.parse(json['desde'] as String).toLocal(),
        hasta: json['hasta'] == null
            ? null
            : DateTime.parse(json['hasta'] as String).toLocal(),
      );
}

/// Una salida en el listado del perfil.
class Salida {
  const Salida({
    required this.noche,
    this.sitios = const [],
    this.fotos = 0,
    this.conQuien = 0,
    this.portada,
  });

  final DateTime noche;
  final List<String> sitios;
  final int fotos;
  final int conQuien;

  /// Tu ultima foto de esa noche; si no subiste, la de alguien que estuvo
  /// en el mismo sitio.
  final String? portada;

  String get donde => sitios.isEmpty ? 'Noche suelta' : sitios.join(' · ');

  factory Salida.desdeJson(Map<String, dynamic> json) => Salida(
    noche: DateTime.parse(json['noche'] as String),
    sitios: (json['sitios'] as List?)?.cast<String>() ?? const [],
    fotos: (json['fotos'] as num?)?.toInt() ?? 0,
    conQuien: (json['con_quien'] as num?)?.toInt() ?? 0,
    portada: json['portada'] as String?,
  );
}
