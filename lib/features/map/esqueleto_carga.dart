import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/tema.dart';

/// Esqueleto de la tarjeta del carrusel del mapa mientras se buscan previas.
///
/// Tiene la forma exacta de la tarjeta que va a llegar (portada a la
/// izquierda, hora, titulo, anfitrion y plazas) y ocupa su mismo hueco, asi
/// que cuando llegan los datos nada salta: solo se rellena. Un bloque liso
/// decia "algo carga"; este dice "aqui va a haber una previa".
///
/// Los bloques no dicen nada al lector de pantalla: el conjunto se anuncia
/// como "Buscando previas". Con "reducir movimiento" el brillo no corre.
class EsqueletoTarjetaMapa extends StatelessWidget {
  const EsqueletoTarjetaMapa({super.key, this.fraccion = 0.86});

  /// Ancho relativo de la tarjeta: el mismo `viewportFraction` del carrusel.
  final double fraccion;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    Widget bloque(double ancho, double alto) => Container(
      width: ancho,
      height: alto,
      decoration: BoxDecoration(
        color: c.superficieActiva,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
      ),
    );

    final tarjeta = FractionallySizedBox(
      widthFactor: fraccion,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: EspaciadoPrevia.xs + 1),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.superficieAlta,
            borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
          ),
          child: Row(
            children: [
              Container(
                width: 104,
                decoration: BoxDecoration(
                  color: c.superficieActiva,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    bloque(72, 20),
                    const SizedBox(height: 10),
                    bloque(double.infinity, 13),
                    const SizedBox(height: 7),
                    bloque(110, 11),
                    const SizedBox(height: 10),
                    bloque(84, 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final conBrillo = MovimientoPrevia.reducido(context)
        ? tarjeta
        : tarjeta
              .animate(onPlay: (a) => a.repeat())
              .shimmer(duration: 1200.ms, color: c.superficie);

    return Semantics(
      label: 'Buscando previas',
      liveRegion: true,
      container: true,
      excludeSemantics: true,
      child: conBrillo,
    );
  }
}
