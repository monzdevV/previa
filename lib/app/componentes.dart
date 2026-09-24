import 'package:flutter/material.dart';

import 'tema.dart';

/// Un titular en la letra gorda y siempre en mayusculas.
///
/// Las mayusculas se ponen aqui y no escritas a mano en cada texto: asi el
/// contenido sigue en minusculas normales (lo que se busca, se traduce o se
/// lee un lector de pantalla) y solo cambia como se ve.
class Titular extends StatelessWidget {
  const Titular(
    this.texto, {
    super.key,
    this.tamano = 36,
    this.color,
    this.alineacion,
    this.lineas,
  });

  final String texto;
  final double tamano;
  final Color? color;
  final TextAlign? alineacion;
  final int? lineas;

  @override
  Widget build(BuildContext context) => Text(
    texto.toUpperCase(),
    textAlign: alineacion,
    maxLines: lineas,
    overflow: lineas == null ? null : TextOverflow.ellipsis,
    semanticsLabel: texto,
    style: TextStyle(
      fontFamily: LetraPrevia.titular,
      fontSize: tamano,
      height: 0.95,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.03 * tamano,
      color: color ?? context.colores.texto,
    ),
  );
}

/// Una cinta de texto que corre sin parar, como las de los carteles de
/// discoteca. Se usa para rotular una seccion, nunca para contar algo que
/// haya que leer entero: el texto se repite y se sale de la pantalla.
class Marquesina extends StatefulWidget {
  const Marquesina({
    super.key,
    required this.texto,
    this.fondo,
    this.tinta,
    this.alto = 40,
    this.segundosPorVuelta = 14,
    this.inclinacion = 0,
  });

  final String texto;
  final Color? fondo;
  final Color? tinta;
  final double alto;
  final int segundosPorVuelta;

  /// Radianes. Una cinta un poco torcida parece pegada encima.
  final double inclinacion;

  @override
  State<Marquesina> createState() => _MarquesinaState();
}

class _MarquesinaState extends State<Marquesina>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.segundosPorVuelta),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quien ha pedido menos movimiento ve la cinta quieta.
    if (MovimientoPrevia.reducido(context)) {
      _control.stop();
    } else if (!_control.isAnimating) {
      _control.repeat();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tinta = widget.tinta ?? context.colores.sobrePrimario;
    final estilo = TextStyle(
      fontFamily: LetraPrevia.titular,
      fontSize: widget.alto * 0.5,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.5,
      color: tinta,
      height: 1,
    );
    final tramo = '${widget.texto.toUpperCase()}  ✦  ';
    final medida = TextPainter(
      text: TextSpan(text: tramo, style: estilo),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final ancho = medida.width;

    return Transform.rotate(
      angle: widget.inclinacion,
      child: Container(
        height: widget.alto,
        color: widget.fondo ?? context.colores.primario,
        child: ClipRect(
          child: LayoutBuilder(
            builder: (_, limites) {
              final copias = (limites.maxWidth / ancho).ceil() + 2;
              return AnimatedBuilder(
                animation: _control,
                builder: (_, hijo) => Transform.translate(
                  offset: Offset(-ancho * _control.value, 0),
                  child: hijo,
                ),
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: double.infinity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < copias; i++)
                        Text(tramo, style: estilo, maxLines: 1),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Un emoji grande y torcido, como una pegatina. Hace de ilustracion sin
/// tener que dibujar nada: el juego ya se llama "No hay 🥚".
class Pegatina extends StatelessWidget {
  const Pegatina(this.emoji, {super.key, this.tamano = 48, this.giro = 0});

  final String emoji;
  final double tamano;
  final double giro;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Transform.rotate(
      angle: giro,
      child: Text(emoji, style: TextStyle(fontSize: tamano, height: 1)),
    ),
  );
}
