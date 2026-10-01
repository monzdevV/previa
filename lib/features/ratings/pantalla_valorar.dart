import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_previas.dart';
import '../requests/piezas_solicitudes.dart' show EntradaLista;
import 'etiquetas_valoracion.dart';

final companerosProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
      (ref, previaId) =>
          ref.watch(repositorioPreviasProvider).companerosDe(previaId),
    );

final misValoracionesProvider = FutureProvider.family<Map<String, int>, String>(
  (ref, previaId) =>
      ref.watch(repositorioPreviasProvider).misValoracionesEn(previaId),
);

/// Lo que dice cada numero de estrellas, para que puntuar no sea adivinar.
const _significados = ['Mal', 'Regular', 'Bien', 'Muy bien', 'Genial'];

/// Valorar a quien coincidió contigo en una previa.
///
/// La reputación es lo único que persiste de una previa cuando esta caduca,
/// así que es lo que sostiene la confianza del sistema entero: sin ella,
/// aceptar a un desconocido sería una apuesta a ciegas cada vez.
class PantallaValorar extends ConsumerWidget {
  const PantallaValorar({super.key, required this.previaId, this.titulo});

  final String previaId;
  final String? titulo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companeros = ref.watch(companerosProvider(previaId));
    final yaValoradas =
        ref.watch(misValoracionesProvider(previaId)).valueOrNull ?? {};
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(titulo ?? 'Valorar')),
      body: companeros.when(
        loading: () => const Cargando(),
        error: (e, _) => Semantics(
          liveRegion: true,
          child: EstadoVacio(
            icono: Icons.cloud_off_rounded,
            titulo: 'Sin conexión',
            detalle:
                'No hemos podido cargar quién fue. Comprueba tu conexión.',
            accion: 'Reintentar',
            onAccion: () => ref.invalidate(companerosProvider(previaId)),
          ),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return const EstadoVacio(
              pegatina: '🫥',
              titulo: 'Nadie más a quien valorar',
              detalle: 'En esta previa no había nadie más contigo.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(EspaciadoPrevia.l),
            children: [
              const Titular('¿Qué tal fue?', tamano: 34),
              const SizedBox(height: EspaciadoPrevia.s),
              Text(
                'Tu valoración es pública y cuenta para su reputación. '
                'Sé justa: a ti te valoran igual.',
                style: textos.bodyMedium,
              ),
              const SizedBox(height: EspaciadoPrevia.l),
              for (var i = 0; i < lista.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: EspaciadoPrevia.m),
                  child: EntradaLista(
                    indice: i,
                    child: _FichaValoracion(
                      key: ValueKey(lista[i]['profile_id']),
                      previaId: previaId,
                      perfilId: lista[i]['profile_id'] as String,
                      nombre:
                          (lista[i]['profiles'] as Map?)?['display_name']
                              as String? ??
                          'Alguien',
                      avatar:
                          (lista[i]['profiles'] as Map?)?['avatar_url']
                              as String?,
                      esAnfitrion: lista[i]['role'] == 'host',
                      puntuacionPrevia: yaValoradas[lista[i]['profile_id']],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FichaValoracion extends ConsumerStatefulWidget {
  const _FichaValoracion({
    super.key,
    required this.previaId,
    required this.perfilId,
    required this.nombre,
    required this.esAnfitrion,
    this.avatar,
    this.puntuacionPrevia,
  });

  final String previaId;
  final String perfilId;
  final String nombre;
  final String? avatar;
  final bool esAnfitrion;
  final int? puntuacionPrevia;

  @override
  ConsumerState<_FichaValoracion> createState() => _FichaValoracionState();
}

class _FichaValoracionState extends ConsumerState<_FichaValoracion> {
  final _comentario = TextEditingController();
  final _etiquetas = <String>{};
  int? _puntuacion;
  bool _guardando = false;
  bool _guardada = false;

  @override
  void initState() {
    super.initState();
    _puntuacion = widget.puntuacionPrevia;
    _guardada = widget.puntuacionPrevia != null;
  }

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  void _puntuar(int estrellas) {
    HapticFeedback.selectionClick();
    setState(() {
      _puntuacion = estrellas;
      _guardada = false;
    });
  }

  void _alternarEtiqueta(String clave) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_etiquetas.remove(clave)) _etiquetas.add(clave);
    });
  }

  Future<void> _guardar() async {
    final puntuacion = _puntuacion;
    if (puntuacion == null || _guardando) return;

    setState(() => _guardando = true);
    final mensajero = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(repositorioPreviasProvider)
          .valorar(
            previaId: widget.previaId,
            perfilId: widget.perfilId,
            puntuacion: puntuacion,
            comentario: componerComentario(_etiquetas, _comentario.text),
          );
      ref.invalidate(misValoracionesProvider(widget.previaId));
      ref.invalidate(miPerfilProvider);
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _guardada = true);
      mensajero.showSnackBar(
        SnackBar(content: Text('Valoración guardada para ${widget.nombre}.')),
      );
    } on ErrorPrevia catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (_) {
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('No se ha podido guardar. Inténtalo otra vez.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final reducido = MovimientoPrevia.reducido(context);
    final nota = _puntuacion ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EspaciadoPrevia.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Decorativa: el nombre va justo al lado.
                ExcludeSemantics(
                  child: AvatarPerfil(
                    url: widget.avatar,
                    inicial: widget.nombre,
                    lado: 44,
                  ),
                ),
                const SizedBox(width: EspaciadoPrevia.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.nombre, style: textos.titleLarge),
                      if (widget.esAnfitrion)
                        Text('Organizaba la previa', style: textos.bodyMedium),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: reducido ? Duration.zero : MovimientoPrevia.rapido,
                  switchInCurve: MovimientoPrevia.curva,
                  transitionBuilder: (hijo, animacion) => FadeTransition(
                    opacity: animacion,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.9, end: 1.0).animate(animacion),
                      child: hijo,
                    ),
                  ),
                  child: _guardada
                      ? Icon(
                          Icons.check_circle,
                          key: const ValueKey('hecha'),
                          color: c.acento,
                          size: 22,
                          semanticLabel: 'Valoración guardada',
                        )
                      : const SizedBox.shrink(key: ValueKey('nada')),
                ),
              ],
            ),

            const SizedBox(height: EspaciadoPrevia.s),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    // Una estrella sin etiqueta es un botón mudo; el tooltip
                    // es además su nombre para el lector.
                    tooltip: i == 1
                        ? '1 estrella para ${widget.nombre}'
                        : '$i estrellas para ${widget.nombre}',
                    isSelected: nota >= i,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => _puntuar(i),
                    // Salto breve al rellenarse: confirma el toque sin
                    // distraer. Con menos movimiento no hay escala.
                    icon: AnimatedScale(
                      scale: nota >= i && !reducido ? 1.12 : 1,
                      duration: reducido
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        nota >= i
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 32,
                        color: nota >= i ? c.aviso : c.textoTenue,
                      ),
                    ),
                  ),
              ],
            ),
            // Lo que significa la nota, en palabras: puntuar no es adivinar.
            // Ya lo dicen las estrellas al lector, asi que se le oculta.
            if (nota > 0)
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(left: EspaciadoPrevia.s + 4),
                  child: Text(
                    _significados[nota - 1].toUpperCase(),
                    style: TextStyle(
                      fontFamily: LetraPrevia.titular,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.4,
                      color: c.textoSuave,
                    ),
                  ),
                ),
              ),

            // El resto aparece al elegir estrellas: primero lo rápido (una
            // nota), luego lo opcional.
            AnimatedSize(
              duration: reducido
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: MovimientoPrevia.curva,
              alignment: Alignment.topCenter,
              child: _puntuacion != null && !_guardada
                  ? _Detalle(
                      etiquetas: _etiquetas,
                      onEtiqueta: _alternarEtiqueta,
                      comentario: _comentario,
                      guardando: _guardando,
                      onGuardar: _guardar,
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiquetas rápidas, comentario y botón de guardar.
class _Detalle extends StatelessWidget {
  const _Detalle({
    required this.etiquetas,
    required this.onEtiqueta,
    required this.comentario,
    required this.guardando,
    required this.onGuardar,
  });

  final Set<String> etiquetas;
  final ValueChanged<String> onEtiqueta;
  final TextEditingController comentario;
  final bool guardando;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: EspaciadoPrevia.s),
        Semantics(
          header: true,
          child: Text('¿Qué destacarías?', style: textos.titleMedium),
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        Wrap(
          spacing: EspaciadoPrevia.s,
          runSpacing: EspaciadoPrevia.s,
          children: [
            for (final e in etiquetasValoracion)
              _EtiquetaRapida(
                etiqueta: e,
                marcada: etiquetas.contains(e.clave),
                onTap: () => onEtiqueta(e.clave),
              ),
          ],
        ),
        const SizedBox(height: EspaciadoPrevia.m),
        TextField(
          controller: comentario,
          // Deja sitio a las etiquetas dentro de los 300 caracteres que
          // admite la columna.
          maxLength: 240,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Añade un comentario (opcional)',
            counterText: '',
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.m),
        FilledButton(
          onPressed: guardando ? null : onGuardar,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          child: AnimatedSwitcher(
            duration: MovimientoPrevia.reducido(context)
                ? Duration.zero
                : MovimientoPrevia.rapido,
            child: guardando
                ? SizedBox(
                    key: const ValueKey('guardando'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: c.textoSuave,
                      semanticsLabel: 'Guardando',
                    ),
                  )
                : const Text('GUARDAR VALORACIÓN', key: ValueKey('texto')),
          ),
        ),
      ],
    );
  }
}

/// Pastilla que se marca y desmarca: amarilla con tinta negra cuando está
/// elegida, como el resto de selecciones de la app.
class _EtiquetaRapida extends StatelessWidget {
  const _EtiquetaRapida({
    required this.etiqueta,
    required this.marcada,
    required this.onTap,
  });

  final EtiquetaValoracion etiqueta;
  final bool marcada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final tinta = marcada ? c.sobrePrimario : c.texto;

    return Semantics(
      button: true,
      toggled: marcada,
      label: etiqueta.texto,
      excludeSemantics: true,
      child: Pulsable(
        escala: 0.97,
        vibrar: false,
        onTap: onTap,
        child: AnimatedContainer(
          duration: MovimientoPrevia.reducido(context)
              ? Duration.zero
              : MovimientoPrevia.rapido,
          curve: MovimientoPrevia.curva,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: EspaciadoPrevia.m - 2,
            vertical: EspaciadoPrevia.s,
          ),
          decoration: BoxDecoration(
            color: marcada ? c.primario : c.superficieAlta,
            borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
            border: Border.all(color: marcada ? c.primario : c.borde),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                marcada ? Icons.check_rounded : etiqueta.icono,
                size: 18,
                color: tinta,
              ),
              const SizedBox(width: EspaciadoPrevia.xs + 2),
              Text(
                etiqueta.texto,
                style: TextStyle(
                  fontFamily: LetraPrevia.titular,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tinta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
