import 'package:flutter/material.dart';

import '../../app/tema.dart';

/// Piezas que comparten el registro y la entrada, para que las dos pantallas
/// se sientan la misma puerta y no dos formularios hechos por separado.

/// El boton de accion de las pantallas de acceso: grande, abajo y al alcance
/// del pulgar.
///
/// Encoge al apretar como el resto de la app (`Pulsable`), pero aqui no se
/// puede usar `Pulsable` tal cual: su `GestureDetector` se quedaria el toque
/// y el `FilledButton` perderia el foco de teclado y la semantica de boton.
/// Por eso solo se escucha el puntero y el toque lo sigue gestionando Material.
class BotonAcceso extends StatefulWidget {
  const BotonAcceso({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
    this.fondo,
    this.tinta,
  });

  final String texto;

  /// Nulo mientras el paso no sea valido: el boton se ve apagado y el color
  /// se enciende solo cuando ya se puede seguir, que es la pista de que
  /// falta algo sin tener que gritar un error antes de tiempo.
  final VoidCallback? onPressed;
  final bool cargando;
  final Color? fondo;
  final Color? tinta;

  @override
  State<BotonAcceso> createState() => _BotonAccesoState();
}

class _BotonAccesoState extends State<BotonAcceso> {
  bool _apretado = false;

  void _apretar(bool valor) {
    if (widget.onPressed == null || widget.cargando) return;
    if (_apretado != valor) setState(() => _apretado = valor);
  }

  @override
  Widget build(BuildContext context) {
    final tinta = widget.tinta ?? context.colores.sobrePrimario;
    return Listener(
      onPointerDown: (_) => _apretar(true),
      onPointerUp: (_) => _apretar(false),
      onPointerCancel: (_) => _apretar(false),
      child: AnimatedScale(
        scale: _apretado && !MovimientoPrevia.reducido(context) ? 0.97 : 1,
        duration: MovimientoPrevia.rapido,
        curve: MovimientoPrevia.curva,
        child: FilledButton(
          // Mientras carga no se desactiva del todo: el boton apagado haria
          // parpadear el color justo cuando la persona esta mirando.
          onPressed: widget.cargando ? () {} : widget.onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: widget.fondo,
            foregroundColor: widget.tinta,
            textStyle: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontSize: 17),
          ),
          child: AnimatedSwitcher(
            duration: MovimientoPrevia.rapido,
            child: widget.cargando
                ? SizedBox.square(
                    key: const ValueKey('cargando'),
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: tinta,
                      semanticsLabel: 'Un momento',
                    ),
                  )
                : Text(widget.texto.toUpperCase(), key: ValueKey(widget.texto)),
          ),
        ),
      ),
    );
  }
}

/// La flecha de volver de las pantallas de acceso, sin barra de titulo: el
/// titular grande de cada paso ya dice donde estas.
class VolverAcceso extends StatelessWidget {
  const VolverAcceso({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: 'Volver',
    // 48 de lado: el objetivo minimo para un pulgar.
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    icon: const Icon(Icons.arrow_back_rounded),
  );
}

/// Un error dicho en una frase y pegado a lo que lo ha causado.
class AvisoError extends StatelessWidget {
  const AvisoError(this.mensaje, {super.key});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: EspaciadoPrevia.m,
          vertical: EspaciadoPrevia.s + EspaciadoPrevia.xs,
        ),
        decoration: BoxDecoration(
          color: c.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: c.error, size: 20),
            const SizedBox(width: EspaciadoPrevia.s),
            Expanded(
              child: Text(
                mensaje,
                style: TextStyle(color: c.error, fontSize: 14, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abre un documento legal sin pasar por el enrutador.
///
/// `/condiciones` y `/privacidad` estan detras del guardia de sesion, pero el
/// consentimiento se pide justo antes de tenerla: hay que poder leer lo que
/// se acepta. Una ruta sin nombre encima de la pila no pasa por `redirect`.
void abrirDocumentoLegal(BuildContext context, Widget documento) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => documento));
}
