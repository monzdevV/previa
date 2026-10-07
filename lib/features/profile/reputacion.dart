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
                  ? context.colores.aviso
                  : context.colores.textoTenue,
            ),
        ],
      ),
    );
  }
}

/// Numero que sube hasta su valor al aparecer.
///
/// Corto (menos de 300 ms) y con la curva de la casa: es un remate, no algo
/// que haya que esperar. Con "reducir movimiento" se muestra directamente el
/// valor final. Los decimales van con coma, como se escriben en España.
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

  static String formatear(double v, int decimales) =>
      v.toStringAsFixed(decimales).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final sinMovimiento = MovimientoPrevia.reducido(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: sinMovimiento ? valor : 0, end: valor),
      duration: sinMovimiento
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: MovimientoPrevia.curva,
      builder: (_, v, _) => Text(
        formatear(v, decimales),
        style: (estilo ?? const TextStyle()).copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Tu reputacion, en grande y con sus insignias.
///
/// Va justo debajo de la cara: antes de quedar con alguien se mira quien es
/// y despues que tal le han valorado. La nota manda (letra gorda, cifras
/// tabulares) y las insignias explican de donde sale. Sin valoraciones no se
/// pinta un cero, que seria mentira: se dice que aun no hay.
class TarjetaReputacion extends StatelessWidget {
  const TarjetaReputacion({super.key, required this.perfil});

  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final tiene = perfil.tieneReputacion;
    final n = perfil.numeroValoraciones;
    final media = perfil.reputacion ?? 0;
    final valoraciones = n == 1 ? 'valoración' : 'valoraciones';
    final detalle = TextStyle(
      color: c.textoSuave,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final resumen = tiene
        ? 'Reputación ${ContadorAnimado.formatear(media, 1)} sobre 5, '
              '$n $valoraciones'
        : 'Aún sin valoraciones';

    return Container(
      padding: const EdgeInsets.fromLTRB(
        EspaciadoPrevia.m,
        EspaciadoPrevia.m,
        EspaciadoPrevia.m,
        EspaciadoPrevia.s,
      ),
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: resumen,
            child: ExcludeSemantics(
              child: tiene
                  ? Row(
                      children: [
                        ContadorAnimado(
                          valor: media,
                          decimales: 1,
                          estilo: TextStyle(
                            fontFamily: LetraPrevia.titular,
                            fontWeight: FontWeight.w900,
                            fontSize: 48,
                            height: 1,
                            letterSpacing: -1.4,
                            color: c.texto,
                          ),
                        ),
                        const SizedBox(width: EspaciadoPrevia.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              EstrellasMedia(media: media, tamano: 20),
                              const SizedBox(height: 4),
                              Text('$n $valoraciones', style: detalle),
                            ],
                          ),
                        ),
                      ],
                    )
                  // Sin nota no hay cifra que enseñar: titular corto y la
                  // frase entera debajo, sin cortarla.
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Titular('Aún sin valorar', tamano: 24),
                            ),
                            EstrellasMedia(media: 0, tamano: 18),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Te valorarán al terminar tus previas.',
                          style: detalle,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: EspaciadoPrevia.xs),
          Wrap(
            spacing: EspaciadoPrevia.s,
            children: [
              for (final i in insigniasDe(perfil)) _PastillaInsignia(i),
            ],
          ),
        ],
      ),
    );
  }
}

/// Una insignia en pastilla. Se ve pequeña, pero el toque ocupa 48 de alto;
/// al tocarla cuenta como se consigue.
class _PastillaInsignia extends StatelessWidget {
  const _PastillaInsignia(this.insignia);

  final InsigniaReputacion insignia;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Tooltip(
      message: insignia.descripcion,
      triggerMode: TooltipTriggerMode.tap,
      excludeFromSemantics: true,
      child: Semantics(
        label: '${insignia.texto}. ${insignia.descripcion}',
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
              decoration: BoxDecoration(
                color: c.superficieAlta,
                borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(insignia.icono, size: 16, color: c.primarioTexto),
                  const SizedBox(width: 6),
                  Text(
                    insignia.texto,
                    style: TextStyle(
                      color: c.texto,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
