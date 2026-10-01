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
import '../juegos/juegos.dart';
import '../map/capas_del_mapa.dart';
import '../map/proveedores_mapa.dart';
import '../requests/pantalla_solicitudes.dart';
import 'componentes_previa.dart';
import 'estados_pantalla.dart';
import 'hoja_solicitar_plaza.dart';
import 'tarjeta_previa.dart';

// Se descartan al salir: cada previa abierta dejaria su copia en memoria, y
// al volver a entrar se veria el estado de la primera visita (plazas, si ya
// te aceptaron) en lugar del actual.
final _detalleProvider = FutureProvider.autoDispose.family<Previa, String>(
  (ref, id) => ref.watch(repositorioPreviasProvider).detalle(id),
);

final _soyMiembroProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, id) => ref.watch(repositorioPreviasProvider).soyMiembro(id),
);

final _miSolicitudProvider = FutureProvider.autoDispose
    .family<Solicitud?, String>(
      (ref, id) => ref.watch(repositorioPreviasProvider).miSolicitudEn(id),
    );

class PantallaDetallePrevia extends ConsumerStatefulWidget {
  const PantallaDetallePrevia({super.key, required this.previaId});

  final String previaId;

  @override
  ConsumerState<PantallaDetallePrevia> createState() =>
      _PantallaDetallePreviaState();
}

class _PantallaDetallePreviaState extends ConsumerState<PantallaDetallePrevia> {
  /// Bloquear o reportar dos veces seguidas duplicaria el reporte o
  /// intentaria cerrar la pantalla dos veces.
  bool _ocupado = false;

  String get previaId => widget.previaId;

  @override
  Widget build(BuildContext context) {
    final detalle = ref.watch(_detalleProvider(previaId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Previa'),
        actions: [
          PopupMenuButton<String>(
            // Sin tooltip el lector solo dice "menú": asi dice que hay dentro.
            tooltip: 'Reportar o bloquear',
            icon: Icon(
              Theme.of(context).platform == TargetPlatform.iOS
                  ? Icons.more_horiz
                  : Icons.more_vert,
            ),
            color: context.colores.superficieAlta,
            enabled: !_ocupado,
            onSelected: (opcion) => _menu(opcion, detalle.valueOrNull),
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
        loading: () => const Cargando(),
        error: (e, _) => EstadoError(
          mensaje: 'No se ha podido cargar la previa',
          detalle: 'Comprueba tu conexión e inténtalo otra vez.',
          onReintentar: () => ref.invalidate(_detalleProvider(previaId)),
        ),
        // Tirar hacia abajo es la forma de saber si ya te han aceptado sin
        // salir y volver a entrar.
        data: (previa) => RefreshIndicator(
          color: context.colores.primarioTexto,
          backgroundColor: context.colores.superficie,
          onRefresh: () async {
            ref.invalidate(_soyMiembroProvider(previaId));
            ref.invalidate(_miSolicitudProvider(previaId));
            ref.invalidate(_detalleProvider(previaId));
            try {
              await ref.read(_detalleProvider(previaId).future);
            } catch (_) {
              // El error lo pinta el propio estado de la pantalla.
            }
          },
          child: _Contenido(previa: previa),
        ),
      ),
      // La accion principal vive fija abajo: es lo que se busca al terminar
      // de leer, y no debe depender de cuanto haya que desplazar.
      bottomNavigationBar: switch (detalle.valueOrNull) {
        final previa? => _BarraAccion(previa: previa),
        null => null,
      },
    );
  }

  /// Si el repositorio ya trae una frase para la persona, se usa esa.
  String _mensajeDeFallo(Object e, String porDefecto) =>
      e is ErrorPrevia ? e.mensaje : porDefecto;

  Future<void> _menu(String opcion, Previa? previa) async {
    if (previa == null || _ocupado) return;
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
      if (confirmado != true || !mounted) return;

      setState(() => _ocupado = true);
      try {
        await repo.bloquear(previa.anfitrionId);
      } catch (e) {
        mensajero.showSnackBar(
          SnackBar(
            content: Text(
              _mensajeDeFallo(
                e,
                'No se ha podido bloquear. Inténtalo otra vez.',
              ),
            ),
          ),
        );
        if (mounted) setState(() => _ocupado = false);
        return;
      }
      ref.invalidate(previasCercaProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      mensajero.showSnackBar(
        const SnackBar(content: Text('Bloqueado. No volveréis a veros.')),
      );
      return;
    }

    final motivo = await _elegirMotivo(context);
    if (motivo == null || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await repo.reportar(
        motivo: motivo,
        previaId: previa.id,
        perfilId: previa.anfitrionId,
      );
      mensajero.showSnackBar(
        const SnackBar(content: Text('Reporte enviado. Gracias por avisar.')),
      );
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            _mensajeDeFallo(
              e,
              'No se ha podido enviar el reporte. Inténtalo otra vez.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.previa});

  final Previa previa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
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
    final plazas = previa.plazasLibres;

    final secciones = <Widget>[
      _Cartel(previa: previa),

      const SizedBox(height: EspaciadoPrevia.m),
      Text(
        // El formato sale en minusculas ("sabado 4 de..."), pero aqui abre
        // la ficha y se lee como frase.
        cuando.isEmpty ? cuando : cuando[0].toUpperCase() + cuando.substring(1),
        style: textos.bodyLarge?.copyWith(color: c.textoSuave),
      ),

      const SizedBox(height: EspaciadoPrevia.m),
      // Plazas, hora, zona y distancia de un vistazo: son los cuatro datos
      // que deciden si pides plaza.
      Wrap(
        spacing: EspaciadoPrevia.s,
        runSpacing: EspaciadoPrevia.s,
        children: [
          ChipDato(
            icono: Icons.event_seat,
            texto: plazas <= 0
                ? 'Completa'
                : (plazas == 1 ? '1 plaza libre' : '$plazas plazas libres'),
            color: previa.quedanPlazas ? c.disponible : null,
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
      BarraPlazas(libres: plazas),

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
      const SizedBox(height: EspaciadoPrevia.l),

      const _Seccion('Organiza'),
      const SizedBox(height: EspaciadoPrevia.m),
      _FichaAnfitrion(previa: previa),

      const SizedBox(height: EspaciadoPrevia.xl),
      _MapaZona(
        previa: previa,
        soyMiembro: soyMiembro,
        yoSoyElAnfitrion: yoSoyElAnfitrion,
      ),
      const SizedBox(height: EspaciadoPrevia.l),
    ];

    return ListView(
      // Siempre desplazable para que el tiron de refrescar funcione aunque
      // el contenido quepa entero en pantalla.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        EspaciadoPrevia.m,
        EspaciadoPrevia.s,
        EspaciadoPrevia.m,
        EspaciadoPrevia.l,
      ),
      children: [
        for (var i = 0; i < secciones.length; i++)
          EntradaEscalonada(indice: i, child: secciones[i]),
      ],
    );
  }
}

/// El cartel de la previa: el bloque del ambiente con el titulo encima.
///
/// El bloque vuela desde la tarjeta con un [Hero]; el titulo va fuera del
/// Hero, que no debe llevar texto.
class _Cartel extends StatelessWidget {
  const _Cartel({required this.previa});

  final Previa previa;

  static const _alto = 184.0;

  @override
  Widget build(BuildContext context) {
    final cabecera = CabeceraAmbiente(
      ambiente: previa.ambiente,
      altura: _alto,
      radio: BorderRadius.circular(EspaciadoPrevia.radioGrande),
    );

    return SizedBox(
      height: _alto,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MovimientoPrevia.reducido(context)
              ? cabecera
              : Hero(tag: tagCabeceraPrevia(previa.id), child: cabecera),
          Positioned(
            top: EspaciadoPrevia.m,
            right: EspaciadoPrevia.m,
            child: PastillaPlazas(libres: previa.plazasLibres),
          ),
          Positioned(
            left: EspaciadoPrevia.m,
            right: EspaciadoPrevia.m,
            bottom: EspaciadoPrevia.m,
            child: Semantics(
              header: true,
              child: Titular(
                previa.titulo,
                tamano: 30,
                lineas: 3,
                color: BloquesPrevia.tintaSobreBloque,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rotulo de seccion, en la letra del cartel y anunciado como encabezado.
class _Seccion extends StatelessWidget {
  const _Seccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) =>
      Semantics(header: true, child: Titular(texto, tamano: 22));
}

/// Antes de pedir plaza en casa de alguien hay que verle la cara, y desde
/// ahi poder abrir su perfil entero.
class _FichaAnfitrion extends StatelessWidget {
  const _FichaAnfitrion({required this.previa});

  final Previa previa;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final reputacion = previa.anfitrionReputacion
        ?.toStringAsFixed(1)
        .replaceAll('.', ',');
    void abrirPerfil() =>
        context.push('${Rutas.perfilDe}/${previa.anfitrionId}');

    return Semantics(
      button: true,
      label: reputacion == null
          ? 'Perfil de ${previa.anfitrionNombre}, sin valoraciones todavía'
          : 'Perfil de ${previa.anfitrionNombre}, '
                'valoración $reputacion sobre 5',
      onTap: abrirPerfil,
      excludeSemantics: true,
      child: Pulsable(
        escala: 0.97,
        onTap: abrirPerfil,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              AvatarPerfil(
                url: previa.anfitrionAvatar,
                inicial: previa.anfitrionNombre,
                lado: 52,
                anillo: context.colores.primario,
              ),
              const SizedBox(width: EspaciadoPrevia.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(previa.anfitrionNombre, style: textos.titleLarge),
                    const SizedBox(height: 2),
                    // Sin estrella y sin ambar: la tinta viva esta reservada
                    // a las plazas libres, y "sobre cinco" lo dice el texto.
                    Text(
                      reputacion == null
                          ? 'Sin valoraciones todavía'
                          : 'Valoración $reputacion/5',
                      style: reputacion == null
                          ? textos.bodyMedium
                          : textos.labelMedium,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.colores.textoTenue),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mapa de la previa.
///
/// Si no eres asistente, se ve el circulo aproximado y la direccion
/// retenida. Si lo eres, o la previa es tuya, se pide la exacta al servidor,
/// que es quien decide si te la da.
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
    final puedeVerla = soyMiembro || yoSoyElAnfitrion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Seccion('Dónde'),
        const SizedBox(height: EspaciadoPrevia.m),

        // Mapa no interactivo: se describe con una frase y se oculta el
        // lienzo, que a un lector de pantalla no le dice nada.
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
                    initialZoom: puedeVerla ? 16 : 14,
                    backgroundColor: context.colores.fondo,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    ...capasBaseDelMapa(
                      context,
                      proveedor: ref.watch(proveedorTeselasProvider),
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: previa.ubicacion,
                          radius: Entorno.metrosDeDifuminado.toDouble(),
                          useRadiusInMeter: true,
                          color: context.colores.primario.withValues(
                            alpha: 0.22,
                          ),
                          borderColor: context.colores.primarioSuave,
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

        if (puedeVerla)
          _BotonDireccionExacta(previaId: previa.id)
        else
          _DireccionRetenida(previa: previa),
      ],
    );
  }
}

// La direccion exacta, presente pero retenida.
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
      decoration: BoxDecoration(
        color: context.colores.superficie,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        border: Border.fromBorderSide(BorderSide(color: context.colores.borde)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Dirección exacta', style: textos.labelMedium),
              const Spacer(),
              Text(
                'Retenida',
                style: textos.labelMedium?.copyWith(
                  color: context.colores.textoTenue,
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
                  decoration: BoxDecoration(
                    color: context.colores.superficieActiva,
                    borderRadius: BorderRadius.circular(
                      EspaciadoPrevia.pastilla,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: EspaciadoPrevia.s + EspaciadoPrevia.xs),
          // Lo que si se puede decir: la celda. Es la misma que dibuja la
          // reticula de arriba, asi que orienta sin revelar el portal.
          Text(
            'Celda ${previa.referenciaCuadricula}  ·  ${previa.zona}',
            style: textos.labelMedium?.copyWith(color: context.colores.texto),
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
          color: context.colores.acento.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
          border: Border.all(
            color: context.colores.acento.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.visibility, color: context.colores.acento, size: 20),
            const SizedBox(width: EspaciadoPrevia.s),
            Expanded(
              child: Text(
                '${_punto!.latitude.toStringAsFixed(5)}, '
                '${_punto!.longitude.toStringAsFixed(5)}',
                style: TextStyle(
                  color: context.colores.texto,
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
      label: Text(_cargando ? 'Pidiendo…' : 'Ver la dirección exacta'),
    );
  }
}

//// Barra fija de abajo con la accion principal.
///
/// Cambia entre estados (pedir, enviada, dentro) con un fundido corto: un
/// salto seco hace dudar de si el toque ha servido.
class _BarraAccion extends ConsumerWidget {
  const _BarraAccion({required this.previa});

  final Previa previa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final soyMiembro =
        ref.watch(_soyMiembroProvider(previa.id)).valueOrNull ?? false;
    final miSolicitud = ref.watch(_miSolicitudProvider(previa.id)).valueOrNull;
    final yoSoyElAnfitrion =
        ref.watch(repositorioAuthProvider).usuarioActual?.id ==
        previa.anfitrionId;

    // La clave identifica el estado de la accion: si cambia, se anima.
    final estado = yoSoyElAnfitrion
        ? 'anfitrion'
        : soyMiembro
        ? 'miembro'
        : 'visitante-${miSolicitud?.estado.name}-${previa.quedanPlazas}';
    final quieto = MovimientoPrevia.reducido(context);

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
          // Con la letra del sistema muy grande la barra podria comerse la
          // pantalla: se limita y desplaza por dentro.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.4,
            ),
            child: SingleChildScrollView(
              child: AnimatedSwitcher(
                duration: quieto ? Duration.zero : MovimientoPrevia.rapido,
                switchInCurve: MovimientoPrevia.curva,
                switchOutCurve: MovimientoPrevia.curva,
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
                  ? 'VER SOLICITUDES'
                  : '$pendientes ${pendientes == 1 ? "SOLICITUD" : "SOLICITUDES"} '
                        'POR RESPONDER',
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
            color: yaPaso ? context.colores.textoSuave : context.colores.acento,
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          if (yaPaso) ...[
            FilledButton.icon(
              onPressed: () => context.push(
                '${Rutas.previa}/${previa.id}/valorar'
                '?titulo=${Uri.encodeQueryComponent(previa.titulo)}',
              ),
              icon: const Icon(Icons.star_outline_rounded, size: 18),
              label: const Text('VALORAR A QUIEN FUE'),
            ),
            const SizedBox(height: EspaciadoPrevia.s),
            OutlinedButton.icon(
              onPressed: () => context.push(rutaChat),
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: const Text('Ver el chat'),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: () => context.push(rutaChat),
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: const Text('ABRIR EL CHAT'),
            ),
            // Los juegos son para la propia previa: solo tienen sentido
            // antes de que termine.
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
      return _Nota(
        icono: Icons.hourglass_top,
        texto: 'Solicitud enviada. A ver qué dice el anfitrión.',
        color: context.colores.aviso,
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
      label: const Text('SOLICITAR PLAZA'),
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota({required this.icono, required this.texto, this.color});

  final IconData icono;
  final String texto;

  /// Nulo significa el gris secundario del tema, que no se puede nombrar
  /// aqui porque un valor por defecto tiene que ser constante.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tinta = color ?? context.colores.textoSuave;

    return Container(
      padding: const EdgeInsets.all(EspaciadoPrevia.m),
      decoration: BoxDecoration(
        color: tinta.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        border: Border.all(color: tinta.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icono, color: tinta, size: 20),
          const SizedBox(width: EspaciadoPrevia.s),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: tinta, fontWeight: FontWeight.w600),
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
      backgroundColor: context.colores.superficieAlta,
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
            backgroundColor: context.colores.error,
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

  // Misma hoja que el resto de la app: mismo asa, misma forma, zona segura.
  return mostrarHoja<String>(
    context,
    builder: (contexto) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: EspaciadoPrevia.l),
              child: Titular('¿Qué ha pasado?', tamano: 26),
            ),
            const SizedBox(height: EspaciadoPrevia.xs),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: EspaciadoPrevia.l,
              ),
              child: Text(
                'Lo revisa el equipo de moderación.',
                style: Theme.of(contexto).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: EspaciadoPrevia.s),
            for (final entrada in motivos.entries)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: EspaciadoPrevia.l,
                ),
                minTileHeight: 52,
                title: Text(entrada.value),
                trailing: Icon(
                  Icons.chevron_right,
                  color: contexto.colores.textoTenue,
                ),
                onTap: () => Navigator.of(contexto).pop(entrada.key),
              ),
            const SizedBox(height: EspaciadoPrevia.m),
          ],
        ),
      ),
    ),
  );
}
