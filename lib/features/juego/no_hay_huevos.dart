import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/reto.dart';
import '../../data/repositories/repositorio_retos.dart';
import '../../data/repositories/repositorio_social.dart';
import '../../data/services/servicio_ubicacion.dart';
import '../feed/pantalla_feed.dart' show AvatarPerfil;

/// Nombre del juego. El huevo es un emoji a proposito: es la gracia del
/// nombre y lo que lo hace reconocible como sticker.
const nombreDelJuego = 'No hay 🥚';

final _miRetoProvider = FutureProvider.autoDispose<Reto?>(
  (ref) => ref.watch(repositorioRetosProvider).miReto(),
);

/// El sticker que da entrada al juego dentro de la sala de un local.
///
/// Solo se pinta a quien ha dicho que va a este local esta noche: el juego
/// va de gente que esta en el mismo sitio.
class StickerNoHayHuevos extends StatelessWidget {
  const StickerNoHayHuevos({super.key, required this.localId});

  final String localId;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final sticker = Semantics(
      button: true,
      label: 'Jugar a No hay huevos',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          abrirNoHayHuevos(context, localId);
        },
        child: Transform.rotate(
          angle: -0.08,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: EspaciadoPrevia.m,
              vertical: EspaciadoPrevia.s + 2,
            ),
            decoration: BoxDecoration(
              color: c.primario,
              borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
              // El borde blanco grueso es lo que hace que parezca un sticker
              // pegado y no un boton mas.
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .45),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              nombreDelJuego,
              style: TextStyle(
                color: c.sobrePrimario,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
      ),
    );

    // Un meneo cada pocos segundos: se ve sin molestar mientras hablas.
    if (MediaQuery.disableAnimationsOf(context)) return sticker;
    return sticker
        .animate(onPlay: (control) => control.repeat())
        .then(delay: 2600.ms)
        .shake(hz: 5, rotation: 0.06, duration: 600.ms);
  }
}

Future<void> abrirNoHayHuevos(BuildContext context, String localId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colores.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(EspaciadoPrevia.radioGrande),
        ),
      ),
      builder: (_) => _HojaReto(localId: localId),
    );

enum _Fase { listo, pidiendo, subiendo, cumplido }

class _HojaReto extends ConsumerStatefulWidget {
  const _HojaReto({required this.localId});

  final String localId;

  @override
  ConsumerState<_HojaReto> createState() => _HojaRetoState();
}

class _HojaRetoState extends ConsumerState<_HojaReto> {
  _Fase _fase = _Fase.listo;

  /// El ultimo fallo, pintado dentro de la hoja. Un SnackBar saldria en la
  /// pantalla de debajo, tapado por la propia hoja.
  String? _error;

  /// La foto ya subida de un reto que no se llego a marcar como hecho. Si
  /// se reintenta, se reaprovecha en vez de subir otra igual a la sala.
  ({String reto, String publicacion})? _pendiente;

  bool get _ocupado => _fase == _Fase.pidiendo || _fase == _Fase.subiendo;

  void _fallo(String texto) {
    if (mounted) setState(() => _error = texto);
  }

  Future<void> _pedir() async {
    if (_ocupado) return;
    // Se leen antes de esperar a nada: si la hoja se cierra a medias, `ref`
    // deja de valer y la peticion se quedaria sin terminar.
    final ubicacion = ref.read(servicioUbicacionProvider);
    final retos = ref.read(repositorioRetosProvider);
    setState(() {
      _fase = _Fase.pidiendo;
      _error = null;
    });

    // La posicion ayuda a demostrar que estas dentro, pero si no llega se
    // pide igual: la base de datos decide si hace falta para este local.
    double? lat;
    double? lng;
    try {
      final punto = await ubicacion.posicionActual().timeout(
        const Duration(seconds: 8),
      );
      lat = punto.latitude;
      lng = punto.longitude;
    } catch (_) {}

    try {
      await retos.pedirReto(widget.localId, lat: lat, lng: lng);
      HapticFeedback.heavyImpact();
      if (mounted) ref.invalidate(_miRetoProvider);
    } on ErrorReto catch (e) {
      _fallo(e.mensaje);
      // Si ya habia uno abierto, que aparezca en vez de seguir escondido.
      if (e.motivo == MotivoSinReto.yaTienesReto && mounted) {
        ref.invalidate(_miRetoProvider);
      }
    } catch (_) {
      _fallo(MotivoSinReto.desconocido.mensaje);
    } finally {
      if (mounted && _fase == _Fase.pidiendo) {
        setState(() => _fase = _Fase.listo);
      }
    }
  }

  Future<void> _cumplir(Reto reto) async {
    if (_ocupado) return;
    final pendiente = _pendiente;
    if (pendiente != null && pendiente.reto == reto.id) {
      return _marcarHecho(reto, pendiente.publicacion);
    }

    final social = ref.read(repositorioSocialProvider);
    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (foto == null || !mounted) return;

    setState(() {
      _fase = _Fase.subiendo;
      _error = null;
    });
    try {
      final bytes = await foto.readAsBytes();
      final punto = foto.name.lastIndexOf('.');
      // A la sala del reto y con su noche: puede no ser la sala desde la
      // que lo miras, y a las seis el reloj ya diria otro dia.
      final publicacion = await social.publicarEnSala(
        localId: reto.localId,
        noche: DateTime(reto.noche.year, reto.noche.month, reto.noche.day, 12),
        bytes: bytes,
        extension: punto > 0
            ? foto.name.substring(punto + 1).toLowerCase()
            : 'jpg',
        esVideo: false,
        texto: '$nombreDelJuego · ${reto.texto}',
      );
      _pendiente = (reto: reto.id, publicacion: publicacion);
    } catch (_) {
      _fallo('No se ha podido subir la foto. Prueba otra vez.');
      if (mounted) setState(() => _fase = _Fase.listo);
      return;
    }
    await _marcarHecho(reto, _pendiente!.publicacion);
  }

  Future<void> _marcarHecho(Reto reto, String publicacion) async {
    final retos = ref.read(repositorioRetosProvider);
    if (mounted) {
      setState(() {
        _fase = _Fase.subiendo;
        _error = null;
      });
    }
    try {
      await retos.completar(reto.id, publicacion);
      _pendiente = null;
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      ref.invalidate(_miRetoProvider);
      setState(() => _fase = _Fase.cumplido);
    } catch (_) {
      _fallo(
        'La foto está subida pero no se ha podido dar el reto por '
        'hecho. Pulsa otra vez.',
      );
      if (mounted) setState(() => _fase = _Fase.listo);
    }
  }

  Future<void> _rajarse(Reto reto) async {
    if (_ocupado) return;
    final retos = ref.read(repositorioRetosProvider);
    final seguro = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿No hay huevos?'),
        content: Text(
          'Te rajas de este reto y cuenta para el límite de la noche. '
          '${reto.restantes == 0 ? 'Era el último.' : 'Te quedarán ${reto.restantes}.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Sigo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Me rajo 🐔'),
          ),
        ],
      ),
    );
    if (seguro != true || !mounted) return;

    try {
      await retos.rajarse(reto.id);
      if (mounted) {
        setState(() => _error = null);
        ref.invalidate(_miRetoProvider);
      }
    } catch (_) {
      _fallo('No se ha podido cerrar el reto.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reto = ref.watch(_miRetoProvider);

    final contenido = switch (_fase) {
      _Fase.cumplido => _Cumplido(
        onOtro: () {
          setState(() => _fase = _Fase.listo);
        },
      ),
      _ => reto.when(
        loading: () => const _Cargando(texto: 'Mirando quién hay…'),
        error: (_, _) => _Invitacion(
          ocupado: false,
          aviso: 'No hemos podido cargar el juego.',
          onJugar: () => ref.invalidate(_miRetoProvider),
          textoBoton: 'Reintentar',
        ),
        data: (r) => r == null
            ? _Invitacion(
                ocupado: _fase == _Fase.pidiendo,
                onJugar: _pedir,
                textoBoton: 'Dame un reto',
              )
            : _FichaReto(
                reto: r,
                enOtroLocal: r.localId != widget.localId,
                subiendo: _fase == _Fase.subiendo,
                onCumplir: () => _cumplir(r),
                onRajarse: () => _rajarse(r),
              ),
      ),
    };

    final c = context.colores;
    return PopScope(
      // Mientras sube la foto no se cierra: cerrarla a medias dejaba la foto
      // en la sala con el reto sin cumplir.
      canPop: !_ocupado,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          EspaciadoPrevia.l,
          EspaciadoPrevia.s,
          EspaciadoPrevia.l,
          EspaciadoPrevia.l,
        ),
        child: AnimatedSize(
          duration: MovimientoPrevia.normal,
          curve: MovimientoPrevia.curva,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(contenido.runtimeType),
                  child: contenido,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: EspaciadoPrevia.m),
                Container(
                      padding: const EdgeInsets.all(EspaciadoPrevia.m),
                      decoration: BoxDecoration(
                        color: c.superficieAlta,
                        borderRadius: BorderRadius.circular(
                          EspaciadoPrevia.radio,
                        ),
                        border: Border.all(color: c.borde),
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: MovimientoPrevia.rapido)
                    .shake(hz: 4, offset: const Offset(4, 0), duration: 300.ms),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Asa extends StatelessWidget {
  const _Asa();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: EspaciadoPrevia.m),
      decoration: BoxDecoration(
        color: context.colores.borde,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
      ),
    ),
  );
}

class _Cargando extends StatelessWidget {
  const _Cargando({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 220,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🥚', style: TextStyle(fontSize: 48))
            .animate(onPlay: (c) => c.repeat())
            .shake(hz: 3, rotation: 0.12, duration: 900.ms),
        const SizedBox(height: EspaciadoPrevia.m),
        Text(texto, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}

class _Invitacion extends StatelessWidget {
  const _Invitacion({
    required this.ocupado,
    required this.onJugar,
    required this.textoBoton,
    this.aviso,
  });

  final bool ocupado;
  final VoidCallback onJugar;
  final String textoBoton;
  final String? aviso;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = context.colores;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Asa(),
        const Text(
          '🥚',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 56),
        ).animate().scale(
          begin: const Offset(.6, .6),
          curve: Curves.elasticOut,
          duration: 700.ms,
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        Text(
          nombreDelJuego,
          textAlign: TextAlign.center,
          style: textos.headlineMedium,
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        Text(
          aviso ??
              'Te toca alguien que está aquí esta noche. Encuéntrale, '
                  'haced lo que diga el reto y subid la foto a la sala.',
          textAlign: TextAlign.center,
          style: textos.bodyLarge?.copyWith(color: c.textoSuave),
        ),
        const SizedBox(height: EspaciadoPrevia.l),
        FilledButton(
          onPressed: ocupado ? null : onJugar,
          child: ocupado
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: c.sobrePrimario,
                  ),
                )
              : Text(textoBoton),
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        Text(
          'Solo juegan quienes han dicho que vienen. Si no quieres salir '
          'en retos, apágalo en Ajustes.',
          textAlign: TextAlign.center,
          style: textos.labelMedium?.copyWith(color: c.textoTenue),
        ),
      ],
    );
  }
}

class _FichaReto extends StatelessWidget {
  const _FichaReto({
    required this.reto,
    required this.enOtroLocal,
    required this.subiendo,
    required this.onCumplir,
    required this.onRajarse,
  });

  final Reto reto;

  /// El reto es de otro local al que tambien dijiste que ibas.
  final bool enOtroLocal;
  final bool subiendo;
  final VoidCallback onCumplir;
  final VoidCallback onRajarse;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = context.colores;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Asa(),
        Row(
          children: [
            Text(
              'TU RETO',
              style: textos.labelMedium?.copyWith(
                color: c.primarioTexto,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              reto.restantes == 0
                  ? 'Último de la noche'
                  : 'Quedan ${reto.restantes} más',
              style: textos.labelMedium?.copyWith(color: c.textoTenue),
            ),
          ],
        ),
        if (enOtroLocal)
          Padding(
            padding: const EdgeInsets.only(top: EspaciadoPrevia.xs),
            child: Text(
              'En ${reto.localNombre}',
              style: textos.bodyMedium?.copyWith(color: c.textoSuave),
            ),
          ),
        const SizedBox(height: EspaciadoPrevia.s),
        Text(reto.texto, style: textos.headlineMedium)
            .animate()
            .fadeIn(duration: 320.ms)
            .moveY(begin: 8, curve: Curves.easeOutCubic),
        const SizedBox(height: EspaciadoPrevia.l),

        // La ficha de a quien buscas: con la cara grande, porque en un local
        // lleno el nombre solo no sirve para encontrar a nadie.
        Container(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          decoration: BoxDecoration(
            color: c.superficieAlta,
            borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
          ),
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.primario, width: 3),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: AvatarPerfil(
                    url: reto.objetivoAvatar,
                    inicial: reto.objetivoNombre,
                    lado: 120,
                  ),
                ),
              ).animate().scale(
                begin: const Offset(.85, .85),
                curve: Curves.easeOutBack,
                duration: 420.ms,
              ),
              const SizedBox(height: EspaciadoPrevia.m),
              Text(
                reto.objetivoNombre,
                style: textos.titleLarge,
                textAlign: TextAlign.center,
              ),
              Text(
                '@${reto.objetivoUsuario}',
                style: textos.bodyMedium?.copyWith(color: c.textoTenue),
              ),
              if (reto.objetivoBio != null &&
                  reto.objetivoBio!.trim().isNotEmpty) ...[
                const SizedBox(height: EspaciadoPrevia.s),
                Text(
                  reto.objetivoBio!,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: textos.bodyMedium?.copyWith(color: c.textoSuave),
                ),
              ],
              const SizedBox(height: EspaciadoPrevia.s),
              TextButton(
                onPressed: () =>
                    context.push('${Rutas.perfilDe}/${reto.objetivoId}'),
                child: const Text('Ver su perfil'),
              ),
            ],
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.l),
        FilledButton.icon(
          onPressed: subiendo ? null : onCumplir,
          icon: subiendo
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: c.sobrePrimario,
                  ),
                )
              : const Icon(Icons.photo_camera_rounded),
          label: Text(subiendo ? 'Subiendo…' : 'Hecho: subir la foto'),
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        TextButton(
          onPressed: subiendo ? null : onRajarse,
          child: const Text('No hay huevos 🐔'),
        ),
      ],
    );
  }
}

class _Cumplido extends StatelessWidget {
  const _Cumplido({required this.onOtro});

  final VoidCallback onOtro;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Asa(),
        const Text(
              '🐣',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 72),
            )
            .animate()
            .scale(
              begin: const Offset(.3, .3),
              curve: Curves.elasticOut,
              duration: 900.ms,
            )
            .then()
            .shake(hz: 4, rotation: 0.1, duration: 500.ms),
        const SizedBox(height: EspaciadoPrevia.s),
        Text(
          '¡Sí hay huevos!',
          textAlign: TextAlign.center,
          style: textos.headlineMedium,
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        Text(
          'La foto ya está en la sala. Le hemos avisado para que la vea.',
          textAlign: TextAlign.center,
          style: textos.bodyLarge?.copyWith(color: context.colores.textoSuave),
        ),
        const SizedBox(height: EspaciadoPrevia.l),
        FilledButton(onPressed: onOtro, child: const Text('Otro reto')),
      ],
    );
  }
}

/// Lo que ve quien sale en la foto de un reto: que reto era y la opcion de
/// quitarla. Se abre desde el aviso.
Future<void> abrirRetoConmigo(
  BuildContext context,
  WidgetRef ref, {
  required String publicacionId,
  String? fotoUrl,
}) async {
  final repo = ref.read(repositorioRetosProvider);
  final RetoConmigo? reto;
  try {
    reto = await repo.retoDeLaFoto(publicacionId);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se ha podido abrir el reto.')),
      );
    }
    return;
  }
  if (!context.mounted) return;
  if (reto == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Esa foto ya no está.')));
    return;
  }

  final quitar = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    backgroundColor: context.colores.superficie,
    builder: (contexto) {
      final textos = Theme.of(contexto).textTheme;
      return Padding(
        padding: const EdgeInsets.all(EspaciadoPrevia.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Asa(),
            if (fotoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Image.network(fotoUrl, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: EspaciadoPrevia.m),
            Text(
              'Sales en un reto de $nombreDelJuego',
              style: textos.titleLarge,
            ),
            const SizedBox(height: EspaciadoPrevia.xs),
            Text(reto!.texto, style: textos.bodyLarge),
            const SizedBox(height: EspaciadoPrevia.l),
            OutlinedButton(
              onPressed: () => Navigator.pop(contexto, true),
              child: const Text('Quitar la foto de la sala'),
            ),
          ],
        ),
      );
    },
  );

  if (quitar != true) return;
  try {
    await repo.quitarFoto(reto.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Foto quitada.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se ha podido quitar la foto.')),
      );
    }
  }
}
