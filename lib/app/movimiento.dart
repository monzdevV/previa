import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Movimiento de Previa.
///
/// Una sola curva y tres duraciones para toda la aplicacion, igual que un
/// sistema de color tiene una paleta cerrada. Si cada pantalla elige su
/// curva, la app se nota hecha a trozos aunque nadie sepa decir por que.
/// Los valores salen de los otros proyectos del autor (ice-gym y
/// social-studio), que ya los probaron.
abstract final class MovimientoPrevia {
  /// Salida exponencial: arranca rapido y se posa despacio. Es lo que hace
  /// que algo parezca responder al dedo y no a un temporizador.
  static const curva = Cubic(0.22, 1, 0.36, 1);

  static const rapido = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 320);
  static const lento = Duration(milliseconds: 700);

  /// Retraso entre elementos de una lista que entra escalonada.
  static const escalon = Duration(milliseconds: 40);

  /// Solo los primeros elementos entran escalonados: si esperara tambien
  /// el vigesimo, hacer scroll se sentiria lento.
  static Duration retrasoDe(int indice) => escalon * indice.clamp(0, 6);

  /// Quien ha pedido menos movimiento en el sistema no lo recibe.
  static bool reducido(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}

/// Encoge un poco al pulsar, como un boton fisico.
///
/// Es la respuesta tactil que dan Instagram y TikTok a todo lo que se toca;
/// la onda de Material sobre una foto no la usa ninguna de las dos.
class Pulsable extends StatefulWidget {
  const Pulsable({
    super.key,
    required this.child,
    required this.onTap,
    this.escala = 0.96,
    this.vibrar = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double escala;
  final bool vibrar;

  @override
  State<Pulsable> createState() => _PulsableState();
}

class _PulsableState extends State<Pulsable> {
  bool _apretado = false;

  void _apretar(bool valor) {
    if (widget.onTap == null || _apretado == valor) return;
    setState(() => _apretado = valor);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => _apretar(true),
    onTapUp: (_) => _apretar(false),
    onTapCancel: () => _apretar(false),
    onTap: widget.onTap == null
        ? null
        : () {
            if (widget.vibrar) HapticFeedback.selectionClick();
            widget.onTap!();
          },
    child: AnimatedScale(
      scale: _apretado && !MovimientoPrevia.reducido(context)
          ? widget.escala
          : 1,
      duration: MovimientoPrevia.rapido,
      curve: MovimientoPrevia.curva,
      child: widget.child,
    ),
  );
}
