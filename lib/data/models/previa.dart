import 'package:latlong2/latlong.dart';

enum EstadoPrevia { abierta, completa, cerrada, cancelada }

EstadoPrevia _estadoDesde(String valor) => switch (valor) {
  'open' => EstadoPrevia.abierta,
  'full' => EstadoPrevia.completa,
  'closed' => EstadoPrevia.cerrada,
  _ => EstadoPrevia.cancelada,
};

/// Una previa tal y como la ve quien la busca en el mapa.
///
/// [ubicacion] es SIEMPRE la posicion difuminada que devuelve el servidor,
/// nunca la direccion real. La direccion exacta se pide aparte, y solo
/// funciona si el servidor confirma que eres asistente aceptado.
class Previa {
  const Previa({
    required this.id,
    required this.titulo,
    required this.zona,
    required this.ubicacion,
    required this.empiezaEn,
    required this.plazasLibres,
    required this.anfitrionId,
    required this.anfitrionNombre,
    this.descripcion,
    this.ambiente = const [],
    this.distanciaMetros,
    this.edadMinima = 18,
    this.edadMaxima,
    this.anfitrionAvatar,
    this.anfitrionReputacion,
    this.estado = EstadoPrevia.abierta,
  });

  final String id;
  final String titulo;
  final String? descripcion;
  final List<String> ambiente;
  final String zona;

  /// Posicion difuminada (~300 m de desplazamiento). Nunca la real.
  final LatLng ubicacion;

  final double? distanciaMetros;
  final DateTime empiezaEn;
  final int plazasLibres;
  final int edadMinima;
  final int? edadMaxima;
  final String anfitrionId;
  final String anfitrionNombre;
  final String? anfitrionAvatar;
  final double? anfitrionReputacion;
  final EstadoPrevia estado;

  bool get quedanPlazas => plazasLibres > 0;

  /// Distancia en el formato que se muestra en la tarjeta.
  String get distanciaLegible {
    final metros = distanciaMetros;
    if (metros == null) return '';
    if (metros < 1000) return '${metros.round()} m';
    return '${(metros / 1000).toStringAsFixed(1)} km';
  }

  /// Lado de la celda, en grados. Unos 400 m a la latitud peninsular.
  ///
  /// Son publicas porque el mapa dibuja esta misma reticula: si la referencia
  /// del indice y las lineas del mapa no fueran la misma cuadricula, la
  /// referencia no serviria para orientarse.
  static const altoCelda = 0.0036;
  static const anchoCelda = 0.0047;

  /// Referencia de cuadricula de la zona, como en el indice de un callejero.
  ///
  /// Se calcula sobre [ubicacion], que ya viene difuminada del servidor, asi
  /// que no dice nada que el circulo del mapa no ensene: es la misma area
  /// aproximada, dicha en algo que cabe en un renglon. Dos previas con la
  /// misma referencia caen en la misma celda y se pueden encadenar andando.
  String get referenciaCuadricula {
    final columna = (ubicacion.longitude / anchoCelda).floor();
    final fila = (ubicacion.latitude / altoCelda).floor();
    final letra = String.fromCharCode(65 + (columna % 26 + 26) % 26);
    return '$letra${(fila % 100 + 100) % 100}';
  }

  /// Cuanto falta para que empiece.
  String get cuandoEmpieza {
    final falta = empiezaEn.difference(DateTime.now());
    if (falta.isNegative) return 'Ya ha empezado';
    if (falta.inMinutes < 60) return 'En ${falta.inMinutes} min';
    if (falta.inHours < 24) return 'En ${falta.inHours} h';
    return 'En ${falta.inDays} d';
  }

  /// Construccion a partir de la RPC `previas_cerca`.
  factory Previa.desdeBusqueda(Map<String, dynamic> json) => Previa(
    id: json['id'] as String,
    titulo: json['title'] as String,
    descripcion: json['description'] as String?,
    ambiente: (json['vibe'] as List?)?.cast<String>() ?? const [],
    zona: json['area_label'] as String,
    ubicacion: LatLng(
      (json['lat'] as num).toDouble(),
      (json['lng'] as num).toDouble(),
    ),
    distanciaMetros: (json['distancia_m'] as num?)?.toDouble(),
    empiezaEn: DateTime.parse(json['starts_at'] as String).toLocal(),
    plazasLibres: (json['plazas_libres'] as num).toInt(),
    edadMinima: (json['min_age'] as num?)?.toInt() ?? 18,
    edadMaxima: (json['max_age'] as num?)?.toInt(),
    anfitrionId: json['host_id'] as String,
    anfitrionNombre: json['host_nombre'] as String? ?? 'Anfitrion',
    anfitrionAvatar: json['host_avatar'] as String?,
    anfitrionReputacion: (json['host_reputacion'] as num?)?.toDouble(),
  );

  /// Construccion a partir de una lectura directa de la tabla `parties`.
  factory Previa.desdeTabla(Map<String, dynamic> json) {
    final anfitrion = json['profiles'] as Map<String, dynamic>?;
    return Previa(
      id: json['id'] as String,
      titulo: json['title'] as String,
      descripcion: json['description'] as String?,
      ambiente: (json['vibe'] as List?)?.cast<String>() ?? const [],
      zona: json['area_label'] as String,
      ubicacion: _puntoDesdeGeoJson(json['location_fuzzed']),
      empiezaEn: DateTime.parse(json['starts_at'] as String).toLocal(),
      plazasLibres:
          ((json['spots_total'] as num).toInt()) -
          ((json['spots_taken'] as num?)?.toInt() ?? 0),
      edadMinima: (json['min_age'] as num?)?.toInt() ?? 18,
      edadMaxima: (json['max_age'] as num?)?.toInt(),
      anfitrionId: json['host_id'] as String,
      anfitrionNombre: anfitrion?['display_name'] as String? ?? 'Anfitrion',
      anfitrionAvatar: anfitrion?['avatar_url'] as String?,
      anfitrionReputacion: (anfitrion?['reputation'] as num?)?.toDouble(),
      estado: _estadoDesde(json['status'] as String? ?? 'open'),
    );
  }

  /// PostGIS entrega los puntos como GeoJSON: coordinates es [lng, lat].
  static LatLng _puntoDesdeGeoJson(dynamic valor) {
    if (valor is Map && valor['coordinates'] is List) {
      final c = valor['coordinates'] as List;
      return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
    }
    return const LatLng(0, 0);
  }
}

enum EstadoSolicitud { pendiente, aceptada, rechazada, cancelada }

/// Peticion de plaza para un grupo: "somos 3, podemos ir?".
class Solicitud {
  const Solicitud({
    required this.id,
    required this.previaId,
    required this.solicitanteId,
    required this.tamanoGrupo,
    required this.estado,
    required this.creadaEn,
    this.mensaje,
    this.solicitante,
    this.previaResumen,
  });

  final String id;
  final String previaId;
  final String solicitanteId;
  final int tamanoGrupo;
  final String? mensaje;
  final EstadoSolicitud estado;
  final DateTime creadaEn;

  /// Datos publicos de quien solicita. Solo viene en la bandeja del anfitrion.
  final Map<String, dynamic>? solicitante;

  /// Datos de la previa. Solo viene al listar mis propias solicitudes.
  final Map<String, dynamic>? previaResumen;

  String get tituloPrevia => previaResumen?['title'] as String? ?? 'Previa';

  String? get zonaPrevia => previaResumen?['area_label'] as String?;

  DateTime? get empiezaPrevia {
    final valor = previaResumen?['starts_at'] as String?;
    return valor == null ? null : DateTime.parse(valor).toLocal();
  }

  bool get estaPendiente => estado == EstadoSolicitud.pendiente;

  String get resumenGrupo =>
      tamanoGrupo == 1 ? 'Va 1 persona' : 'Van $tamanoGrupo personas';

  String get nombreSolicitante =>
      solicitante?['display_name'] as String? ?? 'Alguien';

  String? get avatarSolicitante => solicitante?['avatar_url'] as String?;

  double? get reputacionSolicitante =>
      (solicitante?['reputation'] as num?)?.toDouble();

  String get inicialSolicitante =>
      nombreSolicitante.isNotEmpty ? nombreSolicitante[0].toUpperCase() : '?';

  factory Solicitud.desdeJson(Map<String, dynamic> json) => Solicitud(
    id: json['id'] as String,
    previaId: json['party_id'] as String,
    solicitanteId: json['requester_id'] as String,
    tamanoGrupo: (json['group_size'] as num).toInt(),
    mensaje: json['message'] as String?,
    estado: switch (json['status'] as String) {
      'pending' => EstadoSolicitud.pendiente,
      'accepted' => EstadoSolicitud.aceptada,
      'rejected' => EstadoSolicitud.rechazada,
      _ => EstadoSolicitud.cancelada,
    },
    creadaEn: DateTime.parse(json['created_at'] as String).toLocal(),
    solicitante: json['profiles'] as Map<String, dynamic>?,
    previaResumen: json['parties'] as Map<String, dynamic>?,
  );
}

/// Mensaje del chat de una previa.
class Mensaje {
  const Mensaje({
    required this.id,
    required this.previaId,
    required this.autorId,
    required this.texto,
    required this.enviadoEn,
  });

  final String id;
  final String previaId;
  final String autorId;
  final String texto;
  final DateTime enviadoEn;

  factory Mensaje.desdeJson(Map<String, dynamic> json) => Mensaje(
    id: json['id'] as String,
    previaId: json['party_id'] as String,
    autorId: json['sender_id'] as String,
    texto: json['body'] as String,
    enviadoEn: DateTime.parse(json['created_at'] as String).toLocal(),
  );
}
