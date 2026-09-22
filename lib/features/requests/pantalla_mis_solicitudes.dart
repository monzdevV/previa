import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/previa.dart';
import '../../data/repositories/repositorio_previas.dart';

final misSolicitudesProvider = FutureProvider<List<Solicitud>>(
  (ref) => ref.watch(repositorioPreviasProvider).misSolicitudes(),
);

/// Las plazas que he pedido y en qué han quedado.
class PantallaMisSolicitudes extends ConsumerWidget {
  const PantallaMisSolicitudes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudes = ref.watch(misSolicitudesProvider);
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis solicitudes')),
      body: solicitudes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(EspaciadoPrevia.l),
            child: Text(
              'No se han podido cargar tus solicitudes.',
              style: textos.bodyMedium,
            ),
          ),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(EspaciadoPrevia.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 40,
                      color: context.colores.textoTenue,
                    ),
                    const SizedBox(height: EspaciadoPrevia.m),
                    Text(
                      'Todavía no has pedido plaza',
                      style: textos.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: EspaciadoPrevia.xs),
                    Text(
                      'Busca una previa en el mapa y pide sitio para tu grupo.',
                      textAlign: TextAlign.center,
                      style: textos.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(misSolicitudesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(EspaciadoPrevia.l),
              itemCount: lista.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: EspaciadoPrevia.s),
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
        context.colores.aviso,
        'Esperando a que el anfitrión responda.',
      ),
      EstadoSolicitud.aceptada => (
        'Aceptada',
        context.colores.acento,
        'Estás dentro. Ya puedes ver la dirección y el chat.',
      ),
      EstadoSolicitud.rechazada => (
        'Rechazada',
        context.colores.textoTenue,
        'Esta vez no ha podido ser.',
      ),
      EstadoSolicitud.cancelada => (
        'Cancelada',
        context.colores.textoTenue,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: EspaciadoPrevia.s,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        EspaciadoPrevia.radioGrande,
                      ),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      etiqueta,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: EspaciadoPrevia.xs),
              Wrap(
                spacing: EspaciadoPrevia.m,
                children: [
                  if (solicitud.zonaPrevia != null)
                    Text(
                      '📍 ${solicitud.zonaPrevia}',
                      style: textos.bodyMedium,
                    ),
                  if (empieza != null)
                    Text(
                      '🕐 ${DateFormat("d MMM · HH:mm", "es_ES").format(empieza)}',
                      style: textos.bodyMedium,
                    ),
                  Text('👥 ${solicitud.tamanoGrupo}', style: textos.bodyMedium),
                ],
              ),

              const SizedBox(height: EspaciadoPrevia.s),
              Text(
                explicacion,
                style: textos.bodyMedium?.copyWith(fontSize: 12, color: color),
              ),

              if (solicitud.estaPendiente) ...[
                const SizedBox(height: EspaciadoPrevia.s),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      await ref
                          .read(repositorioPreviasProvider)
                          .cancelarSolicitud(solicitud.id);
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
