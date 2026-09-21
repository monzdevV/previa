import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/tema.dart';
import '../../data/models/noche.dart';
import '../../data/models/publicacion.dart';
import '../../data/repositories/repositorio_social.dart';
import '../feed/pantalla_feed.dart' show AvatarPerfil;
import '../social/pantalla_resumen_noche.dart';
import 'cabecera_perfil.dart';

final _salidasProvider = FutureProvider<List<Salida>>(
  (ref) => ref.watch(repositorioSocialProvider).misUltimasSalidas(),
);

final _deEsasNochesProvider = FutureProvider<List<Publicacion>>(
  (ref) => ref.watch(repositorioSocialProvider).fotosDeMisNoches(),
);

/// Las tres pestañas del perfil.
///
/// Reparto tomado de las redes que ya usa la gente: lo tuyo primero, y lo que
/// subieron otros en las mismas noches al final. Esa tercera es la que da la
/// gracia, porque es donde te encuentras en la foto de fondo de alguien.
class PestanasPerfil extends StatelessWidget {
  const PestanasPerfil({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: ColoresPrevia.primario,
            labelColor: ColoresPrevia.texto,
            unselectedLabelColor: ColoresPrevia.textoTenue,
            tabs: [
              Tab(icon: Icon(Icons.nightlife_rounded), text: 'Salidas'),
              Tab(icon: Icon(Icons.grid_on_rounded), text: 'Tuyo'),
              Tab(icon: Icon(Icons.groups_rounded), text: 'De esas noches'),
            ],
          ),

          // Alto fijo: las pestañas viven dentro de un ListView, que no sabe
          // cuanto miden sus hijos si estos tambien desplazan.
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.62,
            child: const TabBarView(
              children: [_Salidas(), _LoTuyo(), _DeEsasNoches()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Las últimas veces que saliste.
class _Salidas extends ConsumerWidget {
  const _Salidas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salidas = ref.watch(_salidasProvider);

    return salidas.when(
      loading: () => const _Cargando(),
      error: (e, _) => const _Vacio(texto: 'No se ha podido cargar.'),
      data: (lista) => lista.isEmpty
          ? const _Vacio(
              texto: 'Aquí aparecerán tus salidas.\n'
                  'Di que vas a un sitio y empezará a contar.',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(
                vertical: EspaciadoPrevia.m,
              ),
              itemCount: lista.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: EspaciadoPrevia.s + 4),
              itemBuilder: (_, i) => _FilaSalida(salida: lista[i]),
            ),
    );
  }
}

class _FilaSalida extends StatelessWidget {
  const _FilaSalida({required this.salida});

  final Salida salida;

  @override
  Widget build(BuildContext context) {
    final s = salida;
    final fecha = DateFormat("d 'de' MMMM", 'es_ES').format(s.noche);
    final textos = Theme.of(context).textTheme;

    return Material(
      color: ColoresPrevia.superficie,
      borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PantallaResumenNoche(noche: s.noche),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              height: 92,
              child: s.portada == null
                  ? const ColoredBox(
                      color: ColoresPrevia.superficieAlta,
                      child: Icon(
                        Icons.nightlife_rounded,
                        color: ColoresPrevia.textoTenue,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: s.portada!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const ColoredBox(
                        color: ColoresPrevia.superficieAlta,
                      ),
                      errorWidget: (_, _, _) => const ColoredBox(
                        color: ColoresPrevia.superficieAlta,
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(EspaciadoPrevia.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.donde,
                      style: textos.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(fecha, style: textos.labelMedium),
                    const SizedBox(height: EspaciadoPrevia.s),
                    Text(
                      [
                        if (s.conQuien > 0)
                          s.conQuien == 1
                              ? '1 persona'
                              : '${s.conQuien} personas',
                        if (s.fotos > 0)
                          s.fotos == 1 ? '1 foto' : '${s.fotos} fotos',
                      ].join(' · '),
                      style: textos.bodyMedium?.copyWith(
                        color: ColoresPrevia.primario,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: EspaciadoPrevia.s),
              child: Icon(
                Icons.chevron_right,
                color: ColoresPrevia.textoTenue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tus fotos y vídeos.
class _LoTuyo extends ConsumerWidget {
  const _LoTuyo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mias = ref.watch(misPublicacionesProvider);

    return mias.when(
      loading: () => const _Cargando(),
      error: (e, _) => const _Vacio(texto: 'No se ha podido cargar.'),
      data: (lista) => lista.isEmpty
          ? const _Vacio(
              texto: 'Todavía no has subido nada.\n'
                  'Sube una foto de la última noche.',
            )
          : GridView.builder(
              padding: const EdgeInsets.symmetric(vertical: 3),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
              ),
              itemCount: lista.length,
              itemBuilder: (_, i) => _Celda(publicacion: lista[i]),
            ),
    );
  }
}

/// Lo que subió la gente que estuvo donde tú.
class _DeEsasNoches extends ConsumerWidget {
  const _DeEsasNoches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otras = ref.watch(_deEsasNochesProvider);

    return otras.when(
      loading: () => const _Cargando(),
      error: (e, _) => const _Vacio(texto: 'No se ha podido cargar.'),
      data: (lista) => lista.isEmpty
          ? const _Vacio(
              texto: 'Aquí sale lo que sube la gente que estuvo donde tú.\n'
                  'Di que vas a un sitio y mira al día siguiente: igual '
                  'apareces en la foto de alguien.',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(
                vertical: EspaciadoPrevia.m,
              ),
              itemCount: lista.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: EspaciadoPrevia.m),
              itemBuilder: (_, i) => _Compartida(publicacion: lista[i]),
            ),
    );
  }
}

class _Compartida extends StatelessWidget {
  const _Compartida({required this.publicacion});

  final Publicacion publicacion;

  @override
  Widget build(BuildContext context) {
    final p = publicacion;
    final textos = Theme.of(context).textTheme;

    return Material(
      color: ColoresPrevia.superficie,
      borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: CachedNetworkImage(
              imageUrl: p.mediaUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  const ColoredBox(color: ColoresPrevia.superficieAlta),
              errorWidget: (_, _, _) =>
                  const ColoredBox(color: ColoresPrevia.superficieAlta),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(EspaciadoPrevia.s + EspaciadoPrevia.xs),
            child: Row(
              children: [
                AvatarPerfil(
                  url: p.autorAvatar,
                  inicial: p.autorNombre,
                  lado: 30,
                ),
                const SizedBox(width: EspaciadoPrevia.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.autorNombre,
                        style: textos.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Estuvisteis en el mismo sitio',
                        style: textos.labelMedium?.copyWith(
                          color: ColoresPrevia.primario,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(p.hace, style: textos.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Celda extends ConsumerWidget {
  const _Celda({required this.publicacion});

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

/// Borrar lo tuyo desde la cuadricula, manteniendo pulsado.
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

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: ColoresPrevia.primario),
  );
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(EspaciadoPrevia.xl),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}
