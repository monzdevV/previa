import 'package:flutter/material.dart';

import '../../app/tema.dart';

/// Lo minimo que pide el registro (y el servidor).
const minimoContrasena = 6;

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
  if (valor.length < minimoContrasena) return NivelContrasena.muyCorta;

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

/// Barra de 4 segmentos y una frase debajo del campo de contraseña.
///
/// Sustituye al antiguo "Mínimo 6 caracteres / Perfecto": con el campo vacio
/// dice el minimo, mientras falta dice cuanto falta (sin rojo: escribir aun
/// no es equivocarse) y despues orienta sobre la seguridad. Ocupa siempre lo
/// mismo, asi que el formulario no da saltos al escribir.
///
/// El nivel va tambien en texto, no solo en color, y se anuncia como region
/// viva para el lector de pantalla. La frase usa el color de texto y el color
/// queda en las barras, para que se lea con contraste AA en los dos temas.
class IndicadorFuerzaContrasena extends StatelessWidget {
  const IndicadorFuerzaContrasena({super.key, required this.controlador});

  final TextEditingController controlador;

  static Color _color(ColoresPrevia c, NivelContrasena n) => switch (n) {
    NivelContrasena.vacia || NivelContrasena.muyCorta => c.textoTenue,
    NivelContrasena.debil => c.error,
    NivelContrasena.media => c.aviso,
    NivelContrasena.buena || NivelContrasena.fuerte => c.acento,
  };

  static String _frase(NivelContrasena nivel, int largo) => switch (nivel) {
    NivelContrasena.vacia => 'Mínimo $minimoContrasena caracteres',
    NivelContrasena.muyCorta =>
      minimoContrasena - largo == 1
          ? 'Falta 1 carácter'
          : 'Faltan ${minimoContrasena - largo} caracteres',
    NivelContrasena.debil => 'Débil · prueba con números o símbolos',
    _ => nivel.etiqueta,
  };

  @override
  Widget build(BuildContext context) {
    final reducido = MovimientoPrevia.reducido(context);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controlador,
      builder: (context, valor, _) {
        final c = context.colores;
        final nivel = nivelDeContrasena(valor.text);
        final color = _color(c, nivel);
        final frase = _frase(nivel, valor.text.length);

        return Semantics(
          liveRegion: nivel != NivelContrasena.vacia,
          label: nivel == NivelContrasena.vacia
              ? frase
              : 'Seguridad de la contraseña: $frase',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              EspaciadoPrevia.xs,
              EspaciadoPrevia.s,
              EspaciadoPrevia.xs,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: EspaciadoPrevia.xs),
                      Expanded(
                        child: AnimatedContainer(
                          duration: reducido
                              ? Duration.zero
                              : MovimientoPrevia.rapido,
                          curve: MovimientoPrevia.curva,
                          height: 4,
                          decoration: BoxDecoration(
                            color: i < nivel.segmentos
                                ? color
                                : c.superficieActiva,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: EspaciadoPrevia.s - 2),
                Text(
                  frase,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: nivel.index >= NivelContrasena.media.index
                        ? c.texto
                        : c.textoSuave,
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
