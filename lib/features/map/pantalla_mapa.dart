import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app/tema.dart';
import '../../core/entorno.dart';
import '../../data/models/previa.dart';
import '../../data/services/servicio_ubicacion.dart';
import '../party/tarjeta_previa.dart';
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
  const PantallaMapa({super.key, this.onCrearPrevia, this.onAbrirPrevia});

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

  void _buscarAqui() {
    final punto = _centroPendiente;
    if (punto == null) return;
    ref.read(centroBusquedaProvider.notifier).fijar(punto);
    setState(() => _centroPendiente = null);
  }

  Future<void> _volverAMiPosicion() async {
    final posicion = await ref.refresh(posicionDispositivoProvider.future);
    ref.read(centroBusquedaProvider.notifier).fijar(posicion);
    _mapa.move(posicion, 14);
    setState(() => _centroPendiente = null);
  }

  @override
  Widget build(BuildContext context) {
    final posicion = ref.watch(posicionDispositivoProvider);
    final previas = ref.watch(previasCercaProvider);
    final filtros = ref.watch(filtrosProvider);

    final centro =
        ref.watch(centroBusquedaProvider) ??
        posicion.valueOrNull ??
        ServicioUbicacion.centroPorDefecto;

    return Scaffold(
      // La accion primaria se ancla al borde inferior, al alcance del pulgar,
      // en lugar de flotar sobre la hoja: asi no puede taparla nunca y el
      // indice manda en el resto de la pantalla.
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapa,
                  options: MapOptions(
                    initialCenter: centro,
                    initialZoom: 14,
                    minZoom: 10,
                    maxZoom: 17,
                    // Mientras las teselas no llegan, el hueco es la carta y no un
                    // blanco: en una app que se abre de noche ese fogonazo deslumbra.
                    backgroundColor: ColoresPrevia.fondo,
                    onPositionChanged: (camara, porGesto) {
                      if (!porGesto) return;
                      final destino = camara.center;
                      final distancia = const Distance().distance(
                        centro,
                        destino,
                      );
                      // Solo se ofrece rebuscar si de verdad se ha movido.
                      if (distancia > 500) {
                        setState(() => _centroPendiente = destino);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      // Teselas oscuras de CARTO: casan con el tema de la aplicacion
                      // y no exigen clave de API ni tarjeta.
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c'],
                      retinaMode: RetinaMode.isHighDensity(context),
                      userAgentPackageName: 'com.previa.previa',
                      tileProvider: ref.watch(proveedorTeselasProvider),
                    ),


                    // Radio de busqueda. En letra de mapa y no en ambar: el alcance
                    // de la busqueda no es una previa con sitio.
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: centro,
                          radius: filtros.radioMetros.toDouble(),
                          useRadiusInMeter: true,
                          color: Colors.transparent,
                          borderColor: ColoresPrevia.textoTenue.withValues(
                            alpha: 0.5,
                          ),
                          borderStrokeWidth: 1,
                        ),
                      ],
                    ),

                    // Cada previa, como zona aproximada
                    CircleLayer(
                      circles: [
                        for (final p in previas.valueOrNull ?? const <Previa>[])
                          CircleMarker(
                            point: p.ubicacion,
                            radius: Entorno.metrosDeDifuminado.toDouble(),
                            useRadiusInMeter: true,
                            // La celda resaltada no estrena color: sube de tinta y
                            // se contornea en letra de mapa.
                            color: ColoresPrevia.primario.withValues(
                              alpha: _previaResaltada == p.id ? 0.34 : 0.18,
                            ),
                            borderColor: _previaResaltada == p.id
                                ? ColoresPrevia.texto
                                : ColoresPrevia.primario.withValues(alpha: 0.7),
                            borderStrokeWidth: _previaResaltada == p.id ? 2 : 1,
                          ),
                      ],
                    ),

                    MarkerLayer(
                      markers: [
                        if (posicion.hasValue)
                          Marker(
                            point: posicion.value!,
                            width: 14,
                            height: 14,
                            // Tu posicion es letra de mapa, no una tinta viva: lo
                            // vivo esta reservado a las previas con sitio.
                            child: Container(
                              decoration: BoxDecoration(
                                color: ColoresPrevia.texto,
                                border: Border.all(
                                  color: ColoresPrevia.fondoProfundo,
                                ),
                              ),
                            ),
                          ),
                        for (final p in previas.valueOrNull ?? const <Previa>[])
                          Marker(
                            point: p.ubicacion,
                            width: 46,
                            height: 46,
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _previaResaltada = p.id);
                                widget.onAbrirPrevia?.call(p);
                              },
                              child: _PlacaPlazas(
                                plazas: p.plazasLibres,
                                resaltada: _previaResaltada == p.id,
                              ),
                            ),
                          ),
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

                // Barra superior
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(EspaciadoPrevia.m),
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
                        // Volver a mi posicion es un control del mapa, no una
                        // accion primaria: vive aqui y no en un boton flotante.
                        _BotonFiltros(
                          icono: Icons.my_location,
                          resaltado: false,
                          onTap: _volverAMiPosicion,
                        ),
                        const SizedBox(width: EspaciadoPrevia.s),
                        _BotonFiltros(
                          icono: Icons.tune,
                          resaltado: !filtros.sonLosPorDefecto,
                          onTap: () => mostrarHojaFiltros(context),
                        ),
                      ],
                    ),
                  ),
                ),

                // "Buscar en esta zona"
                if (_centroPendiente != null)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 74,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: _buscarAqui,
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Buscar en esta zona'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 42),
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
                    top: MediaQuery.of(context).padding.top + 74,
                    child: _AvisoUbicacion(
                      error: posicion.error,
                      onReintentar: _volverAMiPosicion,
                    ),
                  ),

                _ListaInferior(
                  previas: previas,
                  onTocar: (p) {
                    setState(() => _previaResaltada = p.id);
                    _mapa.move(p.ubicacion, 15);
                    widget.onAbrirPrevia?.call(p);
                  },
                ),
              ],
            ),
          ),

          // Si no hay a donde llevar la accion no se dibuja: una barra apagada
          // a todo el ancho se lee como banda muerta.
          if (widget.onCrearPrevia != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  EspaciadoPrevia.m,
                  EspaciadoPrevia.s,
                  EspaciadoPrevia.m,
                  EspaciadoPrevia.s,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: ColoresPrevia.degradado,
                    borderRadius: BorderRadius.circular(
                      EspaciadoPrevia.radio - 4,
                    ),
                  ),
                  child: FilledButton.icon(
                    onPressed: widget.onCrearPrevia,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 21),
                    label: const Text('Abrir una previa'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Marca de plazas sobre la zona de la previa.
///
/// Pastilla con el color de disponibilidad, igual que el estado en Discord o
/// la burbuja de una historia: de un vistazo dice si ahi se puede entrar.
class _PlacaPlazas extends StatelessWidget {
  const _PlacaPlazas({required this.plazas, required this.resaltada});

  final int plazas;
  final bool resaltada;

  @override
  Widget build(BuildContext context) {
    final ocupacion = Ocupacion.desde(plazas);
    final viva = ocupacion.viva;

    return Center(
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: viva ? ocupacion.color : ColoresPrevia.superficieAlta,
          shape: BoxShape.circle,
          border: Border.all(
            color: resaltada ? Colors.white : Colors.black26,
            width: resaltada ? 3 : 2,
          ),
        ),
        child: Text(
          viva ? '$plazas' : '·',
          style: TextStyle(
            color: viva ? const Color(0xFF07130C) : ColoresPrevia.textoTenue,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _PastillaResumen extends StatelessWidget {
  const _PastillaResumen({required this.texto, required this.cargando});

  final String texto;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: EspaciadoPrevia.m),
      decoration: BoxDecoration(
        color: ColoresPrevia.superficie.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
      ),
      child: Row(
        children: [
          if (cargando) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ColoresPrevia.textoSuave,
              ),
            ),
            const SizedBox(width: EspaciadoPrevia.s),
          ],
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: ColoresPrevia.texto,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonFiltros extends StatelessWidget {
  const _BotonFiltros({
    required this.icono,
    required this.onTap,
    this.resaltado = false,
  });

  final IconData icono;
  final VoidCallback onTap;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: resaltado
              ? ColoresPrevia.primario
              : ColoresPrevia.superficie.withValues(alpha: 0.96),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icono,
          size: 21,
          color: resaltado ? Colors.white : ColoresPrevia.texto,
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
class _ListaInferior extends StatelessWidget {
  const _ListaInferior({required this.previas, required this.onTocar});

  final AsyncValue<List<Previa>> previas;
  final void Function(Previa) onTocar;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      // El indice manda y el mapa queda detras. Los detentes evitan que la
      // lamina se quede a medias cuando se arrastra a una mano y con prisa:
      // cae en mapa, mixto o indice, como un plano que se dobla por su raya.
      initialChildSize: 0.66,
      minChildSize: 0.16,
      maxChildSize: 0.94,
      snap: true,
      snapSizes: const [0.16, 0.66, 0.94],
      builder: (context, controlador) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: ColoresPrevia.fondo,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(EspaciadoPrevia.radioGrande),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(
                  vertical: EspaciadoPrevia.s + EspaciadoPrevia.xs,
                ),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ColoresPrevia.superficieActiva,
                  borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
                ),
              ),
              Expanded(
                child: previas.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _Vacio(
                    icono: Icons.cloud_off,
                    titulo: 'No se ha podido buscar',
                    detalle: 'Comprueba tu conexión e inténtalo otra vez.',
                  ),
                  data: (lista) => lista.isEmpty
                      ? const _Vacio(
                          icono: Icons.grid_off,
                          titulo: 'Nada por aquí ahora mismo',
                          detalle:
                              'Prueba a ampliar el radio en los filtros, '
                              'o abre tú la previa y que venga la gente.',
                        )
                      : ListView.separated(
                          controller: controlador,
                          padding: const EdgeInsets.fromLTRB(
                            EspaciadoPrevia.m,
                            EspaciadoPrevia.s,
                            EspaciadoPrevia.m,
                            EspaciadoPrevia.xxl,
                          ),
                          itemCount: lista.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: EspaciadoPrevia.m),
                          // Compacta: la portada se encoge para que quepan
                          // varias previas comparables en la hoja.
                          itemBuilder: (_, i) => TarjetaPrevia(
                            previa: lista[i],
                            compacta: true,
                            onTap: () => onTocar(lista[i]),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(EspaciadoPrevia.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: ColoresPrevia.textoTenue),
            const SizedBox(height: EspaciadoPrevia.m),
            Text(titulo, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: EspaciadoPrevia.xs),
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
}
