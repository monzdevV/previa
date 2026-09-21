import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../core/entorno.dart';
import '../../data/models/previa.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_previas.dart';
import '../map/proveedores_mapa.dart';
import '../requests/pantalla_solicitudes.dart';
import 'hoja_solicitar_plaza.dart';

final _detalleProvider = FutureProvider.family<Previa, String>(
  (ref, id) => ref.watch(repositorioPreviasProvider).detalle(id),
);

final _soyMiembroProvider = FutureProvider.family<bool, String>(
  (ref, id) => ref.watch(repositorioPreviasProvider).soyMiembro(id),
);

final _miSolicitudProvider = FutureProvider.family<Solicitud?, String>(
  (ref, id) => ref.watch(repositorioPreviasProvider).miSolicitudEn(id),
);

class PantallaDetallePrevia extends ConsumerWidget {
  const PantallaDetallePrevia({super.key, required this.previaId});

  final String previaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(_detalleProvider(previaId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Previa'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Theme.of(context).platform == TargetPlatform.iOS
                  ? Icons.more_horiz
                  : Icons.more_vert,
            ),
            color: ColoresPrevia.superficieAlta,
            onSelected: (opcion) =>
                _menu(context, ref, opcion, detalle.valueOrNull),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reportar', child: Text('Reportar')),
              PopupMenuItem(
                value: 'bloquear',
                child: Text('Bloquear al anfitrión'),
              ),
            ],
          ),
        ],
      ),
      body: detalle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(EspaciadoPrevia.l),
            child: Text(
              'No se ha podido cargar la previa.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        data: (previa) => _Contenido(previa: previa),
      ),
    );
  }

  Future<void> _menu(
    BuildContext context,
    WidgetRef ref,
    String opcion,
    Previa? previa,
  ) async {
    if (previa == null) return;
    final repo = ref.read(repositorioPreviasProvider);
    final mensajero = ScaffoldMessenger.of(context);

    if (opcion == 'bloquear') {
      final confirmado = await _confirmar(
        context,
        titulo: '¿Bloquear a ${previa.anfitrionNombre}?',
        detalle:
            'Dejaréis de veros por completo: sus previas desaparecerán '
            'de tu mapa y no podrá escribirte.',
        accion: 'Bloquear',
      );
      if (confirmado != true) return;

      await repo.bloquear(previa.anfitrionId);
      ref.invalidate(previasCercaProvider);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      mensajero.showSnackBar(
        const SnackBar(content: Text('Bloqueado. No volveréis a veros.')),
      );
      return;
    }

    if (!context.mounted) return;
    final motivo = await _elegirMotivo(context);
    if (motivo == null) return;

    await repo.reportar(
      motivo: motivo,
      previaId: previa.id,
      perfilId: previa.anfitrionId,
    );
    mensajero.showSnackBar(
      const SnackBar(content: Text('Reporte enviado. Gracias por avisar.')),
    );
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.previa});

  final Previa previa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final soyMiembro =
        ref.watch(_soyMiembroProvider(previa.id)).valueOrNull ?? false;
    final miSolicitud = ref.watch(_miSolicitudProvider(previa.id)).valueOrNull;
    final yoSoyElAnfitrion =
        ref.watch(repositorioAuthProvider).usuarioActual?.id ==
        previa.anfitrionId;

    final cuando = DateFormat(
      "EEEE d 'de' MMMM 'a las' HH:mm",
      'es_ES',
    ).format(previa.empiezaEn);

    return ListView(
      padding: const EdgeInsets.all(EspaciadoPrevia.l),
      children: [
        Text(previa.titulo, style: textos.headlineMedium),
        const SizedBox(height: EspaciadoPrevia.s),
        Text(
          cuando,
          style: textos.bodyLarge?.copyWith(color: ColoresPrevia.textoSuave),
        ),

        const SizedBox(height: EspaciadoPrevia.l),

        Row(
          children: [
            Expanded(
              child: _Dato(
                icono: Icons.event_seat,
                valor: previa.plazasLibres == 0
                    ? 'Completa'
                    : '${previa.plazasLibres}',
                etiqueta: previa.plazasLibres == 1
                    ? 'plaza libre'
                    : 'plazas libres',
                destacado: previa.quedanPlazas,
              ),
            ),
            const SizedBox(width: EspaciadoPrevia.s),
            Expanded(
              child: _Dato(
                icono: Icons.place_outlined,
                valor: previa.zona,
                etiqueta: previa.distanciaMetros != null
                    ? 'a ${previa.distanciaLegible}'
                    : 'zona',
              ),
            ),
          ],
        ),

        if (previa.descripcion != null && previa.descripcion!.isNotEmpty) ...[
          const SizedBox(height: EspaciadoPrevia.l),
          Text(previa.descripcion!, style: textos.bodyLarge),
        ],

        if (previa.ambiente.isNotEmpty) ...[
          const SizedBox(height: EspaciadoPrevia.l),
          Wrap(
            spacing: EspaciadoPrevia.s,
            runSpacing: EspaciadoPrevia.s,
            children: [for (final a in previa.ambiente) Chip(label: Text(a))],
          ),
        ],

        const SizedBox(height: EspaciadoPrevia.l),
        const Divider(),
        const SizedBox(height: EspaciadoPrevia.m),

        Text('Organiza', style: textos.titleLarge),
        const SizedBox(height: EspaciadoPrevia.m),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: ColoresPrevia.superficieAlta,
                border: Border.fromBorderSide(
                  BorderSide(color: ColoresPrevia.borde),
                ),
              ),
              child: Text(
                previa.anfitrionNombre.isNotEmpty
                    ? previa.anfitrionNombre[0].toUpperCase()
                    : '?',
                style: textos.titleMedium,
              ),
            ),
            const SizedBox(width: EspaciadoPrevia.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(previa.anfitrionNombre, style: textos.titleLarge),
                  if (previa.anfitrionReputacion != null)
                    // Sin estrella y sin ambar: la tinta viva esta reservada a
                    // las plazas libres, y "sobre cinco" lo dice el texto.
                    Text(
                      '${previa.anfitrionReputacion!.toStringAsFixed(1).replaceAll('.', ',')}/5'
                      '  ·  VALORACIÓN',
                      style: textos.labelMedium,
                    )
                  else
                    Text('Sin valoraciones todavía', style: textos.bodyMedium),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: EspaciadoPrevia.l),
        _MapaZona(previa: previa, soyMiembro: soyMiembro),

        const SizedBox(height: EspaciadoPrevia.l),
        _Accion(
          previa: previa,
          soyMiembro: soyMiembro,
          yoSoyElAnfitrion: yoSoyElAnfitrion,
          miSolicitud: miSolicitud,
        ),
        const SizedBox(height: EspaciadoPrevia.l),
      ],
    );
  }
}

/// Mapa de la previa.
///
/// Si no eres asistente, se ve el circulo aproximado y un aviso que explica
/// por que. Si lo eres, se pide la direccion exacta al servidor.
class _MapaZona extends ConsumerWidget {
  const _MapaZona({required this.previa, required this.soyMiembro});

  final Previa previa;
  final bool soyMiembro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dónde', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: EspaciadoPrevia.m),

        ClipRRect(
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
          child: SizedBox(
            height: 180,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: previa.ubicacion,
                initialZoom: soyMiembro ? 16 : 14,
                backgroundColor: ColoresPrevia.fondo,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/dark_all/'
                      '{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c'],
                  retinaMode: RetinaMode.isHighDensity(context),
                  userAgentPackageName: 'com.previa.previa',
                  tileProvider: ref.watch(proveedorTeselasProvider),
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: previa.ubicacion,
                      radius: Entorno.metrosDeDifuminado.toDouble(),
                      useRadiusInMeter: true,
                      color: ColoresPrevia.primario.withValues(alpha: 0.22),
                      borderColor: ColoresPrevia.primarioSuave,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: EspaciadoPrevia.s),

        if (soyMiembro)
          _BotonDireccionExacta(previaId: previa.id)
        else
          _DireccionRetenida(previa: previa),
      ],
    );
  }
}

/// La direccion exacta, presente pero retenida.
///
/// Se dibuja tachada en lugar de omitirse porque no es lo mismo que un dato
/// no exista a que exista y todavia no te corresponda: ver el renglon
/// censurado es lo que explica la regla de privacidad sin un parrafo legal.
///
/// Las barras son un patron fijo y no derivan de la direccion real, que el
/// cliente nunca llega a recibir: el servidor solo la entrega a asistentes
/// aceptados, asi que aqui no hay nada que filtrar ni siquiera su longitud.
class _DireccionRetenida extends StatelessWidget {
  const _DireccionRetenida({required this.previa});

  final Previa previa;

  static const _barras = [96.0, 54.0, 128.0, 38.0, 72.0];

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(EspaciadoPrevia.m),
      decoration: const BoxDecoration(
        color: ColoresPrevia.superficie,
        border: Border.fromBorderSide(BorderSide(color: ColoresPrevia.borde)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('DIRECCIÓN EXACTA', style: textos.labelMedium),
              const Spacer(),
              Text(
                'RETENIDA',
                style: textos.labelMedium?.copyWith(
                  color: ColoresPrevia.textoTenue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: EspaciadoPrevia.s + EspaciadoPrevia.xs),
          Wrap(
            spacing: EspaciadoPrevia.s,
            runSpacing: EspaciadoPrevia.xs + 2,
            children: [
              for (final ancho in _barras)
                Container(
                  width: ancho,
                  height: 13,
                  color: ColoresPrevia.superficieActiva,
                ),
            ],
          ),
          const SizedBox(height: EspaciadoPrevia.s + EspaciadoPrevia.xs),
          // Lo que si se puede decir: la celda. Es la misma que dibuja la
          // reticula de arriba, asi que orienta sin revelar el portal.
          Text(
            'CELDA ${previa.referenciaCuadricula}  ·  '
            '${previa.zona.toUpperCase()}',
            style: textos.labelMedium?.copyWith(color: ColoresPrevia.texto),
          ),
          const SizedBox(height: EspaciadoPrevia.m),
          Text(
            'Se revela en cuanto el anfitrión acepte tu plaza.',
            style: textos.bodyMedium?.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _BotonDireccionExacta extends ConsumerStatefulWidget {
  const _BotonDireccionExacta({required this.previaId});
  final String previaId;

  @override
  ConsumerState<_BotonDireccionExacta> createState() =>
      _BotonDireccionExactaState();
}

class _BotonDireccionExactaState extends ConsumerState<_BotonDireccionExacta> {
  LatLng? _punto;
  bool _cargando = false;

  Future<void> _pedir() async {
    setState(() => _cargando = true);
    try {
      final punto = await ref
          .read(repositorioPreviasProvider)
          .ubicacionExacta(widget.previaId);
      if (mounted) setState(() => _punto = punto);
    } on ErrorPrevia catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_punto != null) {
      return Container(
        padding: const EdgeInsets.all(EspaciadoPrevia.m),
        decoration: BoxDecoration(
          color: ColoresPrevia.acento.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
          border: Border.all(
            color: ColoresPrevia.acento.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.visibility, color: ColoresPrevia.acento, size: 20),
            const SizedBox(width: EspaciadoPrevia.s),
            Expanded(
              child: Text(
                '${_punto!.latitude.toStringAsFixed(5)}, '
                '${_punto!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(
                  color: ColoresPrevia.texto,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _cargando ? null : _pedir,
      icon: const Icon(Icons.visibility_outlined, size: 18),
      label: Text(_cargando ? 'PIDIENDO…' : 'VER LA DIRECCIÓN EXACTA'),
    );
  }
}

/// El boton principal cambia segun tu relacion con la previa.
class _Accion extends ConsumerWidget {
  const _Accion({
    required this.previa,
    required this.soyMiembro,
    required this.yoSoyElAnfitrion,
    required this.miSolicitud,
  });

  final Previa previa;
  final bool soyMiembro;
  final bool yoSoyElAnfitrion;
  final Solicitud? miSolicitud;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rutaChat =
        '${Rutas.previa}/${previa.id}/chat'
        '?titulo=${Uri.encodeQueryComponent(previa.titulo)}';

    if (yoSoyElAnfitrion) {
      final pendientes =
          ref
              .watch(solicitudesDeProvider(previa.id))
              .valueOrNull
              ?.where((s) => s.estaPendiente)
              .length ??
          0;

      return Column(
        children: [
          FilledButton.icon(
            onPressed: () =>
                context.push('${Rutas.previa}/${previa.id}/solicitudes'),
            icon: const Icon(Icons.inbox_outlined, size: 18),
            label: Text(
              pendientes == 0
                  ? 'Ver solicitudes'
                  : '$pendientes ${pendientes == 1 ? "solicitud" : "solicitudes"} '
                        'por responder',
            ),
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          OutlinedButton.icon(
            onPressed: () => context.push(rutaChat),
            icon: const Icon(Icons.forum_outlined, size: 18),
            label: const Text('Abrir el chat'),
          ),
        ],
      );
    }

    if (soyMiembro) {
      final yaPaso = previa.empiezaEn.isBefore(DateTime.now());

      return Column(
        children: [
          _Nota(
            icono: yaPaso ? Icons.schedule : Icons.check_circle,
            texto: yaPaso
                ? 'Esta previa ya pasó. ¿Qué tal la gente?'
                : 'Estás dentro. Nos vemos allí.',
            color: yaPaso ? ColoresPrevia.textoSuave : ColoresPrevia.acento,
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          if (yaPaso)
            FilledButton.icon(
              onPressed: () => context.push(
                '${Rutas.previa}/${previa.id}/valorar'
                '?titulo=${Uri.encodeQueryComponent(previa.titulo)}',
              ),
              icon: const Icon(Icons.star_outline_rounded, size: 18),
              label: const Text('Valorar a quien fue'),
            )
          else
            FilledButton.icon(
              onPressed: () => context.push(rutaChat),
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: const Text('Abrir el chat'),
            ),
          if (yaPaso) ...[
            const SizedBox(height: EspaciadoPrevia.s),
            OutlinedButton.icon(
              onPressed: () => context.push(rutaChat),
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: const Text('Ver el chat'),
            ),
          ],
        ],
      );
    }

    if (miSolicitud?.estaPendiente ?? false) {
      return const _Nota(
        icono: Icons.hourglass_top,
        texto: 'Solicitud enviada. A ver qué dice el anfitrión.',
        color: ColoresPrevia.aviso,
      );
    }

    if (miSolicitud?.estado == EstadoSolicitud.rechazada) {
      return const _Nota(
        icono: Icons.do_not_disturb_on_outlined,
        texto: 'Esta vez no ha podido ser. Hay más previas cerca.',
      );
    }

    if (!previa.quedanPlazas) {
      return const _Nota(
        icono: Icons.group_off_outlined,
        texto: 'Ya no quedan plazas en esta previa.',
      );
    }

    return FilledButton.icon(
      onPressed: () async {
        final enviada = await mostrarHojaSolicitarPlaza(
          context,
          previaId: previa.id,
          plazasLibres: previa.plazasLibres,
        );
        if (enviada == true) {
          ref.invalidate(_miSolicitudProvider(previa.id));
        }
      },
      icon: const Icon(Icons.inbox_outlined, size: 18),
      label: const Text('SOLICITAR PLAZA'),
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota({
    required this.icono,
    required this.texto,
    this.color = ColoresPrevia.textoSuave,
  });

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EspaciadoPrevia.m),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: EspaciadoPrevia.s),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.valor,
    required this.etiqueta,
    this.destacado = false,
  });

  final IconData icono;
  final String valor;
  final String etiqueta;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final color = destacado ? ColoresPrevia.acento : ColoresPrevia.texto;

    return Container(
      padding: const EdgeInsets.all(EspaciadoPrevia.m),
      decoration: BoxDecoration(
        color: ColoresPrevia.superficie,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        border: Border.all(color: ColoresPrevia.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: ColoresPrevia.textoSuave),
          const SizedBox(height: EspaciadoPrevia.s),
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            etiqueta,
            style: const TextStyle(
              color: ColoresPrevia.textoSuave,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool?> _confirmar(
  BuildContext context, {
  required String titulo,
  required String detalle,
  required String accion,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: ColoresPrevia.superficieAlta,
      title: Text(titulo),
      content: Text(detalle),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: ColoresPrevia.error,
            minimumSize: const Size(0, 44),
          ),
          child: Text(accion),
        ),
      ],
    ),
  );
}

Future<String?> _elegirMotivo(BuildContext context) {
  const motivos = {
    'acoso': 'Acoso o comportamiento inapropiado',
    'perfil_falso': 'Parece un perfil falso',
    'menor_edad': 'Creo que es menor de edad',
    'contenido_inapropiado': 'Contenido inapropiado',
    'spam': 'Spam',
    'otro': 'Otro motivo',
  };

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: ColoresPrevia.fondo,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(EspaciadoPrevia.radioGrande),
      ),
    ),
    builder: (contexto) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: EspaciadoPrevia.l),
          Text(
            '¿Qué ha pasado?',
            style: Theme.of(contexto).textTheme.titleLarge,
          ),
          const SizedBox(height: EspaciadoPrevia.m),
          for (final entrada in motivos.entries)
            ListTile(
              title: Text(entrada.value),
              onTap: () => Navigator.of(contexto).pop(entrada.key),
            ),
          const SizedBox(height: EspaciadoPrevia.m),
        ],
      ),
    ),
  );
}
