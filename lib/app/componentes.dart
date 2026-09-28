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

/// Lo que se enseña cuando no hay nada: vacío, error o sin conexión.
///
/// Un solo componente para toda la app porque los huecos son justo donde
/// una app se nota hecha a trozos: cada pantalla inventaba su texto gris
/// centrado. Este lleva una pegatina, un titular y, si hay algo que hacer,
/// el botón que lo hace. Un vacío sin salida es un callejón.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.titulo,
    this.detalle,
    this.pegatina,
    this.icono,
    this.accion,
    this.onAccion,
    this.compacto = false,
  });

  final String titulo;
  final String? detalle;

  /// Emoji de ilustración. Si no hay, se usa [icono].
  final String? pegatina;
  final IconData? icono;
  final String? accion;
  final VoidCallback? onAccion;

  /// Dentro de una sección de otra pantalla, en lugar de ocuparla entera.
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          compacto ? EspaciadoPrevia.m : EspaciadoPrevia.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pegatina != null)
              Pegatina(pegatina!, tamano: compacto ? 40 : 56, giro: -0.12)
            else if (icono != null)
              Icon(
                icono,
                size: compacto ? 32 : 44,
                color: context.colores.textoTenue,
              ),
            SizedBox(height: compacto ? EspaciadoPrevia.s : EspaciadoPrevia.m),
            Titular(
              titulo,
              tamano: compacto ? 20 : 26,
              alineacion: TextAlign.center,
            ),
            if (detalle != null) ...[
              const SizedBox(height: EspaciadoPrevia.s),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  detalle!,
                  textAlign: TextAlign.center,
                  style: textos.bodyMedium,
                ),
              ),
            ],
            if (accion != null && onAccion != null) ...[
              SizedBox(
                height: compacto ? EspaciadoPrevia.m : EspaciadoPrevia.l,
              ),
              FilledButton(
                onPressed: onAccion,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                child: Text(accion!.toUpperCase()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// La ruleta de carga de la casa, para cuando no se sabe la forma de lo que
/// llega. Si se sabe, mejor un esqueleto.
class Cargando extends StatelessWidget {
  const Cargando({super.key, this.relleno = EspaciadoPrevia.xl});

  final double relleno;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(relleno),
      child: SizedBox.square(
        dimension: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2.6,
          color: context.colores.primarioTexto,
        ),
      ),
    ),
  );
}
