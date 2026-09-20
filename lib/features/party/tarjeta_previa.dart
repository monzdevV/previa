import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/tema.dart';
import '../../data/models/previa.dart';

/// Tarjeta de una previa en los listados.
///
/// El dato que decide si alguien toca o no es cuantas plazas quedan, asi que
/// es lo unico que lleva color de acento. Todo lo demas es jerarquia tipografica.
class TarjetaPrevia extends StatelessWidget {
  const TarjetaPrevia({
    super.key,
    required this.previa,
    this.onTap,
    this.compacta = false,
  });

  final Previa previa;
  final VoidCallback? onTap;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final hora = DateFormat('HH:mm', 'es_ES').format(previa.empiezaEn);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        child: Padding(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      previa.titulo,
                      style: textos.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: EspaciadoPrevia.s),
                  _Plazas(previa.plazasLibres),
                ],
              ),

              const SizedBox(height: EspaciadoPrevia.s),

              // Zona, hora y distancia: los tres datos que se miran de un vistazo.
              Wrap(
                spacing: EspaciadoPrevia.m,
                runSpacing: EspaciadoPrevia.xs,
                children: [
                  _Dato(Icons.place_outlined, previa.zona),
                  _Dato(Icons.schedule, '$hora · ${previa.cuandoEmpieza}'),
                  if (previa.distanciaMetros != null)
                    _Dato(Icons.directions_walk, previa.distanciaLegible),
                ],
              ),

              if (!compacta && previa.descripcion != null &&
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
                const SizedBox(height: EspaciadoPrevia.m),
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
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: ColoresPrevia.superficieAlta,
                    child: Text(
                      previa.anfitrionNombre.isNotEmpty
                          ? previa.anfitrionNombre[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ColoresPrevia.texto,
                      ),
                    ),
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
                    const Icon(Icons.star_rounded,
                        size: 15, color: ColoresPrevia.aviso),
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
      ),
    );
  }
}

class _Plazas extends StatelessWidget {
  const _Plazas(this.libres);
  final int libres;

  @override
  Widget build(BuildContext context) {
    final lleno = libres <= 0;
    final color = lleno ? ColoresPrevia.textoTenue : ColoresPrevia.acento;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: EspaciadoPrevia.s + 2,
        vertical: EspaciadoPrevia.xs + 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
        border: Border.all(color: color.withValues(alpha: 0.45)),
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

class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.texto);
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: ColoresPrevia.textoSuave),
        const SizedBox(width: EspaciadoPrevia.xs),
        Text(
          texto,
          style: const TextStyle(fontSize: 13, color: ColoresPrevia.textoSuave),
        ),
      ],
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
          fontSize: 11,
          color: ColoresPrevia.textoSuave,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
