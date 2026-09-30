import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/previa.dart';
import '../../data/repositories/repositorio_previas.dart';
import '../party/estados_pantalla.dart';

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
        loading: () => const IndicadorCarga(),
        error: (e, _) => EstadoError(
          mensaje: 'No se ha podido cargar tu historial',
          detalle: 'Comprueba tu conexión e inténtalo otra vez.',
          onReintentar: () => ref.invalidate(porValorarProvider),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return EstadoVacio(
              icono: Icons.history,
              titulo: 'Todavía no has ido a ninguna previa',
              detalle: 'Cuando vayas a una y termine, podrás valorar a la '
                  'gente que conociste.',
              acciones: [
                FilledButton.icon(
                  onPressed: () => context.go(Rutas.inicio),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Buscar previas en el mapa'),
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(porValorarProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(EspaciadoPrevia.l),
              itemCount: lista.length,
              separatorBuilder: (_, _) => const SizedBox(height: EspaciadoPrevia.s),
              itemBuilder: (_, i) {
                final p = lista[i];
                final cuando =
                    DateFormat("d 'de' MMMM", 'es_ES').format(p.empiezaEn);

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: EspaciadoPrevia.m,
                      vertical: EspaciadoPrevia.s,
                    ),
                    title: Text(p.titulo, style: textos.titleLarge),
                    subtitle: Text('$cuando · ${p.zona}',
                        style: textos.bodyMedium),
                    trailing: const Icon(Icons.star_outline_rounded),
                    onTap: () => context.push(
                      '${Rutas.previa}/${p.id}/valorar'
                      '?titulo=${Uri.encodeQueryComponent(p.titulo)}',
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
