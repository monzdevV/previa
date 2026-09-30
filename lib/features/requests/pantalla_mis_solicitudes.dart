import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/previa.dart';
import '../../data/repositories/repositorio_previas.dart';
import '../party/estados_pantalla.dart';

final misSolicitudesProvider = FutureProvider<List<Solicitud>>(
  (ref) => ref.watch(repositorioPreviasProvider).misSolicitudes(),
);

/// Las plazas que he pedido y en qué han quedado.
class PantallaMisSolicitudes extends ConsumerWidget {
  const PantallaMisSolicitudes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudes = ref.watch(misSolicitudesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis solicitudes')),
      body: solicitudes.when(
        loading: () => const IndicadorCarga(),
        error: (e, _) => EstadoError(
          mensaje: 'No se han podido cargar tus solicitudes',
          detalle: 'Comprueba tu conexión e inténtalo otra vez.',
          onReintentar: () => ref.invalidate(misSolicitudesProvider),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return EstadoVacio(
              icono: Icons.waving_hand_outlined,
              titulo: 'Todavía no has pedido plaza',
              detalle: 'Busca una previa en el mapa y pide sitio para tu grupo.',
              acciones: [
                FilledButton.icon(
                  // La pantalla se abre con push desde el perfil: go a la raíz
                  // lleva al mapa, que es donde se encuentra una previa.
                  onPressed: () => context.go(Rutas.inicio),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Buscar previas en el mapa'),
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(misSolicitudesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(EspaciadoPrevia.l),
              itemCount: lista.length,
              separatorBuilder: (_, _) => const SizedBox(height: EspaciadoPrevia.s),
              itemBuilder: (_, i) => _Tarjeta(solicitud: lista[i]),
            ),
          );
        },
      ),
    );
  }
}

class _Tarjeta extends ConsumerWidget {
  const _Tarjeta({required this.solicitud});

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final empieza = solicitud.empiezaPrevia;

    final (etiqueta, color, explicacion) = switch (solicitud.estado) {
      EstadoSolicitud.pendiente => (
          'Pendiente',
          ColoresPrevia.aviso,
          'Esperando a que el anfitrión responda.',
        ),
      EstadoSolicitud.aceptada => (
          'Aceptada',
          ColoresPrevia.acento,
          'Estás dentro. Ya puedes ver la dirección y el chat.',
        ),
      EstadoSolicitud.rechazada => (
          'Rechazada',
          ColoresPrevia.textoTenue,
          'Esta vez no ha podido ser.',
        ),
      EstadoSolicitud.cancelada => (
          'Cancelada',
          ColoresPrevia.textoTenue,
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
                    child: Text(solicitud.tituloPrevia,
                        style: textos.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: EspaciadoPrevia.s),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: EspaciadoPrevia.s,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(EspaciadoPrevia.radioGrande),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      etiqueta,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: EspaciadoPrevia.xs),
              // Iconos en lugar de emojis: un lector de pantalla leería
              // "chincheta roja", "reloj", "personas" en medio de la frase.
              Wrap(
                spacing: EspaciadoPrevia.m,
                runSpacing: EspaciadoPrevia.xs,
                children: [
                  if (solicitud.zonaPrevia != null)
                    _Dato(Icons.place_outlined, solicitud.zonaPrevia!),
                  if (empieza != null)
                    _Dato(
                      Icons.schedule,
                      DateFormat("d MMM · HH:mm", "es_ES").format(empieza),
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
              Text(explicacion,
                  style: textos.bodyMedium?.copyWith(fontSize: 12, color: color)),

              if (solicitud.estaPendiente) ...[
                const SizedBox(height: EspaciadoPrevia.s),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      final mensajero = ScaffoldMessenger.of(context);
                      try {
                        await ref
                            .read(repositorioPreviasProvider)
                            .cancelarSolicitud(solicitud.id);
                      } catch (_) {
                        // Antes una excepción aquí no se veía: el usuario
                        // creía haber cancelado y la solicitud seguía viva.
                        mensajero.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No se ha podido cancelar. Inténtalo de nuevo.',
                            ),
                          ),
                        );
                        return;
                      }
                      ref.invalidate(misSolicitudesProvider);
                    },
                    child: const Text('Cancelar solicitud'),
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
          child: Icon(icono, size: 14, color: ColoresPrevia.textoSuave),
        ),
        const SizedBox(width: EspaciadoPrevia.xs),
        Flexible(
          child: Text(
            texto,
            semanticsLabel: leer,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
