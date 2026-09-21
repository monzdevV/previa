import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/publicacion.dart';
import '../../data/repositories/repositorio_social.dart';

/// Zona seleccionada en el feed. Nulo significa "toda la noche".
class ZonaDelFeed extends Notifier<String?> {
  @override
  String? build() => null;

  void fijar(String? zona) => state = zona;
}

final zonaDelFeedProvider = NotifierProvider<ZonaDelFeed, String?>(
  ZonaDelFeed.new,
);

final feedProvider = FutureProvider<List<Publicacion>>((ref) async {
  final zona = ref.watch(zonaDelFeedProvider);
  return ref.watch(repositorioSocialProvider).feed(zona: zona);
});

/// El feed: la noche de la gente.
///
/// Muestra lo reciente de todo el mundo, no solo de a quien sigues, porque
/// una cuenta nueva que abre la aplicacion y ve el vacio no vuelve.
class PantallaFeed extends ConsumerWidget {
  const PantallaFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    final zona = ref.watch(zonaDelFeedProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: EspaciadoPrevia.m,
        title: const _Marca(),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push(Rutas.buscar),
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () async {
              await context.push(Rutas.publicar);
              ref.invalidate(feedProvider);
            },
          ),
          const SizedBox(width: EspaciadoPrevia.s),
        ],
      ),
      body: RefreshIndicator(
        color: ColoresPrevia.primario,
        backgroundColor: ColoresPrevia.superficie,
        onRefresh: () async => ref.refresh(feedProvider.future),
        child: feed.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: ColoresPrevia.primario),
          ),
          error: (e, _) => _Aviso(
            titulo: 'No se ha podido cargar',
            detalle: 'Comprueba tu conexión y desliza hacia abajo.',
          ),
          data: (lista) {
            final zonas = {
              for (final p in lista)
                if (p.zona != null && p.zona!.isNotEmpty) p.zona!,
            }.toList()..sort();

            if (lista.isEmpty && zona == null) {
              return const _FeedVacio();
            }

            return CustomScrollView(
              slivers: [
                if (zonas.isNotEmpty || zona != null)
                  SliverToBoxAdapter(
                    child: _FranjaDeZonas(zonas: zonas, activa: zona),
                  ),
                if (lista.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Aviso(
                      titulo: 'Nada por aquí todavía',
                      detalle: 'Prueba con otra zona o sé tú quien lo estrene.',
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: lista.length,
                    itemBuilder: (_, i) => _Publicacion(publicacion: lista[i]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: ColoresPrevia.degradado,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.local_fire_department_rounded,
          size: 17,
          color: ColoresPrevia.sobrePrimario,
        ),
      ),
      const SizedBox(width: EspaciadoPrevia.s),
      Text(
        'Previa',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

/// Filtro por ciudad o barrio. Es lo que permite "ver la noche en Zaragoza".
class _FranjaDeZonas extends ConsumerWidget {
  const _FranjaDeZonas({required this.zonas, required this.activa});

  final List<String> zonas;
  final String? activa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todas = <String?>[null, ...zonas, if (activa != null && !zonas.contains(activa)) activa];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: EspaciadoPrevia.m),
        itemCount: todas.length,
        separatorBuilder: (_, _) => const SizedBox(width: EspaciadoPrevia.s),
        itemBuilder: (_, i) {
          final z = todas[i];
          final seleccionada = z == activa;
          return Center(
            child: ChoiceChip(
              label: Text(z ?? 'Toda la noche'),
              selected: seleccionada,
              showCheckmark: false,
              onSelected: (_) =>
                  ref.read(zonaDelFeedProvider.notifier).fijar(z),
            ),
          );
        },
      ),
    );
  }
}

class _Publicacion extends ConsumerStatefulWidget {
  const _Publicacion({required this.publicacion});

  final Publicacion publicacion;

  @override
  ConsumerState<_Publicacion> createState() => _PublicacionState();
}

class _PublicacionState extends ConsumerState<_Publicacion> {
  late Publicacion _p = widget.publicacion;

  /// El like se pinta antes de que responda el servidor: esperar a la red
  /// para ver tu propio corazon es lo que hace que una app se sienta lenta.
  Future<void> _alternarLike() async {
    final antes = _p;
    setState(() {
      _p = _p.copiarCon(
        leDiLike: !antes.leDiLike,
        likes: antes.leDiLike ? antes.likes - 1 : antes.likes + 1,
      );
    });
    try {
      await ref
          .read(repositorioSocialProvider)
          .alternarLike(antes.id, teniaLike: antes.leDiLike);
    } catch (_) {
      if (mounted) setState(() => _p = antes);
    }
  }

  Future<void> _alternarSeguimiento() async {
    final antes = _p;
    setState(() => _p = _p.copiarCon(leSigo: !antes.leSigo));
    try {
      await ref
          .read(repositorioSocialProvider)
          .alternarSeguimiento(antes.autorId, loSeguia: antes.leSigo);
    } catch (_) {
      if (mounted) setState(() => _p = antes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            EspaciadoPrevia.m,
            EspaciadoPrevia.s + EspaciadoPrevia.xs,
            EspaciadoPrevia.s,
            EspaciadoPrevia.s + EspaciadoPrevia.xs,
          ),
          child: Row(
            children: [
              AvatarPerfil(url: _p.autorAvatar, inicial: _p.autorNombre, lado: 36),
              const SizedBox(width: EspaciadoPrevia.s + EspaciadoPrevia.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _p.autorNombre,
                      style: textos.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        if (_p.zona != null) _p.zona!,
                        _p.hace,
                      ].join(' · '),
                      style: textos.labelMedium?.copyWith(
                        color: ColoresPrevia.textoTenue,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_p.leSigo)
                TextButton(
                  onPressed: _alternarSeguimiento,
                  child: const Text('Seguir'),
                ),
            ],
          ),
        ),

        _Media(publicacion: _p),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            EspaciadoPrevia.s + EspaciadoPrevia.xs,
            EspaciadoPrevia.s,
            EspaciadoPrevia.m,
            0,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _alternarLike,
                icon: Icon(
                  _p.leDiLike ? Icons.favorite : Icons.favorite_border,
                  color: _p.leDiLike
                      ? ColoresPrevia.primario
                      : ColoresPrevia.texto,
                ),
              ),
              if (_p.likes > 0)
                Text(
                  '${_p.likes}',
                  style: textos.titleMedium,
                ),
            ],
          ),
        ),

        if (_p.texto != null && _p.texto!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              EspaciadoPrevia.m,
              EspaciadoPrevia.xs,
              EspaciadoPrevia.m,
              0,
            ),
            child: Text(_p.texto!, style: textos.bodyLarge),
          ),

        const SizedBox(height: EspaciadoPrevia.l),
      ],
    );
  }
}

class _Media extends StatefulWidget {
  const _Media({required this.publicacion});

  final Publicacion publicacion;

  @override
  State<_Media> createState() => _MediaState();
}

class _MediaState extends State<_Media> {
  VideoPlayerController? _video;
  bool _reproduciendo = false;

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  /// El video se carga al tocarlo y no al aparecer: cargar a la vez todos
  /// los videos de un feed se come los datos y la bateria.
  Future<void> _arrancarVideo() async {
    if (_video != null) {
      setState(() {
        _reproduciendo ? _video!.pause() : _video!.play();
        _reproduciendo = !_reproduciendo;
      });
      return;
    }
    final control = VideoPlayerController.networkUrl(
      Uri.parse(widget.publicacion.mediaUrl),
    );
    await control.initialize();
    await control.setLooping(true);
    await control.play();
    if (!mounted) {
      await control.dispose();
      return;
    }
    setState(() {
      _video = control;
      _reproduciendo = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.publicacion;

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: ColoredBox(
        color: ColoresPrevia.superficie,
        child: p.esVideo ? _construirVideo(p) : _construirFoto(p),
      ),
    );
  }

  Widget _construirFoto(Publicacion p) => CachedNetworkImage(
    imageUrl: p.mediaUrl,
    fit: BoxFit.cover,
    width: double.infinity,
    placeholder: (_, _) =>
        const ColoredBox(color: ColoresPrevia.superficieAlta),
    errorWidget: (_, _, _) => const Center(
      child: Icon(Icons.broken_image_outlined, color: ColoresPrevia.textoTenue),
    ),
  );

  Widget _construirVideo(Publicacion p) {
    final control = _video;

    return GestureDetector(
      onTap: _arrancarVideo,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (control != null && control.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: control.value.size.width,
                height: control.value.size.height,
                child: VideoPlayer(control),
              ),
            )
          else if (p.miniaturaUrl != null)
            CachedNetworkImage(imageUrl: p.miniaturaUrl!, fit: BoxFit.cover)
          else
            const ColoredBox(color: ColoresPrevia.superficieAlta),

          if (!_reproduciendo)
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x99000000),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(EspaciadoPrevia.m),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Avatar circular reutilizable. Si no hay foto, la inicial sobre el gris.
class AvatarPerfil extends StatelessWidget {
  const AvatarPerfil({
    super.key,
    required this.url,
    required this.inicial,
    this.lado = 40,
  });

  final String? url;
  final String inicial;
  final double lado;

  @override
  Widget build(BuildContext context) {
    final letra = inicial.isNotEmpty ? inicial[0].toUpperCase() : '?';

    return Container(
      width: lado,
      height: lado,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: ColoresPrevia.superficieActiva,
        shape: BoxShape.circle,
      ),
      child: url != null && url!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              width: lado,
              height: lado,
              errorWidget: (_, _, _) => Text(letra),
            )
          : Text(
              letra,
              style: TextStyle(
                color: ColoresPrevia.texto,
                fontSize: lado * 0.4,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _FeedVacio extends StatelessWidget {
  const _FeedVacio();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(EspaciadoPrevia.l),
    children: [
      const SizedBox(height: EspaciadoPrevia.xxl),
      Container(
        width: 84,
        height: 84,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: ColoresPrevia.degradado,
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          size: 42,
          color: ColoresPrevia.sobrePrimario,
        ),
      ),
      const SizedBox(height: EspaciadoPrevia.l),
      Text(
        'Estrena la noche',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: EspaciadoPrevia.s),
      Text(
        'Todavía no hay nada publicado. Sube la primera foto y que la '
        'gente vea dónde está la fiesta.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: ColoresPrevia.textoSuave,
        ),
      ),
    ],
  );
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.titulo, required this.detalle});

  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(EspaciadoPrevia.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: EspaciadoPrevia.s),
          Text(
            detalle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}
