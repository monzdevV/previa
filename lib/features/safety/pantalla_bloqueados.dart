import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema.dart';
import '../../data/repositories/repositorio_seguridad.dart';
import '../map/proveedores_mapa.dart';
import '../profile/avatar_previa.dart';

final bloqueadosProvider = FutureProvider.autoDispose<List<UsuarioBloqueado>>(
  (ref) => ref.watch(repositorioSeguridadProvider).bloqueados(),
);

/// Lista de personas bloqueadas, con opcion de desbloquear.
///
/// Sin esta pantalla un bloqueo hecho por error seria irreversible, y
/// las tiendas exigen que el usuario controle su propia lista.
class PantallaBloqueados extends ConsumerWidget {
  const PantallaBloqueados({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(bloqueadosProvider);
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios bloqueados')),
      body: lista.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(EspaciadoPrevia.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.toString(),
                    textAlign: TextAlign.center, style: textos.bodyMedium),
                const SizedBox(height: EspaciadoPrevia.m),
                OutlinedButton(
                  onPressed: () => ref.invalidate(bloqueadosProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (personas) => personas.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(EspaciadoPrevia.xl),
                  child: Text(
                    'No has bloqueado a nadie.',
                    style: textos.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(EspaciadoPrevia.l),
                itemCount: personas.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (_, i) {
                  final p = personas[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AvatarPrevia(
                      iniciales: p.nombre?.isNotEmpty == true
                          ? p.nombre!.substring(0, 1).toUpperCase()
                          : '?',
                      url: p.avatarUrl,
                      radio: 20,
                    ),
                    title: Text(p.etiqueta),
                    trailing: OutlinedButton(
                      onPressed: () => _desbloquear(context, ref, p),
                      child: const Text('Desbloquear'),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _desbloquear(
      BuildContext context, WidgetRef ref, UsuarioBloqueado p) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(repositorioSeguridadProvider).desbloquear(p.id);
      // Sus previas vuelven a ser visibles: hay que recargar el mapa.
      ref.invalidate(previasCercaProvider);
      ref.invalidate(bloqueadosProvider);
      mensajero.showSnackBar(
        SnackBar(content: Text('${p.etiqueta} desbloqueado.')),
      );
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
