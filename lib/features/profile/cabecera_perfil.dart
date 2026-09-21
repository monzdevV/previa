import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/perfil.dart';
import '../../data/models/publicacion.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_social.dart';
import '../feed/pantalla_feed.dart' show AvatarPerfil;
import '../social/pantalla_resumen_noche.dart' show InsigniaDeRacha;

/// Lo que has publicado tu. Vive aqui y no en la pantalla porque tambien lo
/// necesita la cabecera para el contador.
final misPublicacionesProvider = FutureProvider<List<Publicacion>>((ref) async {
  final yo = ref.watch(repositorioAuthProvider).usuarioActual?.id;
  if (yo == null) return const [];
  return ref.watch(repositorioSocialProvider).publicacionesDe(yo);
});

final miFichaProvider = FutureProvider.family<PerfilPublico, String>(
  (ref, id) => ref.watch(repositorioSocialProvider).perfilPublico(id),
);

/// Cabecera del perfil propio.
///
/// Ensena la foto de verdad y no solo las iniciales: si se sube una y no se
/// ve en ningun sitio, la subida no sirve de nada. Tocar la foto lleva a
/// editar, que es lo que espera cualquiera que venga de otra red social.
class CabeceraPerfil extends ConsumerWidget {
  const CabeceraPerfil({super.key, required this.perfil});

  final Perfil? perfil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = perfil;
    if (p == null) return const SizedBox.shrink();

    final textos = Theme.of(context).textTheme;
    final ficha = ref.watch(miFichaProvider(p.id));
    final mias = ref.watch(misPublicacionesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push(Rutas.editarPerfil),
              child: Stack(
                children: [
                  AvatarPerfil(url: p.avatarUrl, inicial: p.nombre, lado: 82),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: ColoresPrevia.primario,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: ColoresPrevia.sobrePrimario,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: EspaciadoPrevia.m),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Contador(
                    valor: mias.valueOrNull?.length ?? 0,
                    etiqueta: 'noches',
                  ),
                  _Contador(
                    valor: ficha.valueOrNull?.seguidores ?? 0,
                    etiqueta: 'seguidores',
                  ),
                  _Contador(
                    valor: ficha.valueOrNull?.siguiendo ?? 0,
                    etiqueta: 'siguiendo',
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: EspaciadoPrevia.m),
        Row(
          children: [
            Expanded(child: Text(p.nombre, style: textos.titleLarge)),
            const InsigniaDeRacha(),
          ],
        ),
        Text('@${p.username}', style: textos.bodyMedium),

        if (p.bio != null && p.bio!.isNotEmpty) ...[
          const SizedBox(height: EspaciadoPrevia.s),
          Text(p.bio!, style: textos.bodyLarge),
        ],

        const SizedBox(height: EspaciadoPrevia.s + EspaciadoPrevia.xs),
        Wrap(
          spacing: EspaciadoPrevia.s,
          runSpacing: EspaciadoPrevia.xs + 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (p.ciudad != null) _Etiqueta(Icons.place_outlined, p.ciudad!),
            if (p.tieneReputacion)
              _Etiqueta(
                Icons.star_rounded,
                '${p.reputacion!.toStringAsFixed(1).replaceAll('.', ',')}'
                ' · ${p.numeroValoraciones} valoraciones',
              ),
            if (p.instagram != null)
              _Etiqueta(Icons.alternate_email_rounded, p.instagram!),
          ],
        ),

        const SizedBox(height: EspaciadoPrevia.m),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(Rutas.editarPerfil),
                icon: const Icon(Icons.edit_outlined, size: 19),
                label: const Text('Editar perfil'),
              ),
            ),
            const SizedBox(width: EspaciadoPrevia.s),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(Rutas.buscar),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 19),
                label: const Text('Añadir gente'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// La cuadricula de lo que has publicado, con borrado al mantener pulsado.
class MisPublicaciones extends ConsumerWidget {
  const MisPublicaciones({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publicaciones = ref.watch(misPublicacionesProvider);
    final textos = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Mis publicaciones', style: textos.titleLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                await context.push(Rutas.publicar);
                ref.invalidate(misPublicacionesProvider);
              },
              icon: const Icon(Icons.add, size: 19),
              label: const Text('Subir'),
            ),
          ],
        ),
        const SizedBox(height: EspaciadoPrevia.s),

        publicaciones.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(EspaciadoPrevia.l),
              child: CircularProgressIndicator(color: ColoresPrevia.primario),
            ),
          ),
          error: (e, _) => const SizedBox.shrink(),
          data: (lista) => lista.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: EspaciadoPrevia.l,
                  ),
                  child: Text(
                    'Todavía no has subido nada. Sube una foto de la última '
                    'noche y que la vea la gente.',
                    style: textos.bodyMedium,
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 3,
                        crossAxisSpacing: 3,
                      ),
                  itemCount: lista.length,
                  itemBuilder: (_, i) => _Miniatura(publicacion: lista[i]),
                ),
        ),
      ],
    );
  }
}

class _Miniatura extends ConsumerWidget {
  const _Miniatura({required this.publicacion});

  final Publicacion publicacion;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
    onLongPress: () => _confirmarBorrado(context, ref, publicacion.id),
    child: Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: publicacion.miniaturaUrl ?? publicacion.mediaUrl,
          fit: BoxFit.cover,
          placeholder: (_, _) =>
              const ColoredBox(color: ColoresPrevia.superficie),
          errorWidget: (_, _, _) =>
              const ColoredBox(color: ColoresPrevia.superficie),
        ),
        if (publicacion.esVideo)
          const Positioned(
            top: 4,
            right: 4,
            child: Icon(
              Icons.play_circle_fill_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
      ],
    ),
  );
}

Future<void> _confirmarBorrado(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final borrar = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      backgroundColor: ColoresPrevia.superficieAlta,
      title: const Text('¿Borrar la publicación?'),
      content: const Text('No se puede deshacer.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(true),
          style: TextButton.styleFrom(foregroundColor: ColoresPrevia.error),
          child: const Text('Borrar'),
        ),
      ],
    ),
  );

  if (borrar != true) return;
  await ref.read(repositorioSocialProvider).borrarPublicacion(id);
  ref.invalidate(misPublicacionesProvider);
}

class _Contador extends StatelessWidget {
  const _Contador({required this.valor, required this.etiqueta});

  final int valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('$valor', style: Theme.of(context).textTheme.titleLarge),
      Text(etiqueta, style: Theme.of(context).textTheme.labelMedium),
    ],
  );
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.icono, this.texto);

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icono, size: 16, color: ColoresPrevia.textoTenue),
      const SizedBox(width: EspaciadoPrevia.xs),
      Text(texto, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}
