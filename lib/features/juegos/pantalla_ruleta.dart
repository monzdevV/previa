import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/tema.dart';
import 'motor/ruleta.dart';

const _coloresSegmento = [
  Color(0xFFE2524B),
  Color(0xFFE8A13A),
  Color(0xFF3FA08A),
  Color(0xFF8E5BD6),
  Color(0xFF3F7FD6),
  Color(0xFFD64F7F),
];

/// Ruleta de jugadores: gira, para en alguien y le toca una sentencia.
class PantallaRuleta extends StatefulWidget {
  const PantallaRuleta({
    super.key,
    required this.jugadores,
    this.sinAlcohol = false,
    this.duracion = const Duration(seconds: 4),
  });

  final List<String> jugadores;
  final bool sinAlcohol;
  final Duration duracion;

  @override
  State<PantallaRuleta> createState() => _PantallaRuletaState();
}

class _PantallaRuletaState extends State<PantallaRuleta>
    with SingleTickerProviderStateMixin {
  final _azar = Random();
  late final AnimationController _anim;
  double _giroBase = 0;
  double _giroObjetivo = 0;
  int? _ganador;
  AccionRuleta? _accion;
  bool _girando = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: widget.duracion)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _terminar();
      });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  double get _giroActual =>
      _giroBase +
      (_giroObjetivo - _giroBase) * Curves.easeOutCubic.transform(_anim.value);

  void _girar() {
    if (_girando) return;
    HapticFeedback.mediumImpact();
    final n = widget.jugadores.length;
    final ganador = _azar.nextInt(n);
    // Se parte de donde quedó la rueda y se le suman vueltas completas: el
    // giro nunca va hacia atrás aunque se gire muchas veces seguidas.
    final base = _giroObjetivo;
    final extra = giroHasta(
      segmentos: n,
      ganador: ganador,
      vueltas: 5 + _azar.nextInt(3),
      dentro: _azar.nextDouble(),
    );
    final vuelta = 2 * pi;
    // `extra` ya incluye la posición final dentro de una vuelta; hay que
    // sumarlo a un múltiplo de vuelta para que sea relativo a la posición
    // actual y no un giro absoluto.
    final baseAlineada = (base / vuelta).ceil() * vuelta;
    setState(() {
      _giroBase = base;
      _giroObjetivo = baseAlineada + extra;
      _ganador = null;
      _accion = null;
      _girando = true;
    });
    _anim.forward(from: 0);
  }

  void _terminar() {
    final n = widget.jugadores.length;
    final ganador = segmentoBajoPuntero(_giroObjetivo, n);
    HapticFeedback.heavyImpact();
    setState(() {
      _girando = false;
      _ganador = ganador;
      _accion = accionesRuleta[_azar.nextInt(accionesRuleta.length)];
    });
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('La ruleta')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ExcludeSemantics(
                      child: AnimatedBuilder(
                        animation: _anim,
                        builder: (_, _) => CustomPaint(
                          painter: _PintorRueda(
                            nombres: widget.jugadores,
                            giro: _giroActual,
                            borde: context.colores.borde,
                            texto: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: EspaciadoPrevia.m),
              Semantics(
                liveRegion: true,
                container: true,
                child: SizedBox(
                  height: 120,
                  child: _ganador == null
                      ? Center(
                          child: Text(
                            _girando
                                ? 'Girando...'
                                : 'Pulsa girar y que decida el azar.',
                            style: texto.bodyMedium,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Titular(
                              'Le toca a ${widget.jugadores[_ganador!]}',
                              tamano: 26,
                            ),
                            const SizedBox(height: EspaciadoPrevia.s),
                            Text(
                              _accion!.texto(sinAlcohol: widget.sinAlcohol),
                              textAlign: TextAlign.center,
                              style: texto.titleMedium,
                            ),
                          ],
                        ),
                ),
              ),
              FilledButton(
                onPressed: _girando ? null : _girar,
                child: Text(_ganador == null ? 'Girar' : 'Girar otra vez'),
              ),
              const SizedBox(height: EspaciadoPrevia.s),
              Text(
                'Nadie está obligado a beber ni a hacer nada.',
                style: texto.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PintorRueda extends CustomPainter {
  _PintorRueda({
    required this.nombres,
    required this.giro,
    required this.borde,
    required this.texto,
  });

  final List<String> nombres;
  final double giro;
  final Color borde;
  final Color texto;

  @override
  void paint(Canvas canvas, Size s) {
    final centro = s.center(Offset.zero);
    final r = min(s.width, s.height) / 2 - 14;
    final n = nombres.length;
    final seg = 2 * pi / n;

    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    canvas.rotate(giro);
    for (var i = 0; i < n; i++) {
      final ini = -pi / 2 + i * seg;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r),
        ini,
        seg,
        true,
        Paint()..color = _coloresSegmento[i % _coloresSegmento.length],
      );
      // El nombre va a lo largo del radio, centrado en su segmento.
      canvas.save();
      canvas.rotate(ini + seg / 2);
      final tp = TextPainter(
        text: TextSpan(
          text: nombres[i],
          style: TextStyle(
            color: texto,
            fontSize: n > 8 ? 14 : 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r * 0.6);
      tp.paint(canvas, Offset(r * 0.32, -tp.height / 2));
      canvas.restore();
    }
    canvas.restore();

    canvas.drawCircle(
      centro,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = borde,
    );
    canvas.drawCircle(centro, 14, Paint()..color = borde);
    // Puntero fijo arriba: marca el segmento ganador.
    final flecha = Path()
      ..moveTo(centro.dx - 14, centro.dy - r - 12)
      ..lineTo(centro.dx + 14, centro.dy - r - 12)
      ..lineTo(centro.dx, centro.dy - r + 18)
      ..close();
    canvas.drawPath(flecha, Paint()..color = Colors.white);
    canvas.drawPath(
      flecha,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black54,
    );
  }

  @override
  bool shouldRepaint(_PintorRueda old) =>
      old.giro != giro || old.nombres != nombres;
}
