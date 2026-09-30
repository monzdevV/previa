import 'package:flutter/material.dart';

import '../../app/tema.dart';
import '../../data/models/perfil.dart';

/// Insignia de reputacion calculada en el cliente.
class InsigniaReputacion {
  const InsigniaReputacion(this.texto, this.descripcion, this.icono);
  final String texto;
  final String descripcion;
  final IconData icono;
}

/// Insignias segun numero y media de valoraciones.
///
/// Se calculan en cliente porque el servidor solo guarda media y contador;
/// los umbrales exigen volumen ademas de nota para que un unico 5 no baste.
List<InsigniaReputacion> insigniasDe(Perfil p) {
  final media = p.reputacion;
  final n = p.numeroValoraciones;
  if (media == null || n == 0) {
    return const [
      InsigniaReputacion(
        'Recién llegada',
        'Aún sin valoraciones',
        Icons.waving_hand_outlined,
      ),
    ];
  }
  final insignias = <InsigniaReputacion>[];
  if (n >= 3 && media >= 4.0) {
    insignias.add(
      const InsigniaReputacion(
        'Buena compañía',
        'Media de 4 o más con al menos 3 valoraciones',
        Icons.favorite_outline,
      ),
    );
  }
  if (n >= 8 && media >= 4.5) {
    insignias.add(
      const InsigniaReputacion(
        'Anfitrión fiable',
        'Media de 4,5 o más con al menos 8 valoraciones',
        Icons.verified_outlined,
      ),
    );
  }
  if (n >= 20 && media >= 4.5) {
    insignias.add(
      const InsigniaReputacion(
        'Habitual de las previas',
        'Más de 20 valoraciones y gran media',
        Icons.local_fire_department_outlined,
      ),
    );
  }
  if (insignias.isEmpty) {
    insignias.add(
      const InsigniaReputacion(
        'Tomando ritmo',
        'Cada previa suma a tu reputación',
        Icons.trending_up,
      ),
    );
  }
  return insignias;
}

/// Cinco estrellas (llenas, medias o vacias) segun una media.
///
/// Es decorativo: el texto con la nota va al lado, asi que se excluye de la
/// semantica para no leer cinco veces "estrella".
class EstrellasMedia extends StatelessWidget {
  const EstrellasMedia({super.key, required this.media, this.tamano = 20});

  final double media;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              media >= i
                  ? Icons.star_rounded
                  : (media >= i - 0.5
                        ? Icons.star_half_rounded
                        : Icons.star_outline_rounded),
              size: tamano,
              color: media >= i - 0.5
                  ? ColoresPrevia.aviso
                  : ColoresPrevia.textoTenue,
            ),
        ],
      ),
    );
  }
}

/// Numero que sube hasta su valor al aparecer.
///
/// Con "reducir movimiento" se muestra directamente el valor final.
class ContadorAnimado extends StatelessWidget {
  const ContadorAnimado({
    super.key,
    required this.valor,
    this.decimales = 0,
    this.estilo,
  });

  final double valor;
  final int decimales;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    final sinMovimiento = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: sinMovimiento ? valor : 0, end: valor),
      duration: sinMovimiento
          ? Duration.zero
          : const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(v.toStringAsFixed(decimales), style: estilo),
    );
  }
}
