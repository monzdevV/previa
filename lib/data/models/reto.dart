/// Un reto de "No hay 🥚": buscar a alguien del local y haceros una foto.
class Reto {
  const Reto({
    required this.id,
    required this.texto,
    required this.deIa,
    required this.objetivoId,
    required this.objetivoUsuario,
    required this.objetivoNombre,
    this.objetivoAvatar,
    this.objetivoBio,
    required this.restantes,
  });

  final String id;
  final String texto;

  /// Si lo escribio la IA o salio de la lista de reserva.
  final bool deIa;

  final String objetivoId;
  final String objetivoUsuario;
  final String objetivoNombre;
  final String? objetivoAvatar;
  final String? objetivoBio;

  /// Cuantos retos te quedan esta noche contando este.
  final int restantes;

  factory Reto.desdeJson(Map<String, dynamic> json) => Reto(
    id: json['id'] as String,
    texto: json['texto'] as String,
    deIa: json['origen'] == 'ia',
    objetivoId: json['objetivo_id'] as String,
    objetivoUsuario: json['objetivo_usuario'] as String,
    objetivoNombre: json['objetivo_nombre'] as String,
    objetivoAvatar: json['objetivo_avatar'] as String?,
    objetivoBio: json['objetivo_bio'] as String?,
    restantes: (json['retos_restantes'] as num?)?.toInt() ?? 0,
  );
}

/// Un reto ya cumplido en el que sales tu, visto desde el objetivo.
class RetoConmigo {
  const RetoConmigo({required this.id, required this.texto});

  final String id;
  final String texto;
}

/// Por que no se ha podido repartir un reto. Cada caso lo decide la base de
/// datos y llega como codigo; aqui solo se le pone voz.
enum MotivoSinReto {
  noVas,
  noEstasAqui,
  sinUbicacion,
  yaTienesReto,
  limiteNoche,
  noHayNadie,
  sinSesion,
  desconocido;

  static MotivoSinReto desdeCodigo(String? codigo) => switch (codigo) {
    'NO_VAS' => noVas,
    'NO_ESTAS_AQUI' => noEstasAqui,
    'SIN_UBICACION' => sinUbicacion,
    'YA_TIENES_RETO' => yaTienesReto,
    'LIMITE_NOCHE' => limiteNoche,
    'NO_HAY_NADIE' => noHayNadie,
    'SIN_SESION' => sinSesion,
    _ => desconocido,
  };

  String get mensaje => switch (this) {
    noVas => 'Primero di que vas a este sitio esta noche.',
    noEstasAqui => 'Tienes que estar en el local para jugar.',
    sinUbicacion => 'Necesitamos tu ubicación para saber que estás dentro.',
    yaTienesReto => 'Ya tienes un reto abierto: cúmplelo o rájate.',
    limiteNoche => 'Se acabaron los retos por esta noche. Vuelve el finde.',
    noHayNadie =>
      'Aún no hay nadie más jugando aquí. Cuando llegue alguien, te toca.',
    sinSesion => 'Tu sesión ha caducado. Vuelve a entrar.',
    desconocido => 'No hemos podido repartir el reto. Prueba otra vez.',
  };
}

class ErrorReto implements Exception {
  const ErrorReto(this.motivo);

  final MotivoSinReto motivo;

  String get mensaje => motivo.mensaje;

  @override
  String toString() => mensaje;
}
