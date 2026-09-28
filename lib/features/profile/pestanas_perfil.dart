import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema.dart';
import '../../data/models/publicacion.dart';
import '../../data/repositories/repositorio_social.dart';
import '../feed/pantalla_feed.dart' show refrescarFeed;
import 'proveedores_perfil.dart';

/// Las fotos de alguien en rejilla de tres, como slivers.
///
/// Son slivers y no una pestaña de alto fijo dentro de una lista: asi la
/// pagina entera desplaza de una vez, sin una segunda barra de scroll
/// escondida a media pantalla.
class SliverRejillaDeFotos extends StatelessWidget {
  const SliverRejillaDeFotos({
    super.key,
    required this.publicaciones,
    required this.vacio,
    this.borrables = false,
  });

  final AsyncValue<List<Publicacion>> publicaciones;
  final Widget vacio;

  /// En tu perfil una pulsacion larga ofrece borrar.
  final bool borrables;

  @override
  Widget build(BuildContext context) {
    return publicaciones.when(
      loading: () => const SliverToBoxAdapter(child: Cargando()),
      error: (e, _) => const SliverToBoxAdapter(
        child: EstadoVacio(
          compacto: true,
          icono: Icons.cloud_off_rounded,
          titulo: 'Sin conexión',
          detalle: 'No hemos podido traer las fotos.',
        ),
      ),
      data: (lista) => lista.isEmpty
          ? SliverToBoxAdapter(child: vacio)
          : SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
                childAspectRatio: 4 / 5,
              ),
              itemCount: lista.length,
              itemBuilder: (_, i) =>
                  _Celda(publicacion: lista[i], borrable: borrables),
            ),
    );
  }
}

/// Lo que subio la gente que estuvo donde tu.
///
/// Es la seccion que da la gracia: donde te encuentras en la foto de fondo
/// de alguien.
class SliverDeEsasNoches extends ConsumerWidget {
  const SliverDeEsasNoches({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otras = ref.watch(deEsasNochesProvider);
    return SliverRejillaDeFotos(
      publicaciones: otras,
      vacio: const EstadoVacio(
        compacto: true,
        pegatina: '📸',
        titulo: 'Aún nada',
        detalle:
            'Aquí sale lo que sube la gente que estuvo donde tú. Di que vas '
            'a un sitio y mira al día siguiente: igual sales en una foto.',
      ),
    );
  }
}

class _Celda extends ConsumerWidget {
  const _Celda({required this.publicacion, required this.borrable});

  final Publicacion publicacion;
  final bool borrable;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
    onLongPress: borrable
        ? () => _confirmarBorrado(context, ref, publicacion.id)
        : null,
    child: Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: publicacion.miniaturaUrl ?? publicacion.mediaUrl,
          fit: BoxFit.cover,
          memCacheWidth: 400,
          placeholder: (_, _) => ColoredBox(color: context.colores.superficie),
          errorWidget: (_, _, _) =>
              ColoredBox(color: context.colores.superficie),
        ),
        if (publicacion.esVideo)
          const Positioned(
            top: 6,
            right: 6,
            child: Icon(
              Icons.play_circle_fill_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
      ],
    ),
  );
}

/// Publicaciones cuyo borrado esta en marcha. La pulsacion larga se puede
/// repetir mientras la primera peticion no vuelve, y un segundo borrado de
/// algo que ya no existe acaba en un error sin sentido para el usuario.
final _borrando = <String>{};

/// Borrar lo tuyo desde la cuadricula, manteniendo pulsado.
Future<void> _confirmarBorrado(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  if (_borrando.contains(id)) return;
  final borrar = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      backgroundColor: context.colores.superficieAlta,
      title: const Text('¿Borrar la publicación?'),
      content: const Text('No se puede deshacer.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(true),
          style: TextButton.styleFrom(foregroundColor: context.colores.error),
          child: const Text('Borrar'),
        ),
      ],
    ),
  );

  if (borrar != true || !context.mounted || !_borrando.add(id)) return;
  final mensajero = ScaffoldMessenger.of(context);
  try {
    await ref.read(repositorioSocialProvider).borrarPublicacion(id);
    ref.invalidate(misPublicacionesProvider);
    // Si no, lo borrado sigue apareciendo en el feed hasta que se recarga.
    refrescarFeed(ref);
  } catch (_) {
    mensajero.showSnackBar(
      const SnackBar(
        content: Text('No se ha podido borrar. Inténtalo otra vez.'),
      ),
    );
  } finally {
    _borrando.remove(id);
  }
}
