import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/tema.dart';
import '../../data/models/previa.dart';
import '../profile/avatar_previa.dart';
import 'componentes_previa.dart';

/// Texto único que leen los lectores de pantalla para una previa (tarjeta y
/// burbuja del mapa). Una sola frase ordenada vale más que oír cada fragmento
/// suelto ("3", "Centro", "21:30"...).
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
  return '${p.titulo}, $plazas, empieza a las $hora, zona ${p.zona}$distancia';
}

/// Tarjeta de una previa en los listados.
///
/// Arriba, una cabecera generada con el ambiente (da identidad sin fotos); el
/// dato que decide si alguien toca, las plazas, va en acento sobre ella.
/// La cabecera es un [Hero] hacia el detalle.
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
  final bool compacta;

  /// La vista previa del formulario no debe competir por el tag del Hero.
  final bool conHero;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final hora = DateFormat('HH:mm', 'es_ES').format(previa.empiezaEn);
    final altura = compacta ? 52.0 : 76.0;

    final cabecera = CabeceraAmbiente(
      ambiente: previa.ambiente,
      altura: altura,
    );

    final tarjeta = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                conHero
                    ? Hero(tag: tagCabeceraPrevia(previa.id), child: cabecera)
                    : cabecera,
                Positioned(
                  top: EspaciadoPrevia.s + 2,
                  right: EspaciadoPrevia.s + 2,
                  child: _Plazas(previa.plazasLibres),
                ),
              ],
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
                  const SizedBox(height: EspaciadoPrevia.s),

                  // Zona, hora y distancia: los tres datos que se miran de un vistazo.
                  Wrap(
                    spacing: EspaciadoPrevia.s,
                    runSpacing: EspaciadoPrevia.s,
                    children: [
                      ChipDato(icono: Icons.place_outlined, texto: previa.zona),
                      ChipDato(
                        icono: Icons.schedule,
                        texto: '$hora · ${previa.cuandoEmpieza}',
                      ),
                      if (previa.distanciaMetros != null)
                        ChipDato(
                          icono: Icons.directions_walk,
                          texto: previa.distanciaLegible,
                        ),
                    ],
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
                    const SizedBox(height: EspaciadoPrevia.s),
                    Wrap(
                      spacing: EspaciadoPrevia.xs,
                      runSpacing: EspaciadoPrevia.xs,
                      children: [
                        for (final etiqueta in previa.ambiente.take(4))
                          _Etiqueta(etiqueta),
                      ],
                    ),
                  ],

                  const SizedBox(height: EspaciadoPrevia.m),
                  Row(
                    children: [
                      AvatarPrevia(
                        iniciales: previa.anfitrionNombre.isNotEmpty
                            ? previa.anfitrionNombre[0].toUpperCase()
                            : '?',
                        url: previa.anfitrionAvatar,
                        radio: 12,
                      ),
                      const SizedBox(width: EspaciadoPrevia.s),
                      Expanded(
                        child: Text(
                          previa.anfitrionNombre,
                          style: textos.bodyMedium?.copyWith(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (previa.anfitrionReputacion != null) ...[
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: ColoresPrevia.aviso,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          previa.anfitrionReputacion!.toStringAsFixed(1),
                          style: textos.bodyMedium?.copyWith(
                            fontSize: 13,
                            color: ColoresPrevia.texto,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Sin onTap la tarjeta es solo informativa y se lee tal cual. Con onTap se
    // anuncia como UN botón con la frase completa, y se silencia el contenido
    // suelto para no leerlo dos veces.
    if (onTap == null) return tarjeta;
    return Semantics(
      button: true,
      container: true,
      label: etiquetaAccesiblePrevia(previa),
      hint: 'Toca para ver la previa',
      onTap: onTap,
      excludeSemantics: true,
      child: tarjeta,
    );
  }
}

/// Plazas sobre la cabecera: fondo casi opaco para que el texto en acento
/// conserve contraste sobre cualquier gradiente.
class _Plazas extends StatelessWidget {
  const _Plazas(this.libres);
  final int libres;

  @override
  Widget build(BuildContext context) {
    final lleno = libres <= 0;
    final color = lleno ? ColoresPrevia.textoSuave : ColoresPrevia.acento;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: EspaciadoPrevia.s + 2,
        vertical: EspaciadoPrevia.xs + 1,
      ),
      decoration: BoxDecoration(
        color: ColoresPrevia.fondo.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        lleno ? 'Completa' : (libres == 1 ? '1 plaza' : '$libres plazas'),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: EspaciadoPrevia.s,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: ColoresPrevia.superficieAlta,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
        border: Border.all(color: ColoresPrevia.borde),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          color: ColoresPrevia.textoSuave,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
