import 'package:flutter/material.dart';

import '../../app/tema.dart';

/// Aviso de que la ubicacion que se ve es aproximada hasta que el anfitrion
/// acepta. Es un widget aparte para poder ponerlo en el mapa, el detalle de
/// la previa y los ajustes con exactamente el mismo texto: si cada pantalla
/// lo redactara por su cuenta acabarian contradiciendose.
class AvisoUbicacionAproximada extends StatelessWidget {
  const AvisoUbicacionAproximada({super.key, this.compacto = false});

  final bool compacto;

  static const texto = 'Ubicación aproximada hasta que te acepten. '
      'La dirección exacta solo se muestra a quien el anfitrión acepta.';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: texto,
      child: Container(
        padding: EdgeInsets.all(compacto ? EspaciadoPrevia.s : EspaciadoPrevia.m),
        decoration: BoxDecoration(
          color: ColoresPrevia.superficie,
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
          border: Border.all(color: ColoresPrevia.borde),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline,
                size: compacto ? 16 : 20, color: ColoresPrevia.primarioSuave),
            const SizedBox(width: EspaciadoPrevia.s),
            Expanded(
              child: Text(
                texto,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: compacto ? 12 : 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
