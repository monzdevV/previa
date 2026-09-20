import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/tema.dart';
import '../../data/models/previa.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_previas.dart';
import '../map/proveedores_mapa.dart';

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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(EspaciadoPrevia.l),
            child: Text(
              'No se han podido cargar las solicitudes.',
              style: textos.bodyMedium,
            ),
          ),
        ),
        data: (lista) {
          final pendientes = lista.where((s) => s.estaPendiente).toList();
          final resueltas = lista.where((s) => !s.estaPendiente).toList();

          if (lista.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(EspaciadoPrevia.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inbox_outlined,
                        size: 40, color: ColoresPrevia.textoTenue),
                    const SizedBox(height: EspaciadoPrevia.m),
                    Text('Nadie ha pedido plaza todavía',
                        style: textos.titleLarge),
                    const SizedBox(height: EspaciadoPrevia.xs),
                    Text(
                      'Dale tiempo. Y si tarda, prueba a añadir una '
                      'descripción y etiquetas de ambiente.',
                      textAlign: TextAlign.center,
                      style: textos.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(solicitudesDeProvider(previaId)),
            child: ListView(
              padding: const EdgeInsets.all(EspaciadoPrevia.l),
              children: [
                if (pendientes.isNotEmpty) ...[
                  Text(
                    pendientes.length == 1
                        ? '1 solicitud pendiente'
                        : '${pendientes.length} solicitudes pendientes',
                    style: textos.titleLarge,
                  ),
                  const SizedBox(height: EspaciadoPrevia.m),
                  for (final s in pendientes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
                      child: _TarjetaSolicitud(solicitud: s, previaId: previaId),
                    ),
                ],
                if (resueltas.isNotEmpty) ...[
                  const SizedBox(height: EspaciadoPrevia.l),
                  Text('Ya resueltas', style: textos.titleLarge),
                  const SizedBox(height: EspaciadoPrevia.m),
                  for (final s in resueltas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
                      child: _TarjetaSolicitud(
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
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
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
                CircleAvatar(
                  radius: 20,
                  backgroundColor: ColoresPrevia.superficieAlta,
                  child: Text(
                    s.inicialSolicitante,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ColoresPrevia.texto,
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
                            const Icon(Icons.star_rounded,
                                size: 14, color: ColoresPrevia.aviso),
                            const SizedBox(width: 2),
                            Text(
                              s.reputacionSolicitante!.toStringAsFixed(1),
                              style: textos.bodyMedium?.copyWith(fontSize: 12),
                            ),
                            const SizedBox(width: EspaciadoPrevia.s),
                          ],
                          Text(cuando,
                              style: textos.bodyMedium?.copyWith(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                _Insignia(solicitud: s),
              ],
            ),

            const SizedBox(height: EspaciadoPrevia.m),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: EspaciadoPrevia.s + 2,
                vertical: EspaciadoPrevia.xs + 2,
              ),
              decoration: BoxDecoration(
                color: ColoresPrevia.acento.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.group, size: 14, color: ColoresPrevia.acento),
                  const SizedBox(width: EspaciadoPrevia.xs),
                  Text(
                    s.resumenGrupo,
                    style: const TextStyle(
                      color: ColoresPrevia.acento,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            if (s.mensaje != null && s.mensaje!.isNotEmpty) ...[
              const SizedBox(height: EspaciadoPrevia.m),
              Text('"${s.mensaje!}"',
                  style: textos.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),
            ],

            if (!widget.soloLectura && s.estaPendiente) ...[
              const SizedBox(height: EspaciadoPrevia.m),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _procesando ? null : () => _responder(aceptar: false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                      ),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: EspaciadoPrevia.s),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed:
                          _procesando ? null : () => _responder(aceptar: true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 46),
                      ),
                      child: _procesando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(s.tamanoGrupo == 1
                              ? 'Aceptar'
                              : 'Aceptar a ${s.tamanoGrupo}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: EspaciadoPrevia.s),
              Text(
                'Si aceptas, verá la dirección exacta.',
                style: textos.bodyMedium?.copyWith(
                  fontSize: 11,
                  color: ColoresPrevia.textoTenue,
                ),
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
    final (texto, color) = switch (solicitud.estado) {
      EstadoSolicitud.pendiente => ('Pendiente', ColoresPrevia.aviso),
      EstadoSolicitud.aceptada => ('Aceptada', ColoresPrevia.acento),
      EstadoSolicitud.rechazada => ('Rechazada', ColoresPrevia.textoTenue),
      EstadoSolicitud.cancelada => ('Cancelada', ColoresPrevia.textoTenue),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: EspaciadoPrevia.s, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        texto,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
