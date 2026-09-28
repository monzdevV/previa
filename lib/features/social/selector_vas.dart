import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/tema.dart';
import '../../data/models/local.dart';

/// La pregunta de la noche, hecha boton.
///
/// Un toque es "voy": es la respuesta de nueve de cada diez veces y no debe
/// costar mas que eso. Los matices (quiza, mas tarde, ya estoy) estan a un
/// toque largo, o a un toque si ya habias contestado, porque entonces lo que
/// quieres es cambiar la respuesta, no repetirla.
///
/// Va encima de bloques de color que cambian de un local a otro, asi que no
/// usa ningun color de marca: tinta si no has dicho nada, blanco si si.
class SelectorVas extends StatefulWidget {
  const SelectorVas({
    super.key,
    required this.estado,
    required this.nombreLocal,
    required this.onElegir,
    this.fondo = BloquesPrevia.amarillo,
  });

  final EstadoNoche? estado;
  final String nombreLocal;
  final ValueChanged<EstadoNoche?> onElegir;

  /// El color del bloque sobre el que va: el texto de la pastilla vacia se
  /// pinta de ese color para que parezca recortada del cartel.
  final Color fondo;

  @override
  State<SelectorVas> createState() => _SelectorVasState();
}

class _SelectorVasState extends State<SelectorVas> {
  /// Sube cada vez que te apuntas, para relanzar la pegatina que salta.
  int _estallidos = 0;

  void _elegir(EstadoNoche? nuevo) {
    if (nuevo == widget.estado) return;
    if (nuevo != null && nuevo.va) {
      HapticFeedback.mediumImpact();
      setState(() => _estallidos++);
    } else {
      HapticFeedback.selectionClick();
    }
    widget.onElegir(nuevo);
  }

  Future<void> _abrirOpciones() async {
    HapticFeedback.selectionClick();
    final eleccion = await mostrarOpcionesVas(
      context,
      nombreLocal: widget.nombreLocal,
      actual: widget.estado,
    );
    if (eleccion != null) _elegir(eleccion.estado);
  }

  @override
  Widget build(BuildContext context) {
    const tinta = BloquesPrevia.tintaSobreBloque;
    final estado = widget.estado;
    final reducido = MovimientoPrevia.reducido(context);

    final Widget pastilla = estado == null
        ? Container(
            key: const ValueKey('vacia'),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tinta,
              borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
            ),
            child: Titular('¿Vas?', tamano: 19, color: widget.fondo),
          )
        : Container(
            key: ValueKey(estado),
            height: 52,
            padding: const EdgeInsets.only(left: 14, right: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (estado == EstadoNoche.aqui)
                  const _PuntoEnDirecto()
                else
                  Text(estado.pegatina, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 7),
                Titular(estado.corta, tamano: 16, color: tinta),
                const SizedBox(width: 2),
                const Icon(Icons.expand_more_rounded, size: 20, color: tinta),
              ],
            ),
          );

    return Semantics(
      button: true,
      label: estado == null
          ? '¿Vas a ${widget.nombreLocal}? Toca para decir que vas'
          : '${estado.etiqueta} a ${widget.nombreLocal}. Toca para cambiarlo',
      excludeSemantics: true,
      child: Pulsable(
        onTap: estado == null ? () => _elegir(EstadoNoche.voy) : _abrirOpciones,
        vibrar: false,
        escala: 0.94,
        child: GestureDetector(
          onLongPress: _abrirOpciones,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedSize(
                duration: reducido ? Duration.zero : MovimientoPrevia.normal,
                curve: MovimientoPrevia.curva,
                child: AnimatedSwitcher(
                  duration: reducido ? Duration.zero : MovimientoPrevia.rapido,
                  switchInCurve: MovimientoPrevia.curva,
                  transitionBuilder: (hijo, animacion) => FadeTransition(
                    opacity: animacion,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.9, end: 1.0).animate(animacion),
                      child: hijo,
                    ),
                  ),
                  child: pastilla,
                ),
              ),
              // La pegatina que salta al apuntarte: el "hecho" que se ve sin
              // leer. Una por toque, y ninguna si se pidio menos movimiento.
              if (_estallidos > 0 && !reducido && estado != null)
                Positioned(
                  top: -8,
                  child: IgnorePointer(
                    child: Pegatina(estado.pegatina, tamano: 34, giro: -0.2)
                        .animate(key: ValueKey(_estallidos))
                        .scale(
                          begin: const Offset(0.5, 0.5),
                          end: const Offset(1.15, 1.15),
                          duration: 180.ms,
                          curve: Curves.easeOutBack,
                        )
                        .moveY(
                          begin: 0,
                          end: -38,
                          duration: 520.ms,
                          curve: MovimientoPrevia.curva,
                        )
                        .fadeOut(delay: 260.ms, duration: 260.ms),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un punto verde que late: "esta aqui ahora", como el en directo de una
/// retransmision. Quieto si se pidio menos movimiento.
class _PuntoEnDirecto extends StatelessWidget {
  const _PuntoEnDirecto();

  @override
  Widget build(BuildContext context) {
    final punto = Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Color(0xFF16B862),
        shape: BoxShape.circle,
      ),
    );
    if (MovimientoPrevia.reducido(context)) return punto;
    return SizedBox.square(
      dimension: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0x5516B862),
                  shape: BoxShape.circle,
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                duration: 1200.ms,
                curve: Curves.easeOut,
              )
              .fadeOut(duration: 1200.ms),
          punto,
        ],
      ),
    );
  }
}

/// Lo que se elige en la hoja. Envuelve el estado porque nulo ya significa
/// "no voy" y hace falta distinguirlo de cerrar la hoja sin elegir.
class EleccionVas {
  const EleccionVas(this.estado);
  final EstadoNoche? estado;
}

/// Las cuatro respuestas y "no voy", en grande y al alcance del pulgar.
Future<EleccionVas?> mostrarOpcionesVas(
  BuildContext context, {
  required String nombreLocal,
  required EstadoNoche? actual,
}) {
  return mostrarHoja<EleccionVas>(
    context,
    builder: (contexto) => Padding(
      padding: EdgeInsets.fromLTRB(
        EspaciadoPrevia.m,
        0,
        EspaciadoPrevia.m,
        EspaciadoPrevia.s + MediaQuery.paddingOf(contexto).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Titular('¿Vas a $nombreLocal?', tamano: 26, lineas: 2),
          const SizedBox(height: EspaciadoPrevia.m),
          for (final (i, e) in EstadoNoche.values.indexed) ...[
            _FilaOpcion(
                  estado: e,
                  elegida: e == actual,
                  onTap: () => Navigator.of(contexto).pop(EleccionVas(e)),
                )
                .animate(delay: MovimientoPrevia.retrasoDe(i))
                .fadeIn(duration: MovimientoPrevia.rapido)
                .moveY(begin: 8, end: 0, curve: MovimientoPrevia.curva),
            const SizedBox(height: EspaciadoPrevia.s),
          ],
          if (actual != null)
            TextButton(
              onPressed: () =>
                  Navigator.of(contexto).pop(const EleccionVas(null)),
              style: TextButton.styleFrom(
                foregroundColor: contexto.colores.textoSuave,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Al final no voy'),
            ),
        ],
      ),
    ),
  );
}

class _FilaOpcion extends StatelessWidget {
  const _FilaOpcion({
    required this.estado,
    required this.elegida,
    required this.onTap,
  });

  final EstadoNoche estado;
  final bool elegida;
  final VoidCallback onTap;

  String get _detalle => switch (estado) {
    EstadoNoche.aqui => 'Ya estás dentro. Quien mire la lista lo sabrá.',
    EstadoNoche.voy => 'Cuentas para la noche y entras en la sala.',
    EstadoNoche.tarde => 'Vas, pero llegas después de la previa.',
    EstadoNoche.quiza => 'Sin compromiso. No cuenta como salida.',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Semantics(
      button: true,
      selected: elegida,
      child: Pulsable(
        onTap: onTap,
        escala: 0.98,
        child: AnimatedContainer(
          duration: MovimientoPrevia.rapido,
          padding: const EdgeInsets.symmetric(
            horizontal: EspaciadoPrevia.m,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: elegida ? c.primario : c.superficieAlta,
            borderRadius: BorderRadius.circular(EspaciadoPrevia.radio + 4),
          ),
          child: Row(
            children: [
              Text(estado.pegatina, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: EspaciadoPrevia.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Titular(
                      estado.etiqueta,
                      tamano: 18,
                      color: elegida ? c.sobrePrimario : c.texto,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _detalle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: elegida
                            ? c.sobrePrimario.withValues(alpha: 0.75)
                            : c.textoSuave,
                      ),
                    ),
                  ],
                ),
              ),
              if (elegida)
                Icon(Icons.check_circle_rounded, color: c.sobrePrimario),
            ],
          ),
        ),
      ),
    );
  }
}
