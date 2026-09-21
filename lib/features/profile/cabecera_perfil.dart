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
