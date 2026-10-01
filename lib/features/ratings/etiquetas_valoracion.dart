import 'package:flutter/material.dart';

/// Etiqueta rapida que se puede anadir a una valoracion.
class EtiquetaValoracion {
  const EtiquetaValoracion(this.clave, this.texto, this.icono);

  /// Lo que se guarda en el comentario. Estable: no cambiar el texto de una
  /// clave ya publicada o las valoraciones antiguas dejarian de reconocerse.
  final String clave;
  final String texto;
  final IconData icono;
}

const etiquetasValoracion = <EtiquetaValoracion>[
  EtiquetaValoracion('puntual', 'Puntual', Icons.schedule),
  EtiquetaValoracion('buen rollo', 'Buen rollo', Icons.celebration_outlined),
  EtiquetaValoracion(
    'casa limpia',
    'Casa limpia',
    Icons.cleaning_services_outlined,
  ),
  EtiquetaValoracion('respetuoso', 'Respetuoso', Icons.handshake_outlined),
  EtiquetaValoracion('generoso', 'Generoso', Icons.local_bar_outlined),
  EtiquetaValoracion('majo', 'Majo', Icons.emoji_emotions_outlined),
];

const maximoComentario = 300;

/// Las etiquetas viajan dentro del comentario, como "[puntual, buen rollo] ...".
///
/// Asi no hace falta tocar el esquema de la base de datos (la columna
/// `comment` es la unica disponible) y el comentario sigue siendo legible
/// si otra version de la app no conoce las etiquetas.
String componerComentario(Iterable<String> claves, String texto) {
  final limpio = texto.trim();
  if (claves.isEmpty) return limpio;
  final prefijo = '[${claves.join(', ')}]';
  // La base de datos rechaza mas de 300 caracteres: se recorta el texto
  // libre, nunca las etiquetas.
  final hueco = maximoComentario - prefijo.length - 1;
  final recortado = limpio.length > hueco
      ? limpio.substring(0, hueco < 0 ? 0 : hueco)
      : limpio;
  return recortado.isEmpty ? prefijo : '$prefijo $recortado';
}

/// Inverso de [componerComentario].
({List<String> claves, String texto}) descomponerComentario(
  String? comentario,
) {
  final c = (comentario ?? '').trim();
  final m = RegExp(r'^\[([^\]]*)\]\s*(.*)$', dotAll: true).firstMatch(c);
  if (m == null) return (claves: <String>[], texto: c);
  final claves = m
      .group(1)!
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  return (claves: claves, texto: m.group(2)!.trim());
}
