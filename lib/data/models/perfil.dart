/// Perfil publico de una persona usuaria.
///
/// Observese que no hay campo de fecha de nacimiento: la base de datos no la
/// entrega nunca al cliente. Cuando hace falta la edad se pide aparte con la
/// funcion `edad()`, y el titular consulta la suya con `mi_fecha_nacimiento()`.
class Perfil {
  const Perfil({
    required this.id,
    required this.username,
    required this.nombre,
    required this.onboarded,
    this.avatarUrl,
    this.bio,
    this.reputacion,
    this.numeroValoraciones = 0,
  });

  final String id;
  final String username;
  final String nombre;
  final bool onboarded;
  final String? avatarUrl;
  final String? bio;
  final double? reputacion;
  final int numeroValoraciones;

  /// Iniciales para el avatar cuando no hay foto.
  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  bool get tieneReputacion => numeroValoraciones > 0 && reputacion != null;

  factory Perfil.desdeJson(Map<String, dynamic> json) => Perfil(
    id: json['id'] as String,
    username: json['username'] as String,
    nombre: json['display_name'] as String,
    onboarded: json['onboarded'] as bool? ?? false,
    avatarUrl: json['avatar_url'] as String?,
    bio: json['bio'] as String?,
    reputacion: (json['reputation'] as num?)?.toDouble(),
    numeroValoraciones: json['ratings_count'] as int? ?? 0,
  );

  Map<String, dynamic> aJson() => {
    'username': username,
    'display_name': nombre,
    'avatar_url': avatarUrl,
    'bio': bio,
  };

  Perfil copiarCon({
    String? username,
    String? nombre,
    String? avatarUrl,
    String? bio,
  }) => Perfil(
    id: id,
    username: username ?? this.username,
    nombre: nombre ?? this.nombre,
    onboarded: onboarded,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    bio: bio ?? this.bio,
    reputacion: reputacion,
    numeroValoraciones: numeroValoraciones,
  );
}
