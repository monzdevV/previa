import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../app/tema.dart';
import '../../core/ambientes.dart';
import '../../core/entorno.dart';
import '../../data/models/perfil.dart';
import '../../data/models/previa.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_previas.dart';
import '../../data/services/servicio_ubicacion.dart';
import '../auth/piezas_acceso.dart' show AvisoError;
import '../map/capas_del_mapa.dart';
import '../map/proveedores_mapa.dart';
import '../profile/proveedores_perfil.dart';
import 'componentes_previa.dart';
import 'tarjeta_previa.dart';

/// Abrir una previa, en tres pasos.
///
/// Un formulario de ocho campos de golpe intimida y deja el boton de
/// publicar debajo del todo. Por pasos se pide poco cada vez, y la tarjeta de
/// abajo (la misma que veran los demas) se va llenando mientras escribes, que
/// es lo que da la sensacion de estar construyendo algo.
class PantallaCrearPrevia extends ConsumerStatefulWidget {
  const PantallaCrearPrevia({super.key});

  @override
  ConsumerState<PantallaCrearPrevia> createState() =>
      _PantallaCrearPreviaState();
}

class _PantallaCrearPreviaState extends ConsumerState<PantallaCrearPrevia> {
  static const _titulosPasos = ['Lo básico', 'Cuándo y cuántos', 'Dónde'];

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

  /// Una quedada en una plaza o en un parque no tiene nada que esconder, asi
  /// que su direccion deja de difuminarse y no hace falta pedir plaza.
  bool _enSitioPublico = false;
  String? _error;

  bool get _esUltimo => _paso == _titulosPasos.length - 1;

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
    _ubicacion = ref.read(posicionDispositivoProvider).valueOrNull;
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

  /// Valida solo lo del paso actual. Como unicamente estan montados los
  /// campos del paso visible, `validate()` no se queja de los demas.
  bool _validarPaso() {
    if (!_formulario.currentState!.validate()) return false;
    if (_paso == 1 && _empiezaEn.isBefore(DateTime.now())) {
      setState(() => _error = 'Esa hora ya ha pasado. Elige otra.');
      return false;
    }
    return true;
  }

  void _siguiente() {
    if (!_validarPaso()) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      _paso++;
    });
  }

  void _atras() {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _paso--;
    });
  }

  Future<void> _publicar() async {
    if (!_validarPaso()) return;

    if (_ubicacion == null) {
      setState(() => _error = 'Mueve el mapa para marcar dónde es la previa.');
      return;
    }
    if (_empiezaEn.isBefore(DateTime.now())) {
      setState(
        () => _error = 'Esa hora ya ha pasado. Vuelve atrás y elige otra.',
      );
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
      HapticFeedback.heavyImpact();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Previa publicada. A ver quién se apunta.'),
        ),
      );
    } on ErrorPrevia catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      // Un fallo de red no puede dejar el boton girando sin explicacion.
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
    final quieto = MovimientoPrevia.reducido(context);
    // Tu cara en la vista previa: la tarjeta de verdad tambien la llevara.
    final yo = ref.watch(miPerfilProvider).valueOrNull;

    // Atras del sistema en el paso 2 o 3 vuelve un paso, no tira todo lo
    // escrito.
    return PopScope(
      canPop: _paso == 0 && !_guardando,
      onPopInvokedWithResult: (salio, _) {
        if (!salio && _paso > 0 && !_guardando) _atras();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Abrir previa')),
        body: Form(
          key: _formulario,
          child: Column(
            children: [
              _Progreso(paso: _paso, titulos: _titulosPasos),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    EspaciadoPrevia.l,
                    EspaciadoPrevia.m,
                    EspaciadoPrevia.l,
                    EspaciadoPrevia.l,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: quieto
                            ? Duration.zero
                            : MovimientoPrevia.rapido,
                        switchInCurve: MovimientoPrevia.curva,
                        switchOutCurve: MovimientoPrevia.curva,
                        transitionBuilder: (hijo, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.02),
                              end: Offset.zero,
                            ).animate(anim),
                            child: hijo,
                          ),
                        ),
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

                      if (_error != null) ...[
                        const SizedBox(height: EspaciadoPrevia.m),
                        AvisoError(_error!),
                      ],

                      const SizedBox(height: EspaciadoPrevia.l),
                      _VistaPrevia(
                        child: ListenableBuilder(
                          listenable: Listenable.merge([
                            _titulo,
                            _descripcion,
                            _zona,
                          ]),
                          builder: (_, _) => TarjetaPrevia(
                            previa: _previaDeVista(yo),
                            conHero: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _BarraPasos(
                paso: _paso,
                esUltimo: _esUltimo,
                guardando: _guardando,
                onAtras: _atras,
                onSiguiente: _esUltimo ? _publicar : _siguiente,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Una previa de mentira con lo escrito hasta ahora, para la vista previa.
  Previa _previaDeVista(Perfil? yo) {
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
      anfitrionNombre: yo?.nombre ?? 'Tú',
      anfitrionAvatar: yo?.avatarUrl,
    );
  }

  // --- Paso 1: lo basico ---------------------------------------------------

  Widget _pasoBasico() {
    final c = context.colores;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _titulo,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Título',
            hintText: 'Previa en Triana',
            prefixIcon: Icon(Icons.local_bar_outlined),
          ),
          validator: (v) => (v == null || v.trim().length < 3)
              ? 'Ponle un título de al menos 3 letras'
              : null,
        ),
        const SizedBox(height: EspaciadoPrevia.xs),
        TextFormField(
          controller: _zona,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
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
        const SizedBox(height: EspaciadoPrevia.xs),
        TextFormField(
          controller: _descripcion,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Cuenta algo (opcional)',
            hintText:
                'Somos 4, tenemos altavoz y sitio de sobra. '
                'Traed lo vuestro.',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.l),
        _Bloque(
          titulo: 'Ambiente',
          subtitulo:
              'Ayuda a que se apunte gente que encaje. Hasta 5; '
              'el primero pinta tu cartel.',
          child: Wrap(
            spacing: EspaciadoPrevia.s,
            runSpacing: EspaciadoPrevia.s,
            children: [
              for (final etiqueta in ambientesDisponibles)
                FilterChip(
                  label: Text(etiqueta),
                  selected: _ambiente.contains(etiqueta),
                  selectedColor: c.primario,
                  checkmarkColor: c.sobrePrimario,
                  labelStyle: _ambiente.contains(etiqueta)
                      ? TextStyle(
                          color: c.sobrePrimario,
                          fontWeight: FontWeight.w700,
                        )
                      : null,
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

  // --- Paso 2: cuando y cuantos --------------------------------------------

  Widget _pasoCuando() {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final formatoCuando = DateFormat("EEEE d 'a las' HH:mm", 'es_ES');
    final cuando = formatoCuando.format(_empiezaEn);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Bloque(
          titulo: '¿Cuándo?',
          child: Semantics(
            // Un toque suelto no se anuncia como boton ni dice su valor.
            button: true,
            excludeSemantics: true,
            label: 'Fecha y hora: $cuando. Toca para cambiarla.',
            onTap: _elegirCuando,
            child: Pulsable(
              onTap: _elegirCuando,
              escala: 0.97,
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: EspaciadoPrevia.m,
                  vertical: EspaciadoPrevia.s + EspaciadoPrevia.xs,
                ),
                decoration: BoxDecoration(
                  color: c.superficie,
                  borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
                  border: Border.all(color: c.borde),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: c.textoSuave),
                    const SizedBox(width: EspaciadoPrevia.m),
                    Expanded(
                      child: Text(
                        cuando,
                        style: textos.titleMedium?.copyWith(color: c.texto),
                      ),
                    ),
                    Text(
                      'Cambiar',
                      style: textos.labelLarge?.copyWith(
                        color: c.primarioTexto,
                      ),
                    ),
                  ],
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
                  BotonPaso(
                    icono: Icons.remove,
                    tooltip: 'Una plaza menos',
                    onPressed: _plazas > 1
                        ? () {
                            HapticFeedback.selectionClick();
                            setState(() => _plazas--);
                          }
                        : null,
                  ),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      label: _plazas == 1
                          ? '1 plaza libre'
                          : '$_plazas plazas libres',
                      excludeSemantics: true,
                      child: Column(
                        children: [
                          CifraAnimada(
                            valor: _plazas,
                            estilo: textos.displaySmall?.copyWith(
                              color: c.primarioTexto,
                            ),
                          ),
                          Text(
                            _plazas == 1 ? 'plaza' : 'plazas',
                            style: textos.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  BotonPaso(
                    icono: Icons.add,
                    tooltip: 'Una plaza más',
                    onPressed: _plazas < 30
                        ? () {
                            HapticFeedback.selectionClick();
                            setState(() => _plazas++);
                          }
                        : null,
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

  // --- Paso 3: donde -------------------------------------------------------

  Widget _pasoDonde() {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final centroMapa =
        _ubicacion ??
        ref.watch(posicionDispositivoProvider).valueOrNull ??
        ServicioUbicacion.centroPorDefecto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Bloque(
          titulo: '¿Es en casa?',
          subtitulo: _enSitioPublico
              ? 'Al ser público, cualquiera ve el sitio exacto y '
                    'puede presentarse sin pedir plaza.'
              : 'En una casa la dirección se guarda: solo la ven los '
                    'que aceptes.',
          child: SwitchListTile.adaptive(
            value: _enSitioPublico,
            onChanged: (v) => setState(() => _enSitioPublico = v),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: c.primario,
            title: Text(
              _enSitioPublico ? 'Sitio público' : 'En una casa',
              style: textos.titleMedium,
            ),
            subtitle: Text(
              _enSitioPublico
                  ? 'Una plaza, un parque, una terraza…'
                  : 'Actívalo si es en la calle o en un parque.',
              style: textos.bodyMedium,
            ),
            secondary: Icon(
              _enSitioPublico ? Icons.park_rounded : Icons.home_rounded,
              color: c.texto,
            ),
          ),
        ),
        _Bloque(
          titulo: 'Marca el sitio',
          subtitulo: _enSitioPublico
              ? 'Mueve el mapa hasta dejar la chincheta en el sitio exacto.'
              : 'Mueve el mapa hasta dejar la chincheta en tu portal. Nadie '
                    'lo verá hasta que aceptes a alguien: en el mapa público '
                    'saldrás dentro de una zona de unos '
                    '${Entorno.metrosDeDifuminado} metros.',
          child: Semantics(
            label:
                'Mapa para marcar el sitio. Arrástralo para mover la '
                'chincheta.',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
              child: SizedBox(
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FlutterMap(
                      mapController: _mapa,
                      options: MapOptions(
                        initialCenter: centroMapa,
                        initialZoom: 16,
                        backgroundColor: c.fondo,
                        onPositionChanged: (camara, porGesto) {
                          if (porGesto) {
                            setState(() => _ubicacion = camara.center);
                          }
                        },
                      ),
                      children: [...capasBaseDelMapa(context)],
                    ),
                    // La chincheta se queda fija en el centro y es el mapa
                    // el que se mueve: mas facil de afinar con el pulgar.
                    // Aqui si es chincheta: es tu sitio y solo lo ves tu.
                    IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: Icon(
                          Icons.place,
                          size: 44,
                          color: c.primario,
                          shadows: const [
                            Shadow(blurRadius: 8, color: Color(0x99000000)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Progreso por pasos: segmentos y "Paso 1 de 3 · Lo básico".
class _Progreso extends StatelessWidget {
  const _Progreso({required this.paso, required this.titulos});

  final int paso;
  final List<String> titulos;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final quieto = MovimientoPrevia.reducido(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        EspaciadoPrevia.l,
        EspaciadoPrevia.xs,
        EspaciadoPrevia.l,
        0,
      ),
      child: Semantics(
        // Region viva: al avanzar, el lector anuncia en que paso estas.
        liveRegion: true,
        label: 'Paso ${paso + 1} de ${titulos.length}: ${titulos[paso]}',
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
                      duration: quieto
                          ? Duration.zero
                          : MovimientoPrevia.rapido,
                      curve: MovimientoPrevia.curva,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i <= paso ? c.primario : c.superficieActiva,
                        borderRadius: BorderRadius.circular(
                          EspaciadoPrevia.pastilla,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: EspaciadoPrevia.m),
            Text(
              'PASO ${paso + 1} DE ${titulos.length}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: c.primarioTexto,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: EspaciadoPrevia.xs),
            Titular(titulos[paso], tamano: 30),
          ],
        ),
      ),
    );
  }
}

/// La vista previa con su rotulo.
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
            ExcludeSemantics(
              child: Icon(
                Icons.visibility_outlined,
                size: 16,
                color: context.colores.textoSuave,
              ),
            ),
            const SizedBox(width: EspaciadoPrevia.xs + 2),
            Text(
              'Así la verán los demás',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        // Es solo una muestra: fuera de la semantica para que el lector no
        // la confunda con una previa de verdad ni ofrezca tocarla.
        ExcludeSemantics(child: IgnorePointer(child: child)),
      ],
    );
  }
}

/// Barra fija de abajo: Atras / Siguiente / Publicar.
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
    final c = context.colores;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.fondo,
        border: Border(top: BorderSide(color: c.borde)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            EspaciadoPrevia.m,
            EspaciadoPrevia.s + EspaciadoPrevia.xs,
            EspaciadoPrevia.m,
            EspaciadoPrevia.s + EspaciadoPrevia.xs,
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
                      ? SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: c.sobrePrimario,
                            semanticsLabel: 'Publicando',
                          ),
                        )
                      : Text(esUltimo ? 'PUBLICAR PREVIA' : 'SIGUIENTE'),
                ),
              ),
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
    final textos = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: EspaciadoPrevia.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(titulo, style: textos.titleLarge),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: EspaciadoPrevia.xs),
            Text(subtitulo!, style: textos.bodyMedium),
          ],
          const SizedBox(height: EspaciadoPrevia.m),
          child,
        ],
      ),
    );
  }
}
