import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../domain/racha/regla_de_racha.dart';
import 'proveedores_perfil.dart';

const _tinta = BloquesPrevia.tintaSobreBloque;

/// La racha de fiestas en el perfil: llama, semanas seguidas y cuánto falta
/// para el siguiente hito.
///
/// Es una de las dos cosas que hacen volver a la app (la otra es el
/// calendario), así que va arriba del todo y en un bloque de color plano, no
/// en una insignia pequeña. El degradado se evita a propósito: DESIGN.md lo
/// reserva a la marca y nunca va detrás de texto.
///
/// Esta clase se encarga solo de leer la racha y de celebrar los hitos;
/// lo que se ve está en [TarjetaRachaVista], que se prueba sin proveedores.
class TarjetaRacha extends ConsumerStatefulWidget {
  const TarjetaRacha({super.key});

  @override
  ConsumerState<TarjetaRacha> createState() => _TarjetaRachaState();
}

class _TarjetaRachaState extends ConsumerState<TarjetaRacha> {
  /// Para no abrir dos veces el mismo mensaje si la tarjeta se reconstruye
  /// mientras el primero sigue en pantalla.
  bool _celebrando = false;

  Future<void> _celebrarSiToca(Racha racha) async {
    if (_celebrando) return;
    final uid = ref.read(uidActualProvider);
    if (uid == null) return;

    final almacen = AlmacenDeHitos(uid);
    var celebrado = await almacen.leer();
    final actual = racha.hitoAlcanzado ?? 0;
    // Racha rota: se olvida lo celebrado para que, al rehacerla, el 3 vuelva
    // a ser una fiesta. Sin esto quien pierde la racha nunca más vería un
    // mensaje en los hitos que ya pasó.
    if (actual < celebrado) {
      celebrado = 0;
      await almacen.guardar(0);
    }
    final hito = hitoPorCelebrar(racha, celebrado: celebrado);
    if (hito == null || !mounted) return;

    _celebrando = true;
    // Se guarda antes de enseñar el mensaje: si la app se cierra con él
    // abierto, no debe repetirse la próxima vez.
    await almacen.guardar(hito);
    if (!mounted) return;
    await mostrarCelebracionDeHito(context, hito: hito);
    _celebrando = false;
  }

  @override
  Widget build(BuildContext context) {
    final racha = ref.watch(rachaProvider).valueOrNull;
    if (racha == null) {
      // Mientras carga se reserva el sitio con el mismo alto, para que el
      // calendario de debajo no dé un salto cuando llegue el dato.
      return const SizedBox(height: _altoTarjeta);
    }

    // Tras pintar y no durante: abrir un diálogo en medio de build lanza.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _celebrarSiToca(racha);
    });
    return TarjetaRachaVista(racha: racha);
  }
}

const _altoTarjeta = 148.0;

/// Lo que se ve de la tarjeta, sin proveedores ni almacenamiento.
class TarjetaRachaVista extends StatelessWidget {
  const TarjetaRachaVista({super.key, required this.racha});

  final Racha racha;

  String get _subtitulo {
    if (!racha.viva) {
      return racha.mejor > 0
          ? 'Tu récord es de ${racha.mejor}. Sal esta semana y empieza otra.'
          : 'Sal esta semana y empieza tu racha.';
    }
    if (racha.saliEstaSemana) return 'Esta semana ya cuenta. Sigue así.';
    return racha.comodinGastado
        ? 'Sal esta semana o la pierdes.'
        : 'Sal antes del domingo y sigue creciendo.';
  }

  String get _textoDeHito {
    final hito = racha.siguienteHito;
    if (hito == null) return 'Has pasado el último hito. Leyenda.';
    final falta = racha.semanasParaHito;
    return falta == 1
        ? 'Falta 1 semana para el hito de $hito'
        : 'Faltan $falta semanas para el hito de $hito';
  }

  @override
  Widget build(BuildContext context) {
    final reducido = MovimientoPrevia.reducido(context);
    final semanas = racha.semanas;

    return Semantics(
      container: true,
      label:
          'Racha de fiestas: '
          '${semanas == 1 ? '1 semana seguida' : '$semanas semanas seguidas'}. '
          '$_subtitulo $_textoDeHito.',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: _altoTarjeta),
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          decoration: BoxDecoration(
            color: BloquesPrevia.amarillo,
            borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Llama(viva: racha.viva, reducido: reducido),
                  const SizedBox(width: EspaciadoPrevia.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Titular('$semanas', tamano: 44, color: _tinta),
                            const SizedBox(width: EspaciadoPrevia.s),
                            Flexible(
                              child: Titular(
                                semanas == 1 ? 'semana' : 'semanas',
                                tamano: 20,
                                color: _tinta,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitulo,
                          style: const TextStyle(
                            color: _tinta,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: EspaciadoPrevia.m),
              _BarraDeHito(progreso: racha.progreso, reducido: reducido),
              const SizedBox(height: EspaciadoPrevia.s),
              Text(
                _textoDeHito,
                style: const TextStyle(
                  color: _tinta,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La llama. Late despacio si la racha está viva; con "reducir movimiento"
/// o sin racha se queda quieta (y apagada, si no hay nada que mantener).
class _Llama extends StatelessWidget {
  const _Llama({required this.viva, required this.reducido});

  final bool viva;
  final bool reducido;

  @override
  Widget build(BuildContext context) {
    final llama = Opacity(
      opacity: viva ? 1 : 0.4,
      child: const Pegatina('🔥', tamano: 52, giro: -0.1),
    );
    if (!viva || reducido) return llama;
    return llama
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.08, 1.08),
          duration: MovimientoPrevia.lento + const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
  }
}

class _BarraDeHito extends StatelessWidget {
  const _BarraDeHito({required this.progreso, required this.reducido});

  final double progreso;
  final bool reducido;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
    child: Container(
      height: 10,
      color: _tinta.withValues(alpha: 0.18),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progreso),
        duration: reducido ? Duration.zero : MovimientoPrevia.lento,
        curve: MovimientoPrevia.curva,
        builder: (_, valor, _) => FractionallySizedBox(
          widthFactor: valor,
          heightFactor: 1,
          child: Container(
            decoration: BoxDecoration(
              color: _tinta,
              borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Qué hito se celebró por última vez en este móvil, por cuenta.
///
/// Vive en el teléfono y no en la base porque es un detalle de la pantalla,
/// no un dato de la persona: lo peor que pasa si se pierde es repetir una
/// felicitación, y eso no justifica una columna ni una migración.
class AlmacenDeHitos {
  AlmacenDeHitos(String uid) : _clave = 'racha_hito_celebrado_$uid';

  final String _clave;

  Future<int> leer() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getInt(_clave) ?? 0;
    } catch (_) {
      // Sin almacenamiento, mejor no felicitar que felicitar en cada visita.
      return 1 << 30;
    }
  }

  Future<void> guardar(int hito) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_clave, hito);
    } catch (_) {}
  }
}

/// El mensaje al alcanzar un hito.
///
/// Un diálogo y no una notificación: solo sale cuando abres el perfil, que es
/// justo cuando quieres verlo. La animación es un rebote de la llama; con
/// "reducir movimiento" aparece ya puesta.
Future<void> mostrarCelebracionDeHito(
  BuildContext context, {
  required int hito,
}) {
  final reducido = MovimientoPrevia.reducido(context);
  final siguiente = hitosDeRacha.where((h) => h > hito).firstOrNull;

  Widget llama = const Pegatina('🔥', tamano: 84, giro: -0.1);
  if (!reducido) {
    llama = llama.animate().scale(
      begin: const Offset(0.3, 0.3),
      end: const Offset(1, 1),
      duration: MovimientoPrevia.lento,
      curve: Curves.elasticOut,
    );
  }

  return showDialog<void>(
    context: context,
    builder: (contexto) => Dialog(
      backgroundColor: BloquesPrevia.amarillo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
      ),
      child: Padding(
        padding: const EdgeInsets.all(EspaciadoPrevia.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            llama,
            const SizedBox(height: EspaciadoPrevia.m),
            Titular(
              '$hito semanas seguidas',
              tamano: 30,
              color: _tinta,
              alineacion: TextAlign.center,
            ),
            const SizedBox(height: EspaciadoPrevia.s),
            Text(
              siguiente == null
                  ? 'Has llegado al último hito. Eres leyenda.'
                  : 'Racha de fiestas en marcha. Siguiente parada: '
                        '$siguiente semanas.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _tinta,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: EspaciadoPrevia.l),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _tinta,
                  foregroundColor: BloquesPrevia.amarillo,
                ),
                onPressed: () => Navigator.of(contexto).pop(),
                child: const Text('¡Vamos!'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
