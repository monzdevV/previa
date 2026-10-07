import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/tema.dart';

/// Una red en la que alguien tiene cuenta.
enum Red {
  instagram('Instagram', FontAwesomeIcons.instagram, Color(0xFFE1306C)),
  tiktok('TikTok', FontAwesomeIcons.tiktok, Color(0xFF111111)),
  x('X', FontAwesomeIcons.xTwitter, Color(0xFF111111));

  const Red(this.nombre, this.icono, this.color);

  final String nombre;
  final FaIconData icono;

  /// El color del disco del icono. TikTok y X son negros de marca, asi que
  /// llevan un filo claro para no perderse sobre el fondo negro.
  final Color color;

  Uri enlace(String usuario) => switch (this) {
    Red.instagram => Uri.parse('https://instagram.com/$usuario'),
    Red.tiktok => Uri.parse('https://www.tiktok.com/@$usuario'),
    Red.x => Uri.parse('https://x.com/$usuario'),
  };
}

/// Las redes de alguien, a la vista y a un toque.
///
/// Van como pastillas con el logo y el usuario, no como un icono gris al
/// final: para quedar con alguien, lo primero que se mira es su Instagram, y
/// esconderlo solo obliga a pedirlo por mensaje.
class FilaDeRedes extends StatelessWidget {
  const FilaDeRedes({
    super.key,
    this.instagram,
    this.tiktok,
    this.xUsuario,
    this.onAnadir,
  });

  final String? instagram;
  final String? tiktok;
  final String? xUsuario;

  /// Solo en tu perfil: si no tienes ninguna, se ofrece añadirlas.
  final VoidCallback? onAnadir;

  @override
  Widget build(BuildContext context) {
    final redes = <(Red, String)>[
      if (instagram?.isNotEmpty ?? false) (Red.instagram, instagram!),
      if (tiktok?.isNotEmpty ?? false) (Red.tiktok, tiktok!),
      if (xUsuario?.isNotEmpty ?? false) (Red.x, xUsuario!),
    ];

    if (redes.isEmpty) {
      if (onAnadir == null) return const SizedBox.shrink();
      return _Pastilla(
        onTap: onAnadir!,
        etiqueta: 'Añadir tus redes',
        disco: Icon(Icons.add_rounded, size: 18, color: context.colores.texto),
        colorDisco: context.colores.superficieActiva,
        texto: 'Añade tus redes',
      );
    }

    return Wrap(
      spacing: EspaciadoPrevia.s,
      runSpacing: EspaciadoPrevia.s,
      children: [
        for (final (red, usuario) in redes)
          _Pastilla(
            onTap: () => launchUrl(
              red.enlace(usuario),
              mode: LaunchMode.externalApplication,
            ),
            etiqueta: '${red.nombre}: $usuario',
            disco: FaIcon(red.icono, size: 15, color: Colors.white),
            colorDisco: red.color,
            texto: usuario,
          ),
      ],
    );
  }
}

class _Pastilla extends StatelessWidget {
  const _Pastilla({
    required this.onTap,
    required this.etiqueta,
    required this.disco,
    required this.colorDisco,
    required this.texto,
  });

  final VoidCallback onTap;
  final String etiqueta;
  final Widget disco;
  final Color colorDisco;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Semantics(
      button: true,
      label: etiqueta,
      excludeSemantics: true,
      child: Pulsable(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.only(left: 6, right: 14),
          decoration: BoxDecoration(
            color: c.superficieAlta,
            borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorDisco,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.bordeCristal),
                ),
                child: disco,
              ),
              const SizedBox(width: EspaciadoPrevia.s),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.texto,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
