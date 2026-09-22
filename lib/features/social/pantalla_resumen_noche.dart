import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/tema.dart';
import '../../data/models/noche.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../profile/proveedores_perfil.dart';

/// La tarjeta del final de la noche.
///
/// Es el momento en el que la aplicacion te devuelve algo: has salido, y esto
/// resume lo que dio de si. Se comparte como imagen porque compartirla es lo
/// que hace que otros pregunten que aplicacion es.
class PantallaResumenNoche extends ConsumerStatefulWidget {
  const PantallaResumenNoche({super.key, required this.noche});

  final DateTime noche;

  @override
  ConsumerState<PantallaResumenNoche> createState() =>
      _PantallaResumenNocheState();
}

class _PantallaResumenNocheState extends ConsumerState<PantallaResumenNoche> {
  final _lienzo = GlobalKey();
  bool _compartiendo = false;

  /// Captura la tarjeta tal cual se ve y la comparte como PNG.
  ///
  /// Se pinta a 3x para que no salga borrosa al verla en el movil de otro.
  Future<void> _compartir() async {
    setState(() => _compartiendo = true);
    try {
      final limite =
          _lienzo.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final imagen = await limite.toImage(pixelRatio: 3);
      final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
      if (datos == null) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              datos.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'previa-noche.png',
            ),
          ],
          text: 'Mi noche en Previa',
        ),
      );
    } finally {
      if (mounted) setState(() => _compartiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumen = ref.watch(resumenProvider(widget.noche));
    final racha = ref.watch(rachaProvider);
    final perfil = ref.watch(miPerfilProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tu noche')),
      body: resumen.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colores.primarioTexto),
        ),
        error: (e, _) => const Center(
          child: Text('No se ha podido cargar la noche.'),
        ),
        data: (r) => ListView(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          children: [
            RepaintBoundary(
              key: _lienzo,
              child: TarjetaDeNoche(
                resumen: r,
                racha: racha.valueOrNull,
                nombre: perfil.valueOrNull?.nombre,
              ),
            ),

            const SizedBox(height: EspaciadoPrevia.l),

            if (r.hayAlgo)
              FilledButton.icon(
                onPressed: _compartiendo ? null : _compartir,
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                label: Text(
                  _compartiendo ? 'Preparando…' : 'Compartir la noche',
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(EspaciadoPrevia.m),
                child: Text(
                  'Esa noche no quedó registrada. Di que vas a un sitio o '
                  'sube una foto y aparecerá aquí.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// La tarjeta en si. Se usa tal cual para la captura, asi que no puede
/// depender de nada que no se vea: ni scroll, ni estados de carga.
class TarjetaDeNoche extends StatelessWidget {
  const TarjetaDeNoche({
    super.key,
    required this.resumen,
    this.racha,
    this.nombre,
  });

  final ResumenDeNoche resumen;
  final Racha? racha;
  final String? nombre;

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat("EEEE d 'de' MMMM", 'es_ES').format(resumen.noche);
    final titulo = '${fecha[0].toUpperCase()}${fecha.substring(1)}';

    return Container(
      padding: const EdgeInsets.all(EspaciadoPrevia.l),
      decoration: BoxDecoration(
        color: context.colores.fondoProfundo,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
        border: Border.all(color: context.colores.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: context.colores.degradado,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 17,
                  color: context.colores.sobrePrimario,
                ),
              ),
              const SizedBox(width: EspaciadoPrevia.s),
              const Text(
                'Previa',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (nombre != null)
                Text(
                  nombre!,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colores.textoTenue,
                  ),
                ),
            ],
          ),

          const SizedBox(height: EspaciadoPrevia.l),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colores.textoTenue,
            ),
          ),
          const SizedBox(height: EspaciadoPrevia.xs),

          if (resumen.sitios.isEmpty)
            const Text(
              'Noche suelta',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            )
          else
            Text(
              resumen.sitios.join(' · '),
              style: const TextStyle(
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),

          const SizedBox(height: EspaciadoPrevia.l),
          Row(
            children: [
              if (resumen.conQuien > 0)
                _Cifra(
                  valor: '${resumen.conQuien}',
                  etiqueta: resumen.conQuien == 1 ? 'persona' : 'personas',
                ),
              if (resumen.fotos > 0)
                _Cifra(
                  valor: '${resumen.fotos}',
                  etiqueta: resumen.fotos == 1 ? 'foto' : 'fotos',
                ),
              if (resumen.duracion != null)
                _Cifra(valor: resumen.duracion!, etiqueta: 'en pie'),
              if (resumen.previas > 0)
                _Cifra(
                  valor: '${resumen.previas}',
                  etiqueta: resumen.previas == 1 ? 'previa' : 'previas',
                ),
            ],
          ),

          if (racha != null && racha!.viva) ...[
            const SizedBox(height: EspaciadoPrevia.l),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: EspaciadoPrevia.m,
                vertical: EspaciadoPrevia.s + EspaciadoPrevia.xs,
              ),
              decoration: BoxDecoration(
                gradient: context.colores.degradado,
                borderRadius: BorderRadius.circular(EspaciadoPrevia.radio - 4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 20,
                    color: context.colores.sobrePrimario,
                  ),
                  const SizedBox(width: EspaciadoPrevia.s),
                  Text(
                    racha!.semanas == 1
                        ? '1 finde seguido'
                        : '${racha!.semanas} findes seguidos',
                    style: TextStyle(
                      color: context.colores.sobrePrimario,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: EspaciadoPrevia.l),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valor,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: context.colores.primarioTexto,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: 12,
            color: context.colores.textoTenue,
          ),
        ),
      ],
    ),
  );
}

/// La racha, para la cabecera del perfil.
class InsigniaDeRacha extends ConsumerWidget {
  const InsigniaDeRacha({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final racha = ref.watch(rachaProvider).valueOrNull;
    if (racha == null || !racha.viva) return const SizedBox.shrink();

    // En riesgo se pinta apagada: es lo que empuja a salir el finde, que es
    // justo el efecto que tiene una racha.
    final enRiesgo = racha.enRiesgo;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: EspaciadoPrevia.s + EspaciadoPrevia.xs,
        vertical: EspaciadoPrevia.xs + 2,
      ),
      decoration: BoxDecoration(
        gradient: enRiesgo ? null : context.colores.degradado,
        color: enRiesgo ? context.colores.superficieAlta : null,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_rounded,
            size: 16,
            color: enRiesgo
                ? context.colores.textoTenue
                : context.colores.sobrePrimario,
          ),
          const SizedBox(width: EspaciadoPrevia.xs),
          Text(
            racha.semanas == 1
                ? '1 finde'
                : '${racha.semanas} findes',
            style: TextStyle(
              color: enRiesgo
                  ? context.colores.textoSuave
                  : context.colores.sobrePrimario,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bytes de la tarjeta, por si mas adelante se quiere subir al feed en lugar
/// de compartirla fuera.
Future<Uint8List?> capturarTarjeta(GlobalKey clave) async {
  final limite = clave.currentContext?.findRenderObject();
  if (limite is! RenderRepaintBoundary) return null;
  final imagen = await limite.toImage(pixelRatio: 3);
  final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
  return datos?.buffer.asUint8List();
}
