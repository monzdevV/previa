import 'package:flutter/material.dart';

import '../../app/tema.dart';

/// Avatar circular: foto si la hay, iniciales si no.
///
/// Es un unico widget para toda la app para que la foto se comporte igual en
/// todas partes (incluido el caso en que la URL falla a cargar, donde se cae
/// a las iniciales en vez de dejar un hueco roto).
class AvatarPrevia extends StatelessWidget {
  const AvatarPrevia({
    super.key,
    required this.iniciales,
    this.url,
    this.radio = 24,
    this.etiqueta,
  });

  final String iniciales;
  final String? url;
  final double radio;

  /// Texto para lectores de pantalla. Si es null el avatar se considera
  /// decorativo, porque normalmente el nombre ya aparece al lado.
  final String? etiqueta;

  @override
  Widget build(BuildContext context) {
    final textoIniciales = Text(
      iniciales,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: radio * 0.7,
      ),
    );

    final avatar = CircleAvatar(
      radius: radio,
      backgroundColor: ColoresPrevia.primario,
      foregroundImage: (url == null || url!.isEmpty)
          ? null
          : NetworkImage(url!),
      // Si la imagen falla, CircleAvatar vuelve a mostrar el child.
      onForegroundImageError: (url == null || url!.isEmpty) ? null : (_, _) {},
      child: textoIniciales,
    );

    return etiqueta == null
        ? ExcludeSemantics(child: avatar)
        : Semantics(
            label: etiqueta,
            image: true,
            // Sin esto el lector leeria tambien las iniciales ("Tu foto AB").
            excludeSemantics: true,
            child: avatar,
          );
  }
}
