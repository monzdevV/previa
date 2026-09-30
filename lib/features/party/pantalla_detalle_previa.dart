import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../profile/avatar_previa.dart';
import '../juegos/juegos.dart';
import '../safety/aviso_ubicacion_aproximada.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../core/entorno.dart';
import '../../data/models/previa.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_previas.dart';
import '../map/proveedores_mapa.dart';
import '../requests/pantalla_solicitudes.dart';
import 'componentes_previa.dart';
import 'estados_pantalla.dart';
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
            // Sin tooltip el lector solo dice "menú": así dice qué hay dentro.
            tooltip: 'Reportar o bloquear',
            icon: const Icon(Icons.more_vert),
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
        loading: () => const IndicadorCarga(),
        error: (e, _) => EstadoError(
          mensaje: 'No se ha podido cargar la previa',
          detalle: 'Comprueba tu conexión e inténtalo otra vez.',
          onReintentar: () => ref.invalidate(_detalleProvider(previaId)),
        ),
        data: (previa) => _Contenido(previa: previa),
      ),
      // El botón principal vive fijo abajo: es lo que se busca al terminar de
      // leer, y no debe depender de cuánto haya que desplazar.
      bottomNavigationBar: detalle.valueOrNull == null
          ? null
          : _BarraAccion(previa: detalle.requireValue),
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

      // Sin try/catch, un fallo de red dejaba al usuario sin respuesta en una
      // acción de seguridad. Ahora siempre se le dice qué ha pasado.
      try {
        await repo.bloquear(previa.anfitrionId);
      } catch (e) {
        mensajero.showSnackBar(SnackBar(content: Text(_mensajeDeFallo(e))));
        return;
      }
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

    try {
      await repo.reportar(
        motivo: motivo,
        previaId: previa.id,
        perfilId: previa.anfitrionId,
      );
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(_mensajeDeFallo(e))));
      return;
    }
    mensajero.showSnackBar(
      const SnackBar(content: Text('Reporte enviado. Gracias por avisar.')),
    );
  }

  String _mensajeDeFallo(Object e) => e is ErrorPrevia
      ? e.mensaje
      : 'No se ha podido completar la acción. Inténtalo de nuevo.';
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.previa});

  final Previa previa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final soyMiembro =
        ref.watch(_soyMiembroProvider(previa.id)).valueOrNull ?? false;
    final yoSoyElAnfitrion =
        ref.watch(repositorioAuthProvider).usuarioActual?.id ==
        previa.anfitrionId;

    final cuando = DateFormat(
      "EEEE d 'de' MMMM 'a las' HH:mm",
      'es_ES',
    ).format(previa.empiezaEn);
    final hora = DateFormat('HH:mm', 'es_ES').format(previa.empiezaEn);

    final secciones = <Widget>[
      // Cabecera con el ambiente. El título va SOBRE el degradado (con velo
      // oscuro) y fuera del Hero, que no debe contener texto.
      Stack(
        children: [
          Hero(
            tag: tagCabeceraPrevia(previa.id),
            child: CabeceraAmbiente(
              ambiente: previa.ambiente,
              altura: 168,
              radio: BorderRadius.circular(EspaciadoPrevia.radioGrande),
            ),
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(EspaciadoPrevia.m),
                    child: Semantics(
                      header: true,
                      child: Text(
                        previa.titulo,
                        style: textos.headlineMedium?.copyWith(
                          color: Colors.white,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      const SizedBox(height: EspaciadoPrevia.m),
      Text(
        cuando,
        style: textos.bodyLarge?.copyWith(color: ColoresPrevia.textoSuave),
      ),

      const SizedBox(height: EspaciadoPrevia.m),
      // Chips: plazas, hora, zona y distancia de un vistazo.
      Wrap(
        spacing: EspaciadoPrevia.s,
        runSpacing: EspaciadoPrevia.s,
        children: [
          ChipDato(
            icono: Icons.event_seat,
            texto: previa.plazasLibres <= 0
                ? 'Completa'
                : (previa.plazasLibres == 1
                      ? '1 plaza libre'
                      : '${previa.plazasLibres} plazas libres'),
            color: previa.quedanPlazas ? ColoresPrevia.acento : null,
          ),
          ChipDato(
            icono: Icons.schedule,
            texto: '$hora · ${previa.cuandoEmpieza}',
          ),
          ChipDato(icono: Icons.place_outlined, texto: previa.zona),
          if (previa.distanciaMetros != null)
            ChipDato(
              icono: Icons.directions_walk,
              texto: 'a ${previa.distanciaLegible}',
            ),
        ],
      ),
      const SizedBox(height: EspaciadoPrevia.m),
      BarraPlazas(libres: previa.plazasLibres),

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

      Semantics(
        header: true,
        child: Text('Organiza', style: textos.titleLarge),
      ),
      const SizedBox(height: EspaciadoPrevia.m),
      Row(
        children: [
          AvatarPrevia(
            iniciales: previa.anfitrionNombre.isNotEmpty
                ? previa.anfitrionNombre[0].toUpperCase()
                : '?',
            url: previa.anfitrionAvatar,
            radio: 22,
          ),
          const SizedBox(width: EspaciadoPrevia.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(previa.anfitrionNombre, style: textos.titleLarge),
                if (previa.anfitrionReputacion != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 15,
                        color: ColoresPrevia.aviso,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        previa.anfitrionReputacion!.toStringAsFixed(1),
                        style: textos.bodyMedium,
                      ),
                    ],
                  )
                else
                  Text('Sin valoraciones todavía', style: textos.bodyMedium),
              ],
            ),
          ),
        ],
      ),

      const SizedBox(height: EspaciadoPrevia.l),
      _MapaZona(
        previa: previa,
        soyMiembro: soyMiembro,
        yoSoyElAnfitrion: yoSoyElAnfitrion,
      ),
      const SizedBox(height: EspaciadoPrevia.l),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        EspaciadoPrevia.l,
        EspaciadoPrevia.s,
        EspaciadoPrevia.l,
        EspaciadoPrevia.l,
      ),
      children: [
        // Entrada escalonada de las secciones (solo las primeras).
        for (var i = 0; i < secciones.length; i++)
          EntradaEscalonada(indice: i, child: secciones[i]),
      ],
    );
  }
}

/// Barra inferior fija con la acción principal.
///
/// Se anima entre estados (solicitar -> enviada -> dentro) con un
/// [AnimatedSwitcher] para que el cambio no sea un salto brusco.
class _BarraAccion extends ConsumerWidget {
  const _BarraAccion({required this.previa});

  final Previa previa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soyMiembro =
        ref.watch(_soyMiembroProvider(previa.id)).valueOrNull ?? false;
    final miSolicitud = ref.watch(_miSolicitudProvider(previa.id)).valueOrNull;
    final yoSoyElAnfitrion =
        ref.watch(repositorioAuthProvider).usuarioActual?.id ==
        previa.anfitrionId;

    // La clave del hijo identifica el "estado" de la acción: cambia la clave,
    // se anima el cambio.
    final estado = yoSoyElAnfitrion
        ? 'anfitrion'
        : soyMiembro
        ? 'miembro'
        : 'visitante-${miSolicitud?.estado.name}-${previa.quedanPlazas}';

    return Material(
      color: ColoresPrevia.superficie,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: ColoresPrevia.borde)),
          ),
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          // Con textScaler grande la barra podría comerse la pantalla: se
          // limita y permite scroll interno.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.4,
            ),
            child: SingleChildScrollView(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (hijo, anim) => FadeTransition(
                  opacity: anim,
                  child: SizeTransition(
                    sizeFactor: anim,
                    alignment: Alignment.topCenter,
                    child: hijo,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(estado),
                  child: _Accion(
                    previa: previa,
                    soyMiembro: soyMiembro,
                    yoSoyElAnfitrion: yoSoyElAnfitrion,
                    miSolicitud: miSolicitud,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mapa de la previa.
///
/// Si no eres asistente, se ve el circulo aproximado y un aviso que explica
/// por que. Si lo eres, se pide la direccion exacta al servidor.
class _MapaZona extends ConsumerWidget {
  const _MapaZona({
    required this.previa,
    required this.soyMiembro,
    required this.yoSoyElAnfitrion,
  });

  final Previa previa;
  final bool soyMiembro;
  final bool yoSoyElAnfitrion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Dónde', style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: EspaciadoPrevia.m),

        // Mapa no interactivo: se describe con una frase y se oculta el
        // lienzo, que para un lector de pantalla no aporta nada.
        Semantics(
          image: true,
          label:
              'Mapa con la zona aproximada de la previa, en ${previa.zona}. '
              'El círculo cubre unos ${Entorno.metrosDeDifuminado} metros.',
          child: ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
              child: SizedBox(
                height: 180,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: previa.ubicacion,
                    initialZoom: soyMiembro ? 16 : 14,
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
          ),
        ),

        const SizedBox(height: EspaciadoPrevia.s),

        if (soyMiembro)
          _BotonDireccionExacta(previaId: previa.id)
        else if (!yoSoyElAnfitrion)
          // Texto único compartido con mapa y ajustes: así no se contradicen.
          const AvisoUbicacionAproximada(compacto: true),
      ],
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
            const Icon(
              Icons.where_to_vote,
              color: ColoresPrevia.acento,
              size: 20,
            ),
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
      icon: const Icon(Icons.where_to_vote_outlined, size: 18),
      label: Text(_cargando ? 'Pidiendo…' : 'Ver la dirección exacta'),
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
            icono: yaPaso ? Icons.nightlife : Icons.check_circle,
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
          ] else ...[
            // Los juegos son para la propia previa: solo tienen sentido antes
            // de que termine.
            const SizedBox(height: EspaciadoPrevia.s),
            OutlinedButton.icon(
              onPressed: () => abrirJuegos(context),
              icon: const Icon(Icons.casino_outlined, size: 18),
              label: const Text('Jugar en la previa'),
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
      icon: const Icon(Icons.waving_hand_outlined, size: 18),
      label: const Text('Solicitar plaza'),
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
            minimumSize: const Size(0, 48),
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
