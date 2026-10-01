/// Que tipo de cosa se ofrece.
///
/// Cerrada a proposito y sin categoria de bebida: el informe legal prohibe
/// promociones que fomenten el consumo excesivo de alcohol, y la forma mas
/// segura de cumplirlo es que ni exista donde ponerlas. Las mismas claves las
/// valida el `check` de `venue_offers.kind` en la base de datos.
enum CategoriaOferta {
  entrada('entrada', 'Entrada', '🎟️'),
  mesa('mesa', 'Mesa', '🪑'),
  zona('zona', 'Zona', '✨'),
  foto('foto', 'Foto', '📸'),
  guardarropa('guardarropa', 'Guardarropa', '🧥'),
  comida('comida', 'Comida', '🍕'),
  experiencia('experiencia', 'Experiencia', '🎧');

  const CategoriaOferta(this.clave, this.etiqueta, this.pegatina);

  final String clave;
  final String etiqueta;
  final String pegatina;

  static CategoriaOferta? desde(String? clave) {
    for (final c in values) {
      if (c.clave == clave) return c;
    }
    return null;
  }
}

/// Como se demuestra que estas en el local al canjear.
enum VerificacionOferta {
  /// Basta con haber dicho "estoy aqui": para cosas pequeñas.
  aqui('aqui'),

  /// Hay que escanear el QR de la puerta: demuestra presencia fisica.
  qr('qr');

  const VerificacionOferta(this.clave);

  final String clave;

  static VerificacionOferta desde(String? clave) => clave == 'aqui' ? aqui : qr;
}

/// Palabras de consumo de alcohol que ninguna oferta puede llevar.
///
/// Es la misma lista que el disparador `privado.guardia_de_oferta`: la app la
/// comprueba para avisar antes, pero la que manda es la de la base de datos.
final _consumoDeAlcohol = RegExp(
  r'barra\s*libre|open\s*bar|\b2\s*x\s*1\b|dos\s*por\s*uno|\bbebe\b|bebid|'
  r'\bcopas?\b|chupito|cubata|combinado|cerveza|alcohol|\bshots?\b|emborrach',
  caseSensitive: false,
);

/// Verdadero si el texto promueve beber. Sirve a quien escriba o importe
/// plantillas y a los tests de contenido.
bool promueveAlcohol(String texto) => _consumoDeAlcohol.hasMatch(texto);

/// Una oferta ya redactada que el local puede lanzar con un toque.
///
/// El MVP no deja escribir texto libre: cada plantilla esta revisada contra
/// las restricciones legales y asi un descuido a las tres de la madrugada no
/// acaba en una promocion de alcohol.
class PlantillaOferta {
  const PlantillaOferta({
    required this.id,
    required this.categoria,
    required this.titulo,
    required this.detalle,
    required this.verificacion,
    required this.cuposSugeridos,
  });

  final String id;
  final CategoriaOferta categoria;
  final String titulo;
  final String detalle;
  final VerificacionOferta verificacion;
  final int cuposSugeridos;

  static const todas = <PlantillaOferta>[
    PlantillaOferta(
      id: 'entrada_ya',
      categoria: CategoriaOferta.entrada,
      titulo: 'Entrada gratis si llegas ya',
      detalle:
          'Para quien llegue durante la oferta. Enseña el código en la puerta.',
      verificacion: VerificacionOferta.qr,
      cuposSugeridos: 30,
    ),
    PlantillaOferta(
      id: 'mesa_descuento',
      categoria: CategoriaOferta.mesa,
      titulo: 'Mesa con descuento',
      detalle: 'Reserva de mesa con descuento para tu grupo esta noche.',
      verificacion: VerificacionOferta.qr,
      cuposSugeridos: 10,
    ),
    PlantillaOferta(
      id: 'foto_grupo',
      categoria: CategoriaOferta.foto,
      titulo: 'Foto de grupo gratis',
      detalle: 'Pasa por el fotomatón o el fotógrafo con tu grupo.',
      verificacion: VerificacionOferta.aqui,
      cuposSugeridos: 50,
    ),
    PlantillaOferta(
      id: 'guardarropa_gratis',
      categoria: CategoriaOferta.guardarropa,
      titulo: 'Guardarropa gratis',
      detalle: 'Deja tu abrigo sin coste hasta el cierre.',
      verificacion: VerificacionOferta.aqui,
      cuposSugeridos: 60,
    ),
    PlantillaOferta(
      id: 'comida_descuento',
      categoria: CategoriaOferta.comida,
      titulo: 'Comida con descuento',
      detalle: 'Descuento en la comida de la carta, sin pedido mínimo.',
      verificacion: VerificacionOferta.aqui,
      cuposSugeridos: 40,
    ),
    PlantillaOferta(
      id: 'zona_reservada',
      categoria: CategoriaOferta.zona,
      titulo: 'Acceso a la zona chill',
      detalle: 'Entra a la zona reservada sin coste extra durante la oferta.',
      verificacion: VerificacionOferta.aqui,
      cuposSugeridos: 25,
    ),
  ];
}

/// Una oferta en vivo de un local.
class Oferta {
  const Oferta({
    required this.id,
    required this.localId,
    required this.categoria,
    required this.titulo,
    required this.inicio,
    required this.fin,
    required this.cupos,
    this.detalle,
    this.canjes = 0,
    this.verificacion = VerificacionOferta.qr,
    this.cancelada = false,
    this.miCodigo,
  });

  final String id;
  final String localId;
  final CategoriaOferta categoria;
  final String titulo;
  final String? detalle;
  final DateTime inicio;
  final DateTime fin;

  /// Cuantas personas pueden canjearla en total.
  final int cupos;

  /// Cuantas la han canjeado ya.
  final int canjes;
  final VerificacionOferta verificacion;
  final bool cancelada;

  /// El codigo de canje de quien mira, si ya la canjeo. Evita que un segundo
  /// toque en "Canjear" parezca consumir otro cupo.
  final String? miCodigo;

  int get cuposRestantes => (cupos - canjes).clamp(0, cupos);
  bool get agotada => cuposRestantes == 0;
  bool get yaCanjeada => miCodigo != null;

  /// Cuanto queda, sin bajar de cero. Se pide el reloj de fuera para que las
  /// pruebas y la cuenta atras usen el mismo.
  Duration restante(DateTime ahora) {
    final d = fin.difference(ahora);
    return d.isNegative ? Duration.zero : d;
  }

  bool activa(DateTime ahora) =>
      !cancelada && !ahora.isBefore(inicio) && ahora.isBefore(fin);

  /// Se puede canjear: activa, con cupo, y que no la hayas canjeado ya.
  bool canjeable(DateTime ahora) => activa(ahora) && !agotada && !yaCanjeada;

  Oferta copiaCon({int? canjes, bool? cancelada, String? miCodigo}) => Oferta(
    id: id,
    localId: localId,
    categoria: categoria,
    titulo: titulo,
    detalle: detalle,
    inicio: inicio,
    fin: fin,
    cupos: cupos,
    canjes: canjes ?? this.canjes,
    verificacion: verificacion,
    cancelada: cancelada ?? this.cancelada,
    miCodigo: miCodigo ?? this.miCodigo,
  );

  factory Oferta.desdeJson(Map<String, dynamic> json) => Oferta(
    id: json['id'] as String,
    localId: json['venue_id'] as String,
    categoria:
        CategoriaOferta.desde(json['kind'] as String?) ??
        CategoriaOferta.experiencia,
    titulo: json['title'] as String,
    detalle: json['detail'] as String?,
    inicio: DateTime.parse(json['starts_at'] as String),
    fin: DateTime.parse(json['ends_at'] as String),
    cupos: (json['max_redemptions'] as num).toInt(),
    canjes: (json['canjes'] as num?)?.toInt() ?? 0,
    verificacion: VerificacionOferta.desde(json['verification'] as String?),
    cancelada: json['cancelled_at'] != null,
    miCodigo: json['mi_codigo'] as String?,
  );
}

/// "12:05" o "1:02:30" para la cuenta atras.
String textoCuentaAtras(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String dos(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${dos(m)}:${dos(s)}' : '${dos(m)}:${dos(s)}';
}
