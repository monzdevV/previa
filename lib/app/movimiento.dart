import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colores.dart';

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
  static const normal = Duration(milliseconds: 280);
  static const lento = Duration(milliseconds: 700);

  /// Cambio de pantalla. Por debajo de 300 ms: a partir de ahi navegar se
  /// siente como esperar. La vuelta es mas corta que la ida, porque quien
  /// vuelve ya sabe a donde va.
  static const pagina = Duration(milliseconds: 280);
  static const paginaVuelta = Duration(milliseconds: 220);

  /// Cuanto encoge lo que se pulsa. Sutil: 0,97 se nota en el dedo sin que
  /// el boton parezca que se hunde.
  static const escalaPulsado = 0.97;

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
    this.escala = MovimientoPrevia.escalaPulsado,
    this.vibrar = true,
    this.formaFoco = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double escala;
  final bool vibrar;

  /// La forma del anillo de foco (teclado, mando, lector de pantalla con
  /// teclado): circulo en los botones redondos, pastilla en las pastillas.
  final OutlinedBorder formaFoco;

  @override
  State<Pulsable> createState() => _PulsableState();
}

class _PulsableState extends State<Pulsable> {
  bool _apretado = false;
  bool _foco = false;

  void _apretar(bool valor) {
    if (widget.onTap == null || _apretado == valor) return;
    setState(() => _apretado = valor);
  }

  void _pulsar() {
    if (widget.vibrar) HapticFeedback.selectionClick();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final activo = widget.onTap != null;
    // Sin teclado esto no pinta nada: el anillo solo aparece cuando el foco
    // llega por teclado, nunca al tocar.
    return FocusableActionDetector(
      enabled: activo,
      onShowFocusHighlight: (valor) => setState(() => _foco = valor),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (activo) _pulsar();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _apretar(true),
        onTapUp: (_) => _apretar(false),
        onTapCancel: () => _apretar(false),
        onTap: activo ? _pulsar : null,
        child: AnimatedScale(
          scale: _apretado && !MovimientoPrevia.reducido(context)
              ? widget.escala
              : 1,
          duration: MovimientoPrevia.rapido,
          curve: MovimientoPrevia.curva,
          child: _foco
              ? DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: ShapeDecoration(
                    shape: widget.formaFoco.copyWith(
                      side: BorderSide(color: context.colores.texto, width: 3),
                    ),
                  ),
                  child: widget.child,
                )
              : widget.child,
        ),
      ),
    );
  }
}

/// Transicion entre pantallas de toda la app.
///
/// Fundido con una subida corta (4 % del alto), con la curva de la casa:
/// arranca rapido y se posa. La pantalla que queda debajo se atenua un
/// poco para dar profundidad. La vuelta usa la curva invertida, para que
/// tambien la salida empiece rapida (nada de arranques lentos).
///
/// En iOS y macOS se deja la transicion del sistema: el gesto de deslizar
/// desde el borde para volver es lo que la gente espera alli. Con "reducir
/// movimiento" no hay animacion en ninguna plataforma.
///
/// Va en el `pageTransitionsTheme`, asi que vale igual para las rutas de
/// go_router que para un `Navigator.push` con `MaterialPageRoute`.
class TransicionPrevia extends PageTransitionsBuilder {
  const TransicionPrevia();

  static const _sistemaIos = CupertinoPageTransitionsBuilder();

  @override
  Duration get transitionDuration => MovimientoPrevia.pagina;

  @override
  Duration get reverseTransitionDuration => MovimientoPrevia.paginaVuelta;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MovimientoPrevia.reducido(context)) return child;

    final plataforma = Theme.of(context).platform;
    if (plataforma == TargetPlatform.iOS ||
        plataforma == TargetPlatform.macOS) {
      return _sistemaIos.buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }

    final entrada = CurvedAnimation(
      parent: animation,
      curve: MovimientoPrevia.curva,
      reverseCurve: MovimientoPrevia.curva.flipped,
    );
    final debajo = Tween<double>(begin: 1, end: 0.85).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: MovimientoPrevia.curva,
        reverseCurve: MovimientoPrevia.curva.flipped,
      ),
    );
    return FadeTransition(
      opacity: debajo,
      child: FadeTransition(
        opacity: entrada,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(entrada),
          child: child,
        ),
      ),
    );
  }
}
