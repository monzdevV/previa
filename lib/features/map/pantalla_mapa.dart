import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app/tema.dart';
import '../../core/entorno.dart';
import '../../data/models/previa.dart';
import '../../data/services/servicio_ubicacion.dart';
import '../party/estados_pantalla.dart';
import '../party/tarjeta_previa.dart';
import 'agrupacion_mapa.dart';
import 'esqueleto_carga.dart';
import 'filtros_rapidos.dart';
import 'hoja_filtros.dart';
import 'proveedores_mapa.dart';

/// Mapa de previas cercanas.
///
/// La decision visual importante: las previas se dibujan como **circulos**,
/// no como chinchetas. Una chincheta dice "esta casa exactamente"; un circulo
/// dice "por aqui". Como el servidor solo entrega coordenadas desplazadas
/// unos 300 m, la chincheta seria una mentira. El circulo es honesto y ademas
/// le explica al usuario, sin texto, por que no puede ver el portal.
class PantallaMapa extends ConsumerStatefulWidget {
  const PantallaMapa({
    super.key,
    this.onCrearPrevia,
    this.onAbrirPrevia,
    this.conTeselas = true,
  });

  /// Desactivarlo evita peticiones de red a CARTO; solo lo usan los tests de
  /// widget, donde no hay conexión y las teselas fallarían con ruido.
  final bool conTeselas;

  final VoidCallback? onCrearPrevia;
  final void Function(Previa previa)? onAbrirPrevia;

  @override
  ConsumerState<PantallaMapa> createState() => _PantallaMapaState();
}

class _PantallaMapaState extends ConsumerState<PantallaMapa> {
  final _mapa = MapController();

  /// Centro al que ha arrastrado el usuario, todavia sin buscar.
  LatLng? _centroPendiente;
  String? _previaResaltada;

  /// Zoom actual (redondeado a medios pasos). Se guarda para decidir si se
  /// agrupan las previas; redondear evita reconstruir en cada fotograma de
  /// un gesto de pellizco.
  double _zoom = 14;

  void _buscarAqui() {
    final punto = _centroPendiente;
    if (punto == null) return;
    ref.read(centroBusquedaProvider.notifier).fijar(punto);
    setState(() => _centroPendiente = null);
  }

  void _abrir(Previa p) {
    setState(() => _previaResaltada = p.id);
    widget.onAbrirPrevia?.call(p);
  }

  Future<void> _volverAMiPosicion() async {
    final posicion = await ref.refresh(posicionDispositivoProvider.future);
    ref.read(centroBusquedaProvider.notifier).fijar(posicion);
    _mapa.move(posicion, 14);
    setState(() => _centroPendiente = null);
  }

  Color _colorDe(Previa p) =>
      _previaResaltada == p.id ? ColoresPrevia.acento : ColoresPrevia.primario;

  /// Acerca el mapa a un grupo para que se deshaga en previas sueltas. Se
  /// acerca un tramo fijo y no "hasta encajar" para que el gesto sea predecible.
  void _acercarAGrupo(GrupoPrevias g) {
    _mapa.move(g.centro, (_zoom + 2).clamp(10, 17).toDouble());
  }

  Marker _marcadorGrupo(GrupoPrevias g) {
    final n = g.previas.length;
    return Marker(
      point: g.centro,
      width: 56,
      height: 56,
      child: Semantics(
        button: true,
        container: true,
        label: '$n previas en esta zona',
        hint: 'Toca para acercar el mapa',
        onTap: () => _acercarAGrupo(g),
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _acercarAGrupo(g),
            child: _Aparece(
              clave: 'g${g.centro.latitude}${g.centro.longitude}$n',
              child: _BurbujaGrupo(cantidad: n),
            ),
          ),
        ),
      ),
    );
  }

  Marker _marcadorPrevia(Previa p) {
    // 48x48: objetivo táctil mínimo. La burbuja dibujada es más pequeña (34)
    // y va centrada dentro.
    return Marker(
      point: p.ubicacion,
      width: 48,
      height: 48,
      child: Semantics(
        button: true,
        // container: cada previa es un nodo propio y no se funde con la
        // etiqueta del mapa que la rodea.
        container: true,
        label: etiquetaAccesiblePrevia(p),
        onTap: () => _abrir(p),
        // El número suelto de la burbuja no dice nada; se sustituye por la
        // frase completa.
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _abrir(p),
            child: _Aparece(
              clave: p.id,
              child: _BurbujaPlazas(
                plazas: p.plazasLibres,
                resaltada: _previaResaltada == p.id,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posicion = ref.watch(posicionDispositivoProvider);
    final previas = ref.watch(previasCercaProvider);
    final filtros = ref.watch(filtrosProvider);
    final grupos = agruparPrevias(
      previas.valueOrNull ?? const <Previa>[],
      _zoom,
    );

    final centro =
        ref.watch(centroBusquedaProvider) ??
        posicion.valueOrNull ??
        ServicioUbicacion.centroPorDefecto;

    return Scaffold(
      body: Stack(
        children: [
          // El lienzo del mapa no genera nodos semánticos por sí mismo (los
          // círculos son pintura). Se etiqueta como un bloque y se remite a la
          // lista, que es la alternativa accesible completa; las burbujas de
          // cada previa sí son botones con etiqueta propia.
          Semantics(
            label:
                'Mapa de previas cercanas. La lista completa de previas '
                'está en el panel inferior.',
            child: FlutterMap(
              mapController: _mapa,
              options: MapOptions(
                initialCenter: centro,
                initialZoom: 14,
                minZoom: 10,
                maxZoom: 17,
                onPositionChanged: (camara, porGesto) {
                  final zoom = (camara.zoom * 2).round() / 2;
                  if (zoom != _zoom) setState(() => _zoom = zoom);
                  if (!porGesto) return;
                  final destino = camara.center;
                  final distancia = const Distance().distance(centro, destino);
                  // Solo se ofrece rebuscar si de verdad se ha movido.
                  if (distancia > 500) {
                    setState(() => _centroPendiente = destino);
                  }
                },
              ),
              children: [
                if (widget.conTeselas)
                  TileLayer(
                    // Teselas oscuras de CARTO: casan con el tema de la aplicacion
                    // y no exigen clave de API ni tarjeta.
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c'],
                    retinaMode: RetinaMode.isHighDensity(context),
                    userAgentPackageName: 'com.previa.previa',
                  ),

                // Radio de busqueda
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: centro,
                      radius: filtros.radioMetros.toDouble(),
                      useRadiusInMeter: true,
                      color: ColoresPrevia.primario.withValues(alpha: 0.05),
                      borderColor: ColoresPrevia.primario.withValues(
                        alpha: 0.25,
                      ),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),

                // Cada previa, como zona aproximada. Dos capas: un halo amplio y
                // muy suave (da sensacion de "por aqui" sin bordes duros) y el
                // nucleo con borde fino. Siguen siendo circulos y no chinchetas:
                // la ubicacion esta desplazada ~300 m a proposito.
                CircleLayer(
                  circles: [
                    for (final g in grupos)
                      if (g.esAgrupado)
                        CircleMarker(
                          point: g.centro,
                          radius: Entorno.metrosDeDifuminado * 1.8,
                          useRadiusInMeter: true,
                          color: ColoresPrevia.primario.withValues(alpha: 0.14),
                          borderColor: ColoresPrevia.primarioSuave.withValues(
                            alpha: 0.5,
                          ),
                          borderStrokeWidth: 1.5,
                        )
                      else ...[
                        CircleMarker(
                          point: g.centro,
                          radius: Entorno.metrosDeDifuminado * 1.7,
                          useRadiusInMeter: true,
                          color: _colorDe(g.previas.first)
                              .withValues(alpha: 0.09),
                        ),
                        CircleMarker(
                          point: g.centro,
                          radius: Entorno.metrosDeDifuminado.toDouble(),
                          useRadiusInMeter: true,
                          color: _colorDe(g.previas.first)
                              .withValues(alpha: 0.24),
                          borderColor: _previaResaltada == g.previas.first.id
                              ? ColoresPrevia.acento
                              : ColoresPrevia.primarioSuave,
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                  ],
                ),

                MarkerLayer(
                  markers: [
                    if (posicion.hasValue)
                      Marker(
                        point: posicion.value!,
                        width: 18,
                        height: 18,
                        child: Semantics(
                          label: 'Tu posición aproximada',
                          container: true,
                          image: true,
                          child: Container(
                            decoration: BoxDecoration(
                              color: ColoresPrevia.acento,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    for (final g in grupos)
                      if (g.esAgrupado)
                        _marcadorGrupo(g)
                      else
                        _marcadorPrevia(g.previas.first),
                  ],
                ),

                const RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: [
                    TextSourceAttribution('OpenStreetMap · CARTO'),
                  ],
                ),
              ],
            ),
          ),

          // Barra superior
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    EspaciadoPrevia.m,
                    EspaciadoPrevia.m,
                    EspaciadoPrevia.m,
                    EspaciadoPrevia.s,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PastillaResumen(
                          texto: previas.when(
                            loading: () => 'Buscando previas…',
                            error: (_, _) => 'No se ha podido buscar',
                            data: (lista) => lista.isEmpty
                                ? 'Nada por aquí ahora mismo'
                                : '${lista.length} '
                                      '${lista.length == 1 ? "previa" : "previas"} '
                                      'en ${filtros.radioLegible}',
                          ),
                          cargando: previas.isLoading,
                        ),
                      ),
                      const SizedBox(width: EspaciadoPrevia.s),
                      _BotonFiltros(
                        activos: !filtros.sonLosPorDefecto,
                        onTap: () => mostrarHojaFiltros(context),
                      ),
                    ],
                  ),
                ),
                // Atajos de filtro: lo habitual a un toque, sin abrir la hoja.
                const FiltrosRapidos(),
              ],
            ),
          ),

          // "Buscar en esta zona"
          if (_centroPendiente != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 136,
              left: 0,
              right: 0,
              child: Center(
                child: FilledButton.icon(
                  onPressed: _buscarAqui,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Buscar en esta zona'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: EspaciadoPrevia.l,
                    ),
                  ),
                ),
              ),
            ),

          // Si la ubicacion ha fallado, se explica y se ofrece salida.
          if (posicion.hasError)
            Positioned(
              left: EspaciadoPrevia.m,
              right: EspaciadoPrevia.m,
              top: MediaQuery.of(context).padding.top + 136,
              child: _AvisoUbicacion(
                error: posicion.error,
                onReintentar: _volverAMiPosicion,
              ),
            ),

          _ListaInferior(
            previas: previas,
            onTocar: (p) {
              _mapa.move(p.ubicacion, 15);
              _abrir(p);
            },
            onCrearPrevia: widget.onCrearPrevia,
          ),
        ],
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'miPosicion',
            tooltip: 'Centrar en mi posición',
            backgroundColor: ColoresPrevia.superficieAlta,
            foregroundColor: ColoresPrevia.texto,
            onPressed: _volverAMiPosicion,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          FloatingActionButton.extended(
            heroTag: 'crearPrevia',
            backgroundColor: ColoresPrevia.primario,
            foregroundColor: Colors.white,
            onPressed: widget.onCrearPrevia,
            icon: const Icon(Icons.add),
            label: const Text('Abrir previa'),
          ),
        ],
      ),
    );
  }
}

/// Burbuja sobre el mapa con el numero de plazas libres.
///
/// Es puramente visual: la semántica (botón + frase completa) la pone quien la
/// usa, por eso no expone nada por sí misma.
class _BurbujaPlazas extends StatelessWidget {
  const _BurbujaPlazas({required this.plazas, required this.resaltada});

  final int plazas;
  final bool resaltada;

  @override
  Widget build(BuildContext context) {
    final color = resaltada ? ColoresPrevia.acento : ColoresPrevia.primario;

    return Center(
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.55),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        // El círculo tiene tamaño fijo: si el usuario sube el tamaño de letra
        // del sistema, el número se desbordaría y se recortaría. Se limita el
        // escalado solo aquí (el resto de la app sí respeta el ajuste) y se
        // deja que FittedBox lo encoja si aun así no cabe.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: Center(
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Text(
                  '$plazas',
                  style: TextStyle(
                    color: resaltada ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
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

/// Pastilla de resumen de la parte superior del mapa.
///
/// Altura MÍNIMA de 48 y no fija: con un tamaño de letra grande el texto
/// pasa a dos líneas y la pastilla crece en vez de recortarlo.
class _PastillaResumen extends StatelessWidget {
  const _PastillaResumen({required this.texto, required this.cargando});

  final String texto;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Se anuncia sola cuando cambia ("3 previas en 5 km") tras buscar.
      liveRegion: true,
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: EspaciadoPrevia.m,
          vertical: EspaciadoPrevia.s,
        ),
        decoration: BoxDecoration(
          color: ColoresPrevia.superficie.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
          border: Border.all(color: ColoresPrevia.borde),
          boxShadow: ElevacionPrevia.flotante,
        ),
        child: Row(
          children: [
            // El texto ya dice "Buscando previas…", así que el icono o el
            // indicador se ocultan al lector para no duplicar.
            ExcludeSemantics(
              child: cargando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ColoresPrevia.primarioSuave,
                      ),
                    )
                  : const Icon(
                      Icons.nightlife,
                      size: 18,
                      color: ColoresPrevia.primarioSuave,
                    ),
            ),
            const SizedBox(width: EspaciadoPrevia.s),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(
                  color: ColoresPrevia.texto,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón de filtros. Es un IconButton (no un InkWell a mano) para heredar
/// foco de teclado, 48 dp de área y el tooltip, que además es su etiqueta
/// para el lector de pantalla.
class _BotonFiltros extends StatelessWidget {
  const _BotonFiltros({required this.activos, required this.onTap});

  final bool activos;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: activos ? 'Filtros (hay filtros activos)' : 'Filtros',
      onPressed: onTap,
      icon: const Icon(Icons.tune, size: 20),
      style: IconButton.styleFrom(
        fixedSize: const Size(48, 48),
        backgroundColor: activos
            ? ColoresPrevia.primario
            : ColoresPrevia.superficie.withValues(alpha: 0.96),
        foregroundColor: activos ? Colors.white : ColoresPrevia.texto,
        side: BorderSide(
          color: activos ? ColoresPrevia.primario : ColoresPrevia.bordeCampo,
        ),
      ),
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

    return Container(
      padding: const EdgeInsets.all(EspaciadoPrevia.m),
      decoration: BoxDecoration(
        color: ColoresPrevia.superficie,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        border: Border.all(color: ColoresPrevia.aviso.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_off_outlined,
                size: 18,
                color: ColoresPrevia.aviso,
              ),
              const SizedBox(width: EspaciadoPrevia.s),
              Expanded(
                child: Text(
                  mensaje,
                  style: const TextStyle(
                    color: ColoresPrevia.texto,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: EspaciadoPrevia.xs),
          const Text(
            'Puedes seguir moviendo el mapa a mano y buscar por zona.',
            style: TextStyle(color: ColoresPrevia.textoSuave, fontSize: 12),
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: vaAAjustes
                  ? () => ref.read(servicioUbicacionProvider).abrirAjustes()
                  : onReintentar,
              child: Text(vaAAjustes ? 'Abrir ajustes' : 'Reintentar'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Listado deslizable sobre el mapa.
///
/// Es la alternativa accesible al mapa: contiene todas las previas con sus
/// datos completos y se puede recorrer con el lector de pantalla sin tocar
/// el lienzo.
class _ListaInferior extends ConsumerStatefulWidget {
  const _ListaInferior({
    required this.previas,
    required this.onTocar,
    this.onCrearPrevia,
  });

  final AsyncValue<List<Previa>> previas;
  final void Function(Previa) onTocar;
  final VoidCallback? onCrearPrevia;

  @override
  ConsumerState<_ListaInferior> createState() => _ListaInferiorState();
}

class _ListaInferiorState extends ConsumerState<_ListaInferior> {
  static const _tamanoInicial = 0.26;
  static const _tamanoMaximo = 0.82;

  final _hoja = DraggableScrollableController();

  /// Previas cuya tarjeta ya se animo al entrar (ver itemBuilder).
  final _vistas = <String>{};

  /// Un estado vacío o de error lleva botones de acción: a la altura inicial
  /// quedarían fuera de pantalla y habría que adivinar que se puede
  /// desplazar. Por eso la hoja se abre hasta la mitad cuando aparece uno.
  static const _tamanoConAcciones = 0.5;

  static bool _pideAcciones(AsyncValue<List<Previa>> v) =>
      v.hasError || (v.hasValue && v.value!.isEmpty);

  @override
  void initState() {
    super.initState();
    if (_pideAcciones(widget.previas)) _abrirParaAcciones();
  }

  @override
  void didUpdateWidget(covariant _ListaInferior anterior) {
    super.didUpdateWidget(anterior);
    if (_pideAcciones(widget.previas) && !_pideAcciones(anterior.previas)) {
      _abrirParaAcciones();
    }
  }

  void _abrirParaAcciones() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hoja.isAttached) return;
      if (_hoja.size < _tamanoConAcciones) {
        _hoja.animateTo(
          _tamanoConAcciones,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _hoja.dispose();
    super.dispose();
  }

  /// Arrastrar la agarradera no es posible con lector de pantalla ni con
  /// teclado; un toque alterna entre tamaño inicial y ampliado.
  void _alternar() {
    if (!_hoja.isAttached) return;
    final ampliar = _hoja.size < (_tamanoInicial + _tamanoMaximo) / 2;
    _hoja.animateTo(
      ampliar ? _tamanoMaximo : _tamanoInicial,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtros = ref.watch(filtrosProvider);

    return DraggableScrollableSheet(
      controller: _hoja,
      initialChildSize: _tamanoInicial,
      minChildSize: 0.12,
      maxChildSize: _tamanoMaximo,
      builder: (context, controlador) {
        return Container(
          decoration: const BoxDecoration(
            color: ColoresPrevia.fondo,
            boxShadow: ElevacionPrevia.hoja,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(EspaciadoPrevia.radioGrande),
            ),
            border: Border(top: BorderSide(color: ColoresPrevia.borde)),
          ),
          child: Column(
            children: [
              // Agarradera: 48 dp de alto para poder pulsarla.
              Semantics(
                button: true,
                label: 'Lista de previas cercanas',
                hint: 'Toca para ampliar o reducir la lista',
                excludeSemantics: true,
                onTap: _alternar,
                child: InkWell(
                  onTap: _alternar,
                  child: SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ColoresPrevia.bordeCampo,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: widget.previas.when(
                  loading: () => EsqueletoPrevias(controlador: controlador),
                  error: (e, _) => EstadoError(
                    controlador: controlador,
                    mensaje: 'No se ha podido buscar',
                    detalle: 'Comprueba tu conexión e inténtalo otra vez.',
                    onReintentar: () => ref.invalidate(previasCercaProvider),
                  ),
                  data: (lista) => lista.isEmpty
                      ? EstadoVacio(
                          controlador: controlador,
                          compacto: true,
                          icono: Icons.nightlife_outlined,
                          titulo: 'Nada por aquí ahora mismo',
                          detalle:
                              'Sé la primera persona en abrir una previa '
                              'y que venga la gente, o busca más lejos.',
                          acciones: [
                            if (widget.onCrearPrevia != null)
                              FilledButton.icon(
                                onPressed: widget.onCrearPrevia,
                                icon: const Icon(Icons.add),
                                label: const Text('Abrir una previa'),
                              ),
                            ..._accionesDeBusqueda(filtros),
                            const MensajeResponsable(),
                          ],
                        )
                      : ListView.separated(
                          controller: controlador,
                          padding: const EdgeInsets.fromLTRB(
                            EspaciadoPrevia.m,
                            EspaciadoPrevia.s,
                            EspaciadoPrevia.m,
                            EspaciadoPrevia.xxl + EspaciadoPrevia.xl,
                          ),
                          itemCount: lista.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: EspaciadoPrevia.s),
                          itemBuilder: (_, i) {
                            final previa = lista[i];
                            // Solo la primera vez que se ve cada tarjeta:
                            // si no, al desplazar la lista se reanimaria.
                            final nueva = _vistas.add(previa.id);
                            return _Entrada(
                              animar: nueva && i < 8,
                              retraso: Duration(milliseconds: 45 * i),
                              child: TarjetaPrevia(
                                previa: previa,
                                onTap: () => widget.onTocar(previa),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Salidas del estado vacío relacionadas con la búsqueda: quitar filtros
  /// si los hay (la causa más probable de no ver nada) o ampliar el radio.
  List<Widget> _accionesDeBusqueda(Filtros filtros) {
    final notificador = ref.read(filtrosProvider.notifier);

    // Filtros (horas, plazas, ambiente) son la causa más probable de no ver
    // nada. El radio se trata aparte: ampliarlo no debe convertir la oferta
    // en "Quitar filtros", que lo devolvería a 5 km.
    final acciones = <Widget>[];
    if (filtros.hayFiltrosAparteDelRadio) {
      acciones.add(
        OutlinedButton.icon(
          onPressed: notificador.quitarFiltrosSalvoRadio,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Quitar filtros'),
        ),
      );
    }
    if (filtros.radioMetros < Filtros.radioMaximoMetros) {
      final nuevo = (filtros.radioMetros * 2).clamp(
        Filtros.radioMinimoMetros,
        Filtros.radioMaximoMetros,
      );
      acciones.add(
        OutlinedButton.icon(
          onPressed: () => notificador.fijarRadio(nuevo),
          icon: const Icon(Icons.zoom_out_map),
          label: Text('Ampliar a ${Filtros(radioMetros: nuevo).radioLegible}'),
        ),
      );
    }
    return acciones;
  }
}

/// Entrada suave (escala + fundido) de un marcador la primera vez que se
/// dibuja. La clave identifica la previa: si el mapa se reconstruye con la
/// misma previa no se repite la animacion, solo cuando aparece una nueva.
/// Con "reducir movimiento" del sistema aparece directamente.
class _Aparece extends StatelessWidget {
  const _Aparece({required this.clave, required this.child});

  final String clave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(clave),
      tween: Tween(begin: 0, end: 1),
      duration: MovimientoPrevia.normal,
      curve: Curves.easeOutBack,
      builder: (context, t, hijo) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.5 + 0.5 * t, child: hijo),
      ),
      child: child,
    );
  }
}

/// Burbuja de un grupo de previas: mas grande que una suelta y neutra
/// (superficie con borde de marca) para que se lea como "varias" y no compita
/// con el color de accion de las previas individuales.
class _BurbujaGrupo extends StatelessWidget {
  const _BurbujaGrupo({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: ColoresPrevia.superficieAlta,
          shape: BoxShape.circle,
          border: Border.all(color: ColoresPrevia.primarioSuave, width: 2.5),
          boxShadow: ElevacionPrevia.flotante,
        ),
        // Mismo criterio que _BurbujaPlazas: tamano fijo, escalado acotado.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: Center(
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  '$cantidad',
                  style: const TextStyle(
                    color: ColoresPrevia.texto,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
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

/// Entrada escalonada de una tarjeta: fundido y leve subida, con un retraso
/// creciente por posicion para que la lista "caiga" en cascada en vez de
/// aparecer de golpe. Respeta "reducir movimiento".
class _Entrada extends StatelessWidget {
  const _Entrada({
    required this.animar,
    required this.retraso,
    required this.child,
  });

  final bool animar;
  final Duration retraso;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animar || MediaQuery.disableAnimationsOf(context)) return child;
    final total = MovimientoPrevia.normal + retraso;
    // El retraso se codifica en la curva (Interval) para usar un solo
    // controlador implicito en vez de un Future.delayed por tarjeta.
    final inicio = retraso.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(inicio, 1, curve: MovimientoPrevia.curva),
      builder: (context, t, hijo) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: hijo,
        ),
      ),
      child: child,
    );
  }
}
