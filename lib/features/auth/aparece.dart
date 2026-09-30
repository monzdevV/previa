import 'package:flutter/material.dart';

/// Entrada escalonada y sutil: fundido + desplazamiento de unos pocos puntos.
///
/// Cada elemento usa un único controlador con un tramo (Interval) propio en
/// lugar de un Timer con retraso: así no quedan temporizadores pendientes
/// al salir de la pantalla (ni en los tests) y el coste es mínimo. Con
/// "reducir animaciones" del sistema el contenido aparece ya colocado.
class Aparece extends StatefulWidget {
  const Aparece({super.key, this.orden = 0, required this.child});

  /// Posición en la secuencia; cada paso añade ~80 ms de retraso.
  final int orden;
  final Widget child;

  @override
  State<Aparece> createState() => _ApareceState();
}

class _ApareceState extends State<Aparece> with SingleTickerProviderStateMixin {
  static const _pasoMs = 80;
  static const _baseMs = 420;

  late final AnimationController _controlador;
  late final Animation<double> _curva;

  @override
  void initState() {
    super.initState();
    final total = _baseMs + widget.orden * _pasoMs;
    _controlador = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    _curva = CurvedAnimation(
      parent: _controlador,
      curve: Interval(
        widget.orden * _pasoMs / total,
        1,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controlador.value = 1;
    } else if (!_controlador.isCompleted && !_controlador.isAnimating) {
      _controlador.forward();
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curva,
      child: widget.child,
      builder: (_, hijo) => Opacity(
        opacity: _curva.value,
        // Sin esto, con opacidad 0 el contenido desaparece también para los
        // lectores de pantalla durante la entrada.
        alwaysIncludeSemantics: true,
        child: Transform.translate(
          offset: Offset(0, (1 - _curva.value) * 14),
          child: hijo,
        ),
      ),
    );
  }
}
