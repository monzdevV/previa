import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../app/tema.dart';
import '../../core/ambientes.dart';
import '../../core/entorno.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_previas.dart';
import '../../data/services/servicio_ubicacion.dart';
import '../map/proveedores_mapa.dart';
import '../profile/proveedores_perfil.dart';

class PantallaCrearPrevia extends ConsumerStatefulWidget {
  const PantallaCrearPrevia({super.key});

  @override
  ConsumerState<PantallaCrearPrevia> createState() =>
      _PantallaCrearPreviaState();
}

class _PantallaCrearPreviaState extends ConsumerState<PantallaCrearPrevia> {
  final _formulario = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _zona = TextEditingController();
  final _mapa = MapController();

  LatLng? _ubicacion;
  DateTime _empiezaEn = _proximaHoraRedonda();
  int _plazas = 3;
  final Set<String> _ambiente = {};
  bool _guardando = false;

  /// Una quedada en una plaza o en un parque no tiene nada que esconder, asi
  /// que su direccion deja de difuminarse y no hace falta pedir plaza.
  bool _enSitioPublico = false;
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
    super.dispose();
  }

  Future<void> _elegirCuando() async {
    final ahora = DateTime.now();

    final dia = await showDatePicker(
      context: context,
      initialDate: _empiezaEn,
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
      _empiezaEn = DateTime(
        dia.year,
        dia.month,
        dia.day,
        hora.hour,
        hora.minute,
      );
    });
  }

  Future<void> _publicar() async {
    if (!_formulario.currentState!.validate()) return;

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
            enSitioPublico: _enSitioPublico,
          );

      // Que el mapa y "mis previas" se enteren.
      ref.invalidate(previasCercaProvider);
      ref.invalidate(misPreviasProvider);
      refrescarPerfil(ref);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Previa publicada. A ver quién se apunta.'),
        ),
      );
    } on ErrorPrevia catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final formatoCuando = DateFormat("EEEE d 'a las' HH:mm", 'es_ES');
    final centroMapa =
        _ubicacion ??
        ref.watch(posicionDispositivoProvider).valueOrNull ??
        ServicioUbicacion.centroPorDefecto;

    return Scaffold(
      appBar: AppBar(title: const Text('Abrir previa')),
      body: SafeArea(
        child: Form(
          key: _formulario,
          child: ListView(
            padding: const EdgeInsets.all(EspaciadoPrevia.l),
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
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Escribe la zona'
                    : null,
              ),

              const SizedBox(height: EspaciadoPrevia.l),

              // Cuando
              _Bloque(
                titulo: '¿Cuándo?',
                child: InkWell(
                  onTap: _elegirCuando,
                  borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.schedule),
                    ),
                    child: Text(
                      formatoCuando.format(_empiezaEn),
                      style: TextStyle(
                        color: context.colores.texto,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),

              // Plazas
              _Bloque(
                titulo: '¿Cuánta gente cabe?',
                subtitulo:
                    'Plazas libres que ofreces, sin contaros a vosotros.',
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _plazas > 1
                          ? () => setState(() => _plazas--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '$_plazas',
                          style: textos.displaySmall?.copyWith(
                            color: context.colores.acento,
                          ),
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _plazas < 30
                          ? () => setState(() => _plazas++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),

              _Bloque(
                titulo: '¿Dónde es?',
                subtitulo: _enSitioPublico
                    ? 'Al ser público, cualquiera ve el sitio exacto y '
                          'puede presentarse sin pedir plaza.'
                    : 'En una casa la dirección se guarda: solo la ven los '
                          'que aceptes.',
                child: SwitchListTile.adaptive(
                  value: _enSitioPublico,
                  onChanged: (v) => setState(() => _enSitioPublico = v),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: context.colores.primario,
                  title: Text(
                    _enSitioPublico ? 'Sitio público' : 'En una casa',
                    style: textos.titleMedium,
                  ),
                  secondary: Icon(
                    _enSitioPublico
                        ? Icons.park_rounded
                        : Icons.home_rounded,
                    color: context.colores.texto,
                  ),
                ),
              ),

              // Ambiente
              _Bloque(
                titulo: 'Ambiente',
                subtitulo: 'Ayuda a que se apunte gente que encaje.',
                child: Wrap(
                  spacing: EspaciadoPrevia.s,
                  runSpacing: EspaciadoPrevia.s,
                  children: [
                    for (final etiqueta in ambientesDisponibles)
                      FilterChip(
                        label: Text(etiqueta),
                        selected: _ambiente.contains(etiqueta),
                        selectedColor: context.colores.primario,
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

              // Ubicacion
              _Bloque(
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
                        IgnorePointer(
                          child: Icon(
                            Icons.place,
                            size: 42,
                            color: context.colores.acento,
                            shadows: [
                              Shadow(blurRadius: 8, color: Colors.black),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: EspaciadoPrevia.m),
                Container(
                  padding: const EdgeInsets.all(EspaciadoPrevia.m),
                  decoration: BoxDecoration(
                    color: context.colores.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
                    border: Border.all(
                      color: context.colores.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: context.colores.error),
                  ),
                ),
              ],

              const SizedBox(height: EspaciadoPrevia.l),
              FilledButton(
                onPressed: _guardando ? null : _publicar,
                child: _guardando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Publicar previa'),
              ),
              const SizedBox(height: EspaciadoPrevia.l),
            ],
          ),
        ),
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
      padding: const EdgeInsets.only(bottom: EspaciadoPrevia.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleLarge),
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
