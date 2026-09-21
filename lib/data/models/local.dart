/// Una discoteca, bar o sala, con cuanta gente dice que va esta noche.
class Local {
  const Local({
    required this.id,
    required this.nombre,
    required this.ciudad,
    this.zona,
    this.urlEntradas,
    this.instagram,
    this.van = 0,
    this.voy = false,
  });

  final String id;
  final String nombre;
  final String ciudad;
  final String? zona;

  /// A donde se manda a quien quiera la entrada.
  final String? urlEntradas;

  final String? instagram;

  /// Cuanta gente ha dicho que va esta noche.
  final int van;

  /// Si tu has dicho que vas.
  final bool voy;

  bool get tieneEntradas => urlEntradas != null && urlEntradas!.isNotEmpty;

  Local copiarCon({int? van, bool? voy}) => Local(
    id: id,
    nombre: nombre,
    ciudad: ciudad,
    zona: zona,
    urlEntradas: urlEntradas,
    instagram: instagram,
    van: van ?? this.van,
    voy: voy ?? this.voy,
  );

  factory Local.desdeJson(Map<String, dynamic> json) => Local(
    id: json['id'] as String,
    nombre: json['name'] as String,
    ciudad: json['city'] as String,
    zona: json['area_label'] as String?,
    urlEntradas: json['ticket_url'] as String?,
    instagram: json['instagram'] as String?,
    van: (json['van'] as num?)?.toInt() ?? 0,
    voy: json['voy'] as bool? ?? false,
  );
}
