import 'dart:math' as math;

import 'cara.dart';

/// Como dices que vas a un sitio esta noche.
///
/// Cuatro respuestas y no un si o un no, porque la noche no funciona asi:
/// "quiza" anima a otros sin comprometerte, "mas tarde" avisa de que no
/// estaras a la hora de la previa, y "estoy aqui" es lo que convierte la
/// lista en un sitio vivo. "No voy" no es un estado: es no decir nada.
enum EstadoNoche {
  aqui('aqui', 'Estoy aquí', 'Aquí', '📍'),
  voy('voy', 'Voy', 'Voy', '🙌'),
  tarde('tarde', 'Voy más tarde', 'Más tarde', '🌙'),
  quiza('quiza', 'Quizá', 'Quizá', '🤔');

  const EstadoNoche(this.clave, this.etiqueta, this.corta, this.pegatina);

  /// Lo que se guarda en el servidor.
  final String clave;
  final String etiqueta;

  /// Para la pastilla, donde no cabe la frase entera.
  final String corta;
  final String pegatina;

  /// Quiza no es ir: no cuenta como salida ni te mete en la sala.
  bool get va => this != EstadoNoche.quiza;

  static EstadoNoche? desde(String? clave) {
    for (final e in values) {
      if (e.clave == clave) return e;
    }
    return null;
  }
}

/// Una discoteca, bar o sala, con quien dice que va esta noche.
class Local {
  const Local({
    required this.id,
    required this.nombre,
    required this.ciudad,
    this.zona,
    this.urlEntradas,
    this.instagram,
    this.portadaUrl,
    this.logoUrl,
    this.eslogan,
    this.lat,
    this.lng,
    this.van = 0,
    this.quiza = 0,
    this.aqui = 0,
    this.miEstado,
    this.caras = const [],
  });

  final String id;
  final String nombre;
  final String ciudad;
  final String? zona;

  /// A donde se manda a quien quiera la entrada.
  final String? urlEntradas;

  final String? instagram;

  /// La foto del local por dentro. Es lo que manda en la tarjeta: ver el
  /// sitio decide mas que leer su nombre.
  final String? portadaUrl;

  /// El logo en blanco, para ir encima de la foto. Si no hay, se escribe el
  /// nombre en grande.
  final String? logoUrl;

  /// Una frase corta del propio local ("Tu finde empieza aqui").
  final String? eslogan;

  /// Donde esta. Nulo si el servidor no lo sabe o no lo manda todavia.
  final double? lat;
  final double? lng;

  /// Cuanta gente va esta noche, contigo incluido si vas. Quiza no cuenta.
  final int van;
  final int quiza;

  /// De los que van, cuantos dicen que ya estan dentro.
  final int aqui;

  /// Lo que has dicho tu, o nulo si nada.
  final EstadoNoche? miEstado;

  /// Algunas caras de quien va, sin la tuya. Primero la gente que sigues.
  final List<Cara> caras;

  bool get voy => miEstado?.va ?? false;

  bool get tieneEntradas => urlEntradas != null && urlEntradas!.isNotEmpty;

  bool get tieneInstagram => instagram != null && instagram!.isNotEmpty;

  /// La linea pequeña bajo el logo: su frase si la tiene; si no, su Instagram,
  /// que es como la gente busca un sitio; y si tampoco, el barrio.
  String? get lema {
    if (eslogan != null && eslogan!.trim().isNotEmpty) return eslogan!.trim();
    if (tieneInstagram) return '@$instagram';
    if (zona != null && zona!.trim().isNotEmpty) return zona!.trim();
    return null;
  }

  /// Metros en linea recta hasta [latitud], [longitud], o nulo si no se sabe
  /// donde esta el local.
  ///
  /// Haversine y no la distancia de PostGIS porque se calcula en el
  /// telefono: asi la posicion de quien mira no sale nunca del dispositivo.
  double? metrosHasta(double latitud, double longitud) {
    if (lat == null || lng == null) return null;
    const radioTierra = 6371000.0;
    double rad(double g) => g * math.pi / 180;
    final dLat = rad(lat! - latitud);
    final dLng = rad(lng! - longitud);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitud)) *
            math.cos(rad(lat!)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * radioTierra * math.asin(math.sqrt(a.toDouble()));
  }

  /// El local tras cambiar tu respuesta, sin esperar al servidor.
  ///
  /// Los contadores se recalculan aqui para que la ficha responda al toque;
  /// al recargar manda lo que diga el servidor.
  Local conMiEstado(EstadoNoche? nuevo) {
    final antesIba = voy;
    final ahoraVa = nuevo?.va ?? false;
    return Local(
      id: id,
      nombre: nombre,
      ciudad: ciudad,
      zona: zona,
      urlEntradas: urlEntradas,
      instagram: instagram,
      portadaUrl: portadaUrl,
      logoUrl: logoUrl,
      eslogan: eslogan,
      lat: lat,
      lng: lng,
      van: van + (ahoraVa ? 1 : 0) - (antesIba ? 1 : 0),
      quiza:
          quiza +
          (nuevo == EstadoNoche.quiza ? 1 : 0) -
          (miEstado == EstadoNoche.quiza ? 1 : 0),
      aqui:
          aqui +
          (nuevo == EstadoNoche.aqui ? 1 : 0) -
          (miEstado == EstadoNoche.aqui ? 1 : 0),
      miEstado: nuevo,
      caras: caras,
    );
  }

  /// Acepta las dos formas que puede devolver `locales_de_la_noche`: la de
  /// antes (solo `van` y `voy`) y la que trae estados y caras. Asi la app
  /// no depende de que el servidor este ya actualizado. Lo mismo con la foto,
  /// el logo, el eslogan y las coordenadas: sin la migracion
  /// `locales_con_foto` no llegan y la tarjeta tiene su version sin ellos.
  factory Local.desdeJson(Map<String, dynamic> json) {
    final estado =
        EstadoNoche.desde(json['mi_estado'] as String?) ??
        ((json['voy'] as bool? ?? false) ? EstadoNoche.voy : null);
    return Local(
      id: json['id'] as String,
      nombre: json['name'] as String,
      ciudad: json['city'] as String,
      zona: json['area_label'] as String?,
      urlEntradas: json['ticket_url'] as String?,
      instagram: json['instagram'] as String?,
      portadaUrl: _url(json['cover_url']),
      logoUrl: _url(json['logo_url']),
      eslogan: json['tagline'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      van: (json['van'] as num?)?.toInt() ?? 0,
      quiza: (json['quiza'] as num?)?.toInt() ?? 0,
      aqui: (json['aqui'] as num?)?.toInt() ?? 0,
      miEstado: estado,
      caras: [
        for (final c in (json['caras'] as List?) ?? const [])
          Cara(
            id: (c as Map)['id'] as String?,
            nombre: c['nombre'] as String? ?? '?',
            avatar: c['avatar'] as String?,
          ),
      ],
    );
  }
}

/// Una URL vacia es lo mismo que ninguna: evita pedir una imagen a "".
String? _url(Object? valor) {
  final texto = (valor as String?)?.trim();
  return texto == null || texto.isEmpty ? null : texto;
}

/// "731 m" o "4 km": los metros solo cuando de verdad se va andando.
String textoDistancia(double metros) {
  if (metros < 950) return '${(metros / 10).round() * 10} m';
  if (metros < 9500) {
    final km = (metros / 100).round() / 10;
    return km == km.roundToDouble()
        ? '${km.toInt()} km'
        : '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }
  return '${(metros / 1000).round()} km';
}

/// Alguien en la lista de quien va a un local, con como va.
class Asistente {
  const Asistente({
    required this.id,
    required this.nombre,
    required this.estado,
    this.usuario,
    this.avatar,
    this.leSigo = false,
  });

  final String id;
  final String nombre;
  final String? usuario;
  final String? avatar;
  final bool leSigo;
  final EstadoNoche estado;

  factory Asistente.desdeJson(Map<String, dynamic> json) => Asistente(
    id: json['id'] as String,
    nombre: json['display_name'] as String? ?? 'Alguien',
    usuario: json['username'] as String?,
    avatar: json['avatar_url'] as String?,
    leSigo: json['le_sigo'] as bool? ?? false,
    // Sin estado es el servidor de antes, donde estar en la lista era ir.
    estado: EstadoNoche.desde(json['estado'] as String?) ?? EstadoNoche.voy,
  );
}
