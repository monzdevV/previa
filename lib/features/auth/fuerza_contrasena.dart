import 'package:flutter/material.dart';

import '../../app/tema.dart';

/// Nivel de fortaleza orientativo de una contraseña.
enum NivelContrasena {
  vacia('', 0),
  muyCorta('Muy corta', 1),
  debil('Débil', 1),
  media('Media', 2),
  buena('Buena', 3),
  fuerte('Fuerte', 4);

  const NivelContrasena(this.etiqueta, this.segmentos);
  final String etiqueta;

  /// Segmentos de la barra que se rellenan (de 4).
  final int segmentos;
}

/// Heurística simple y explicable (no pretende sustituir a un estimador real):
/// menos de 6 caracteres es el mínimo que exige el registro; a partir de ahí
/// suman longitud, mezcla de mayúsculas/minúsculas, números y símbolos.
///
/// Es solo una guía visual: nunca bloquea el registro, que lo decide el
/// validador de longitud mínima y el servidor.
NivelContrasena nivelDeContrasena(String valor) {
  if (valor.isEmpty) return NivelContrasena.vacia;
  if (valor.length < 6) return NivelContrasena.muyCorta;

  var puntos = 0;
  if (valor.length >= 8) puntos++;
  if (valor.length >= 12) puntos++;
  if (RegExp(r'[a-z]').hasMatch(valor) && RegExp(r'[A-Z]').hasMatch(valor)) {
    puntos++;
  }
  if (RegExp(r'\d').hasMatch(valor)) puntos++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(valor)) puntos++;

  if (puntos <= 1) return NivelContrasena.debil;
  if (puntos == 2) return NivelContrasena.media;
  if (puntos == 3) return NivelContrasena.buena;
  return NivelContrasena.fuerte;
}

/// Barra de 4 segmentos + etiqueta. El nivel se comunica también con texto
/// (no solo con color) y se anuncia como región viva para lectores de pantalla.
class IndicadorFuerzaContrasena extends StatelessWidget {
  const IndicadorFuerzaContrasena({super.key, required this.controlador});

  final TextEditingController controlador;

  static Color _color(NivelContrasena n) => switch (n) {
        NivelContrasena.vacia => ColoresPrevia.borde,
        NivelContrasena.muyCorta || NivelContrasena.debil => ColoresPrevia.error,
        NivelContrasena.media => ColoresPrevia.aviso,
        NivelContrasena.buena || NivelContrasena.fuerte => ColoresPrevia.acento,
      };

  @override
  Widget build(BuildContext context) {
    final reducir = MediaQuery.disableAnimationsOf(context);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controlador,
      builder: (context, valor, _) {
        final nivel = nivelDeContrasena(valor.text);
        if (nivel == NivelContrasena.vacia) return const SizedBox.shrink();
        final color = _color(nivel);

        return Semantics(
          liveRegion: true,
          label: 'Seguridad de la contraseña: ${nivel.etiqueta}',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.only(
              top: EspaciadoPrevia.s,
              left: EspaciadoPrevia.xs,
              right: EspaciadoPrevia.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: AnimatedContainer(
                            duration: reducir
                                ? Duration.zero
                                : const Duration(milliseconds: 250),
                            height: 5,
                            decoration: BoxDecoration(
                              color: i < nivel.segmentos
                                  ? color
                                  : ColoresPrevia.borde,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: EspaciadoPrevia.m),
                Text(
                  nivel.etiqueta,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
