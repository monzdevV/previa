import 'package:flutter/material.dart';

import '../../app/tema.dart';

/// Entrada escalonada de las pantallas de acceso: fundido y unos pocos puntos
/// hacia arriba, con la curva de la casa.
///
/// Un solo controlador por elemento con su tramo (`Interval`) en lugar de un
/// retraso con temporizador: al salir de la pantalla no queda nada pendiente
/// (tampoco en las pruebas). Quien ha pedido menos movimiento ve el contenido
/// ya colocado.
///
/// La idea viene de la version de GitHub, pero con los tiempos de
/// `MovimientoPrevia`: alli el primer elemento tardaba 420 ms y aqui ninguna
/// entrada pasa de 300.
class Aparece extends StatefulWidget {
  const Aparece({super.key, this.orden = 0, required this.child});

  /// Posicion en la secuencia; cada paso suma un escalon de retraso.
  final int orden;
  final Widget child;

  @override
  State<Aparece> createState() => _ApareceState();
}

class _ApareceState extends State<Aparece> with SingleTickerProviderStateMixin {
  /// Lo que dura cada elemento en entrar, sin contar su retraso.
  static const _entrada = Duration(milliseconds: 240);

  /// Un poco mas que el escalon de las listas: aqui son tres o cuatro piezas
  /// grandes y se tiene que leer el orden.
  static const _escalon = Duration(milliseconds: 50);

  late final AnimationController _control;
  late final Animation<double> _curva;

  @override
  void initState() {
    super.initState();
    final retraso = _escalon * widget.orden.clamp(0, 6);
    final total = retraso + _entrada;
    _control = AnimationController(vsync: this, duration: total);
    _curva = CurvedAnimation(
      parent: _control,
      curve: Interval(
        retraso.inMicroseconds / total.inMicroseconds,
        1,
        curve: MovimientoPrevia.curva,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MovimientoPrevia.reducido(context)) {
      _control.value = 1;
    } else if (!_control.isCompleted && !_control.isAnimating) {
      _control.forward();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curva,
    child: widget.child,
    builder: (_, hijo) => Opacity(
      opacity: _curva.value,
      // Sin esto, mientras entra con opacidad cero el lector de pantalla
      // tampoco lo encuentra.
      alwaysIncludeSemantics: true,
      child: Transform.translate(
        offset: Offset(0, (1 - _curva.value) * 16),
        child: hijo,
      ),
    ),
  );
}
