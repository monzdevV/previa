import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/tema.dart';
import '../../data/models/previa.dart';
import 'componentes_previa.dart';

/// Texto único que leen los lectores de pantalla para una previa. Una sola
/// frase ordenada vale más que oír cada fragmento suelto ("3", "Centro",
/// "21:30"...).
String etiquetaAccesiblePrevia(Previa p) {
  final hora = DateFormat('HH:mm', 'es_ES').format(p.empiezaEn);
  final plazas = p.plazasLibres <= 0
      ? 'completa'
      : (p.plazasLibres == 1
            ? '1 plaza libre'
            : '${p.plazasLibres} plazas libres');
  final distancia = p.distanciaMetros != null
      ? ', a ${p.distanciaLegible}'
      : '';
  return '${p.titulo}, $plazas, empieza a las $hora, zona ${p.zona}'
      '$distancia, organiza ${p.anfitrionNombre}';
}

/// Tarjeta de una previa en los listados.
///
/// Arriba, el cartel del ambiente con la hora en grande: es lo que da
/// identidad a algo que no tiene foto (la casa de alguien no se enseña). El
/// dato que decide si alguien toca, las plazas, va encima en su pastilla, y
/// abajo la cara de quien abre la puerta, porque eso decide si pides plaza.
/// El cartel vuela hasta el detalle con un [Hero].
class TarjetaPrevia extends StatelessWidget {
  const TarjetaPrevia({
    super.key,
    required this.previa,
    this.onTap,
    this.compacta = false,
    this.conHero = true,
  });

  final Previa previa;
  final VoidCallback? onTap;

  /// En la hoja del mapa y en el perfil el alto es oro: el cartel se encoge
  /// y la descripción desaparece, pero la cara y las plazas se quedan.
  final bool compacta;

  /// La vista previa del formulario no debe competir por la etiqueta del Hero.
  final bool conHero;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final hora = DateFormat('HH:mm', 'es_ES').format(previa.empiezaEn);
    final alto = compacta ? 72.0 : 112.0;
    final radioArriba = const BorderRadius.vertical(
      top: Radius.circular(EspaciadoPrevia.radio),
    );

    final cabecera = CabeceraAmbiente(
      ambiente: previa.ambiente,
      altura: alto,
      radio: radioArriba,
    );

    final tarjeta = DecoratedBox(
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: alto,
            child: Stack(
              fit: StackFit.expand,
              children: [
                conHero && !MovimientoPrevia.reducido(context)
                    ? Hero(tag: tagCabeceraPrevia(previa.id), child: cabecera)
                    : cabecera,
                Positioned(
                  top: EspaciadoPrevia.s + EspaciadoPrevia.xs,
                  right: EspaciadoPrevia.s + EspaciadoPrevia.xs,
                  child: PastillaPlazas(libres: previa.plazasLibres),
                ),
                // La hora como en un cartel: es lo segundo que se mira despues
                // de si queda sitio.
                Positioned(
                  left: EspaciadoPrevia.m,
                  bottom: EspaciadoPrevia.s + EspaciadoPrevia.xs,
                  child: Titular(
                    hora,
                    tamano: compacta ? 26 : 38,
                    color: BloquesPrevia.tintaSobreBloque,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(EspaciadoPrevia.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  previa.titulo,
                  style: textos.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: EspaciadoPrevia.xs),
                Text(
                  [
                    previa.zona,
                    if (previa.distanciaLegible.isNotEmpty)
                      previa.distanciaLegible,
                    previa.cuandoEmpieza,
                  ].join(' · '),
                  style: textos.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                if (!compacta &&
                    previa.descripcion != null &&
                    previa.descripcion!.isNotEmpty) ...[
                  const SizedBox(height: EspaciadoPrevia.s),
                  Text(
                    previa.descripcion!,
                    style: textos.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                if (previa.ambiente.isNotEmpty) ...[
                  const SizedBox(
                    height: EspaciadoPrevia.s + EspaciadoPrevia.xs,
                  ),
                  Wrap(
                    spacing: EspaciadoPrevia.xs + 2,
                    runSpacing: EspaciadoPrevia.xs + 2,
                    children: [
                      for (final etiqueta in previa.ambiente.take(3))
                        _Etiqueta(etiqueta),
                    ],
                  ),
                ],

                const SizedBox(height: EspaciadoPrevia.s + EspaciadoPrevia.xs),
                _Anfitrion(previa: previa),
              ],
            ),
          ),
        ],
      ),
    );

    // Sin onTap la tarjeta es solo informativa y se lee tal cual. Con onTap
    // se anuncia como UN botón con la frase completa, y se silencia el
    // contenido suelto para no leerlo dos veces.
    if (onTap == null) return tarjeta;
    return Semantics(
      button: true,
      container: true,
      label: etiquetaAccesiblePrevia(previa),
      hint: 'Toca para ver la previa',
      onTap: onTap,
      excludeSemantics: true,
      child: Pulsable(onTap: onTap, escala: 0.97, child: tarjeta),
    );
  }
}

/// Quien organiza: su cara, su nombre y lo que dicen de él.
class _Anfitrion extends StatelessWidget {
  const _Anfitrion({required this.previa});

  final Previa previa;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final reputacion = previa.anfitrionReputacion;

    return Row(
      children: [
        AvatarPerfil(
          url: previa.anfitrionAvatar,
          inicial: previa.anfitrionNombre,
          lado: 28,
        ),
        const SizedBox(width: EspaciadoPrevia.s),
        Expanded(
          child: Text(
            previa.anfitrionNombre,
            style: textos.bodyMedium?.copyWith(
              color: context.colores.texto,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Sin estrella y sin ambar: la tinta viva esta reservada a las
        // plazas libres, y "sobre cinco" ya lo dice el texto.
        if (reputacion != null)
          Text(
            '${reputacion.toStringAsFixed(1).replaceAll('.', ',')}/5',
            style: textos.labelMedium,
          ),
      ],
    );
  }
}

/// Plazas libres en pastilla, con el color de la ocupación.
///
/// Pública porque el detalle la reutiliza: las plazas tienen que decirse
/// igual en el listado y en la ficha.
class PastillaPlazas extends StatelessWidget {
  const PastillaPlazas({super.key, required this.libres});

  final int libres;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final ocupacion = Ocupacion.desde(libres);
    final etiqueta = switch (ocupacion) {
      Ocupacion.completa => 'Completa',
      _ => libres == 1 ? '1 plaza' : '$libres plazas',
    };
    // Sobre el verde y el naranja, negro; la completa va en una pastilla
    // oscura casi opaca para que se lea sobre cualquier bloque.
    final tinta = ocupacion.viva ? c.sobrePrimario : c.textoSuave;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: EspaciadoPrevia.s + EspaciadoPrevia.xs,
        vertical: EspaciadoPrevia.xs + 2,
      ),
      decoration: BoxDecoration(
        color: ocupacion.viva
            ? ocupacion.color(c)
            : c.fondo.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // El punto de "en directo": dice de un vistazo que ahi se entra.
          if (ocupacion.viva) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: tinta, shape: BoxShape.circle),
            ),
            const SizedBox(width: EspaciadoPrevia.xs + 1),
          ],
          Text(
            etiqueta,
            style: TextStyle(
              color: tinta,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: EspaciadoPrevia.s + EspaciadoPrevia.xs,
      vertical: EspaciadoPrevia.xs + 1,
    ),
    decoration: BoxDecoration(
      color: context.colores.superficieAlta,
      borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
    ),
    child: Text(
      texto,
      style: TextStyle(
        color: context.colores.textoSuave,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
