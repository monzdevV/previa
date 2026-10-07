import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/tema.dart';

/// Estado de una solicitud en pastilla.
///
/// El color va en el punto y el borde, no en las letras: el naranja y el
/// verde sobre blanco no llegan al contraste mínimo para texto pequeño, así
/// que el texto es siempre el del tema. La usa también "Mis solicitudes".
class PastillaEstado extends StatelessWidget {
  const PastillaEstado({super.key, required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: EspaciadoPrevia.s + 2,
        vertical: EspaciadoPrevia.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: EspaciadoPrevia.xs + 2),
          Text(
            texto.toUpperCase(),
            semanticsLabel: 'Estado: $texto',
            style: TextStyle(
              fontFamily: LetraPrevia.titular,
              color: c.texto,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Entrada escalonada de la casa: aparece y sube 12 px, solo los primeros
/// (40 ms entre elementos). Sin animacion si el sistema pide menos movimiento.
///
/// Duracion por debajo de 300 ms: es una lista que se abre a menudo.
class EntradaLista extends StatelessWidget {
  const EntradaLista({super.key, required this.indice, required this.child});

  final int indice;
  final Widget child;

  static const _duracion = Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context) {
    if (MovimientoPrevia.reducido(context)) return child;
    return child
        .animate(delay: MovimientoPrevia.retrasoDe(indice))
        .fadeIn(duration: _duracion, curve: MovimientoPrevia.curva)
        .moveY(
          begin: 12,
          end: 0,
          duration: _duracion,
          curve: MovimientoPrevia.curva,
        );
  }
}
