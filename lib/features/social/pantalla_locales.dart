import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/local.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_social.dart';
import '../juegos/no_hay_huevos.dart' show StickerNoHayHuevos;
import '../map/proveedores_mapa.dart' show posicionDispositivoProvider;
import '../profile/proveedores_perfil.dart';
import 'pantalla_sala.dart';
import 'selector_vas.dart';

/// Ciudad que se esta mirando. Se queda fijada mientras dure la sesion.
class CiudadDeLaNoche extends Notifier<String> {
  @override
  String build() => 'Zaragoza';

  void fijar(String ciudad) {
    final limpia = ciudad.trim();
    if (limpia.isNotEmpty) state = limpia;
  }
}

final ciudadDeLaNocheProvider = NotifierProvider<CiudadDeLaNoche, String>(
  CiudadDeLaNoche.new,
);

final localesProvider = FutureProvider<List<Local>>((ref) async {
  final ciudad = ref.watch(ciudadDeLaNocheProvider);
  return ref.watch(repositorioSocialProvider).localesDeLaNoche(ciudad);
});

/// Los locales de mas cerca a mas lejos, cada uno con sus metros.
///
/// Se ordena aqui y no en el servidor porque la posicion no sale del
/// telefono. Sin posicion (permiso denegado, web sin GPS) se respeta el
/// orden del servidor, que pone primero donde va mas gente: es el siguiente
/// mejor criterio para decidir a donde ir.
List<(Local, double?)> ordenarPorCercania(List<Local> lista, LatLng? yo) {
  final conDistancia = [
    for (final (i, l) in lista.indexed)
      (l, yo == null ? null : l.metrosHasta(yo.latitude, yo.longitude), i),
  ];
  conDistancia.sort((a, b) {
    final (da, db) = (a.$2, b.$2);
    if (da != null && db != null && da != db) return da.compareTo(db);
    if (da == null && db != null) return 1;
    if (da != null && db == null) return -1;
    // El sort de Dart no es estable: el indice conserva el orden del servidor
    // entre los que empatan o no tienen coordenadas.
    return a.$3.compareTo(b.$3);
  });
  return [for (final e in conDistancia) (e.$1, e.$2)];
}

/// ¿Vas? Los sitios de la ciudad, uno debajo de otro, con su foto a sangre.
///
/// Es el lenguaje de las guias de ocio que la gente ya usa: lo que decide
/// entrar en un sitio es verlo por dentro, asi que la foto manda y no hay
/// cabecera ni bloques de color que compitan con ella. Encima de cada foto,
/// abajo, lo justo: quien es el sitio (logo o nombre), a cuanto esta, y la
/// pregunta de la noche con las caras de quien va.
///
/// Interaccion:
/// - Toque en la tarjeta: la ficha del local (quien va, sala, entradas).
/// - Toque en la pastilla "¿Vas?": voy, sin mas. Si ya habias contestado,
///   abre las opciones para cambiarlo.
/// - Toque largo en cualquier parte de la tarjeta: quiza, mas tarde, estoy
///   aqui o no voy.
class PantallaLocales extends ConsumerWidget {
  const PantallaLocales({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locales = ref.watch(localesProvider);
    final ciudad = ref.watch(ciudadDeLaNocheProvider);
    // La posicion la pide ya el mapa al arrancar; aqui solo se escucha, asi
    // que esta pestaña no añade ninguna peticion de permiso.
    final yo = ref.watch(posicionDispositivoProvider).valueOrNull;
    final arriba = MediaQuery.paddingOf(context).top;

    // Con fotos detras, la barra de estado va en blanco en los dos temas; en
    // los estados vacios manda el tema.
    final hayFotos = locales.isLoading || (locales.valueOrNull?.isNotEmpty ?? false);
    final hueco = arriba + _TarjetaLocal.altoPastillaCiudad;

    final lista = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        ...locales.when(
          loading: () => [_Esqueletos(extraPrimera: hueco)],
          error: (e, _) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.only(top: hueco),
                child: EstadoVacio(
                  icono: Icons.cloud_off_rounded,
                  titulo: 'Sin conexión',
                  detalle:
                      'No hemos podido ver los sitios de $ciudad. Desliza '
                      'hacia abajo o reinténtalo.',
                  accion: 'Reintentar',
                  onAccion: () => ref.invalidate(localesProvider),
                ),
              ),
            ),
          ],
          data: (lista) {
            if (lista.isEmpty) {
              return [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.only(top: hueco),
                    child: EstadoVacio(
                      pegatina: '🪩',
                      titulo: 'Aún no hay sitios en $ciudad',
                      detalle:
                          'Añade el primero y que la gente pueda decir que '
                          'va. O mira otra ciudad desde arriba.',
                      accion: 'Añadir un sitio',
                      onAccion: () => _proponerLocal(context, ref, ciudad),
                    ),
                  ),
                ),
              ];
            }
            final ordenados = ordenarPorCercania(lista, yo);
            final reducido = MovimientoPrevia.reducido(context);
            return [
              SliverList.builder(
                itemCount: ordenados.length,
                itemBuilder: (_, i) {
                  final (local, metros) = ordenados[i];
                  final tarjeta = _TarjetaLocal(
                    key: ValueKey(local.id),
                    local: local,
                    metros: metros,
                    extraArriba: i == 0 ? hueco : 0,
                  );
                  // Solo opacidad: las tarjetas van pegadas, y cualquier
                  // desplazamiento abriria rendijas entre ellas al entrar.
                  if (reducido) return tarjeta;
                  return tarjeta
                      .animate(delay: MovimientoPrevia.retrasoDe(i))
                      .fadeIn(
                        duration: MovimientoPrevia.normal,
                        curve: MovimientoPrevia.curva,
                      );
                },
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    EspaciadoPrevia.m,
                    EspaciadoPrevia.l,
                    EspaciadoPrevia.m,
                    0,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => _proponerLocal(context, ref, ciudad),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('¿Falta tu sitio? Añádelo'),
                  ),
                ),
              ),
            ];
          },
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: context.holguraInferior + EspaciadoPrevia.m),
        ),
      ],
    );

    final cuerpo = Stack(
      children: [
        RefreshIndicator(
          color: context.colores.primarioTexto,
          backgroundColor: context.colores.superficie,
          // Que baje por debajo de la pastilla de la ciudad y no detras.
          edgeOffset: hueco - EspaciadoPrevia.s,
          // El fallo se traga aqui porque ya lo pinta la propia lista.
          onRefresh: () => ref
              .refresh(localesProvider.future)
              .then((_) {}, onError: (_) {}),
          child: lista,
        ),
        // Sombra bajo la barra de estado: sin ella, la hora y la bateria se
        // pierden encima de una foto clara.
        if (hayFotos)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: hueco + EspaciadoPrevia.m,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: arriba + EspaciadoPrevia.s + 4,
          left: 0,
          right: 0,
          child: Center(
            child: _PastillaCiudad(
              ciudad: ciudad,
              onTap: () => _cambiarCiudad(context, ref, ciudad),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      body: hayFotos
          ? AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.light,
              child: cuerpo,
            )
          : cuerpo,
    );
  }
}

/// La ciudad, flotando arriba y centrada: es lo unico que se toca fuera de
/// las fotos, y blanca para que se lea sobre cualquiera de ellas.
class _PastillaCiudad extends StatelessWidget {
  const _PastillaCiudad({required this.ciudad, required this.onTap});

  final String ciudad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const tinta = BloquesPrevia.tintaSobreBloque;
    return Semantics(
      button: true,
      label: 'Ciudad: $ciudad. Toca para cambiarla',
      excludeSemantics: true,
      child: Pulsable(
        onTap: onTap,
        child: Container(
          height: 44,
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.only(left: 12, right: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
            // Borde fino para el tema claro, donde la pastilla puede caer
            // sobre el fondo blanco de un estado vacio.
            border: Border.all(color: const Color(0x14000000)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // El ambar del tema claro: el amarillo de marca sobre blanco no
              // se distingue.
              Icon(
                Icons.place_rounded,
                size: 20,
                color: ColoresPrevia.claro.primarioTexto,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  ciudad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: tinta,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: Color(0x99120F12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un local: su foto a ancho completo, sin esquinas ni margenes, pegada a la
/// siguiente. Como un carrete de fotos, no como una pila de fichas.
class _TarjetaLocal extends ConsumerStatefulWidget {
  const _TarjetaLocal({
    super.key,
    required this.local,
    required this.metros,
    this.extraArriba = 0,
  });

  final Local local;
  final double? metros;

  /// La primera tarjeta pasa por detras de la barra de estado y de la
  /// pastilla de la ciudad: crece eso para que su contenido no quede debajo.
  final double extraArriba;

  /// Lo que ocupa la pastilla de la ciudad bajo la barra de estado.
  static const altoPastillaCiudad = 60.0;

  /// Un cuarto de pantalla, con limites: en un movil pequeño no puede bajar
  /// de lo que ocupa el texto, y en una tableta no debe crecer sin fin.
  static double altoBase(BuildContext context) =>
      (MediaQuery.sizeOf(context).height * 0.26).clamp(196.0, 280.0);

  @override
  ConsumerState<_TarjetaLocal> createState() => _TarjetaLocalState();
}

class _TarjetaLocalState extends ConsumerState<_TarjetaLocal> {
  late Local _l = widget.local;

  /// Mientras la peticion no vuelve se ignoran los toques: dos seguidos
  /// descuadrarian los contadores, que se calculan en local.
  bool _enCurso = false;

  bool _apretada = false;

  @override
  void didUpdateWidget(covariant _TarjetaLocal anterior) {
    super.didUpdateWidget(anterior);
    // Al recargar la lista manda lo que dice el servidor, no la copia que se
    // tomo la primera vez que se pinto la tarjeta.
    if (!_enCurso && anterior.local != widget.local) _l = widget.local;
  }

  Future<void> _decir(EstadoNoche? estado) async {
    if (_enCurso) return;
    final antes = _l;
    final mensajero = ScaffoldMessenger.of(context);
    setState(() {
      _enCurso = true;
      _l = _l.conMiEstado(estado);
    });
    try {
      await ref.read(repositorioSocialProvider).decirSiVoy(antes.id, estado);
      // Decir que vas cuenta como noche, asi que mueve la racha, el
      // calendario y las salidas del perfil.
      refrescarPerfil(ref);
    } catch (e) {
      if (!mounted) return;
      setState(() => _l = antes);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            e is ErrorPrevia
                ? e.mensaje
                : 'No se ha podido guardar. Prueba otra vez.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _enCurso = false);
    }
  }

  Future<void> _opciones() async {
    HapticFeedback.selectionClick();
    final eleccion = await mostrarOpcionesVas(
      context,
      nombreLocal: _l.nombre,
      actual: _l.miEstado,
    );
    if (eleccion == null || eleccion.estado == _l.miEstado) return;
    if (eleccion.estado?.va ?? false) HapticFeedback.mediumImpact();
    await _decir(eleccion.estado);
  }

  void _apretar(bool valor) {
    if (_apretada != valor) setState(() => _apretada = valor);
  }

  @override
  Widget build(BuildContext context) {
    final yo = ref.watch(miPerfilProvider).valueOrNull;
    final reducido = MovimientoPrevia.reducido(context);

    // Tu cara entra la primera en cuanto dices que vas: es la confirmacion
    // mas clara de que te has apuntado, y la misma que veran los demas.
    final caras = [
      if (_l.voy && yo != null)
        Cara(id: yo.id, nombre: yo.nombre, avatar: yo.avatarUrl),
      ..._l.caras.where((c) => c.id != yo?.id),
    ];
    // Lo que no cabe en las tres caras de la pastilla va como "+N".
    final resto = (_l.van - caras.take(3).length).clamp(0, 999);
    final lema = _l.lema;

    final alto = _TarjetaLocal.altoBase(context) + widget.extraArriba;

    return Semantics(
      container: true,
      button: true,
      label: [
        _l.nombre,
        ?lema,
        if (widget.metros != null) 'a ${textoDistancia(widget.metros!)}',
      ].join('. '),
      hint: 'Ver quién va, la sala y las entradas',
      onTap: () => _verFicha(context, _l),
      onLongPress: _opciones,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _apretar(true),
        onTapUp: (_) => _apretar(false),
        onTapCancel: () => _apretar(false),
        onTap: () => _verFicha(context, _l),
        onLongPress: _opciones,
        child: SizedBox(
          height: alto,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: FondoLocal(url: _l.portadaUrl, semilla: _l.id),
              ),
              const _Velo(),
              // Al apretar, la foto se apaga un poco: la respuesta al dedo sin
              // encoger la tarjeta, que abriria rendijas entre fotos pegadas.
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _apretada ? 1 : 0,
                  duration: reducido ? Duration.zero : MovimientoPrevia.rapido,
                  curve: MovimientoPrevia.curva,
                  child: const ColoredBox(color: Color(0x33000000)),
                ),
              ),
              Positioned(
                left: EspaciadoPrevia.m + 4,
                right: EspaciadoPrevia.m,
                bottom: EspaciadoPrevia.m + 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MarcaLocal(local: _l),
                          if (lema != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              lema,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _estiloSobreFoto(15, FontWeight.w500),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: EspaciadoPrevia.m),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SelectorVas(
                          estado: _l.miEstado,
                          nombreLocal: _l.nombre,
                          onElegir: _decir,
                          caras: caras,
                          resto: resto,
                          van: _l.van,
                        ),
                        if (_l.aqui > 0 || widget.metros != null) ...[
                          const SizedBox(height: 8),
                          _LineaDeDatos(
                            dentro: _l.aqui,
                            metros: widget.metros,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Como un sello: solo en los sitios a los que vas, porque el
              // juego va de gente que esta en el mismo local.
              if (_l.voy)
                Positioned(
                  top: widget.extraArriba + EspaciadoPrevia.m,
                  right: EspaciadoPrevia.m,
                  child: reducido
                      ? StickerNoHayHuevos(localId: _l.id)
                      : StickerNoHayHuevos(localId: _l.id)
                            .animate()
                            .fadeIn(duration: MovimientoPrevia.rapido)
                            .scale(
                              begin: const Offset(0.85, 0.85),
                              end: const Offset(1, 1),
                              curve: MovimientoPrevia.curva,
                              duration: MovimientoPrevia.normal,
                            ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Texto blanco sobre foto, con una sombra corta que lo sostiene si el velo
/// no basta (una foto con un foco blanco justo debajo, por ejemplo).
TextStyle _estiloSobreFoto(double tamano, FontWeight peso) => TextStyle(
  color: Colors.white,
  fontSize: tamano,
  fontWeight: peso,
  height: 1.2,
  shadows: const [
    Shadow(color: Color(0x73000000), blurRadius: 8, offset: Offset(0, 1)),
  ],
);

/// El degradado que hace legible cualquier foto.
///
/// Un tinte azul de noche en toda la foto y un oscuro que crece hacia abajo,
/// donde va el texto. El tinte unifica fotos de sitios muy distintos (una
/// terraza al sol y un club con laseres) para que la lista se lea como una
/// sola cosa; el oscuro de abajo es el que garantiza el contraste.
class _Velo extends StatelessWidget {
  const _Velo();

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.42, 1],
          colors: [Color(0x2E0A1430), Color(0x520A1430), Color(0xE0040814)],
        ),
      ),
    ),
  );
}

/// La foto de un local, o su version sin foto.
///
/// Sin foto no hay un gris de "imagen no disponible": hay luces de club con
/// los colores de Previa, elegidos por el id para que un local salga siempre
/// igual y dos seguidos rara vez coincidan. Es tambien lo que se ve mientras
/// carga, asi que la foto aparece encima sin salto.
class FondoLocal extends StatelessWidget {
  const FondoLocal({super.key, required this.url, required this.semilla});

  final String? url;
  final String semilla;

  @override
  Widget build(BuildContext context) {
    final luces = _Luces(semilla: semilla);
    if (url == null) return luces;
    final ancho = MediaQuery.sizeOf(context).width;
    final densidad = MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      // Decodificada al ancho de la pantalla: una foto de 4000 px por fila
      // en una lista larga se come la memoria de un movil modesto.
      memCacheWidth: (ancho * densidad).round(),
      fadeInDuration: MovimientoPrevia.reducido(context)
          ? Duration.zero
          : MovimientoPrevia.normal,
      fadeInCurve: MovimientoPrevia.curva,
      placeholder: (_, _) => luces,
      errorWidget: (_, _, _) => luces,
    );
  }
}

class _Luces extends StatelessWidget {
  const _Luces({required this.semilla});

  final String semilla;

  @override
  Widget build(BuildContext context) {
    final n = semilla.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0xFFFF);
    final foco = BloquesPrevia.deIndice(n);
    final contra = BloquesPrevia.deIndice(n + 2);
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF07080C)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.75, -0.7),
            radius: 1.15,
            colors: [foco.withValues(alpha: .55), foco.withValues(alpha: 0)],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.9, 0.9),
              radius: 0.9,
              colors: [
                contra.withValues(alpha: .32),
                contra.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quien es el sitio: su logo si lo tiene, o su nombre en grande.
///
/// El logo dice mas que el nombre (se reconoce sin leer), pero muchos locales
/// no lo tendran; el nombre en Rubik gorda y en mayusculas es la version que
/// siempre funciona y la que se ve si el logo tarda o falla.
class MarcaLocal extends StatelessWidget {
  const MarcaLocal({super.key, required this.local, this.tamano = 32});

  final Local local;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final nombre = Text(
      local.nombre.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      semanticsLabel: local.nombre,
      style: _estiloSobreFoto(tamano, FontWeight.w900).copyWith(
        fontFamily: LetraPrevia.titular,
        height: 1,
        letterSpacing: -0.03 * tamano,
      ),
    );
    final logo = local.logoUrl;
    if (logo == null) return nombre;
    final alto = tamano * 1.45;
    return SizedBox(
      height: alto,
      child: CachedNetworkImage(
        imageUrl: logo,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        // Los logos son pequeños: se decodifican al alto en el que se pintan.
        memCacheHeight: (alto * MediaQuery.devicePixelRatioOf(context)).round(),
        fadeInDuration: MovimientoPrevia.reducido(context)
            ? Duration.zero
            : MovimientoPrevia.rapido,
        placeholder: (_, _) => const SizedBox.shrink(),
        errorWidget: (_, _, _) =>
            Align(alignment: Alignment.centerLeft, child: nombre),
      ),
    );
  }
}

/// "● 4 dentro · 📍 731 m": lo que pasa ahora y lo que cuesta llegar.
class _LineaDeDatos extends StatelessWidget {
  const _LineaDeDatos({required this.dentro, required this.metros});

  final int dentro;
  final double? metros;

  @override
  Widget build(BuildContext context) {
    final estilo = _estiloSobreFoto(14, FontWeight.w600).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dentro > 0) ...[
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              // El verde del oscuro: va sobre foto oscurecida en los dos temas.
              color: Color(0xFF35E07F),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text('$dentro dentro', style: estilo),
        ],
        if (dentro > 0 && metros != null) const SizedBox(width: 12),
        if (metros != null) ...[
          const Icon(
            Icons.location_on_rounded,
            size: 15,
            color: Colors.white,
            shadows: [Shadow(color: Color(0x73000000), blurRadius: 8)],
          ),
          const SizedBox(width: 3),
          Text(textoDistancia(metros!), style: estilo),
        ],
      ],
    );
  }
}

/// Bloques con brillo con la forma de las fotos que van a llegar: a ancho
/// completo y pegados, igual que la lista, para que al cargar nada se mueva.
class _Esqueletos extends StatelessWidget {
  const _Esqueletos({required this.extraPrimera});

  final double extraPrimera;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final reducido = MovimientoPrevia.reducido(context);
    final alto = _TarjetaLocal.altoBase(context);
    return SliverList.builder(
      itemCount: 4,
      itemBuilder: (_, i) {
        final bloque = Container(
          height: alto + (i == 0 ? extraPrimera : 0),
          color: i.isEven ? c.superficie : c.superficieAlta,
        );
        if (reducido) return bloque;
        return bloque
            .animate(onPlay: (a) => a.repeat())
            .shimmer(
              duration: 1400.ms,
              delay: (i * 120).ms,
              color: c.superficieActiva,
            );
      },
    );
  }
}

Future<void> _cambiarCiudad(
  BuildContext context,
  WidgetRef ref,
  String actual,
) async {
  final campo = TextEditingController(text: actual);
  final ciudades = ref.read(repositorioSocialProvider).ciudadesConLocales();
  final nueva = await mostrarHoja<String>(
    context,
    builder: (contexto) => Padding(
      padding: EdgeInsets.fromLTRB(
        EspaciadoPrevia.m,
        0,
        EspaciadoPrevia.m,
        MediaQuery.viewInsetsOf(contexto).bottom +
            MediaQuery.paddingOf(contexto).bottom +
            EspaciadoPrevia.m,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Titular('¿Dónde sales?', tamano: 28),
          const SizedBox(height: EspaciadoPrevia.m),
          // Las ciudades que ya tienen sitios, a un toque: escribir es para
          // cuando la tuya aun no esta.
          FutureBuilder<List<String>>(
            future: ciudades,
            builder: (_, resultado) {
              final lista = resultado.data ?? const <String>[];
              if (lista.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: EspaciadoPrevia.m),
                child: Wrap(
                  spacing: EspaciadoPrevia.s,
                  runSpacing: EspaciadoPrevia.s,
                  children: [
                    for (final c in lista)
                      ChoiceChip(
                        label: Text(c),
                        selected: c.toLowerCase() == actual.toLowerCase(),
                        onSelected: (_) => Navigator.of(contexto).pop(c),
                      ),
                  ],
                ),
              );
            },
          ),
          TextField(
            controller: campo,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.place_outlined),
              hintText: 'Otra ciudad',
            ),
            onSubmitted: (v) => Navigator.of(contexto).pop(v),
          ),
          const SizedBox(height: EspaciadoPrevia.m),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(campo.text),
            child: const Text('VER ESTA NOCHE'),
          ),
        ],
      ),
    ),
  );
  campo.dispose();
  if (nueva != null) ref.read(ciudadDeLaNocheProvider.notifier).fijar(nueva);
}

Future<void> _proponerLocal(
  BuildContext context,
  WidgetRef ref,
  String ciudad,
) async {
  final nombre = TextEditingController();
  final instagram = TextEditingController();
  final mensajero = ScaffoldMessenger.of(context);

  final creado = await mostrarHoja<bool>(
    context,
    builder: (contexto) => Padding(
      padding: EdgeInsets.fromLTRB(
        EspaciadoPrevia.m,
        0,
        EspaciadoPrevia.m,
        MediaQuery.viewInsetsOf(contexto).bottom +
            MediaQuery.paddingOf(contexto).bottom +
            EspaciadoPrevia.m,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Titular('Un sitio nuevo en $ciudad', tamano: 26, lineas: 2),
          const SizedBox(height: EspaciadoPrevia.m),
          TextField(
            controller: nombre,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre del sitio'),
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          TextField(
            controller: instagram,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Instagram (opcional)',
              prefixText: '@',
            ),
          ),
          const SizedBox(height: EspaciadoPrevia.m),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('AÑADIR'),
          ),
        ],
      ),
    ),
  );

  final textoNombre = nombre.text.trim();
  final textoInstagram = instagram.text.trim().replaceAll('@', '');
  nombre.dispose();
  instagram.dispose();
  if (creado != true) return;
  if (textoNombre.length < 2) {
    mensajero.showSnackBar(
      const SnackBar(content: Text('El nombre necesita al menos 2 letras.')),
    );
    return;
  }

  try {
    await ref
        .read(repositorioSocialProvider)
        .crearLocal(
          nombre: textoNombre,
          ciudad: ciudad,
          instagram: textoInstagram.isEmpty ? null : textoInstagram,
        );
    ref.invalidate(localesProvider);
  } catch (_) {
    mensajero.showSnackBar(
      const SnackBar(content: Text('No se ha podido añadir el sitio.')),
    );
  }
}

Future<void> _abrir(String url) async {
  final destino = Uri.tryParse(url);
  if (destino == null) return;
  await launchUrl(destino, mode: LaunchMode.externalApplication);
}

/// La ficha de un local: su foto, quien va agrupado por como va, y la sala.
Future<void> _verFicha(BuildContext context, Local local) {
  return mostrarHoja<void>(
    context,
    arrastrable: true,
    altoInicial: 0.66,
    builder: (_) => _HojaDelLocal(local: local),
  );
}

class _HojaDelLocal extends ConsumerWidget {
  const _HojaDelLocal({required this.local});

  final Local local;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    return FutureBuilder<List<Asistente>>(
      future: ref.read(repositorioSocialProvider).quienVa(local.id),
      builder: (context, resultado) {
        final gente = resultado.data ?? const <Asistente>[];

        return ListView(
          primary: true,
          padding: EdgeInsets.fromLTRB(
            EspaciadoPrevia.m,
            EspaciadoPrevia.m,
            EspaciadoPrevia.m,
            EspaciadoPrevia.l + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: EspaciadoPrevia.m),
                decoration: BoxDecoration(
                  color: c.superficieActiva,
                  borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
                ),
              ),
            ),
            // La misma foto que la tarjeta: al abrir la ficha se sigue
            // mirando el mismo sitio, no un formulario.
            ClipRRect(
              borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
              child: SizedBox(
                height: 168,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FondoLocal(url: local.portadaUrl, semilla: local.id),
                    const _Velo(),
                    Positioned(
                      left: EspaciadoPrevia.m,
                      right: EspaciadoPrevia.m,
                      bottom: EspaciadoPrevia.m,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MarcaLocal(local: local, tamano: 30),
                          if (local.zona != null &&
                              local.zona!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              local.zona!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _estiloSobreFoto(14, FontWeight.w500),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (local.eslogan != null && local.eslogan!.trim().isNotEmpty) ...[
              const SizedBox(height: EspaciadoPrevia.s + 4),
              Text(
                local.eslogan!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            const SizedBox(height: EspaciadoPrevia.m),
            Wrap(
              spacing: EspaciadoPrevia.s,
              runSpacing: EspaciadoPrevia.s,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PantallaSala(
                          localId: local.id,
                          nombreLocal: local.nombre,
                        ),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  icon: const Icon(Icons.forum_rounded, size: 19),
                  label: const Text('SALA'),
                ),
                if (local.tieneEntradas)
                  OutlinedButton.icon(
                    onPressed: () => _abrir(local.urlEntradas!),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                    icon: const Icon(Icons.local_activity_rounded, size: 19),
                    label: const Text('ENTRADA'),
                  ),
                if (local.tieneInstagram)
                  OutlinedButton.icon(
                    onPressed: () =>
                        _abrir('https://instagram.com/${local.instagram}'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                    icon: const Icon(Icons.alternate_email_rounded, size: 19),
                    label: Text(local.instagram!),
                  ),
              ],
            ),
            const SizedBox(height: EspaciadoPrevia.l),
            if (resultado.connectionState == ConnectionState.waiting)
              const Cargando()
            else if (resultado.hasError)
              const EstadoVacio(
                compacto: true,
                icono: Icons.cloud_off_rounded,
                titulo: 'Sin conexión',
                detalle: 'No hemos podido ver quién va.',
              )
            else if (gente.isEmpty)
              const EstadoVacio(
                compacto: true,
                pegatina: '👀',
                titulo: 'Nadie todavía',
                detalle:
                    'Toca "¿Vas?" en la foto y serás la primera cara de la '
                    'lista.',
              )
            else
              for (final estado in EstadoNoche.values)
                ..._grupo(
                  context,
                  estado,
                  gente.where((g) => g.estado == estado).toList(),
                ),
          ],
        );
      },
    );
  }

  List<Widget> _grupo(
    BuildContext context,
    EstadoNoche estado,
    List<Asistente> gente,
  ) {
    if (gente.isEmpty) return const [];
    final titulo = switch (estado) {
      EstadoNoche.aqui => 'Ya están aquí',
      EstadoNoche.voy => 'Van',
      EstadoNoche.tarde => 'Van más tarde',
      EstadoNoche.quiza => 'Quizá',
    };
    return [
      Padding(
        padding: const EdgeInsets.only(
          top: EspaciadoPrevia.s,
          bottom: EspaciadoPrevia.xs,
        ),
        child: Row(
          children: [
            Text(estado.pegatina, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: EspaciadoPrevia.s),
            Titular(titulo, tamano: 18),
            const SizedBox(width: EspaciadoPrevia.s),
            Text(
              '${gente.length}',
              style: TextStyle(
                color: context.colores.textoTenue,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
      for (final p in gente)
        ListTile(
          contentPadding: EdgeInsets.zero,
          minTileHeight: 60,
          onTap: () {
            Navigator.of(context).pop();
            context.push('${Rutas.perfilDe}/${p.id}');
          },
          leading: AvatarPerfil(
            url: p.avatar,
            inicial: p.nombre,
            lado: 46,
            anillo: estado == EstadoNoche.aqui
                ? context.colores.disponible
                : null,
          ),
          title: Text(p.nombre, style: Theme.of(context).textTheme.titleMedium),
          subtitle: p.usuario == null ? null : Text('@${p.usuario}'),
          trailing: p.leSigo
              ? Text(
                  'Le sigues',
                  style: TextStyle(
                    color: context.colores.textoTenue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Icon(Icons.chevron_right, color: context.colores.textoTenue),
        ),
    ];
  }
}
