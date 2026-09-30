import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../app/tema.dart';
import '../../core/ambientes.dart';
import '../../core/entorno.dart';
import '../../data/models/previa.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_previas.dart';
import '../../data/services/servicio_ubicacion.dart';
import '../map/proveedores_mapa.dart';
import 'componentes_previa.dart';
import 'estados_pantalla.dart';
import 'tarjeta_previa.dart';

/// Formulario de crear previa en tres pasos.
///
/// Un formulario largo con 8 campos intimida y esconde el botón de publicar.
/// Por pasos se pide poco cada vez, y la vista previa de la tarjeta (la misma
/// que verán los demás en el listado) da la sensación de ir construyendo algo.
class PantallaCrearPrevia extends ConsumerStatefulWidget {
  const PantallaCrearPrevia({super.key});

  @override
  ConsumerState<PantallaCrearPrevia> createState() =>
      _PantallaCrearPreviaState();
}

class _PantallaCrearPreviaState extends ConsumerState<PantallaCrearPrevia> {
  static const _titulosPasos = ['Lo básico', 'Cuándo y cuánta gente', 'Dónde'];

  final _formulario = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _zona = TextEditingController();
  final _mapa = MapController();

  int _paso = 0;
  LatLng? _ubicacion;
  DateTime _empiezaEn = _proximaHoraRedonda();
  int _plazas = 3;
  final Set<String> _ambiente = {};
  bool _guardando = false;
  String? _error;

  static DateTime _proximaHoraRedonda() {
    final ahora = DateTime.now();
    // Por defecto, dentro de un par de horas: nadie publica una previa
    // para "ahora mismo".
    final destino = ahora.add(const Duration(hours: 2));
    return DateTime(destino.year, destino.month, destino.day, destino.hour);
  }

  @override
  void initState() {
    super.initState();
    // Se parte de donde esta el usuario, que casi siempre es donde sera
    // la previa. Puede moverlo si no.
    final posicion = ref.read(posicionDispositivoProvider).valueOrNull;
    _ubicacion = posicion;
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _zona.dispose();
    _mapa.dispose();
    super.dispose();
  }

  Future<void> _elegirCuando() async {
    final ahora = DateTime.now();

    final dia = await showDatePicker(
      context: context,
      initialDate: _empiezaEn.isBefore(ahora) ? ahora : _empiezaEn,
      firstDate: ahora,
      // Una previa es un plan de esta noche o de mañana, no de dentro de un mes.
      lastDate: ahora.add(const Duration(days: 14)),
      locale: const Locale('es', 'ES'),
      helpText: '¿Qué día?',
    );
    if (dia == null || !mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_empiezaEn),
      helpText: '¿A qué hora empieza?',
    );
    if (hora == null) return;

    setState(() {
      _error = null;
      _empiezaEn = DateTime(
        dia.year,
        dia.month,
        dia.day,
        hora.hour,
        hora.minute,
      );
    });
  }

  /// Valida solo lo del paso actual. Como únicamente los campos del paso
  /// visible están montados, `validate()` no se queja de los demás.
  bool _validarPaso() {
    if (!_formulario.currentState!.validate()) return false;
    if (_paso == 1 && _empiezaEn.isBefore(DateTime.now())) {
      setState(() => _error = 'Esa hora ya ha pasado.');
      return false;
    }
    return true;
  }

  void _siguiente() {
    if (!_validarPaso()) return;
    setState(() {
      _error = null;
      _paso++;
    });
  }

  void _atras() => setState(() {
    _error = null;
    _paso--;
  });

  Future<void> _publicar() async {
    if (!_validarPaso()) return;

    if (_ubicacion == null) {
      setState(() => _error = 'Mueve el mapa para marcar dónde es la previa.');
      return;
    }
    if (_empiezaEn.isBefore(DateTime.now())) {
      setState(() => _error = 'Esa hora ya ha pasado.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await ref
          .read(repositorioPreviasProvider)
          .crear(
            titulo: _titulo.text,
            descripcion: _descripcion.text,
            zona: _zona.text,
            ubicacionExacta: _ubicacion!,
            empiezaEn: _empiezaEn,
            plazas: _plazas,
            ambiente: _ambiente.toList(),
          );

      // Que el mapa y "mis previas" se enteren.
      ref.invalidate(previasCercaProvider);
      ref.invalidate(misPreviasProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Previa publicada. A ver quién se apunta.'),
        ),
      );
    } on ErrorPrevia catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      // Un fallo de red no puede dejar el botón girando sin explicación.
      if (mounted) {
        setState(
          () => _error = 'No se ha podido publicar. Comprueba tu conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esUltimo = _paso == _titulosPasos.length - 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Abrir previa')),
      body: SafeArea(
        child: Form(
          key: _formulario,
          child: Column(
            children: [
              _Progreso(paso: _paso, titulos: _titulosPasos),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    EspaciadoPrevia.l,
                    EspaciadoPrevia.s,
                    EspaciadoPrevia.l,
                    EspaciadoPrevia.l,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (hijo, anim) =>
                            FadeTransition(opacity: anim, child: hijo),
                        layoutBuilder: (actual, anteriores) => Stack(
                          alignment: Alignment.topCenter,
                          children: [...anteriores, ?actual],
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_paso),
                          child: switch (_paso) {
                            0 => _pasoBasico(),
                            1 => _pasoCuando(),
                            _ => _pasoDonde(),
                          },
                        ),
                      ),

                      const SizedBox(height: EspaciadoPrevia.m),
                      _VistaPrevia(
                        child: ListenableBuilder(
                          listenable: Listenable.merge([
                            _titulo,
                            _descripcion,
                            _zona,
                          ]),
                          builder: (_, _) => TarjetaPrevia(
                            previa: _previaDeVista(),
                            conHero: false,
                          ),
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: EspaciadoPrevia.m),
                        AvisoError(_error!),
                      ],
                    ],
                  ),
                ),
              ),
              _BarraPasos(
                paso: _paso,
                esUltimo: esUltimo,
                guardando: _guardando,
                onAtras: _atras,
                onSiguiente: esUltimo ? _publicar : _siguiente,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Previa ficticia con lo escrito hasta ahora, para la vista previa.
  Previa _previaDeVista() {
    final titulo = _titulo.text.trim();
    final zona = _zona.text.trim();
    final descripcion = _descripcion.text.trim();
    return Previa(
      id: 'vista-previa',
      titulo: titulo.isEmpty ? 'El título de tu previa' : titulo,
      descripcion: descripcion.isEmpty ? null : descripcion,
      ambiente: _ambiente.toList(),
      zona: zona.isEmpty ? 'Tu zona' : zona,
      ubicacion: _ubicacion ?? ServicioUbicacion.centroPorDefecto,
      empiezaEn: _empiezaEn,
      plazasLibres: _plazas,
      anfitrionId: 'yo',
      anfitrionNombre: 'Tú',
    );
  }

  // --- Paso 1: lo básico ---------------------------------------------------

  Widget _pasoBasico() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _titulo,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Título',
            hintText: 'Previa en Triana',
            prefixIcon: Icon(Icons.local_bar_outlined),
          ),
          validator: (v) => (v == null || v.trim().length < 3)
              ? 'Ponle un título de al menos 3 caracteres'
              : null,
        ),
        TextFormField(
          controller: _descripcion,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Cuenta algo',
            hintText:
                'Somos 4, tenemos altavoz y sitio de sobra. '
                'Traed lo vuestro.',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        TextFormField(
          controller: _zona,
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Zona o barrio',
            hintText: 'Triana, Centro, Malasaña…',
            prefixIcon: Icon(Icons.place_outlined),
            helperText: 'Es lo único del sitio que se ve en el listado.',
          ),
          validator: (v) =>
              (v == null || v.trim().length < 2) ? 'Escribe la zona' : null,
        ),
        const SizedBox(height: EspaciadoPrevia.l),
        _Bloque(
          titulo: 'Ambiente',
          subtitulo:
              'Ayuda a que se apunte gente que encaje. Hasta 5; '
              'la primera da color a tu tarjeta.',
          child: Wrap(
            spacing: EspaciadoPrevia.s,
            runSpacing: EspaciadoPrevia.s,
            children: [
              for (final etiqueta in ambientesDisponibles)
                FilterChip(
                  label: Text(etiqueta),
                  selected: _ambiente.contains(etiqueta),
                  selectedColor: ColoresPrevia.primario,
                  checkmarkColor: Colors.white,
                  onSelected: (marcada) => setState(() {
                    if (marcada) {
                      if (_ambiente.length < 5) _ambiente.add(etiqueta);
                    } else {
                      _ambiente.remove(etiqueta);
                    }
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Paso 2: cuándo y plazas --------------------------------------------

  Widget _pasoCuando() {
    final textos = Theme.of(context).textTheme;
    final formatoCuando = DateFormat("EEEE d 'a las' HH:mm", 'es_ES');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Bloque(
          titulo: '¿Cuándo?',
          child: Semantics(
            // Un InkWell suelto no se anuncia como botón ni dice su valor.
            button: true,
            excludeSemantics: true,
            label: 'Fecha y hora, ${formatoCuando.format(_empiezaEn)}',
            onTap: _elegirCuando,
            child: InkWell(
              onTap: _elegirCuando,
              borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.schedule),
                ),
                child: Text(
                  formatoCuando.format(_empiezaEn),
                  style: const TextStyle(
                    color: ColoresPrevia.texto,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
        _Bloque(
          titulo: '¿Cuánta gente cabe?',
          subtitulo: 'Plazas libres que ofreces, sin contaros a vosotros.',
          child: Column(
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Una plaza menos',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(56, 56),
                    ),
                    onPressed: _plazas > 1
                        ? () => setState(() => _plazas--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (hijo, anim) => ScaleTransition(
                          scale: anim,
                          child: FadeTransition(opacity: anim, child: hijo),
                        ),
                        child: Text(
                          '$_plazas',
                          key: ValueKey(_plazas),
                          semanticsLabel: _plazas == 1
                              ? '1 plaza libre'
                              : '$_plazas plazas libres',
                          style: textos.displaySmall?.copyWith(
                            color: ColoresPrevia.acento,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Una plaza más',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(56, 56),
                    ),
                    onPressed: _plazas < 30
                        ? () => setState(() => _plazas++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: EspaciadoPrevia.m),
              BarraPlazas(libres: _plazas),
            ],
          ),
        ),
      ],
    );
  }

  // --- Paso 3: dónde -------------------------------------------------------

  Widget _pasoDonde() {
    final centroMapa =
        _ubicacion ??
        ref.watch(posicionDispositivoProvider).valueOrNull ??
        ServicioUbicacion.centroPorDefecto;

    return _Bloque(
      titulo: '¿Dónde es?',
      subtitulo:
          'Marca el sitio exacto. Nadie lo verá hasta que '
          'aceptes a alguien: en el mapa público aparecerás dentro '
          'de una zona de unos ${Entorno.metrosDeDifuminado} metros.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        child: SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              FlutterMap(
                mapController: _mapa,
                options: MapOptions(
                  initialCenter: centroMapa,
                  initialZoom: 16,
                  onPositionChanged: (camara, porGesto) {
                    if (porGesto) {
                      setState(() => _ubicacion = camara.center);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/'
                        '{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c'],
                    retinaMode: RetinaMode.isHighDensity(context),
                    userAgentPackageName: 'com.previa.previa',
                  ),
                ],
              ),
              // La chincheta se queda fija en el centro y es el mapa
              // el que se mueve: mas facil de afinar con el pulgar.
              const IgnorePointer(
                child: Icon(
                  Icons.place,
                  size: 42,
                  color: ColoresPrevia.acento,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicador de progreso por pasos: segmentos + "Paso 1 de 3 · Lo básico".
class _Progreso extends StatelessWidget {
  const _Progreso({required this.paso, required this.titulos});

  final int paso;
  final List<String> titulos;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final etiqueta = 'Paso ${paso + 1} de ${titulos.length}: ${titulos[paso]}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        EspaciadoPrevia.l,
        EspaciadoPrevia.xs,
        EspaciadoPrevia.l,
        EspaciadoPrevia.s,
      ),
      child: Semantics(
        // Región viva: al avanzar, el lector anuncia en qué paso estás.
        liveRegion: true,
        label: etiqueta,
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < titulos.length; i++) ...[
                  if (i > 0) const SizedBox(width: EspaciadoPrevia.xs),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 5,
                      decoration: BoxDecoration(
                        color: i <= paso
                            ? ColoresPrevia.primario
                            : ColoresPrevia.borde,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: EspaciadoPrevia.s),
            Text(etiqueta, style: textos.titleLarge),
          ],
        ),
      ),
    );
  }
}

/// Envoltorio de la vista previa con su rótulo.
class _VistaPrevia extends StatelessWidget {
  const _VistaPrevia({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.visibility_outlined,
                size: 16,
                color: ColoresPrevia.textoSuave,
              ),
            ),
            const SizedBox(width: EspaciadoPrevia.xs + 2),
            Semantics(
              header: true,
              child: Text(
                'Así se verá',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        // Es solo una muestra: se excluye de la semántica para que el lector
        // no la confunda con una previa real ni ofrezca tocarla.
        ExcludeSemantics(child: IgnorePointer(child: child)),
      ],
    );
  }
}

/// Barra inferior fija con Atrás / Siguiente / Publicar.
class _BarraPasos extends StatelessWidget {
  const _BarraPasos({
    required this.paso,
    required this.esUltimo,
    required this.guardando,
    required this.onAtras,
    required this.onSiguiente,
  });

  final int paso;
  final bool esUltimo;
  final bool guardando;
  final VoidCallback onAtras;
  final VoidCallback onSiguiente;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EspaciadoPrevia.m),
      decoration: const BoxDecoration(
        color: ColoresPrevia.superficie,
        border: Border(top: BorderSide(color: ColoresPrevia.borde)),
      ),
      child: Row(
        children: [
          if (paso > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: guardando ? null : onAtras,
                child: const Text('Atrás'),
              ),
            ),
            const SizedBox(width: EspaciadoPrevia.s),
          ],
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: guardando ? null : onSiguiente,
              child: guardando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                        semanticsLabel: 'Publicando',
                      ),
                    )
                  : Text(esUltimo ? 'Publicar previa' : 'Siguiente'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.titulo, required this.child, this.subtitulo});

  final String titulo;
  final String? subtitulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: EspaciadoPrevia.xs),
            Text(subtitulo!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: EspaciadoPrevia.m),
          child,
        ],
      ),
    );
  }
}
