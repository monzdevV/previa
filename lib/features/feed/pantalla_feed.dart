import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/publicacion.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_social.dart';
import '../social/pantalla_avisos.dart';

/// Zona seleccionada en el feed. Nulo significa "toda la noche".
class ZonaDelFeed extends Notifier<String?> {
  @override
  String? build() => null;

  void fijar(String? zona) => state = zona;
}

final zonaDelFeedProvider = NotifierProvider<ZonaDelFeed, String?>(
  ZonaDelFeed.new,
);

/// El feed sin filtrar. Va aparte porque de el salen las zonas: si se
/// sacaran de la lista ya filtrada, al elegir una desaparecerian las demas.
final _feedEnteroProvider = FutureProvider<List<Publicacion>>(
  (ref) => ref.watch(repositorioSocialProvider).feed(),
);

final feedProvider = FutureProvider<List<Publicacion>>((ref) async {
  final zona = ref.watch(zonaDelFeedProvider);
  if (zona == null) return ref.watch(_feedEnteroProvider.future);
  return ref.watch(repositorioSocialProvider).feed(zona: zona);
});

/// Vuelve a pedir el feed. Hay que invalidar los dos: sin zona, el feed
/// lee el entero, y si solo se invalida el de fuera sigue saliendo lo viejo.
void refrescarFeed(WidgetRef ref) {
  ref.invalidate(_feedEnteroProvider);
  ref.invalidate(feedProvider);
}

final _zonasDelFeedProvider = Provider<List<String>>((ref) {
  final lista = ref.watch(_feedEnteroProvider).value ?? const [];
  return {
    for (final p in lista)
      if (p.zona != null && p.zona!.isNotEmpty) p.zona!,
  }.toList()..sort();
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
            icon: const ChinchetaDeAvisos(
              hijo: Icon(Icons.favorite_border_rounded),
            ),
            onPressed: () async {
              await context.push(Rutas.avisos);
              refrescarFeed(ref);
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () => context.push(Rutas.mensajes),
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () async {
              await context.push(Rutas.publicar);
              refrescarFeed(ref);
            },
          ),
          const SizedBox(width: EspaciadoPrevia.s),
        ],
      ),
      body: RefreshIndicator(
        color: context.colores.primarioTexto,
        backgroundColor: context.colores.superficie,
        onRefresh: () {
          ref.invalidate(_feedEnteroProvider);
          return ref.refresh(feedProvider.future);
        },
        child: feed.when(
          // Esqueletos con la forma de lo que va a llegar: la pantalla no
          // salta cuando carga, y se lee como "ya viene" y no como "espera".
          loading: () => const _Esqueletos(),
          // Dentro de una lista para que el gesto de refrescar funcione
          // tambien aqui, que es justo cuando mas falta hace.
          error: (e, _) => _Desplazable(
            child: _Aviso(
              titulo: 'No se ha podido cargar',
              detalle: 'Comprueba tu conexión y desliza hacia abajo.',
              accion: 'Reintentar',
              onAccion: () => ref.invalidate(_feedEnteroProvider),
            ),
          ),
          data: (lista) {
            final zonas = ref.watch(_zonasDelFeedProvider);

            if (lista.isEmpty && zona == null) {
              return const _FeedVacio();
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                    // La clave ata el estado de la fila a su publicacion: sin
                    // ella, al refrescar, la fila 0 conservaba el like de la
                    // publicacion que estaba antes en esa posicion.
                    itemBuilder: (_, i) => _Publicacion(
                      key: ValueKey(lista[i].id),
                      publicacion: lista[i],
                      indice: i,
                    ),
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
          gradient: context.colores.degradado,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.local_fire_department_rounded,
          size: 17,
          color: context.colores.sobrePrimario,
        ),
      ),
      const SizedBox(width: EspaciadoPrevia.s),
      Text(
        'Previa',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
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
    final todas = <String?>[
      null,
      ...zonas,
      if (activa != null && !zonas.contains(activa)) activa,
    ];

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
  const _Publicacion({
    super.key,
    required this.publicacion,
    required this.indice,
  });

  final Publicacion publicacion;

  /// Posicion en la lista, para escalonar la entrada.
  final int indice;

  @override
  ConsumerState<_Publicacion> createState() => _PublicacionState();
}

class _PublicacionState extends ConsumerState<_Publicacion> {
  late Publicacion _p = widget.publicacion;

  // Una peticion en vuelo por accion. Dos toques rapidos lanzaban un insert
  // y un delete a la vez, sin orden garantizado, y la fila acababa mintiendo.
  bool _likeEnVuelo = false;
  bool _seguirEnVuelo = false;

  /// Cuenta los dobles toques para relanzar el corazon grande cada vez.
  int _corazones = 0;

  @override
  void didUpdateWidget(covariant _Publicacion anterior) {
    super.didUpdateWidget(anterior);
    // Lo que llega del servidor manda salvo que haya un cambio a medias.
    if (widget.publicacion != anterior.publicacion &&
        !_likeEnVuelo &&
        !_seguirEnVuelo) {
      _p = widget.publicacion;
    }
  }

  /// El like se pinta antes de que responda el servidor: esperar a la red
  /// para ver tu propio corazon es lo que hace que una app se sienta lenta.
  Future<void> _alternarLike() async {
    if (_likeEnVuelo) return;
    _likeEnVuelo = true;
    HapticFeedback.lightImpact();
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
    } finally {
      _likeEnVuelo = false;
    }
  }

  /// Doble toque en la foto: como en Instagram, solo da like, nunca lo
  /// quita. Quitarlo con el mismo gesto que lo pone confunde.
  void _likeConDobleToque() {
    setState(() => _corazones++);
    if (!_p.leDiLike) _alternarLike();
  }

  Future<void> _alternarSeguimiento() async {
    if (_seguirEnVuelo) return;
    _seguirEnVuelo = true;
    HapticFeedback.selectionClick();
    final antes = _p;
    setState(() => _p = _p.copiarCon(leSigo: !antes.leSigo));
    try {
      await ref
          .read(repositorioSocialProvider)
          .alternarSeguimiento(antes.autorId, loSeguia: antes.leSigo);
    } catch (_) {
      if (mounted) setState(() => _p = antes);
    } finally {
      _seguirEnVuelo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final yo = ref.watch(clienteSupabaseProvider).auth.currentUser?.id;

    final fila = Column(
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
              Pulsable(
                onTap: () => context.push('${Rutas.perfilDe}/${_p.autorId}'),
                child: AvatarPerfil(
                  url: _p.autorAvatar,
                  inicial: _p.autorNombre,
                  lado: 36,
                ),
              ),
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
                      [if (_p.zona != null) _p.zona!, _p.hace].join(' · '),
                      style: textos.labelMedium?.copyWith(
                        color: context.colores.textoTenue,
                      ),
                    ),
                  ],
                ),
              ),
              // En lo tuyo no hay nadie a quien seguir.
              if (!_p.leSigo && _p.autorId != yo)
                TextButton(
                  onPressed: _alternarSeguimiento,
                  child: const Text('Seguir'),
                ),
            ],
          ),
        ),

        GestureDetector(
          onDoubleTap: _likeConDobleToque,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _Media(publicacion: _p),
              if (_corazones > 0) _CorazonGrande(key: ValueKey(_corazones)),
            ],
          ),
        ),

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
                tooltip: _p.leDiLike ? 'Quitar me gusta' : 'Me gusta',
                icon: AnimatedSwitcher(
                  duration: MovimientoPrevia.rapido,
                  transitionBuilder: (hijo, animacion) => ScaleTransition(
                    scale: CurvedAnimation(
                      parent: animacion,
                      curve: Curves.easeOutBack,
                    ),
                    child: hijo,
                  ),
                  child: Icon(
                    _p.leDiLike ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(_p.leDiLike),
                    // El amarillo de marca sobre blanco no se lee como icono;
                    // en claro el corazon usa el ambar oscuro.
                    color: _p.leDiLike
                        ? context.colores.primarioTexto
                        : context.colores.texto,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: MovimientoPrevia.rapido,
                transitionBuilder: (hijo, animacion) => FadeTransition(
                  opacity: animacion,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .4),
                      end: Offset.zero,
                    ).animate(animacion),
                    child: hijo,
                  ),
                ),
                child: _p.likes > 0
                    ? Text(
                        '${_p.likes}',
                        key: ValueKey(_p.likes),
                        style: textos.titleMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      )
                    : const SizedBox.shrink(),
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

    if (MovimientoPrevia.reducido(context)) return fila;
    return fila
        .animate(delay: MovimientoPrevia.retrasoDe(widget.indice))
        .fadeIn(
          duration: MovimientoPrevia.normal,
          curve: MovimientoPrevia.curva,
        )
        .moveY(begin: 12, end: 0, curve: MovimientoPrevia.curva);
  }
}

/// El corazon que salta en el centro de la foto al dar doble toque.
class _CorazonGrande extends StatelessWidget {
  const _CorazonGrande({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child:
        Icon(
              Icons.favorite,
              size: 110,
              color: context.colores.primario,
              shadows: const [Shadow(blurRadius: 24, color: Color(0x66000000))],
            )
            .animate()
            .scale(
              begin: const Offset(.4, .4),
              end: const Offset(1, 1),
              duration: 380.ms,
              curve: Curves.elasticOut,
            )
            .then(delay: 250.ms)
            .fadeOut(duration: 220.ms),
  );
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
  bool _cargando = false;

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
    // Sin esto, dos toques mientras carga creaban dos reproductores.
    if (_cargando) return;
    setState(() => _cargando = true);
    final control = VideoPlayerController.networkUrl(
      Uri.parse(widget.publicacion.mediaUrl),
    );
    try {
      await control.initialize();
      await control.setLooping(true);
      await control.play();
    } catch (_) {
      await control.dispose();
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido reproducir el vídeo.')),
        );
      }
      return;
    }
    if (!mounted) {
      await control.dispose();
      return;
    }
    setState(() {
      _video = control;
      _reproduciendo = true;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.publicacion;

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: ColoredBox(
        color: context.colores.superficie,
        child: p.esVideo ? _construirVideo(p) : _construirFoto(p),
      ),
    );
  }

  Widget _construirFoto(Publicacion p) => CachedNetworkImage(
    imageUrl: p.mediaUrl,
    fit: BoxFit.cover,
    width: double.infinity,
    fadeInDuration: const Duration(milliseconds: 250),
    fadeInCurve: MovimientoPrevia.curva,
    placeholder: (_, _) => ColoredBox(color: context.colores.superficieAlta)
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: context.colores.superficieActiva),
    errorWidget: (_, _, _) => Center(
      child: Icon(
        Icons.broken_image_outlined,
        color: context.colores.textoTenue,
      ),
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
            ColoredBox(color: context.colores.superficieAlta),

          if (_cargando)
            Center(
              child: CircularProgressIndicator(color: context.colores.primario),
            )
          else if (!_reproduciendo)
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
      decoration: BoxDecoration(
        color: context.colores.superficieActiva,
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
                color: context.colores.texto,
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
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(EspaciadoPrevia.l),
    children: [
      const SizedBox(height: EspaciadoPrevia.xxl),
      Container(
        width: 84,
        height: 84,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: context.colores.degradado,
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
        ),
        child: Icon(
          Icons.auto_awesome_rounded,
          size: 42,
          color: context.colores.sobrePrimario,
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
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: context.colores.textoSuave),
      ),
    ],
  );
}

/// Envuelve un estado vacio o de error para que se pueda arrastrar: el
/// RefreshIndicator solo se entera del gesto si hay algo desplazable.
class _Desplazable extends StatelessWidget {
  const _Desplazable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, limites) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: limites.maxHeight),
        child: child,
      ),
    ),
  );
}

/// Dos publicaciones de mentira con la forma de las de verdad.
class _Esqueletos extends StatelessWidget {
  const _Esqueletos();

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    Widget barra(double ancho, double alto) => Container(
      width: ancho,
      height: alto,
      decoration: BoxDecoration(
        color: c.superficieAlta,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
      ),
    );

    final esqueleto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.superficieAlta,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: EspaciadoPrevia.s + EspaciadoPrevia.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  barra(120, 12),
                  const SizedBox(height: 6),
                  barra(80, 10),
                ],
              ),
            ],
          ),
        ),
        AspectRatio(
          aspectRatio: 4 / 5,
          child: ColoredBox(color: c.superficie),
        ),
        Padding(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          child: barra(180, 12),
        ),
      ],
    );

    return ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: [esqueleto, esqueleto],
        )
        .animate(onPlay: (control) => control.repeat())
        .shimmer(duration: 1400.ms, color: c.superficieActiva);
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.titulo,
    required this.detalle,
    this.accion,
    this.onAccion,
  });

  final String titulo;
  final String detalle;
  final String? accion;
  final VoidCallback? onAccion;

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
          if (accion != null && onAccion != null) ...[
            const SizedBox(height: EspaciadoPrevia.m),
            OutlinedButton(onPressed: onAccion, child: Text(accion!)),
          ],
        ],
      ),
    ),
  );
}
