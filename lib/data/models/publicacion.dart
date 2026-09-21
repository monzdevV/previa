/// Una publicacion del feed: la noche contada por quien estuvo.
class Publicacion {
  const Publicacion({
    required this.id,
    required this.autorId,
    required this.autorNombre,
    required this.mediaUrl,
    required this.esVideo,
    required this.creadaEn,
    this.autorUsuario,
    this.autorAvatar,
    this.miniaturaUrl,
    this.texto,
    this.zona,
    this.likes = 0,
    this.leDiLike = false,
    this.leSigo = false,
  });

  final String id;
  final String autorId;
  final String? autorUsuario;
  final String autorNombre;
  final String? autorAvatar;

  final String mediaUrl;
  final bool esVideo;
  final String? miniaturaUrl;

  final String? texto;

  /// Zona a la que pertenece, por ejemplo "Zaragoza". Es lo que permite ver
  /// la noche de una ciudad sin exponer la ubicacion de nadie.
  final String? zona;

  final int likes;
  final bool leDiLike;
  final bool leSigo;
  final DateTime creadaEn;

  Publicacion copiarCon({int? likes, bool? leDiLike, bool? leSigo}) =>
      Publicacion(
        id: id,
        autorId: autorId,
        autorUsuario: autorUsuario,
        autorNombre: autorNombre,
        autorAvatar: autorAvatar,
        mediaUrl: mediaUrl,
        esVideo: esVideo,
        miniaturaUrl: miniaturaUrl,
        texto: texto,
        zona: zona,
        likes: likes ?? this.likes,
        leDiLike: leDiLike ?? this.leDiLike,
        leSigo: leSigo ?? this.leSigo,
        creadaEn: creadaEn,
      );

  /// Cuanto hace que se publico, en el formato corto de las redes.
  String get hace {
    final d = DateTime.now().difference(creadaEn);
    if (d.inMinutes < 1) return 'ahora';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    if (d.inHours < 24) return '${d.inHours} h';
    if (d.inDays < 7) return '${d.inDays} d';
    return '${(d.inDays / 7).floor()} sem';
  }

  factory Publicacion.desdeJson(Map<String, dynamic> json) => Publicacion(
    id: json['id'] as String,
    autorId: json['author_id'] as String,
    autorUsuario: json['username'] as String?,
    autorNombre: json['display_name'] as String? ?? 'Alguien',
    autorAvatar: json['avatar_url'] as String?,
    mediaUrl: json['media_url'] as String,
    esVideo: (json['media_type'] as String?) == 'video',
    miniaturaUrl: json['thumbnail_url'] as String?,
    texto: json['caption'] as String?,
    zona: json['area_label'] as String?,
    likes: (json['like_count'] as num?)?.toInt() ?? 0,
    leDiLike: json['le_di_like'] as bool? ?? false,
    leSigo: json['le_sigo'] as bool? ?? false,
    creadaEn: DateTime.parse(json['created_at'] as String).toLocal(),
  );
}

/// Perfil publico resumido, tal y como sale en buscadores y listas de gente.
class PerfilResumen {
  const PerfilResumen({
    required this.id,
    required this.nombre,
    this.usuario,
    this.avatar,
    this.reputacion,
    this.leSigo = false,
  });

  final String id;
  final String? usuario;
  final String nombre;
  final String? avatar;
  final double? reputacion;
  final bool leSigo;

  String get inicial => nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

  PerfilResumen copiarCon({bool? leSigo}) => PerfilResumen(
    id: id,
    usuario: usuario,
    nombre: nombre,
    avatar: avatar,
    reputacion: reputacion,
    leSigo: leSigo ?? this.leSigo,
  );

  factory PerfilResumen.desdeJson(Map<String, dynamic> json) => PerfilResumen(
    id: json['id'] as String,
    usuario: json['username'] as String?,
    nombre: json['display_name'] as String? ?? 'Alguien',
    avatar: json['avatar_url'] as String?,
    reputacion: (json['reputation'] as num?)?.toDouble(),
    leSigo: json['le_sigo'] as bool? ?? false,
  );
}

/// La ficha completa de alguien: su resumen mas lo que solo se enseña al
/// visitar su perfil.
class PerfilPublico {
  const PerfilPublico({
    required this.perfil,
    this.bio,
    this.ciudad,
    this.instagram,
    this.esDemo = false,
    this.seguidores = 0,
    this.siguiendo = 0,
  });

  final PerfilResumen perfil;
  final String? bio;
  final String? ciudad;
  final String? instagram;

  /// Perfil sembrado para la demostracion. Se avisa en pantalla para que
  /// nadie confunda un ejemplo con una persona real.
  final bool esDemo;

  final int seguidores;
  final int siguiendo;
}

/// Una fila de la bandeja de mensajes.
class Conversacion {
  const Conversacion({
    required this.otroId,
    required this.nombre,
    required this.ultimoEn,
    this.usuario,
    this.avatar,
    this.ultimo,
    this.ultimoMio = false,
    this.sinLeer = 0,
  });

  final String otroId;
  final String? usuario;
  final String nombre;
  final String? avatar;
  final String? ultimo;

  /// Si el ultimo mensaje lo escribiste tu. Sirve para anteponer "Tú:".
  final bool ultimoMio;

  final int sinLeer;
  final DateTime ultimoEn;

  factory Conversacion.desdeJson(Map<String, dynamic> json) => Conversacion(
    otroId: json['id'] as String,
    usuario: json['username'] as String?,
    nombre: json['display_name'] as String? ?? 'Alguien',
    avatar: json['avatar_url'] as String?,
    ultimo: json['ultimo'] as String?,
    ultimoMio: json['ultimo_mio'] as bool? ?? false,
    sinLeer: (json['sin_leer'] as num?)?.toInt() ?? 0,
    ultimoEn: DateTime.parse(json['ultimo_en'] as String).toLocal(),
  );
}

/// Un mensaje directo.
class MensajeDirecto {
  const MensajeDirecto({
    required this.id,
    required this.texto,
    required this.mio,
    required this.enviadoEn,
    this.leido = false,
  });

  final String id;
  final String texto;

  /// Si lo has escrito tu. Decide de que lado de la pantalla se pinta.
  final bool mio;

  final bool leido;
  final DateTime enviadoEn;

  factory MensajeDirecto.desdeJson(Map<String, dynamic> json, String yo) =>
      MensajeDirecto(
        id: json['id'] as String,
        texto: json['body'] as String,
        mio: json['sender_id'] == yo,
        leido: json['read_at'] != null,
        enviadoEn: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}

/// Un mensaje de la sala de un local.
class MensajeDeSala {
  const MensajeDeSala({
    required this.id,
    required this.autorId,
    required this.autorNombre,
    required this.texto,
    required this.mio,
    required this.enviadoEn,
    this.autorAvatar,
  });

  final String id;
  final String autorId;
  final String autorNombre;
  final String? autorAvatar;
  final String texto;

  /// Si lo has escrito tu. Decide de que lado se pinta la burbuja.
  final bool mio;

  final DateTime enviadoEn;

  factory MensajeDeSala.desdeJson(Map<String, dynamic> json, String yo) =>
      MensajeDeSala(
        id: json['id'] as String,
        autorId: json['sender_id'] as String,
        autorNombre: json['display_name'] as String? ?? 'Alguien',
        autorAvatar: json['avatar_url'] as String?,
        texto: json['body'] as String,
        mio: json['sender_id'] == yo,
        enviadoEn: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
