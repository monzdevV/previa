import 'package:flutter/material.dart';

import '../../app/tema.dart';

/// Esqueleto de carga de la lista de previas (shimmer hecho a mano).
///
/// Por que un esqueleto y no un spinner: muestra la FORMA de lo que va a
/// llegar, asi la hoja no "salta" al cargar y la espera se percibe mas corta.
/// Sin paquetes: un unico AnimationController desliza un degradado sobre
/// todos los bloques a la vez (ShaderMask), que es barato.
///
/// Accesibilidad: los bloques no dicen nada, asi que todo el esqueleto se
/// anuncia como "Cargando" (igual que [IndicadorCarga]). Con "reducir
/// movimiento" del sistema el brillo se queda quieto.
class EsqueletoPrevias extends StatefulWidget {
  const EsqueletoPrevias({super.key, this.controlador, this.tarjetas = 3});

  /// Controlador de la hoja deslizable: sin el, arrastrar sobre el esqueleto
  /// no mueve la hoja.
  final ScrollController? controlador;
  final int tarjetas;

  @override
  State<EsqueletoPrevias> createState() => _EsqueletoPreviasState();
}

class _EsqueletoPreviasState extends State<EsqueletoPrevias>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reloj = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con movimiento reducido no se repite: ademas evita animaciones
    // infinitas que impedirian a los tests de widget "asentarse".
    if (MediaQuery.disableAnimationsOf(context)) {
      _reloj.stop();
    } else if (!_reloj.isAnimating) {
      _reloj.repeat();
    }
  }

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      liveRegion: true,
      container: true,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _reloj,
        builder: (context, hijo) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final t = _reloj.value * 2 - 0.5; // recorre de -0.5 a 1.5
            return LinearGradient(
              begin: Alignment(-1 + t * 2, -0.3),
              end: Alignment(t * 2, 0.3),
              colors: const [
                Color(0x00FFFFFF),
                Color(0x26FFFFFF),
                Color(0x00FFFFFF),
              ],
            ).createShader(rect);
          },
          child: hijo,
        ),
        child: ListView(
          controller: widget.controlador,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            EspaciadoPrevia.m,
            EspaciadoPrevia.s,
            EspaciadoPrevia.m,
            EspaciadoPrevia.xl,
          ),
          children: [
            for (var i = 0; i < widget.tarjetas; i++) ...[
              if (i > 0) const SizedBox(height: EspaciadoPrevia.s),
              const _TarjetaEsqueleto(),
            ],
          ],
        ),
      ),
    );
  }
}

class _TarjetaEsqueleto extends StatelessWidget {
  const _TarjetaEsqueleto();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EspaciadoPrevia.m),
      decoration: BoxDecoration(
        color: ColoresPrevia.superficie,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        border: Border.all(color: ColoresPrevia.borde),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _Bloque(alto: 18, ancho: double.infinity)),
              SizedBox(width: EspaciadoPrevia.l),
              _Bloque(alto: 24, ancho: 64, radio: 12),
            ],
          ),
          SizedBox(height: EspaciadoPrevia.m),
          Row(
            children: [
              _Bloque(alto: 12, ancho: 70),
              SizedBox(width: EspaciadoPrevia.m),
              _Bloque(alto: 12, ancho: 90),
              SizedBox(width: EspaciadoPrevia.m),
              _Bloque(alto: 12, ancho: 50),
            ],
          ),
          SizedBox(height: EspaciadoPrevia.m),
          Row(
            children: [
              _Bloque(alto: 24, ancho: 24, radio: 12),
              SizedBox(width: EspaciadoPrevia.s),
              _Bloque(alto: 12, ancho: 100),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.alto, required this.ancho, this.radio = 6});

  final double alto;
  final double ancho;
  final double radio;

  @override
  Widget build(BuildContext context) => Container(
    height: alto,
    width: ancho,
    decoration: BoxDecoration(
      color: ColoresPrevia.superficieAlta,
      borderRadius: BorderRadius.circular(radio),
    ),
  );
}
