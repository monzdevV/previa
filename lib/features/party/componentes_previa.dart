import 'package:flutter/material.dart';

import '../../app/tema.dart';

/// Cartel de una previa según su ambiente: un bloque de color plano y un
/// icono grande.
///
/// Las previas no llevan foto (es la casa de alguien y su portal no se
/// enseña), así que el ambiente es lo único que puede darle cara a la
/// tarjeta. Se resuelve con los mismos bloques de la pestaña Noche y no con
/// degradados: el degradado está reservado a la marca y la acción principal.
class EstiloAmbiente {
  const EstiloAmbiente(this.bloque, this.icono);

  final Color bloque;
  final IconData icono;
}

const _porDefecto = EstiloAmbiente(BloquesPrevia.amarillo, Icons.nightlife);

// Solo hay cinco bloques para diez ambientes: se reparten para que los que
// suelen ir juntos (techno y terraza, reggaeton y latino) no coincidan, y es
// el icono el que termina de distinguirlos.
const _estilos = <String, EstiloAmbiente>{
  'reggaeton': EstiloAmbiente(BloquesPrevia.rojo, Icons.speaker_group),
  'techno': EstiloAmbiente(BloquesPrevia.azul, Icons.graphic_eq),
  'tranqui': EstiloAmbiente(BloquesPrevia.menta, Icons.spa),
  'indie': EstiloAmbiente(BloquesPrevia.lila, Icons.headphones),
  'latino': EstiloAmbiente(BloquesPrevia.amarillo, Icons.music_note),
  'pop': EstiloAmbiente(BloquesPrevia.lila, Icons.star_rounded),
  'rock': EstiloAmbiente(BloquesPrevia.rojo, Icons.electric_bolt),
  'cachondeo': EstiloAmbiente(BloquesPrevia.amarillo, Icons.celebration),
  'cartas': EstiloAmbiente(BloquesPrevia.menta, Icons.style),
  'terraza': EstiloAmbiente(BloquesPrevia.azul, Icons.wb_twilight),
};

/// Estilo de la primera etiqueta conocida; si no hay, el amarillo de marca.
EstiloAmbiente estiloDeAmbiente(List<String> ambiente) {
  for (final a in ambiente) {
    final estilo = _estilos[a];
    if (estilo != null) return estilo;
  }
  return _porDefecto;
}

/// Etiqueta de Hero compartida por tarjeta y detalle. Centralizada para que
/// las dos pantallas no se desincronicen y la transición se rompa en silencio.
String tagCabeceraPrevia(String previaId) => 'cabecera-previa-$previaId';

/// El bloque de color del ambiente, sin texto.
///
/// Sin texto a propósito: así puede volar dentro de un [Hero] sin pedir un
/// `Material` por encima durante el vuelo. Lo que se escribe encima va fuera
/// del Hero, en la pantalla que lo usa. Es decorativo: el ambiente ya se lee
/// en las etiquetas.
class CabeceraAmbiente extends StatelessWidget {
  const CabeceraAmbiente({
    super.key,
    required this.ambiente,
    this.altura = 96,
    this.radio = const BorderRadius.vertical(
      top: Radius.circular(EspaciadoPrevia.radio),
    ),
  });

  final List<String> ambiente;
  final double altura;
  final BorderRadius radio;

  @override
  Widget build(BuildContext context) {
    final estilo = estiloDeAmbiente(ambiente);
    const tinta = BloquesPrevia.tintaSobreBloque;

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: radio,
        child: Container(
          height: altura,
          width: double.infinity,
          color: estilo.bloque,
          // El icono enorme y cortado por el borde hace de pegatina: se lee
          // como ilustración, no como un botón.
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                right: -altura * 0.12,
                bottom: -altura * 0.22,
                child: Transform.rotate(
                  angle: -0.18,
                  child: Icon(
                    estilo.icono,
                    size: altura * 0.95,
                    color: tinta.withValues(alpha: 0.16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastilla con icono y texto: plazas, hora, zona, distancia.
///
/// El texto es `Flexible` y puede pasar a varias líneas: con la letra del
/// sistema agrandada no desborda la fila.
class ChipDato extends StatelessWidget {
  const ChipDato({
    super.key,
    required this.icono,
    required this.texto,
    this.color,
    this.leer,
  });

  final IconData icono;
  final String texto;

  /// Color de acento (plazas libres). Sin él, tono neutro.
  final Color? color;

  /// Frase alternativa para el lector cuando el texto solo no basta.
  final String? leer;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final tinta = color ?? c.textoSuave;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: EspaciadoPrevia.s + EspaciadoPrevia.xs,
        vertical: EspaciadoPrevia.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color == null
            ? c.superficieAlta
            : color!.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
        border: color == null
            ? null
            : Border.all(color: color!.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icono, size: 15, color: tinta)),
          const SizedBox(width: EspaciadoPrevia.xs + 2),
          Flexible(
            child: Text(
              texto,
              semanticsLabel: leer,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color ?? c.texto,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de plazas: un segmento por plaza libre, hasta [maximo].
///
/// No se conoce el aforo total (solo las libres), así que la barra enseña
/// "cuánto sitio queda" y no un porcentaje. Es decorativa: el número ya va
/// escrito al lado.
class BarraPlazas extends StatelessWidget {
  const BarraPlazas({super.key, required this.libres, this.maximo = 10});

  final int libres;
  final int maximo;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final llenos = libres.clamp(0, maximo);
    final color = libres <= 0 ? c.textoTenue : c.disponible;
    final quieto = MovimientoPrevia.reducido(context);

    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < maximo; i++) ...[
            if (i > 0) const SizedBox(width: EspaciadoPrevia.xs),
            Expanded(
              child: AnimatedContainer(
                duration: quieto ? Duration.zero : MovimientoPrevia.rapido,
                curve: MovimientoPrevia.curva,
                height: 6,
                decoration: BoxDecoration(
                  color: i < llenos ? color : c.superficieActiva,
                  borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Entrada escalonada: aparece y sube 12 px, un escalón después que el
/// anterior.
///
/// Usa los mismos números que el resto de listas de la app
/// ([MovimientoPrevia.retrasoDe]): solo los seis primeros esperan, para que
/// desplazar no se sienta lento. Quien pide menos movimiento lo ve todo ya
/// colocado.
class EntradaEscalonada extends StatelessWidget {
  const EntradaEscalonada({
    super.key,
    required this.indice,
    required this.child,
  });

  final int indice;
  final Widget child;

  static const _subida = 12.0;
  static const _duracion = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    if (MovimientoPrevia.reducido(context)) return child;

    // El retraso se mete dentro de la propia duración con un Interval: así no
    // hacen falta temporizadores y la animación se puede asentar en pruebas.
    final retraso = MovimientoPrevia.retrasoDe(indice);
    final total = _duracion + retraso;
    final inicio = retraso.inMicroseconds / total.inMicroseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(inicio, 1, curve: MovimientoPrevia.curva),
      builder: (context, t, hijo) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * _subida),
          child: hijo,
        ),
      ),
      child: child,
    );
  }
}

/// Número que cambia delante del usuario (plazas, personas del grupo).
///
/// Entra desde un poco más pequeño y nunca desde cero: un número que nace de
/// un punto parece salir de la nada.
class CifraAnimada extends StatelessWidget {
  const CifraAnimada({
    super.key,
    required this.valor,
    required this.estilo,
    this.leer,
  });

  final int valor;
  final TextStyle? estilo;
  final String? leer;

  @override
  Widget build(BuildContext context) {
    final quieto = MovimientoPrevia.reducido(context);
    return AnimatedSwitcher(
      duration: quieto ? Duration.zero : MovimientoPrevia.rapido,
      switchInCurve: MovimientoPrevia.curva,
      switchOutCurve: MovimientoPrevia.curva,
      transitionBuilder: (hijo, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0).animate(anim),
          child: hijo,
        ),
      ),
      child: Text(
        '$valor',
        key: ValueKey(valor),
        semanticsLabel: leer,
        style: estilo?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Botón de - / + de 56 dp, para el pulgar.
class BotonPaso extends StatelessWidget {
  const BotonPaso({
    super.key,
    required this.icono,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icono;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return IconButton.filledTonal(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size(56, 56),
        backgroundColor: c.superficieAlta,
        foregroundColor: c.texto,
        disabledBackgroundColor: c.superficie,
        disabledForegroundColor: c.textoTenue,
      ),
      onPressed: onPressed,
      icon: Icon(icono),
    );
  }
}
