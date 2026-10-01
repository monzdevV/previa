import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/previa.dart';
import '../../data/repositories/repositorio_previas.dart';
import 'piezas_solicitudes.dart';

final misSolicitudesProvider = FutureProvider<List<Solicitud>>(
  (ref) => ref.watch(repositorioPreviasProvider).misSolicitudes(),
);

/// Las plazas que he pedido y en qué han quedado.
class PantallaMisSolicitudes extends ConsumerStatefulWidget {
  const PantallaMisSolicitudes({super.key});

  @override
  ConsumerState<PantallaMisSolicitudes> createState() =>
      _PantallaMisSolicitudesState();
}

class _PantallaMisSolicitudesState
    extends ConsumerState<PantallaMisSolicitudes> {
  /// Solicitudes canceladas a falta de confirmar: se ocultan al instante y
  /// solo se cancelan de verdad cuando el aviso se cierra sin pulsar
  /// "Deshacer". Mientras no se llama al servidor, cancelar tiene vuelta
  /// atrás; una vez llamado, la previa podría llenarse y ya no la habría.
  final Set<String> _ocultas = {};

  void _cancelarConDeshacer(Solicitud s) {
    final mensajero = ScaffoldMessenger.of(context);
    // Se capturan ahora: el aviso sobrevive a esta pantalla y al cerrarse ya
    // no se podría usar `ref` si la pantalla se ha destruido.
    final repo = ref.read(repositorioPreviasProvider);
    final contenedor = ProviderScope.containerOf(context, listen: false);
    setState(() => _ocultas.add(s.id));

    mensajero.hideCurrentSnackBar();
    mensajero
        .showSnackBar(
          SnackBar(
            content: Text('Solicitud a «${s.tituloPrevia}» cancelada.'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () {
                if (mounted) setState(() => _ocultas.remove(s.id));
              },
            ),
          ),
        )
        .closed
        .then((motivo) async {
          if (motivo == SnackBarClosedReason.action) return;
          try {
            await repo.cancelarSolicitud(s.id);
            contenedor.invalidate(misSolicitudesProvider);
          } catch (_) {
            // Si falla hay que decirlo: si no, uno cree haber cancelado y la
            // solicitud sigue viva. Se repone en la lista.
            if (mounted) setState(() => _ocultas.remove(s.id));
            mensajero.showSnackBar(
              const SnackBar(
                content: Text('No se ha podido cancelar. Inténtalo otra vez.'),
              ),
            );
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final solicitudes = ref.watch(misSolicitudesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis solicitudes')),
      body: solicitudes.when(
        loading: () => const Cargando(),
        error: (e, _) => Semantics(
          liveRegion: true,
          child: EstadoVacio(
            icono: Icons.cloud_off_rounded,
            titulo: 'Sin conexión',
            detalle:
                'No hemos podido traer tus solicitudes. '
                'Comprueba tu conexión.',
            accion: 'Reintentar',
            onAccion: () => ref.invalidate(misSolicitudesProvider),
          ),
        ),
        data: (todas) {
          final lista = todas.where((s) => !_ocultas.contains(s.id)).toList();
          if (lista.isEmpty) {
            return const EstadoVacio(
              pegatina: '🙋',
              titulo: 'Todavía no has pedido plaza',
              detalle:
                  'Busca una previa en la pestaña Mapa y pide sitio para '
                  'tu grupo.',
            );
          }

          return RefreshIndicator(
            color: context.colores.primarioTexto,
            backgroundColor: context.colores.superficie,
            onRefresh: () async {
              ref.invalidate(misSolicitudesProvider);
              try {
                await ref.read(misSolicitudesProvider.future);
              } catch (_) {
                // El fallo ya lo pinta el estado de error de la pantalla.
              }
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(EspaciadoPrevia.l),
              itemCount: lista.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: EspaciadoPrevia.s),
              itemBuilder: (_, i) => EntradaLista(
                key: ValueKey(lista[i].id),
                indice: i,
                child: _Tarjeta(
                  solicitud: lista[i],
                  onCancelar: () => _cancelarConDeshacer(lista[i]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.solicitud, required this.onCancelar});

  final Solicitud solicitud;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final empieza = solicitud.empiezaPrevia;

    final (etiqueta, color, explicacion) = switch (solicitud.estado) {
      EstadoSolicitud.pendiente => (
        'Pendiente',
        c.aviso,
        'Esperando a que el anfitrión responda.',
      ),
      EstadoSolicitud.aceptada => (
        'Aceptada',
        c.acento,
        'Estás dentro. Ya puedes ver la dirección y el chat.',
      ),
      EstadoSolicitud.rechazada => (
        'Rechazada',
        c.textoSuave,
        'Esta vez no ha podido ser.',
      ),
      EstadoSolicitud.cancelada => (
        'Cancelada',
        c.textoSuave,
        'La cancelaste tú.',
      ),
    };

    return Card(
      child: InkWell(
        onTap: () => context.push('${Rutas.previa}/${solicitud.previaId}'),
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        child: Padding(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      solicitud.tituloPrevia,
                      style: textos.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: EspaciadoPrevia.s),
                  PastillaEstado(texto: etiqueta, color: color),
                ],
              ),

              const SizedBox(height: EspaciadoPrevia.s),
              // Iconos y no emojis: un lector de pantalla leería "chincheta
              // roja", "reloj" y "personas" en medio de la frase.
              Wrap(
                spacing: EspaciadoPrevia.m,
                runSpacing: EspaciadoPrevia.xs,
                children: [
                  if (solicitud.zonaPrevia != null)
                    _Dato(Icons.place_outlined, solicitud.zonaPrevia!),
                  if (empieza != null)
                    _Dato(
                      Icons.schedule,
                      DateFormat('d MMM · HH:mm', 'es_ES').format(empieza),
                    ),
                  _Dato(
                    Icons.group_outlined,
                    '${solicitud.tamanoGrupo}',
                    leer: solicitud.tamanoGrupo == 1
                        ? 'Grupo de 1 persona'
                        : 'Grupo de ${solicitud.tamanoGrupo} personas',
                  ),
                ],
              ),

              const SizedBox(height: EspaciadoPrevia.s),
              Text(
                explicacion,
                style: textos.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: c.textoSuave,
                ),
              ),

              if (solicitud.estaPendiente) ...[
                const SizedBox(height: EspaciadoPrevia.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onCancelar,
                    style: TextButton.styleFrom(
                      foregroundColor: c.error,
                      minimumSize: const Size(0, 48),
                    ),
                    child: Text(
                      'Cancelar solicitud',
                      semanticsLabel:
                          'Cancelar la solicitud a ${solicitud.tituloPrevia}',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dato breve con icono (zona, hora, tamaño del grupo).
class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.texto, {this.leer});

  final IconData icono;
  final String texto;

  /// Frase alternativa para el lector cuando el texto solo ("3") no basta.
  final String? leer;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(icono, size: 15, color: context.colores.textoSuave),
        ),
        const SizedBox(width: EspaciadoPrevia.xs),
        Flexible(
          child: Text(
            texto,
            semanticsLabel: leer,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
