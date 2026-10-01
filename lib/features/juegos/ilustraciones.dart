import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'modelo_juegos.dart';

/// Colores de cada juego: degradado de fondo de su tarjeta. Oscuros a
/// propósito (noche, poca luz) y sin texto encima, así no hay problema de
/// contraste: el texto va en la zona de superficie de la tarjeta.
List<Color> coloresJuego(TipoJuego j) => switch (j) {
  TipoJuego.noHayHuevos => const [Color(0xFFE2524B), Color(0xFF7A1F3D)],
  TipoJuego.yoNunca => const [Color(0xFF3FA08A), Color(0xFF1B3F5C)],
  TipoJuego.masProbable => const [Color(0xFFE8A13A), Color(0xFF8A3A2A)],
  TipoJuego.verdadOReto => const [Color(0xFF8E5BD6), Color(0xFF3B1E6B)],
};

/// Ilustración de cada juego dibujada con CustomPainter (la app no lleva
/// assets). Es decorativa: se excluye del árbol de semántica.
class IlustracionJuego extends StatelessWidget {
  const IlustracionJuego({super.key, required this.juego});

  final TipoJuego juego;

  @override
  Widget build(BuildContext context) {
    final CustomPainter pintor = switch (juego) {
      TipoJuego.noHayHuevos => _PintorHuevos(coloresJuego(juego)),
      TipoJuego.yoNunca => _PintorVasos(coloresJuego(juego)),
      TipoJuego.masProbable => _PintorSenalar(coloresJuego(juego)),
      TipoJuego.verdadOReto => _PintorCartas(coloresJuego(juego)),
    };
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(painter: pintor, size: Size.infinite),
      ),
    );
  }
}

void _fondo(Canvas c, Size s, List<Color> cols) {
  c.drawRect(
    Offset.zero & s,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: cols,
      ).createShader(Offset.zero & s),
  );
  // Destello suave para que no sea un degradado plano.
  c.drawCircle(
    Offset(s.width * 0.85, s.height * 0.1),
    s.height * 0.7,
    Paint()
      ..shader =
          RadialGradient(
            colors: [Colors.white.withValues(alpha: 0.18), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(s.width * 0.85, s.height * 0.1),
              radius: s.height * 0.7,
            ),
          ),
  );
}

class _PintorHuevos extends CustomPainter {
  _PintorHuevos(this.cols);
  final List<Color> cols;

  void _huevo(Canvas c, Offset centro, double alto, {bool roto = false}) {
    final r = Rect.fromCenter(center: centro, width: alto * 0.74, height: alto);
    final p = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.4),
        colors: [Color(0xFFFFF4DC), Color(0xFFF1C98B)],
      ).createShader(r);
    c.drawOval(r, p);
    if (roto) {
      final g = Path()
        ..moveTo(r.left + r.width * 0.05, centro.dy - alto * 0.05)
        ..lineTo(r.left + r.width * 0.3, centro.dy + alto * 0.08)
        ..lineTo(r.left + r.width * 0.5, centro.dy - alto * 0.1)
        ..lineTo(r.left + r.width * 0.72, centro.dy + alto * 0.06)
        ..lineTo(r.right - r.width * 0.05, centro.dy - alto * 0.06);
      c.drawPath(
        g,
        Paint()
          ..color = cols.last
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size s) {
    _fondo(canvas, s, cols);
    final h = s.height;
    _huevo(canvas, Offset(s.width * 0.3, h * 0.6), h * 0.62);
    _huevo(canvas, Offset(s.width * 0.5, h * 0.48), h * 0.8, roto: true);
    _huevo(canvas, Offset(s.width * 0.7, h * 0.62), h * 0.58);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _PintorVasos extends CustomPainter {
  _PintorVasos(this.cols);
  final List<Color> cols;

  void _vaso(Canvas c, Offset base, double alto, Color liquido) {
    final a = alto * 0.42;
    final cuerpo = Path()
      ..moveTo(base.dx - a, base.dy - alto)
      ..lineTo(base.dx + a, base.dy - alto)
      ..lineTo(base.dx + a * 0.75, base.dy)
      ..lineTo(base.dx - a * 0.75, base.dy)
      ..close();
    c.drawPath(cuerpo, Paint()..color = Colors.white.withValues(alpha: 0.22));
    final nivel = Path()
      ..moveTo(base.dx - a * 0.92, base.dy - alto * 0.6)
      ..lineTo(base.dx + a * 0.92, base.dy - alto * 0.6)
      ..lineTo(base.dx + a * 0.75, base.dy)
      ..lineTo(base.dx - a * 0.75, base.dy)
      ..close();
    c.drawPath(nivel, Paint()..color = liquido);
    c.drawPath(
      cuerpo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  @override
  void paint(Canvas canvas, Size s) {
    _fondo(canvas, s, cols);
    final h = s.height;
    _vaso(
      canvas,
      Offset(s.width * 0.34, h * 0.88),
      h * 0.6,
      const Color(0xFFFFC94D),
    );
    _vaso(
      canvas,
      Offset(s.width * 0.56, h * 0.88),
      h * 0.72,
      const Color(0xFFFF8A9B),
    );
    _vaso(
      canvas,
      Offset(s.width * 0.76, h * 0.88),
      h * 0.5,
      const Color(0xFF7FE3C0),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _PintorSenalar extends CustomPainter {
  _PintorSenalar(this.cols);
  final List<Color> cols;

  @override
  void paint(Canvas canvas, Size s) {
    _fondo(canvas, s, cols);
    final centro = Offset(s.width * 0.5, s.height * 0.5);
    final radio = s.height * 0.36;
    const n = 5;
    final pincel = Paint();
    for (var i = 0; i < n; i++) {
      final ang = -math.pi / 2 + i * 2 * math.pi / n;
      final p = centro + Offset(math.cos(ang), math.sin(ang)) * radio * 1.15;
      // Cabeza y hombros de cada "persona" del corro.
      pincel.color = Colors.white.withValues(alpha: 0.9);
      canvas.drawCircle(p - Offset(0, radio * 0.16), radio * 0.2, pincel);
      canvas.drawArc(
        Rect.fromCenter(
          center: p + Offset(0, radio * 0.25),
          width: radio * 0.6,
          height: radio * 0.5,
        ),
        math.pi,
        math.pi,
        true,
        pincel,
      );
      // Línea de "señalar" hacia el elegido (la persona 0).
      if (i != 0) {
        final destino =
            centro +
            Offset(math.cos(-math.pi / 2), math.sin(-math.pi / 2)) *
                radio *
                1.15;
        canvas.drawLine(
          p,
          Offset.lerp(p, destino, 0.55)!,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.45)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _PintorCartas extends CustomPainter {
  _PintorCartas(this.cols);
  final List<Color> cols;

  void _carta(
    Canvas c,
    Offset centro,
    Size t,
    double ang,
    String signo,
    Color col,
  ) {
    c.save();
    c.translate(centro.dx, centro.dy);
    c.rotate(ang);
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: t.width, height: t.height),
      const Radius.circular(12),
    );
    c.drawRRect(r, Paint()..color = const Color(0xFFF6F0EA));
    final tp = TextPainter(
      text: TextSpan(
        text: signo,
        style: TextStyle(
          color: col,
          fontSize: t.height * 0.6,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size s) {
    _fondo(canvas, s, cols);
    final t = Size(s.height * 0.55, s.height * 0.78);
    _carta(
      canvas,
      Offset(s.width * 0.42, s.height * 0.52),
      t,
      -0.25,
      '?',
      const Color(0xFF3B1E6B),
    );
    _carta(
      canvas,
      Offset(s.width * 0.6, s.height * 0.5),
      t,
      0.22,
      '!',
      const Color(0xFFB8324B),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
