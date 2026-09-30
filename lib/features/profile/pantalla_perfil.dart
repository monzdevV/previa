import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../map/proveedores_mapa.dart';
import '../party/tarjeta_previa.dart';
import '../safety/exportar_datos.dart';
import 'avatar_previa.dart';

class PantallaPerfil extends ConsumerWidget {
  const PantallaPerfil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(miPerfilProvider);
    final misPrevias = ref.watch(misPreviasProvider);
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            tooltip: 'Editar perfil',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Rutas.editarPerfil),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(miPerfilProvider);
          ref.invalidate(misPreviasProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(EspaciadoPrevia.l),
          children: [
            perfil.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('No se ha podido cargar tu perfil.',
                  style: textos.bodyMedium),
              data: (p) => Row(
                children: [
                  AvatarPrevia(
                    iniciales: p?.iniciales ?? '?',
                    url: p?.avatarUrl,
                    radio: 32,
                  ),
                  const SizedBox(width: EspaciadoPrevia.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p?.nombre ?? '', style: textos.titleLarge),
                        Text('@${p?.username ?? ''}', style: textos.bodyMedium),
                        if (p != null && p.tieneReputacion)
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 15, color: ColoresPrevia.aviso),
                              const SizedBox(width: 2),
                              Text(
                                '${p.reputacion!.toStringAsFixed(1)} '
                                '· ${p.numeroValoraciones} valoraciones',
                                style: textos.bodyMedium,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: EspaciadoPrevia.xl),
            Row(
              children: [
                Text('Mis previas', style: textos.titleLarge),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.push(Rutas.crearPrevia),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Abrir'),
                ),
              ],
            ),
            const SizedBox(height: EspaciadoPrevia.s),

            misPrevias.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(EspaciadoPrevia.l),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('No se han podido cargar tus previas.',
                  style: textos.bodyMedium),
              data: (lista) => lista.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(EspaciadoPrevia.l),
                      decoration: BoxDecoration(
                        color: ColoresPrevia.superficie,
                        borderRadius:
                            BorderRadius.circular(EspaciadoPrevia.radio),
                        border: Border.all(color: ColoresPrevia.borde),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.nightlife_outlined,
                              size: 32, color: ColoresPrevia.textoTenue),
                          const SizedBox(height: EspaciadoPrevia.s),
                          Text(
                            'Todavía no has abierto ninguna previa.',
                            style: textos.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        for (final p in lista)
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: EspaciadoPrevia.s),
                            child: TarjetaPrevia(
                              previa: p,
                              compacta: true,
                              onTap: () =>
                                  context.push('${Rutas.previa}/${p.id}'),
                            ),
                          ),
                      ],
                    ),
            ),

            const SizedBox(height: EspaciadoPrevia.l),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.waving_hand_outlined),
              title: const Text('Mis solicitudes'),
              subtitle: const Text('Las plazas que has pedido'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Rutas.misSolicitudes),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star_outline_rounded),
              title: const Text('Previas a las que fui'),
              subtitle: const Text('Valora a la gente que conociste'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Rutas.porValorar),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Privacidad y convivencia'),
              subtitle: const Text('Qué guardamos y cómo funciona'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Rutas.ajustes),
            ),

            const SizedBox(height: EspaciadoPrevia.m),
            const Divider(),
            const SizedBox(height: EspaciadoPrevia.m),

            Text('Tus datos', style: textos.titleLarge),
            const SizedBox(height: EspaciadoPrevia.s),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.download_outlined),
              title: const Text('Descargar mis datos'),
              subtitle: const Text('Todo lo que guardamos de ti, en un fichero'),
              onTap: () => _exportar(context, ref),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline, color: ColoresPrevia.error),
              title: const Text('Eliminar mi cuenta',
                  style: TextStyle(color: ColoresPrevia.error)),
              subtitle: const Text('Se borra todo y no hay vuelta atrás'),
              onTap: () => _eliminarCuenta(context, ref),
            ),

            const SizedBox(height: EspaciadoPrevia.l),
            OutlinedButton.icon(
              onPressed: () => ref.read(repositorioAuthProvider).salir(),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Cerrar sesión'),
            ),
            const SizedBox(height: EspaciadoPrevia.l),
          ],
        ),
      ),
    );
  }

  Future<void> _exportar(BuildContext context, WidgetRef ref) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final datos = await ref.read(repositorioAuthProvider).exportarMisDatos();
      final entregado = await entregarExportacion(datos);
      if (entregado) {
        mensajero.showSnackBar(
          const SnackBar(content: Text('Fichero con tus datos listo.')),
        );
      }
    } catch (e) {
      // ErrorPrevia trae mensaje propio; cualquier otro fallo (p. ej. no
      // hay hoja de compartir) recibe un texto generico.
      mensajero.showSnackBar(
        SnackBar(
          content: Text(e is ErrorPrevia
              ? e.mensaje
              : 'No se ha podido guardar el fichero con tus datos.'),
        ),
      );
    }
  }

  Future<void> _eliminarCuenta(BuildContext context, WidgetRef ref) async {
    final mensajero = ScaffoldMessenger.of(context);
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => const _DialogoEliminarCuenta(),
    );

    if (confirmado != true) return;
    try {
      await ref.read(repositorioAuthProvider).eliminarMiCuenta();
    } catch (e) {
      // Antes el fallo se perdia en silencio y el usuario creia que se
      // habia borrado o que la app estaba colgada.
      mensajero.showSnackBar(
        SnackBar(
          content: Text(e is ErrorPrevia
              ? e.mensaje
              : 'No se ha podido eliminar la cuenta.'),
        ),
      );
    }
  }
}

/// Pide escribir ELIMINAR: un toque accidental no debe borrar una cuenta.
class _DialogoEliminarCuenta extends StatefulWidget {
  const _DialogoEliminarCuenta();

  @override
  State<_DialogoEliminarCuenta> createState() => _DialogoEliminarCuentaState();
}

class _DialogoEliminarCuentaState extends State<_DialogoEliminarCuenta> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listo = _texto.text.trim().toUpperCase() == 'ELIMINAR';
    return AlertDialog(
      backgroundColor: ColoresPrevia.superficieAlta,
      title: const Text('¿Eliminar tu cuenta?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se borrarán tu perfil, tus previas, tus mensajes y tus '
            'valoraciones. Esto no se puede deshacer.',
          ),
          const SizedBox(height: EspaciadoPrevia.m),
          const Text('Escribe ELIMINAR para confirmar:'),
          const SizedBox(height: EspaciadoPrevia.s),
          TextField(
            controller: _texto,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: listo ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: ColoresPrevia.error,
            minimumSize: const Size(0, 44),
          ),
          child: const Text('Eliminar'),
        ),
      ],
    );
  }
}
