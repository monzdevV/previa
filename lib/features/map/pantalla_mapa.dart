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

    final centro = ref.watch(centroBusquedaProvider) ??
        posicion.valueOrNull ??
        ServicioUbicacion.centroPorDefecto;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCenter: centro,
              initialZoom: 14,
              minZoom: 10,
              maxZoom: 17,
              onPositionChanged: (camara, porGesto) {
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
              TileLayer(
                // Teselas oscuras de CARTO: casan con el tema de la aplicacion
                // y no exigen clave de API ni tarjeta.
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
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
                    borderColor: ColoresPrevia.primario.withValues(alpha: 0.25),
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
                      color: (_previaResaltada == p.id
                              ? ColoresPrevia.acento
                              : ColoresPrevia.primario)
                          .withValues(alpha: 0.22),
                      borderColor: _previaResaltada == p.id
                          ? ColoresPrevia.acento
                          : ColoresPrevia.primarioSuave,
                      borderStrokeWidth: 2,
                    ),
                ],
              ),

              MarkerLayer(
                markers: [
                  if (posicion.hasValue)
                    Marker(
                      point: posicion.value!,
                      width: 18,
                      height: 18,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ColoresPrevia.acento,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
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
                        child: _BurbujaPlazas(
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
                  _BotonRedondo(
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

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'miPosicion',
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
              color: color.withValues(alpha: 0.5),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
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
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
        border: Border.all(color: ColoresPrevia.borde),
      ),
      child: Row(
        children: [
          if (cargando)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ColoresPrevia.primarioSuave,
              ),
            )
          else
            const Icon(Icons.nightlife, size: 18, color: ColoresPrevia.primarioSuave),
          const SizedBox(width: EspaciadoPrevia.s),
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

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({
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
      borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: resaltado
              ? ColoresPrevia.primario
              : ColoresPrevia.superficie.withValues(alpha: 0.96),
          shape: BoxShape.circle,
          border: Border.all(
            color: resaltado ? ColoresPrevia.primario : ColoresPrevia.borde,
          ),
        ),
        child: Icon(
          icono,
          size: 20,
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
        e is ErrorUbicacion && e.causa == FalloUbicacion.permisoDenegadoParaSiempre;

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
              const Icon(Icons.location_off_outlined,
                  size: 18, color: ColoresPrevia.aviso),
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
      initialChildSize: 0.26,
      minChildSize: 0.12,
      maxChildSize: 0.82,
      builder: (context, controlador) {
        return Container(
          decoration: const BoxDecoration(
            color: ColoresPrevia.fondo,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(EspaciadoPrevia.radioGrande),
            ),
            border: Border(top: BorderSide(color: ColoresPrevia.borde)),
          ),
          child: Column(
            children: [
              // Agarradera
              Container(
                margin: const EdgeInsets.symmetric(vertical: EspaciadoPrevia.s + 2),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ColoresPrevia.borde,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: previas.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _Vacio(
                    icono: Icons.cloud_off,
                    titulo: 'No se ha podido buscar',
                    detalle: 'Comprueba tu conexión e inténtalo otra vez.',
                  ),
                  data: (lista) => lista.isEmpty
                      ? const _Vacio(
                          icono: Icons.nightlife_outlined,
                          titulo: 'Nada por aquí ahora mismo',
                          detalle: 'Prueba a ampliar el radio en los filtros, '
                              'o abre tú la previa y que venga la gente.',
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
                          itemBuilder: (_, i) => TarjetaPrevia(
                            previa: lista[i],
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
  const _Vacio({required this.icono, required this.titulo, required this.detalle});

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
