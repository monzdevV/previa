import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/previa.dart';
import '../../data/repositories/repositorio_previas.dart';

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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(EspaciadoPrevia.l),
            child: Text(
              'No se ha podido cargar tu historial.',
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
                    const Icon(
                      Icons.history,
                      size: 40,
                      color: ColoresPrevia.textoTenue,
                    ),
                    const SizedBox(height: EspaciadoPrevia.m),
                    Text(
                      'Todavía no has ido a ninguna previa',
                      style: textos.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: EspaciadoPrevia.xs),
                    Text(
                      'Cuando vayas a una y termine, podrás valorar a la gente '
                      'que conociste.',
                      textAlign: TextAlign.center,
                      style: textos.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(porValorarProvider),
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

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: EspaciadoPrevia.m,
                      vertical: EspaciadoPrevia.s,
                    ),
                    title: Text(p.titulo, style: textos.titleLarge),
                    subtitle: Text(
                      '$cuando · ${p.zona}',
                      style: textos.bodyMedium,
                    ),
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
