import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/previa.dart';
import '../../data/repositories/repositorio_previas.dart';
import '../requests/piezas_solicitudes.dart' show EntradaLista;

final porValorarProvider = FutureProvider<List<Previa>>(
  (ref) => ref.watch(repositorioPreviasProvider).previasPorValorar(),
);

/// Listado de previas pasadas a las que fui, para valorar a quien coincidió.
class PantallaPorValorar extends ConsumerWidget {
  const PantallaPorValorar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previas = ref.watch(porValorarProvider);
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Previas a las que fui')),
      body: previas.when(
        loading: () => const Cargando(),
        error: (e, _) => Semantics(
          liveRegion: true,
          child: EstadoVacio(
            icono: Icons.cloud_off_rounded,
            titulo: 'Sin conexión',
            detalle:
                'No hemos podido cargar tu historial. Comprueba tu conexión.',
            accion: 'Reintentar',
            onAccion: () => ref.invalidate(porValorarProvider),
          ),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return const EstadoVacio(
              pegatina: '🌙',
              titulo: 'Todavía no has ido a ninguna previa',
              detalle:
                  'Cuando vayas a una y termine, podrás valorar a la gente '
                  'que conociste.',
            );
          }

          return RefreshIndicator(
            color: context.colores.primarioTexto,
            backgroundColor: context.colores.superficie,
            onRefresh: () async {
              ref.invalidate(porValorarProvider);
              try {
                await ref.read(porValorarProvider.future);
              } catch (_) {
                // El fallo ya lo pinta el estado de error de la pantalla.
              }
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(EspaciadoPrevia.l),
              itemCount: lista.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: EspaciadoPrevia.s),
              itemBuilder: (_, i) {
                final p = lista[i];
                final cuando = DateFormat(
                  "d 'de' MMMM",
                  'es_ES',
                ).format(p.empiezaEn);

                return EntradaLista(
                  key: ValueKey(p.id),
                  indice: i,
                  child: Card(
                    child: ListTile(
                      minTileHeight: 72,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: EspaciadoPrevia.m,
                        vertical: EspaciadoPrevia.s,
                      ),
                      title: Text(p.titulo, style: textos.titleLarge),
                      subtitle: Text(
                        '$cuando · ${p.zona}',
                        style: textos.bodyMedium,
                      ),
                      trailing: ExcludeSemantics(
                        child: Icon(
                          Icons.star_outline_rounded,
                          color: context.colores.primarioTexto,
                        ),
                      ),
                      onTap: () => context.push(
                        '${Rutas.previa}/${p.id}/valorar'
                        '?titulo=${Uri.encodeQueryComponent(p.titulo)}',
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
