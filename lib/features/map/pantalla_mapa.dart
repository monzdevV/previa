import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../app/tema.dart';
import '../../core/entorno.dart';
import '../../data/models/previa.dart';
import '../../data/services/servicio_ubicacion.dart';
import '../party/tarjeta_previa.dart';
import 'agrupacion_mapa.dart';
import 'capas_del_mapa.dart';
import 'esqueleto_carga.dart';
import 'hoja_filtros.dart';
import 'proveedores_mapa.dart';

/// Alto del carrusel de tarjetas de abajo.
const _altoCarrusel = 132.0;

/// Ancho de cada tarjeta del carrusel respecto a la pantalla: deja asomar la
/// siguiente para que se entienda que se puede deslizar.
const _fraccionTarjeta = 0.86;

/// Zoom maximo del mapa. A este zoom un grupo ya no se deshace acercando.
const _zoomMaximo = 17.0;

/// Mapa de previas cercanas: mapa, contexto y una accion.
///
/// Arriba una sola pastilla con lo que hay cerca (y los filtros detras). Abajo
/// un carrusel de tarjetas atado al mapa: deslizar una tarjeta lleva la
/// camara a su previa, y tocar una previa en el mapa trae su tarjeta. Asi el
/// mapa no se tapa con una lista y no se llena de botones.
///
/// Las previas se dibujan como **circulos**, no como chinchetas. Una chincheta
/// dice "esta casa exactamente"; un circulo dice "por aqui". Como el servidor
/// solo entrega coordenadas desplazadas unos 300 m, la chincheta seria una
/// mentira. Encima del circulo va una placa con la cara de quien la abre,
/// porque "por aqui hay una previa" dice menos que "por aqui esta Marta".
class PantallaMapa extends ConsumerStatefulWidget {
  const PantallaMapa({super.key, this.onCrearPrevia, this.onAbrirPrevia});

  final VoidCallback? onCrearPrevia;
  final void Function(Previa previa)? onAbrirPrevia;

  @override
  ConsumerState<PantallaMapa> createState() => _PantallaMapaState();
}

class _PantallaMapaState extends ConsumerState<PantallaMapa>
    with TickerProviderStateMixin {
  final _mapa = MapController();
  final _paginas = PageController(viewportFraction: _fraccionTarjeta);

  /// Centro al que ha arrastrado el usuario, todavia sin buscar.
  LatLng? _centroPendiente;
  String? _seleccionada;

  /// El agrupado se rehace al cambiar de zoom entero, no en cada fotograma
  /// del gesto: con eso basta para que las placas no se pisen.
  int _zoomDeAgrupado = 14;
  bool _mapaListo = false;

  AnimationController? _vuelo;

  @override
  void dispose() {
    _vuelo?.dispose();
    _paginas.dispose();
    super.dispose();
  }

  /// Cuanto tapan los controles de abajo: la camara centra en la franja
  /// visible y no en el centro de la pantalla, o la previa quedaria debajo
  /// del carrusel.
  Offset get _desfase {
    final abajo = MediaQuery.paddingOf(context).bottom + _altoCarrusel + 60;
    return Offset(0, -abajo / 2 + 40);
  }

  /// Lleva la camara a [destino] con un vuelo corto en vez de un salto.
  ///
  /// Un salto hace perder la orientacion: no se sabe si la previa estaba al
  /// lado o al otro lado de la ciudad. El vuelo lo cuenta.
  void _volarA(LatLng destino, double zoom) {
    if (!_mapaListo) return;
    final camara = _mapa.camera;
    if (MovimientoPrevia.reducido(context)) {
      _mapa.move(destino, zoom, offset: _desfase);
      return;
    }
    _vuelo?.dispose();
    final vuelo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _vuelo = vuelo;
    final curva = CurvedAnimation(parent: vuelo, curve: MovimientoPrevia.curva);
    final lat = Tween(begin: camara.center.latitude, end: destino.latitude);
    final lng = Tween(begin: camara.center.longitude, end: destino.longitude);
    final z = Tween(begin: camara.zoom, end: zoom);
    // El desfase entra poco a poco: aplicado de golpe, el primer fotograma
    // daba un tiron hacia arriba.
    final desfase = Tween(begin: Offset.zero, end: _desfase);
    vuelo.addListener(() {
      final t = curva.value;
      _mapa.move(
        LatLng(lat.transform(t), lng.transform(t)),
        z.transform(t),
        offset: desfase.transform(t),
      );
    });
    vuelo.forward();
  }

  void _buscarAqui() {
    final punto = _centroPendiente;
    if (punto == null) return;
    HapticFeedback.selectionClick();
    ref.read(centroBusquedaProvider.notifier).fijar(punto);
    setState(() => _centroPendiente = null);
  }

  Future<void> _volverAMiPosicion() async {
    final LatLng posicion;
    try {
      posicion = await ref.refresh(posicionDispositivoProvider.future);
    } catch (_) {
      // El fallo ya lo pinta el aviso de ubicacion, que escucha al mismo
      // proveedor; aqui solo hay que no dejar la excepcion suelta.
      return;
    }
    if (!mounted) return;
    ref.read(centroBusquedaProvider.notifier).fijar(posicion);
    _volarA(posicion, 14);
    setState(() => _centroPendiente = null);
  }

  /// Desde el mapa: se trae su tarjeta al carrusel.
  void _elegirEnMapa(List<Previa> lista, Previa p) {
    HapticFeedback.selectionClick();
    final i = lista.indexWhere((x) => x.id == p.id);
    setState(() => _seleccionada = p.id);
    if (i >= 0 && _paginas.hasClients) {
      _paginas.animateToPage(
        i,
        duration: MovimientoPrevia.normal,
        curve: MovimientoPrevia.curva,
      );
    }
    _volarA(p.ubicacion, math.max(_mapa.camera.zoom, 15));
  }

  /// Desde el carrusel: la camara va a la previa de la tarjeta.
  void _alCambiarTarjeta(List<Previa> lista, int i) {
    if (i >= lista.length) return;
    final p = lista[i];
    if (p.id == _seleccionada) return;
    setState(() => _seleccionada = p.id);
    _volarA(p.ubicacion, math.max(_mapa.camera.zoom, 14.5));
  }

  /// Toque en un grupo: se acerca para deshacerlo. Si el mapa ya no puede
  /// acercarse mas (dos previas en la misma calle), acercar no serviria de
  /// nada y se abren en lista.
  void _abrirGrupo(GrupoPrevias grupo) {
    HapticFeedback.selectionClick();
    final zoom = _mapaListo ? _mapa.camera.zoom : 14.0;
    if (zoom >= _zoomMaximo - 0.5) {
      _verLista(context, grupo.previas, titulo: 'Aquí al lado');
      return;
    }
    _volarA(grupo.centro, math.min(zoom + 2, _zoomMaximo));
  }

  @override
  Widget build(BuildContext context) {
    final posicion = ref.watch(posicionDispositivoProvider);
    final previas = ref.watch(previasCercaProvider);
    final filtros = ref.watch(filtrosProvider);
    final lista = previas.valueOrNull ?? const <Previa>[];

    final centro =
        ref.watch(centroBusquedaProvider) ??
        posicion.valueOrNull ??
        ServicioUbicacion.centroPorDefecto;

    // El mapa arranca en la ciudad por defecto porque la posicion tarda en
    // llegar, y `initialCenter` solo se lee una vez. Cuando llega la primera
    // posicion buena se lleva la camara hasta ella, salvo que el usuario ya
    // haya elegido otra zona a mano.
    ref.listen<AsyncValue<LatLng>>(posicionDispositivoProvider, (antes, ahora) {
      final punto = ahora.valueOrNull;
      if (punto == null || antes?.valueOrNull != null) return;
      if (ref.read(centroBusquedaProvider) != null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapaListo) _volarA(punto, _mapa.camera.zoom);
      });
    });

    // Una busqueda nueva empieza sin nada elegido y con el carrusel al
    // principio: la tarjeta que estaba elegida puede no existir ya.
    ref.listen(previasCercaProvider, (_, ahora) {
      if (!ahora.hasValue) return;
      setState(() => _seleccionada = null);
      if (_paginas.hasClients) _paginas.jumpToPage(0);
    });

    final resumen = previas.when(
      loading: () => 'Buscando previas…',
      error: (_, _) => 'No se ha podido buscar',
      data: (l) => l.isEmpty
          ? 'Nada en ${filtros.radioLegible}'
          : '${l.length} ${l.length == 1 ? "previa" : "previas"} · '
                '${filtros.radioLegible}',
    );
    final grupos = agruparPrevias(lista, _zoomDeAgrupado.toDouble());

    return Scaffold(
      body: Stack(
        children: [
          // El lienzo del mapa es pintura: no dice nada al lector de
          // pantalla. Se etiqueta como un bloque y se remite al carrusel y a
          // la lista, que cuentan lo mismo con texto.
          Semantics(
            label:
                'Mapa de previas cercanas. Las previas también están en las '
                'tarjetas de abajo y en la lista.',
            child: FlutterMap(
              mapController: _mapa,
              options: MapOptions(
                initialCenter: centro,
                initialZoom: 14,
                minZoom: 10,
                maxZoom: _zoomMaximo,
                // Mientras las teselas no llegan, el hueco es el fondo y no un
                // blanco: en una app que se abre de noche ese fogonazo deslumbra.
                backgroundColor: context.colores.fondo,
                onMapReady: () => setState(() => _mapaListo = true),
                onTap: (_, _) => setState(() => _seleccionada = null),
                onPositionChanged: (camara, porGesto) {
                  final z = camara.zoom.floor();
                  if (z != _zoomDeAgrupado) setState(() => _zoomDeAgrupado = z);
                  if (!porGesto) return;
                  final distancia = const Distance().distance(
                    centro,
                    camara.center,
                  );
                  // Solo se ofrece rebuscar si de verdad se ha movido.
                  if (distancia > 500 && _centroPendiente == null) {
                    setState(() => _centroPendiente = camara.center);
                  } else if (distancia > 500) {
                    _centroPendiente = camara.center;
                  }
                },
              ),
              children: [
                ...capasBaseDelMapa(
                  context,
                  proveedor: ref.watch(proveedorTeselasProvider),
                  conAtribucion: false,
                ),

                // Radio de busqueda, en letra de mapa y no en amarillo: el
                // alcance de la busqueda no es una previa con sitio.
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: centro,
                      radius: filtros.radioMetros.toDouble(),
                      useRadiusInMeter: true,
                      color: Colors.transparent,
                      borderColor: context.colores.textoTenue.withValues(
                        alpha: 0.45,
                      ),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),

                // Cada previa, como zona aproximada.
                CircleLayer(
                  circles: [
                    for (final p in lista)
                      CircleMarker(
                        point: p.ubicacion,
                        radius: Entorno.metrosDeDifuminado.toDouble(),
                        useRadiusInMeter: true,
                        color:
                            (p.quedanPlazas
                                    ? context.colores.primario
                                    : context.colores.textoTenue)
                                .withValues(
                                  alpha: _seleccionada == p.id ? 0.3 : 0.14,
                                ),
                        borderColor: _seleccionada == p.id
                            ? context.colores.texto
                            : context.colores.primario.withValues(alpha: 0.5),
                        borderStrokeWidth: _seleccionada == p.id ? 2 : 1,
                      ),
                  ],
                ),

                MarkerLayer(
                  markers: [
                    if (posicion.hasValue)
                      Marker(
                        point: posicion.value!,
                        width: 22,
                        height: 22,
                        child: const _TuPosicion(),
                      ),
                    for (final grupo in grupos)
                      if (!grupo.esAgrupado)
                        Marker(
                          point: grupo.centro,
                          width: 84,
                          height: 50,
                          child: _Aparece(
                            clave: grupo.previas.first.id,
                            child: _Placa(
                              previa: grupo.previas.first,
                              elegida: _seleccionada == grupo.previas.first.id,
                              onTap: () =>
                                  _elegirEnMapa(lista, grupo.previas.first),
                            ),
                          ),
                        )
                      else
                        Marker(
                          point: grupo.centro,
                          width: 56,
                          height: 56,
                          child: _Aparece(
                            clave:
                                'grupo:${grupo.previas.map((p) => p.id).join(',')}',
                            child: _Racimo(
                              cuantas: grupo.previas.length,
                              onTap: () => _abrirGrupo(grupo),
                            ),
                          ),
                        ),
                  ],
                ),
              ],
            ),
          ),

          // Arriba: una sola pastilla. Resume lo que hay y abre los filtros.
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                EspaciadoPrevia.m,
                EspaciadoPrevia.s,
                EspaciadoPrevia.m,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Se anuncia sola al cambiar ("3 previas · 5 km") tras cada
                  // busqueda, y dice que abre los filtros.
                  Semantics(
                    button: true,
                    liveRegion: true,
                    hint: filtros.sonLosPorDefecto
                        ? 'Abre los filtros'
                        : 'Hay filtros puestos. Abre los filtros',
                    child: PastillaCristal(
                      icono: filtros.sonLosPorDefecto
                          ? Icons.tune_rounded
                          : Icons.filter_alt_rounded,
                      texto: resumen,
                      cargando: previas.isLoading,
                      alto: 48,
                      onTap: () => mostrarHojaFiltros(context),
                      desplegable: true,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: MovimientoPrevia.rapido,
                    // Sin recorte de tamaño: el recorte cortaba la sombra del
                    // vidrio y dejaba un rectangulo claro alrededor.
                    transitionBuilder: (hijo, animacion) => FadeTransition(
                      opacity: animacion,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.92, end: 1.0).animate(animacion),
                        alignment: Alignment.topLeft,
                        child: hijo,
                      ),
                    ),
                    child: _centroPendiente == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(
                              top: EspaciadoPrevia.s,
                            ),
                            child: Semantics(
                              button: true,
                              child: PastillaCristal(
                                icono: Icons.search_rounded,
                                texto: 'Buscar en esta zona',
                                alto: 48,
                                onTap: _buscarAqui,
                              ),
                            ),
                          ),
                  ),
                  if (posicion.hasError) ...[
                    const SizedBox(height: EspaciadoPrevia.s),
                    _AvisoUbicacion(
                      error: posicion.error,
                      onReintentar: _volverAMiPosicion,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Abajo: controles del mapa y el carrusel, por encima de la barra
          // de pestañas, que flota sobre esta pantalla.
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + EspaciadoPrevia.s,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: EspaciadoPrevia.m,
                  ),
                  child: Row(
                    children: [
                      if (lista.isNotEmpty)
                        Semantics(
                          button: true,
                          hint: 'Ver todas en lista',
                          child: PastillaCristal(
                            icono: Icons.view_agenda_rounded,
                            texto: 'Lista',
                            alto: 48,
                            onTap: () => _verLista(context, lista),
                          ),
                        ),
                      // Esri pide que se cite el plano. Va aqui, entre los
                      // controles, porque abajo a la izquierda lo taparia el
                      // carrusel.
                      Expanded(
                        child: Text(
                          '© Esri · OpenStreetMap',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            color: context.colores.textoTenue,
                          ),
                        ),
                      ),
                      BotonCristal(
                        icono: Icons.my_location_rounded,
                        etiqueta: 'Volver a mi posición',
                        lado: 48,
                        onTap: _volverAMiPosicion,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: EspaciadoPrevia.s + 2),
                // Esqueleto y carrusel tienen alto fijo para que nada salte
                // al cargar; la tarjeta suelta (vacio, error) crece si la
                // letra del sistema es grande, en vez de cortarse.
                previas.when(
                  loading: () => const SizedBox(
                    height: _altoCarrusel,
                    child: EsqueletoTarjetaMapa(fraccion: _fraccionTarjeta),
                  ),
                  error: (e, _) => _TarjetaSuelta(
                    pegatina: '📡',
                    titulo: 'No hemos podido buscar',
                    detalle: 'Revisa la conexión y vuelve a intentarlo.',
                    accion: 'Reintentar',
                    onAccion: () => ref.invalidate(previasCercaProvider),
                  ),
                  data: (l) => l.isEmpty
                      ? _vacio(filtros)
                      : SizedBox(
                          height: _altoCarrusel,
                          child: PageView.builder(
                            controller: _paginas,
                            itemCount: l.length,
                            onPageChanged: (i) => _alCambiarTarjeta(l, i),
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: EspaciadoPrevia.xs + 1,
                              ),
                              child: _TarjetaMapa(
                                previa: l[i],
                                elegida: _seleccionada == l[i].id,
                                onTap: () => widget.onAbrirPrevia?.call(l[i]),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Nada que ensenar. La salida depende de por que: con filtros puestos lo
  /// mas probable es que sobren; sin filtros, que la zona se quede corta.
  /// Abrir una previa siempre es la otra salida.
  Widget _vacio(Filtros filtros) {
    final notificador = ref.read(filtrosProvider.notifier);
    final abrir = widget.onCrearPrevia;
    final ampliado = math.min(
      filtros.radioMetros * 2,
      Filtros.radioMaximoMetros,
    );
    final puedeAmpliar = filtros.radioMetros < Filtros.radioMaximoMetros;

    if (filtros.hayFiltrosAparteDelRadio) {
      return _TarjetaSuelta(
        pegatina: '🔍',
        titulo: 'Nada con estos filtros',
        detalle: 'Quítalos y mira lo que hay, o abre tú la previa.',
        accion: 'Quitar filtros',
        onAccion: notificador.quitarFiltrosSalvoRadio,
        secundaria: abrir == null ? null : 'Abrir una',
        onSecundaria: abrir,
      );
    }
    final radio = Filtros(radioMetros: ampliado).radioLegible;
    return _TarjetaSuelta(
      pegatina: '🏠',
      titulo: 'Nada por aquí',
      detalle: puedeAmpliar
          ? '¿Abres tú la previa? O mira hasta $radio.'
          : '¿Abres tú la previa y que venga la gente?',
      accion: abrir == null ? null : 'Abrir una',
      onAccion: abrir,
      secundaria: puedeAmpliar ? 'Ampliar a $radio' : null,
      onSecundaria: puedeAmpliar
          ? () => notificador.fijarRadio(ampliado)
          : null,
    );
  }

  Future<void> _verLista(
    BuildContext context,
    List<Previa> lista, {
    String titulo = 'Cerca de ti',
  }) {
    final reducido = MovimientoPrevia.reducido(context);
    return mostrarHoja<void>(
      context,
      arrastrable: true,
      altoInicial: 0.75,
      builder: (contexto) => ListView(
        primary: true,
        padding: EdgeInsets.fromLTRB(
          EspaciadoPrevia.m,
          EspaciadoPrevia.l,
          EspaciadoPrevia.m,
          EspaciadoPrevia.l + MediaQuery.paddingOf(contexto).bottom,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Titular(titulo, tamano: 30),
                ),
              ),
              if (widget.onCrearPrevia != null)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(contexto).pop();
                    widget.onCrearPrevia!();
                  },
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('ABRIR'),
                ),
            ],
          ),
          const SizedBox(height: EspaciadoPrevia.xs),
          Text(
            lista.length == 1 ? '1 previa' : '${lista.length} previas',
            style: TextStyle(
              color: contexto.colores.textoSuave,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: EspaciadoPrevia.m),
          for (final (i, p) in lista.indexed)
            _entrada(
              reducido: reducido,
              indice: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: EspaciadoPrevia.m),
                child: TarjetaPrevia(
                  previa: p,
                  compacta: true,
                  onTap: () {
                    Navigator.of(contexto).pop();
                    widget.onAbrirPrevia?.call(p);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Las tarjetas de la lista caen en cascada al abrirla, solo las primeras
/// (ver [MovimientoPrevia.retrasoDe]). Con movimiento reducido, aparecen.
Widget _entrada({
  required bool reducido,
  required int indice,
  required Widget child,
}) {
  if (reducido || indice > 6) return child;
  return child
      .animate(delay: MovimientoPrevia.retrasoDe(indice))
      .fadeIn(duration: const Duration(milliseconds: 220))
      .moveY(
        begin: 10,
        end: 0,
        duration: const Duration(milliseconds: 220),
        curve: MovimientoPrevia.curva,
      );
}

/// Entrada de un marcador la primera vez que aparece: sube de 0.85 y se
/// funde, sin rebote. La clave es la previa (o el grupo): si el mapa se
/// redibuja con lo mismo no se repite. Con movimiento reducido, aparece.
class _Aparece extends StatelessWidget {
  const _Aparece({required this.clave, required this.child});

  final String clave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MovimientoPrevia.reducido(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(clave),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: MovimientoPrevia.curva,
      builder: (context, t, hijo) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: hijo),
      ),
      child: child,
    );
  }
}

/// Tu posicion: un punto blanco con halo, en letra de mapa y no en amarillo,
/// que esta reservado a las previas con sitio.
class _TuPosicion extends StatelessWidget {
  const _TuPosicion();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.colores.texto.withValues(alpha: 0.18),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: context.colores.texto,
        shape: BoxShape.circle,
        border: Border.all(color: context.colores.fondo, width: 2),
      ),
    ),
  );
}

/// La placa de una previa: la cara de quien la abre y las plazas que quedan.
class _Placa extends StatelessWidget {
  const _Placa({
    required this.previa,
    required this.elegida,
    required this.onTap,
  });

  final Previa previa;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final ocupacion = Ocupacion.desde(previa.plazasLibres);
    final viva = ocupacion.viva;
    final fondo = viva ? ocupacion.color(c) : c.superficieAlta;
    final tinta = viva ? const Color(0xFF07130C) : c.textoTenue;

    return Semantics(
      button: true,
      // Cada placa es su propio nodo y no se funde con la etiqueta del mapa.
      container: true,
      selected: elegida,
      label:
          '${previa.titulo}, de ${previa.anfitrionNombre}. '
          '${viva ? (previa.plazasLibres == 1 ? 'Queda 1 plaza' : 'Quedan ${previa.plazasLibres} plazas') : 'Completa'}',
      hint: 'Toca para verla en el carrusel',
      excludeSemantics: true,
      onTap: onTap,
      child: Pulsable(
        onTap: onTap,
        escala: 0.94,
        // La vibracion ya la da quien elige la previa.
        vibrar: false,
        // Placa de tamano fijo sobre el mapa: si la letra del sistema crece
        // sin limite el numero se sale. Se acota solo aqui.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Center(
            child: AnimatedScale(
              scale: elegida ? 1.15 : 1,
              duration: MovimientoPrevia.rapido,
              curve: MovimientoPrevia.curva,
              child: Container(
                padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
                decoration: BoxDecoration(
                  color: fondo,
                  borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
                  border: Border.all(
                    color: elegida ? c.texto : Colors.black26,
                    width: elegida ? 2.5 : 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AvatarPerfil(
                      url: previa.anfitrionAvatar,
                      inicial: previa.anfitrionNombre,
                      lado: 26,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      viva ? '${previa.plazasLibres}' : 'Llena',
                      style: TextStyle(
                        color: tinta,
                        fontFamily: LetraPrevia.titular,
                        fontWeight: FontWeight.w900,
                        fontSize: viva ? 16 : 12,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Varias previas que a este zoom se pisarian. Tocar acerca la camara (o,
/// si ya no se puede acercar mas, las abre en lista).
class _Racimo extends StatelessWidget {
  const _Racimo({required this.cuantas, required this.onTap});

  final int cuantas;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Semantics(
      button: true,
      container: true,
      label: '$cuantas previas juntas',
      hint: 'Toca para verlas',
      excludeSemantics: true,
      onTap: onTap,
      child: Pulsable(
        onTap: onTap,
        escala: 0.94,
        vibrar: false,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.primario,
            shape: BoxShape.circle,
            border: Border.all(color: c.fondo, width: 3),
            boxShadow: [
              BoxShadow(
                color: c.primario.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  '$cuantas',
                  style: TextStyle(
                    fontFamily: LetraPrevia.titular,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: c.sobrePrimario,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La tarjeta de una previa en el carrusel del mapa.
///
/// Lo que decide si caminar hasta alli, en este orden: a que hora, quien la
/// abre, cuanto queda y si hay sitio. La descripcion se lee en el detalle.
class _TarjetaMapa extends StatelessWidget {
  const _TarjetaMapa({
    required this.previa,
    required this.elegida,
    required this.onTap,
  });

  final Previa previa;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final hora = DateFormat('HH:mm', 'es_ES').format(previa.empiezaEn);
    final ocupacion = Ocupacion.desde(previa.plazasLibres);

    final plazas = switch (ocupacion) {
      Ocupacion.completa => 'Completa',
      _ when previa.plazasLibres == 1 => 'Queda 1 plaza',
      _ => 'Quedan ${previa.plazasLibres} plazas',
    };
    final donde = previa.distanciaLegible.isEmpty
        ? previa.zona
        : '${previa.zona}, a ${previa.distanciaLegible}';

    // Una sola frase en el orden en que se decide (cuando, que, quien,
    // donde, sitio), en lugar de leer cada texto suelto de la tarjeta.
    return Semantics(
      button: true,
      selected: elegida,
      label:
          '${previa.cuandoEmpieza}, a las $hora. ${previa.titulo}. '
          'Abre ${previa.anfitrionNombre}. $donde. $plazas',
      hint: 'Toca para ver la previa',
      excludeSemantics: true,
      onTap: onTap,
      child: Pulsable(
        onTap: onTap,
        escala: 0.97,
        child: AnimatedContainer(
          duration: MovimientoPrevia.rapido,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
            border: Border.all(
              color: elegida ? c.primario : Colors.transparent,
              width: 2,
            ),
          ),
          child: Cristal(
            radio: EspaciadoPrevia.radioGrande - 2,
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 104,
                    height: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _Portada(previa: previa),
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(
                                EspaciadoPrevia.pastilla,
                              ),
                            ),
                            child: Text(
                              previa.distanciaLegible.isEmpty
                                  ? previa.zona
                                  : previa.distanciaLegible,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Titular(hora, tamano: 24),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              previa.cuandoEmpieza,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textoSuave,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        previa.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.texto,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${previa.anfitrionNombre} · ${previa.zona}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textoSuave, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      _Plazas(
                        ocupacion: ocupacion,
                        libres: previa.plazasLibres,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Portada extends StatelessWidget {
  const _Portada({required this.previa});

  final Previa previa;

  @override
  Widget build(BuildContext context) {
    final foto = previa.anfitrionAvatar;
    if (foto != null && foto.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: foto,
        fit: BoxFit.cover,
        memCacheWidth: 300,
        placeholder: (_, _) =>
            ColoredBox(color: context.colores.superficieActiva),
        errorWidget: (_, _, _) => _PortadaSinFoto(previa: previa),
      );
    }
    return _PortadaSinFoto(previa: previa);
  }
}

class _PortadaSinFoto extends StatelessWidget {
  const _PortadaSinFoto({required this.previa});

  final Previa previa;

  @override
  Widget build(BuildContext context) {
    final letra = previa.anfitrionNombre.trim().isEmpty
        ? '?'
        : previa.anfitrionNombre.trim()[0].toUpperCase();
    return ColoredBox(
      color: BloquesPrevia.deIndice(previa.anfitrionNombre.hashCode.abs()),
      child: Center(
        child: Text(
          letra,
          style: const TextStyle(
            fontFamily: LetraPrevia.titular,
            fontWeight: FontWeight.w900,
            fontSize: 52,
            color: BloquesPrevia.tintaSobreBloque,
          ),
        ),
      ),
    );
  }
}

class _Plazas extends StatelessWidget {
  const _Plazas({required this.ocupacion, required this.libres});

  final Ocupacion ocupacion;
  final int libres;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final texto = switch (ocupacion) {
      Ocupacion.completa => 'Completa',
      _ when libres == 1 => 'Queda 1 plaza',
      _ => 'Quedan $libres plazas',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: ocupacion.color(c),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ocupacion.viva ? ocupacion.color(c) : c.textoTenue,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              decoration: ocupacion.viva ? null : TextDecoration.lineThrough,
            ),
          ),
        ),
      ],
    );
  }
}

/// Una sola tarjeta en lugar del carrusel: vacio, error o lo que haga falta
/// contar sin lista.
///
/// Con una accion, el boton va a la derecha. Con dos, van debajo del texto:
/// la principal en amarillo y la otra como texto, para que solo haya un
/// amarillo que mirar. Mide como minimo lo que el carrusel, para que el
/// cambio de estado no haga saltar los controles de encima; con letra grande
/// crece en vez de cortarse.
class _TarjetaSuelta extends StatelessWidget {
  const _TarjetaSuelta({
    required this.pegatina,
    required this.titulo,
    required this.detalle,
    this.accion,
    this.onAccion,
    this.secundaria,
    this.onSecundaria,
  });

  final String pegatina;
  final String titulo;
  final String detalle;
  final String? accion;
  final VoidCallback? onAccion;
  final String? secundaria;
  final VoidCallback? onSecundaria;

  @override
  Widget build(BuildContext context) {
    final principal = accion != null && onAccion != null
        ? FilledButton(
            onPressed: onAccion,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(accion!.toUpperCase()),
          )
        : null;
    final otra = secundaria != null && onSecundaria != null
        ? TextButton(
            onPressed: onSecundaria,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 44),
              foregroundColor: context.colores.primarioTexto,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(secundaria!),
          )
        : null;
    final texto = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Titular(titulo, tamano: 20),
        const SizedBox(height: 4),
        Text(
          detalle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.colores.textoSuave, fontSize: 13),
        ),
        // Con accion secundaria, los botones van debajo del texto.
        if (otra != null) ...[
          const SizedBox(height: EspaciadoPrevia.s),
          Wrap(
            spacing: EspaciadoPrevia.xs,
            runSpacing: EspaciadoPrevia.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [?principal, otra],
          ),
        ],
      ],
    );

    final tarjeta = Padding(
      padding: const EdgeInsets.symmetric(horizontal: EspaciadoPrevia.m),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _altoCarrusel),
        child: Cristal(
          radio: EspaciadoPrevia.radioGrande,
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Pegatina(pegatina, tamano: 40, giro: -0.12),
              ),
              const SizedBox(width: EspaciadoPrevia.m),
              Expanded(child: texto),
              if (principal != null && otra == null) ...[
                const SizedBox(width: EspaciadoPrevia.s),
                principal,
              ],
            ],
          ),
        ),
      ),
    );

    // Se anuncia al aparecer: quien no ve el mapa se entera de que no hay
    // nada (o de que ha fallado) sin tener que ir a buscarlo.
    final anunciada = Semantics(
      liveRegion: true,
      container: true,
      child: tarjeta,
    );
    if (MovimientoPrevia.reducido(context)) return anunciada;
    return anunciada
        .animate()
        .fadeIn(duration: MovimientoPrevia.rapido)
        .moveY(
          begin: 12,
          end: 0,
          duration: const Duration(milliseconds: 220),
          curve: MovimientoPrevia.curva,
        );
  }
}

class _AvisoUbicacion extends ConsumerWidget {
  const _AvisoUbicacion({required this.error, required this.onReintentar});

  final Object? error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = error;
    final mensaje = e is ErrorUbicacion
        ? e.mensaje
        : 'No hemos podido situarte.';
    final vaAAjustes =
        e is ErrorUbicacion &&
        e.causa == FalloUbicacion.permisoDenegadoParaSiempre;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Cristal(
        radio: EspaciadoPrevia.radio,
        padding: const EdgeInsets.fromLTRB(
          EspaciadoPrevia.m,
          EspaciadoPrevia.s,
          EspaciadoPrevia.xs,
          EspaciadoPrevia.s,
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 18,
              color: context.colores.aviso,
            ),
            const SizedBox(width: EspaciadoPrevia.s),
            Expanded(
              child: Text(
                '$mensaje Mueve el mapa a mano para buscar.',
                style: TextStyle(color: context.colores.texto, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: vaAAjustes
                  ? () => ref.read(servicioUbicacionProvider).abrirAjustes()
                  : onReintentar,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: context.colores.primarioTexto,
              ),
              child: Text(vaAAjustes ? 'Abrir ajustes' : 'Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
