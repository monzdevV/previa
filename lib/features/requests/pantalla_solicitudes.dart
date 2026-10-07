import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/previa.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_previas.dart';
import '../map/proveedores_mapa.dart';
import 'piezas_solicitudes.dart';

final solicitudesDeProvider = FutureProvider.family<List<Solicitud>, String>(
  (ref, previaId) =>
      ref.watch(repositorioPreviasProvider).solicitudesDe(previaId),
);

/// Bandeja del anfitrión: quién quiere entrar en su previa.
///
/// Aceptar o rechazar es lo único que hace esta pantalla. El recuento de
/// plazas, el alta como miembro y el paso a "completa" los resuelve un
/// disparador en la base de datos, no este código: así dos anfitriones
/// aceptando a la vez no pueden pasarse del aforo.
class PantallaSolicitudes extends ConsumerWidget {
  const PantallaSolicitudes({super.key, required this.previaId});

  final String previaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudes = ref.watch(solicitudesDeProvider(previaId));
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes')),
      body: solicitudes.when(
        loading: () => const Cargando(),
        error: (e, _) => Semantics(
          liveRegion: true,
          child: EstadoVacio(
            icono: Icons.cloud_off_rounded,
            titulo: 'Sin conexión',
            detalle:
                'No hemos podido traer las solicitudes. '
                'Comprueba tu conexión.',
            accion: 'Reintentar',
            onAccion: () => ref.invalidate(solicitudesDeProvider(previaId)),
          ),
        ),
        data: (lista) {
          final pendientes = lista.where((s) => s.estaPendiente).toList();
          final resueltas = lista.where((s) => !s.estaPendiente).toList();

          if (lista.isEmpty) {
            return EstadoVacio(
              pegatina: '📭',
              titulo: 'Nadie ha pedido plaza todavía',
              detalle:
                  'Dale tiempo. Y si tarda, prueba a añadir una '
                  'descripción y etiquetas de ambiente.',
              accion: 'Comprobar de nuevo',
              onAccion: () => ref.invalidate(solicitudesDeProvider(previaId)),
            );
          }

          return RefreshIndicator(
            color: context.colores.primarioTexto,
            backgroundColor: context.colores.superficie,
            onRefresh: () async {
              ref.invalidate(solicitudesDeProvider(previaId));
              try {
                await ref.read(solicitudesDeProvider(previaId).future);
              } catch (_) {
                // El fallo ya lo pinta el estado de error de la pantalla.
              }
            },
            child: ListView(
              padding: const EdgeInsets.all(EspaciadoPrevia.l),
              children: [
                if (pendientes.isNotEmpty) ...[
                  Semantics(
                    header: true,
                    child: Text(
                      pendientes.length == 1
                          ? '1 solicitud pendiente'
                          : '${pendientes.length} solicitudes pendientes',
                      style: textos.titleLarge,
                    ),
                  ),
                  const SizedBox(height: EspaciadoPrevia.m),
                  for (var i = 0; i < pendientes.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
                      child: EntradaLista(
                        indice: i,
                        child: _TarjetaSolicitud(
                          // Clave por id: al resolver una, las demás conservan
                          // su estado en vez de intercambiárselo.
                          key: ValueKey(pendientes[i].id),
                          solicitud: pendientes[i],
                          previaId: previaId,
                        ),
                      ),
                    ),
                ],
                if (resueltas.isNotEmpty) ...[
                  const SizedBox(height: EspaciadoPrevia.l),
                  Semantics(
                    header: true,
                    child: Text('Ya resueltas', style: textos.titleLarge),
                  ),
                  const SizedBox(height: EspaciadoPrevia.m),
                  for (final s in resueltas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
                      child: _TarjetaSolicitud(
                        key: ValueKey(s.id),
                        solicitud: s,
                        previaId: previaId,
                        soloLectura: true,
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TarjetaSolicitud extends ConsumerStatefulWidget {
  const _TarjetaSolicitud({
    super.key,
    required this.solicitud,
    required this.previaId,
    this.soloLectura = false,
  });

  final Solicitud solicitud;
  final String previaId;
  final bool soloLectura;

  @override
  ConsumerState<_TarjetaSolicitud> createState() => _TarjetaSolicitudState();
}

class _TarjetaSolicitudState extends ConsumerState<_TarjetaSolicitud> {
  bool _procesando = false;

  /// Aceptar y rechazar no se pueden deshacer desde la app (el servidor da de
  /// alta al miembro, ajusta el aforo y abre el chat), así que se confirma
  /// antes en lugar de ofrecer un "deshacer" que no podríamos cumplir.
  Future<void> _pedirConfirmacion({required bool aceptar}) async {
    final s = widget.solicitud;
    final c = context.colores;
    final plazas = s.tamanoGrupo == 1 ? '1 plaza' : '${s.tamanoGrupo} plazas';

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        backgroundColor: c.superficieAlta,
        title: Text(
          aceptar
              ? '¿Aceptar a ${s.nombreSolicitante}?'
              : '¿Rechazar a ${s.nombreSolicitante}?',
        ),
        content: Text(
          aceptar
              ? '${s.resumenGrupo}: ocuparán $plazas. Verán la dirección '
                    'exacta y entrarán en el chat.'
              : 'No verán la dirección ni entrarán en el chat. '
                    'No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: c.texto,
              minimumSize: const Size(0, 48),
            ),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: aceptar ? c.primario : c.error,
              // Sobre el amarillo, negro; sobre el rojo de error, blanco.
              foregroundColor: aceptar ? c.sobrePrimario : Colors.white,
            ),
            child: Text(aceptar ? 'Sí, aceptar' : 'Sí, rechazar'),
          ),
        ],
      ),
    );
    if (confirmado == true && mounted) await _responder(aceptar: aceptar);
  }

  Future<void> _responder({required bool aceptar}) async {
    setState(() => _procesando = true);
    final mensajero = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(repositorioPreviasProvider)
          .responderSolicitud(widget.solicitud.id, aceptar: aceptar);

      ref.invalidate(solicitudesDeProvider(widget.previaId));
      ref.invalidate(misPreviasProvider);
      ref.invalidate(previasCercaProvider);

      if (aceptar) HapticFeedback.heavyImpact();
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            aceptar
                ? '${widget.solicitud.nombreSolicitante} está dentro. '
                      'Ya podéis hablar por el chat.'
                : 'Solicitud rechazada.',
          ),
        ),
      );
    } on ErrorPrevia catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (_) {
      // Un fallo de red no puede dejar el botón sin respuesta: se avisa y se
      // puede volver a intentar.
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('No se ha podido responder. Inténtalo otra vez.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final cuando = DateFormat('d MMM · HH:mm', 'es_ES').format(s.creadaEn);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EspaciadoPrevia.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Antes de aceptar a alguien en casa hay que verle la cara y
                // poder abrir su perfil.
                Semantics(
                  button: true,
                  label: 'Ver el perfil de ${s.nombreSolicitante}',
                  excludeSemantics: true,
                  child: Pulsable(
                    escala: 0.97,
                    onTap: () =>
                        context.push('${Rutas.perfilDe}/${s.solicitanteId}'),
                    child: AvatarPerfil(
                      url: s.avatarSolicitante,
                      inicial: s.nombreSolicitante,
                      lado: 48,
                    ),
                  ),
                ),
                const SizedBox(width: EspaciadoPrevia.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.nombreSolicitante, style: textos.titleLarge),
                      Row(
                        children: [
                          if (s.reputacionSolicitante != null) ...[
                            ExcludeSemantics(
                              child: Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: c.aviso,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              s.reputacionSolicitante!.toStringAsFixed(1),
                              semanticsLabel:
                                  'Reputación '
                                  '${s.reputacionSolicitante!.toStringAsFixed(1)}'
                                  ' de 5',
                              style: textos.bodyMedium?.copyWith(
                                fontSize: 12,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(width: EspaciadoPrevia.s),
                          ],
                          Flexible(
                            child: Text(
                              cuando,
                              overflow: TextOverflow.ellipsis,
                              style: textos.bodyMedium?.copyWith(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: EspaciadoPrevia.s),
                _Insignia(solicitud: s),
              ],
            ),

            const SizedBox(height: EspaciadoPrevia.m),
            // El tamaño del grupo es lo primero que se mira antes de aceptar:
            // va en pastilla neutra (el verde se reserva a "queda sitio").
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: EspaciadoPrevia.s + 2,
                vertical: EspaciadoPrevia.xs + 2,
              ),
              decoration: BoxDecoration(
                color: c.superficieAlta,
                borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Icon(Icons.group, size: 14, color: c.primarioTexto),
                  ),
                  const SizedBox(width: EspaciadoPrevia.xs),
                  Flexible(
                    child: Text(
                      s.resumenGrupo,
                      style: TextStyle(
                        color: c.texto,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (s.mensaje != null && s.mensaje!.isNotEmpty) ...[
              const SizedBox(height: EspaciadoPrevia.m),
              Text(
                '"${s.mensaje!}"',
                style: textos.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],

            if (!widget.soloLectura && s.estaPendiente) ...[
              const SizedBox(height: EspaciadoPrevia.m),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _procesando
                          ? null
                          : () => _pedirConfirmacion(aceptar: false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(
                        'Rechazar',
                        semanticsLabel: 'Rechazar a ${s.nombreSolicitante}',
                      ),
                    ),
                  ),
                  const SizedBox(width: EspaciadoPrevia.s),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _procesando
                          ? null
                          : () => _pedirConfirmacion(aceptar: true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      // El texto y la rueda se funden: sin salto de anchura.
                      child: AnimatedSwitcher(
                        duration: MovimientoPrevia.reducido(context)
                            ? Duration.zero
                            : MovimientoPrevia.rapido,
                        switchInCurve: MovimientoPrevia.curva,
                        child: _procesando
                            ? SizedBox(
                                key: const ValueKey('cargando'),
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: c.textoSuave,
                                  semanticsLabel: 'Enviando respuesta',
                                ),
                              )
                            : Text(
                                s.tamanoGrupo == 1
                                    ? 'Aceptar'
                                    : 'Aceptar a ${s.tamanoGrupo}',
                                key: const ValueKey('texto'),
                                semanticsLabel: s.tamanoGrupo == 1
                                    ? 'Aceptar a ${s.nombreSolicitante}'
                                    : 'Aceptar a ${s.nombreSolicitante} '
                                          'y su grupo de ${s.tamanoGrupo}',
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: EspaciadoPrevia.s),
              Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.lock_open_rounded,
                      size: 14,
                      color: c.textoSuave,
                    ),
                  ),
                  const SizedBox(width: EspaciadoPrevia.xs),
                  Expanded(
                    child: Text(
                      'Si aceptas, verá la dirección exacta.',
                      style: textos.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: c.textoSuave,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Insignia extends StatelessWidget {
  const _Insignia({required this.solicitud});
  final Solicitud solicitud;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final (texto, color) = switch (solicitud.estado) {
      EstadoSolicitud.pendiente => ('Pendiente', c.aviso),
      EstadoSolicitud.aceptada => ('Aceptada', c.acento),
      EstadoSolicitud.rechazada => ('Rechazada', c.textoSuave),
      EstadoSolicitud.cancelada => ('Cancelada', c.textoSuave),
    };

    return PastillaEstado(texto: texto, color: color);
  }
}
