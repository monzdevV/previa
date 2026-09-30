import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_previas.dart';
import '../party/estados_pantalla.dart';
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
        loading: () => const IndicadorCarga(),
        error: (e, _) => EstadoError(
          mensaje: 'No se ha podido cargar quién fue',
          detalle: 'Comprueba tu conexión e inténtalo otra vez.',
          onReintentar: () => ref.invalidate(companerosProvider(previaId)),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return const EstadoVacio(
              icono: Icons.group_outlined,
              titulo: 'Nadie más a quien valorar',
              detalle: 'No hay nadie más a quien valorar en esta previa.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(EspaciadoPrevia.l),
            children: [
              Text('¿Qué tal fue?', style: textos.headlineMedium),
              const SizedBox(height: EspaciadoPrevia.s),
              Text(
                'Tu valoración es pública y cuenta para su reputación. '
                'Sé justa: a ti te valoran igual.',
                style: textos.bodyMedium,
              ),
              const SizedBox(height: EspaciadoPrevia.l),
              for (final c in lista)
                Padding(
                  padding: const EdgeInsets.only(bottom: EspaciadoPrevia.m),
                  child: _FichaValoracion(
                    previaId: previaId,
                    perfilId: c['profile_id'] as String,
                    nombre:
                        (c['profiles'] as Map?)?['display_name'] as String? ??
                        'Alguien',
                    esAnfitrion: c['role'] == 'host',
                    puntuacionPrevia: yaValoradas[c['profile_id']],
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
    required this.previaId,
    required this.perfilId,
    required this.nombre,
    required this.esAnfitrion,
    this.puntuacionPrevia,
  });

  final String previaId;
  final String perfilId;
  final String nombre;
  final bool esAnfitrion;
  final int? puntuacionPrevia;

  @override
  ConsumerState<_FichaValoracion> createState() => _FichaValoracionState();
}

class _FichaValoracionState extends ConsumerState<_FichaValoracion> {
  final _comentario = TextEditingController();
  int? _puntuacion;
  final _etiquetas = <String>{};
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

  Future<void> _guardar() async {
    final puntuacion = _puntuacion;
    if (puntuacion == null) return;

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
      if (mounted) setState(() => _guardada = true);
      mensajero.showSnackBar(
        SnackBar(content: Text('Valoración guardada para ${widget.nombre}.')),
      );
    } on ErrorPrevia catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (_) {
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('No se ha podido guardar. Inténtalo de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final sinMovimiento = MediaQuery.disableAnimationsOf(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EspaciadoPrevia.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Decorativo: el nombre está justo al lado, leer también la
                // inicial sería redundante.
                ExcludeSemantics(
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: ColoresPrevia.superficieAlta,
                    child: Text(
                      widget.nombre.isNotEmpty
                          ? widget.nombre[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ColoresPrevia.texto,
                      ),
                    ),
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
                if (_guardada)
                  const Icon(
                    Icons.check_circle,
                    color: ColoresPrevia.acento,
                    size: 20,
                  ),
              ],
            ),

            const SizedBox(height: EspaciadoPrevia.m),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    // Una estrella sin etiqueta es un botón mudo; el tooltip
                    // es además su nombre para el lector. 48 dp de objetivo.
                    tooltip: i == 1
                        ? '1 estrella para ${widget.nombre}'
                        : '$i estrellas para ${widget.nombre}',
                    isSelected: (_puntuacion ?? 0) >= i,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => setState(() {
                      _puntuacion = i;
                      _guardada = false;
                    }),
                    // Rebote breve al rellenarse: confirma el toque sin
                    // distraer. Con "reducir movimiento" no hay escala.
                    icon: AnimatedScale(
                      scale: (_puntuacion ?? 0) >= i && !sinMovimiento
                          ? 1.15
                          : 1,
                      duration: sinMovimiento
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        (_puntuacion ?? 0) >= i
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 32,
                        color: (_puntuacion ?? 0) >= i
                            ? ColoresPrevia.aviso
                            : ColoresPrevia.textoTenue,
                      ),
                    ),
                  ),
              ],
            ),

            if (_puntuacion != null && !_guardada) ...[
              const SizedBox(height: EspaciadoPrevia.s),
              Text('¿Qué destacarías?', style: textos.bodyMedium),
              const SizedBox(height: EspaciadoPrevia.s),
              Wrap(
                spacing: EspaciadoPrevia.s,
                runSpacing: EspaciadoPrevia.xs,
                children: [
                  for (final e in etiquetasValoracion)
                    FilterChip(
                      avatar: Icon(e.icono, size: 18),
                      label: Text(e.texto),
                      selected: _etiquetas.contains(e.clave),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: (marcada) => setState(() {
                        if (marcada) {
                          _etiquetas.add(e.clave);
                        } else {
                          _etiquetas.remove(e.clave);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: EspaciadoPrevia.s),
              TextField(
                controller: _comentario,
                // Deja sitio a las etiquetas dentro de los 300 caracteres
                // que admite la columna.
                maxLength: 240,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Añade un comentario (opcional)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: EspaciadoPrevia.s),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                child: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                          semanticsLabel: 'Guardando',
                        ),
                      )
                    : const Text('Guardar valoración'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
