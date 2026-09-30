import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/tema.dart';

/// Composiciones graficas del onboarding y la bienvenida, dibujadas con
/// CustomPainter: sin assets externos no hay nada que pese, se desenfoque al
/// escalar ni licencia que revisar.
enum TipoIlustracion { previa, privacidad, seguridad, permiso }

/// Marco comun: fondo con halo, animacion suave en bucle y descripcion para
/// lectores de pantalla. Si el usuario pidio reducir animaciones, el bucle no
/// se ejecuta y se queda en un fotograma agradable.
class Ilustracion extends StatefulWidget {
  const Ilustracion({
    super.key,
    required this.tipo,
    required this.descripcion,
    this.altura = 240,
  });

  final TipoIlustracion tipo;
  final String descripcion;
  final double altura;

  @override
  State<Ilustracion> createState() => _IlustracionState();
}

class _IlustracionState extends State<Ilustracion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bucle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _bucle.stop();
      _bucle.value = 0.35;
    } else if (!_bucle.isAnimating) {
      _bucle.repeat();
    }
  }

  @override
  void dispose() {
    _bucle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.descripcion,
      child: ExcludeSemantics(
        child: SizedBox(
          height: widget.altura,
          width: double.infinity,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _bucle,
              builder: (_, _) => CustomPaint(
                painter: _Pintor(widget.tipo, _bucle.value),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pintor extends CustomPainter {
  _Pintor(this.tipo, this.t);

  final TipoIlustracion tipo;
  final double t;

  static const _degradado = [ColoresPrevia.primario, ColoresPrevia.acento];

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;

    // Halo de fondo compartido.
    canvas.drawCircle(
      centro,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            ColoresPrevia.primario.withValues(alpha: 0.28),
            ColoresPrevia.primario.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centro, radius: r)),
    );

    switch (tipo) {
      case TipoIlustracion.previa:
        _previa(canvas, centro, r);
      case TipoIlustracion.privacidad:
        _privacidad(canvas, centro, r);
      case TipoIlustracion.seguridad:
        _seguridad(canvas, centro, r);
      case TipoIlustracion.permiso:
        _permiso(canvas, centro, r);
    }
  }

  void _chincheta(Canvas canvas, Offset c, double tam) {
    final pintura = Paint()
      ..shader = const LinearGradient(colors: _degradado).createShader(
        Rect.fromCircle(center: c, radius: tam * 1.5),
      );
    final camino = Path()
      ..moveTo(c.dx, c.dy + tam * 1.5)
      ..cubicTo(c.dx - tam * 1.6, c.dy + tam * 0.2, c.dx - tam, c.dy - tam,
          c.dx, c.dy - tam)
      ..cubicTo(c.dx + tam, c.dy - tam, c.dx + tam * 1.6, c.dy + tam * 0.2,
          c.dx, c.dy + tam * 1.5)
      ..close();
    canvas.drawPath(camino, pintura);
    canvas.drawCircle(
      Offset(c.dx, c.dy - tam * 0.05),
      tam * 0.38,
      Paint()..color = ColoresPrevia.fondo,
    );
  }

  void _ondas(Canvas canvas, Offset c, double radioMax, Color color) {
    for (var i = 0; i < 3; i++) {
      final f = (t + i / 3) % 1;
      canvas.drawCircle(
        c,
        radioMax * (0.3 + 0.7 * f),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: (1 - f) * 0.6),
      );
    }
  }

  void _persona(Canvas canvas, Offset c, double s, Color color) {
    final p = Paint()..color = color;
    canvas.drawCircle(c.translate(0, -s * 0.9), s * 0.45, p);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(
            center: c.translate(0, s * 0.35), width: s * 1.5, height: s * 1.1),
        topLeft: Radius.circular(s * 0.75),
        topRight: Radius.circular(s * 0.75),
        bottomLeft: Radius.circular(s * 0.2),
        bottomRight: Radius.circular(s * 0.2),
      ),
      p,
    );
  }

  void _previa(Canvas canvas, Offset c, double r) {
    _ondas(canvas, c.translate(0, r * 0.25), r * 0.95,
        ColoresPrevia.primarioSuave);
    // Tres personas alrededor de la chincheta: "gente cerca de ti".
    final flota = math.sin(t * 2 * math.pi) * 3;
    _persona(canvas, c.translate(-r * 0.62, r * 0.35 + flota), r * 0.17,
        ColoresPrevia.superficieAlta);
    _persona(canvas, c.translate(r * 0.62, r * 0.35 - flota), r * 0.17,
        ColoresPrevia.superficieAlta);
    _persona(canvas, c.translate(0, r * 0.72), r * 0.2, ColoresPrevia.borde);
    _chincheta(canvas, c.translate(0, -r * 0.12 + flota), r * 0.36);
  }

  void _privacidad(Canvas canvas, Offset c, double r) {
    // Cuadricula tipo mapa.
    final calle = Paint()
      ..color = ColoresPrevia.borde
      ..strokeWidth = 2;
    for (var i = -2; i <= 2; i++) {
      canvas.drawLine(Offset(c.dx + i * r * 0.4, c.dy - r * 0.9),
          Offset(c.dx + i * r * 0.4 + r * 0.15, c.dy + r * 0.9), calle);
      canvas.drawLine(Offset(c.dx - r * 1.2, c.dy + i * r * 0.36),
          Offset(c.dx + r * 1.2, c.dy + i * r * 0.36 - r * 0.1), calle);
    }
    // Circulo aproximado: relleno + borde discontinuo que "respira".
    final rad = r * (0.55 + 0.04 * math.sin(t * 2 * math.pi));
    canvas.drawCircle(
      c,
      rad,
      Paint()..color = ColoresPrevia.primario.withValues(alpha: 0.25),
    );
    const trozos = 28;
    for (var i = 0; i < trozos; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: rad),
        i * 2 * math.pi / trozos,
        2 * math.pi / trozos,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = ColoresPrevia.primarioSuave,
      );
    }
    // Punto tenue en el centro: sugiere que el lugar exacto no se revela.
    canvas.drawCircle(c, 5, Paint()..color = ColoresPrevia.textoTenue);
  }

  void _seguridad(Canvas canvas, Offset c, double r) {
    final s = r * 0.85;
    final escudo = Path()
      ..moveTo(c.dx, c.dy - s)
      ..cubicTo(c.dx + s * 0.4, c.dy - s * 0.8, c.dx + s * 0.8,
          c.dy - s * 0.75, c.dx + s * 0.85, c.dy - s * 0.7)
      ..cubicTo(c.dx + s * 0.85, c.dy + s * 0.3, c.dx + s * 0.4,
          c.dy + s * 0.75, c.dx, c.dy + s)
      ..cubicTo(c.dx - s * 0.4, c.dy + s * 0.75, c.dx - s * 0.85,
          c.dy + s * 0.3, c.dx - s * 0.85, c.dy - s * 0.7)
      ..cubicTo(c.dx - s * 0.8, c.dy - s * 0.75, c.dx - s * 0.4,
          c.dy - s * 0.8, c.dx, c.dy - s)
      ..close();
    canvas.drawPath(
      escudo,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _degradado,
        ).createShader(Rect.fromCircle(center: c, radius: s)),
    );
    final texto = TextPainter(
      text: TextSpan(
        text: '+18',
        style: TextStyle(
          fontSize: s * 0.7,
          fontWeight: FontWeight.w800,
          color: ColoresPrevia.fondo,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    texto.paint(canvas, c - Offset(texto.width / 2, texto.height / 2));
    _ondas(canvas, c, r * 1.05, ColoresPrevia.acento);
  }

  void _permiso(Canvas canvas, Offset c, double r) {
    // Tarjeta de "permiso" con un pin y un circulo aproximado.
    final tarjeta = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: r * 1.7, height: r * 1.3),
      Radius.circular(r * 0.2),
    );
    canvas.drawRRect(tarjeta, Paint()..color = ColoresPrevia.superficieAlta);
    canvas.drawRRect(
      tarjeta,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ColoresPrevia.bordeCampo,
    );
    final centroMapa = c.translate(0, -r * 0.12);
    canvas.drawCircle(
      centroMapa,
      r * (0.4 + 0.03 * math.sin(t * 2 * math.pi)),
      Paint()..color = ColoresPrevia.acento.withValues(alpha: 0.22),
    );
    _chincheta(canvas, centroMapa.translate(0, -r * 0.05), r * 0.2);
    // Dos botones esquematicos, como en un dialogo de permisos.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - r * 0.75, c.dy + r * 0.38, r * 0.66, r * 0.16),
        Radius.circular(r * 0.08),
      ),
      Paint()..color = ColoresPrevia.borde,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx + r * 0.09, c.dy + r * 0.38, r * 0.66, r * 0.16),
        Radius.circular(r * 0.08),
      ),
      Paint()..color = ColoresPrevia.primario,
    );
  }

  @override
  bool shouldRepaint(_Pintor viejo) => viejo.t != t || viejo.tipo != tipo;
}
