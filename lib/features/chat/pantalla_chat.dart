import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/tema.dart';
import '../../data/models/previa.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_previas.dart';
import '../../data/repositories/repositorio_seguridad.dart';
import '../juegos/juegos.dart';
import '../safety/acciones_seguridad.dart';

/// Mensajes en vivo. Supabase Realtime empuja cada insercion por WebSocket,
/// asi que no hay que refrescar ni sondear. Se cierra al salir del chat para
/// no dejar la suscripcion abierta mientras se navega por otras pantallas.
final mensajesProvider = StreamProvider.autoDispose.family<List<Mensaje>, String>(
  (ref, previaId) => ref.watch(repositorioPreviasProvider).mensajesDe(previaId),
);

/// Quien va, para poder poner nombre a cada mensaje.
final miembrosProvider = FutureProvider.autoDispose
    .family<Map<String, String>, String>((
  ref,
  previaId,
) async {
  final filas = await ref
      .watch(repositorioPreviasProvider)
      .miembrosDe(previaId);
  return {
    for (final f in filas)
      f['profile_id'] as String:
          (f['profiles'] as Map?)?['display_name'] as String? ?? 'Alguien',
  };
});

/// Si soy el anfitrion: el anfitrion no puede "salir", solo cancelar.
final _soyAnfitrionProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, previaId) =>
      ref.watch(repositorioSeguridadProvider).soyAnfitrion(previaId),
);

/// Dos mensajes seguidos del mismo autor se agrupan si son del mismo dia y
/// estan a menos de este tiempo: una conversacion retomada horas despues
/// merece volver a mostrar el nombre.
const ventanaAgrupacionChat = Duration(minutes: 5);

bool _mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Si [b] (posterior) va pegado a [a] en la misma rafaga.
@visibleForTesting
bool mensajesAgrupados(Mensaje a, Mensaje b) =>
    a.autorId == b.autorId &&
    _mismoDia(a.enviadoEn, b.enviadoEn) &&
    b.enviadoEn.difference(a.enviadoEn).abs() < ventanaAgrupacionChat;

class PantallaChat extends ConsumerStatefulWidget {
  const PantallaChat({super.key, required this.previaId, this.titulo});

  final String previaId;
  final String? titulo;

  @override
  ConsumerState<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends ConsumerState<PantallaChat> {
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  bool _enviando = false;

  @override
  void dispose() {
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _texto.text.trim();
    if (texto.isEmpty || _enviando) return;

    setState(() => _enviando = true);
    // Se vacia ya: si falla se repone, pero lo normal es que funcione y
    // esperar al servidor con el campo lleno se siente lento.
    _texto.clear();

    try {
      await ref
          .read(repositorioPreviasProvider)
          .enviarMensaje(widget.previaId, texto);
      _alFinal(forzar: true);
    } catch (_) {
      if (mounted) {
        _texto.text = texto;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se ha podido enviar. Inténtalo otra vez.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Baja al ultimo mensaje. La lista va invertida, asi que "el final" es el
  /// principio del scroll.
  ///
  /// Si quien lee esta subido mirando mensajes viejos, un mensaje ajeno nuevo
  /// no le arrastra abajo: se le respeta la lectura. [forzar] baja siempre
  /// (mis propios mensajes).
  void _alFinal({bool forzar = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final pos = _scroll.position;
      final cerca = pos.pixels - pos.minScrollExtent < 200;
      if (!forzar && !cerca) return;
      if (MovimientoPrevia.reducido(context)) {
        _scroll.jumpTo(pos.minScrollExtent);
      } else {
        _scroll.animateTo(
          pos.minScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: MovimientoPrevia.curva,
        );
      }
    });
  }

  /// Rellena el campo con una frase sugerida (no la envia: quien escribe
  /// decide si la manda).
  void _usarSugerencia(String frase) {
    _texto.text = frase;
    _texto.selection = TextSelection.collapsed(offset: frase.length);
  }

  /// Menu de seguridad del chat: todo lo importante a un toque desde la
  /// cabecera, sin tener que buscar en los ajustes.
  Future<void> _abrirSeguridad(Map<String, String> nombres, String? yo) {
    final esAnfitrion =
        ref.read(_soyAnfitrionProvider(widget.previaId)).valueOrNull ?? false;
    final otros = nombres.entries.where((e) => e.key != yo).toList();
    final contextoPantalla = context;

    return mostrarHoja<void>(
      context,
      builder: (contexto) {
        final c = contexto.colores;
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: EspaciadoPrevia.m + MediaQuery.paddingOf(contexto).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  EspaciadoPrevia.l,
                  0,
                  EspaciadoPrevia.l,
                  EspaciadoPrevia.xs,
                ),
                child: Titular('Seguridad', tamano: 28),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  EspaciadoPrevia.l,
                  0,
                  EspaciadoPrevia.l,
                  EspaciadoPrevia.s,
                ),
                child: Text(
                  'Nadie se entera de que has reportado o bloqueado.',
                  style: Theme.of(contexto).textTheme.bodyMedium,
                ),
              ),
              _OpcionHoja(
                icono: Icons.flag_outlined,
                texto: 'Reportar esta previa',
                onTap: () {
                  Navigator.of(contexto).pop();
                  flujoReportar(
                    contextoPantalla,
                    ref,
                    previaId: widget.previaId,
                  );
                },
              ),
              for (final o in otros)
                _OpcionHoja(
                  icono: Icons.person_outline,
                  texto: 'Reportar o bloquear a ${o.value}',
                  onTap: () {
                    Navigator.of(contexto).pop();
                    mostrarHojaPersona(
                      contextoPantalla,
                      ref,
                      perfilId: o.key,
                      nombre: o.value,
                      previaId: widget.previaId,
                    );
                  },
                ),
              if (!esAnfitrion)
                _OpcionHoja(
                  icono: Icons.logout,
                  texto: 'Salir de la previa',
                  color: c.error,
                  onTap: () async {
                    Navigator.of(contexto).pop();
                    final salio = await flujoSalir(
                      contextoPantalla,
                      ref,
                      previaId: widget.previaId,
                    );
                    // Ya no eres miembro: el chat no tiene sentido abierto.
                    if (salio && contextoPantalla.mounted) {
                      Navigator.of(contextoPantalla).pop();
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _reportarMensaje(Mensaje m, Map<String, String> nombres) {
    HapticFeedback.mediumImpact();
    mostrarHojaPersona(
      context,
      ref,
      perfilId: m.autorId,
      nombre: nombres[m.autorId] ?? 'Alguien',
      previaId: widget.previaId,
      mensajeId: m.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mensajes = ref.watch(mensajesProvider(widget.previaId));
    final nombres =
        ref.watch(miembrosProvider(widget.previaId)).valueOrNull ?? {};
    final yo = ref.watch(repositorioAuthProvider).usuarioActual?.id;
    // Se pide ya para que el menu de seguridad lo tenga al abrirse.
    ref.watch(_soyAnfitrionProvider(widget.previaId));
    final c = context.colores;
    final reducido = MovimientoPrevia.reducido(context);

    ref.listen(mensajesProvider(widget.previaId), (_, _) => _alFinal());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.titulo ?? 'Chat',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              nombres.isEmpty
                  ? 'Cargando…'
                  : '${nombres.length} ${nombres.length == 1 ? "persona" : "personas"}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: c.textoSuave,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Juegos de previa',
            icon: const Icon(Icons.casino_outlined),
            // Los nombres del chat van a la partida para no teclearlos otra vez.
            onPressed: () => abrirJuegos(
              context,
              jugadoresIniciales: nombres.values.take(12).toList(),
            ),
          ),
          IconButton(
            tooltip: 'Seguridad',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => _abrirSeguridad(nombres, yo),
          ),
          const SizedBox(width: EspaciadoPrevia.xs),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            // Pasar de vacio a lista (al llegar el primer mensaje) se funde
            // en vez de saltar.
            child: AnimatedSwitcher(
              duration: reducido
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              switchInCurve: MovimientoPrevia.curva,
              switchOutCurve: Curves.easeOut,
              child: mensajes.when(
                loading: () => const Cargando(key: ValueKey('carga')),
                error: (e, _) => Semantics(
                  key: const ValueKey('error'),
                  liveRegion: true,
                  child: EstadoVacio(
                    icono: Icons.cloud_off_rounded,
                    titulo: 'Sin conexión',
                    detalle:
                        'No hemos podido abrir el chat. Comprueba tu conexión.',
                    accion: 'Reintentar',
                    onAccion: () =>
                        ref.invalidate(mensajesProvider(widget.previaId)),
                  ),
                ),
                data: (lista) => lista.isEmpty
                    ? _ChatVacio(
                        key: const ValueKey('vacio'),
                        onSugerencia: _usarSugerencia,
                      )
                    : _ListaMensajes(
                        key: const ValueKey('lista'),
                        controlador: _scroll,
                        mensajes: lista,
                        yo: yo,
                        nombres: nombres,
                        onLongPress: (m) => _reportarMensaje(m, nombres),
                      ),
              ),
            ),
          ),

          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(EspaciadoPrevia.s + 2),
              decoration: BoxDecoration(
                color: c.superficie,
                border: Border(top: BorderSide(color: c.borde)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _texto,
                      maxLines: 4,
                      minLines: 1,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _enviar(),
                      decoration: const InputDecoration(
                        hintText: 'Escribe algo…',
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: EspaciadoPrevia.m,
                          vertical: EspaciadoPrevia.s + 4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: EspaciadoPrevia.s),
                  // Sin texto el boton se apaga: un "enviar" que no hace nada
                  // al pulsarlo parece roto.
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _texto,
                    builder: (_, valor, _) {
                      final activo =
                          !_enviando && valor.text.trim().isNotEmpty;
                      return IconButton.filled(
                        tooltip: 'Enviar mensaje',
                        onPressed: activo ? _enviar : null,
                        style: IconButton.styleFrom(
                          backgroundColor: c.primario,
                          foregroundColor: c.sobrePrimario,
                          disabledBackgroundColor: c.superficieActiva,
                          disabledForegroundColor: c.textoTenue,
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 20),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de una hoja: objetivo de 48 dp, icono y texto.
class _OpcionHoja extends StatelessWidget {
  const _OpcionHoja({
    required this.icono,
    required this.texto,
    required this.onTap,
    this.color,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 56,
    contentPadding: const EdgeInsets.symmetric(horizontal: EspaciadoPrevia.l),
    leading: Icon(icono, color: color ?? context.colores.texto),
    title: Text(
      texto,
      style: TextStyle(
        color: color ?? context.colores.texto,
        fontWeight: FontWeight.w600,
      ),
    ),
    onTap: onTap,
  );
}

/// Lista de mensajes con separadores de dia, aviso del sistema y agrupacion
/// por autor.
class _ListaMensajes extends StatelessWidget {
  const _ListaMensajes({
    super.key,
    required this.controlador,
    required this.mensajes,
    required this.yo,
    required this.nombres,
    required this.onLongPress,
  });

  final ScrollController controlador;
  final List<Mensaje> mensajes;
  final String? yo;
  final Map<String, String> nombres;
  final void Function(Mensaje) onLongPress;

  @override
  Widget build(BuildContext context) {
    // Se montan en orden de lectura y la lista los pinta del reves: asi al
    // abrir se ve lo ultimo sin tener que bajar a mano, como en cualquier chat.
    final elementos = <Widget>[
      // Fijo arriba del todo: orienta y apunta al escudo de seguridad sin que
      // nadie tenga que buscarlo.
      const _MensajeSistema(
        texto:
            'Este chat es solo para quienes van a la previa. Si algo no va '
            'bien, pulsa el escudo de arriba o mantén pulsado un mensaje '
            'para reportarlo.',
      ),
    ];

    for (var i = 0; i < mensajes.length; i++) {
      final m = mensajes[i];
      final anterior = i > 0 ? mensajes[i - 1] : null;
      final siguiente = i < mensajes.length - 1 ? mensajes[i + 1] : null;

      if (anterior == null || !_mismoDia(anterior.enviadoEn, m.enviadoEn)) {
        elementos.add(_SeparadorDia(fecha: m.enviadoEn));
      }

      final esMio = m.autorId == yo;
      elementos.add(
        _Burbuja(
          key: ValueKey(m.id),
          mensaje: m,
          esMio: esMio,
          nombre: esMio ? 'Tú' : (nombres[m.autorId] ?? 'Alguien'),
          primeroDelGrupo: anterior == null || !mensajesAgrupados(anterior, m),
          ultimoDelGrupo: siguiente == null || !mensajesAgrupados(m, siguiente),
          // Pulsacion larga en un mensaje ajeno: reportarlo o bloquear a su
          // autor (lo exigen las tiendas).
          onLongPress: esMio ? null : () => onLongPress(m),
        ),
      );
    }

    return ListView.builder(
      controller: controlador,
      reverse: true,
      padding: const EdgeInsets.all(EspaciadoPrevia.m),
      itemCount: elementos.length,
      itemBuilder: (_, i) => elementos[elementos.length - 1 - i],
    );
  }
}

/// Mensaje del sistema: centrado, sin autor, tono neutro.
class _MensajeSistema extends StatelessWidget {
  const _MensajeSistema({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
      child: Container(
        padding: const EdgeInsets.all(EspaciadoPrevia.m),
        decoration: BoxDecoration(
          color: c.superficie,
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
          border: Border.all(color: c.borde),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.shield_outlined,
                size: 18,
                color: c.primarioTexto,
              ),
            ),
            const SizedBox(width: EspaciadoPrevia.s),
            Expanded(
              child: Text(
                texto,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Separador con el dia ("Hoy", "Ayer" o "lunes 5 de mayo").
class _SeparadorDia extends StatelessWidget {
  const _SeparadorDia({required this.fecha});

  final DateTime fecha;

  String _etiqueta() {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    final diferencia = hoy.difference(dia).inDays;
    if (diferencia == 0) return 'Hoy';
    if (diferencia == 1) return 'Ayer';
    return DateFormat("EEEE d 'de' MMMM", 'es_ES').format(fecha);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final etiqueta = _etiqueta();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EspaciadoPrevia.m),
      child: Center(
        child: Semantics(
          header: true,
          label: etiqueta,
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: EspaciadoPrevia.m,
              vertical: EspaciadoPrevia.xs,
            ),
            decoration: BoxDecoration(
              color: c.superficieAlta,
              borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
            ),
            // Mayusculas pequenas de cartel, como el resto de rotulos.
            child: Text(
              etiqueta.toUpperCase(),
              style: TextStyle(
                fontFamily: LetraPrevia.titular,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: c.textoSuave,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({
    super.key,
    required this.mensaje,
    required this.esMio,
    required this.nombre,
    required this.primeroDelGrupo,
    required this.ultimoDelGrupo,
    this.onLongPress,
  });

  final Mensaje mensaje;
  final bool esMio;
  final String nombre;

  /// Primer mensaje de una rafaga del mismo autor: lleva el nombre y mas aire.
  final bool primeroDelGrupo;

  /// Ultimo de la rafaga: lleva la hora y la "cola" de la burbuja.
  final bool ultimoDelGrupo;

  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final hora = DateFormat('HH:mm').format(mensaje.enviadoEn);
    const grande = Radius.circular(EspaciadoPrevia.radio);
    const pequeno = Radius.circular(4);

    // Las esquinas del lado del autor se aplanan entre mensajes agrupados,
    // para que la rafaga se lea como un solo bloque; abajo queda la "cola"
    // de siempre.
    final radio = BorderRadius.only(
      topLeft: esMio || primeroDelGrupo ? grande : pequeno,
      topRight: !esMio || primeroDelGrupo ? grande : pequeno,
      bottomLeft: esMio ? grande : pequeno,
      bottomRight: esMio ? pequeno : grande,
    );

    final burbuja = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: EspaciadoPrevia.m,
        vertical: EspaciadoPrevia.s + 2,
      ),
      decoration: BoxDecoration(
        color: esMio ? c.primario : c.superficieAlta,
        borderRadius: radio,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mensaje.texto,
            style: TextStyle(
              color: esMio ? c.sobrePrimario : c.texto,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          // La hora solo cierra la rafaga: repetida en cada linea es ruido.
          if (ultimoDelGrupo) ...[
            const SizedBox(height: 2),
            Text(
              hora,
              style: TextStyle(
                fontSize: 10,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: esMio
                    ? c.sobrePrimario.withValues(alpha: 0.65)
                    : c.textoTenue,
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: primeroDelGrupo ? EspaciadoPrevia.s : 0,
        bottom: ultimoDelGrupo ? EspaciadoPrevia.xs : 2,
      ),
      // Una sola frase para el lector: quien, que y cuando. La pulsacion
      // larga se expone como accion para que no sea solo un gesto tactil.
      child: Semantics(
        container: true,
        excludeSemantics: true,
        label: '$nombre, ${mensaje.texto}, $hora',
        hint: onLongPress == null ? null : 'Mantén pulsado para reportar',
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: esMio
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (primeroDelGrupo && !esMio)
              Padding(
                padding: const EdgeInsets.only(
                  left: EspaciadoPrevia.s + 4,
                  bottom: 2,
                ),
                child: Text(
                  nombre,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.textoSuave,
                  ),
                ),
              ),
            GestureDetector(onLongPress: onLongPress, child: burbuja),
          ],
        ),
      ),
    );
  }
}

/// Estado vacio del chat: invita a hablar y ofrece frases para empezar.
class _ChatVacio extends StatelessWidget {
  const _ChatVacio({super.key, required this.onSugerencia});

  /// Rellena el campo de texto (no envia).
  final ValueChanged<String> onSugerencia;

  static const _sugerencias = [
    '¡Hola a todos! Ya tengo ganas.',
    '¿Llevamos algo de beber o de picar?',
    'Llegamos a la hora, ¡hasta ahora!',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final reducido = MovimientoPrevia.reducido(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(EspaciadoPrevia.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Pegatina('🧊', tamano: 56, giro: -0.12),
            const SizedBox(height: EspaciadoPrevia.m),
            Semantics(
              header: true,
              child: const Titular(
                'Rompe el hielo',
                tamano: 26,
                alineacion: TextAlign.center,
              ),
            ),
            const SizedBox(height: EspaciadoPrevia.s),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                'Todavía no ha escrito nadie. Di quién eres y a qué hora '
                'llegáis.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: EspaciadoPrevia.l),
            for (var i = 0; i < _sugerencias.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
                child: _Sugerencia(
                  texto: _sugerencias[i],
                  onTap: () => onSugerencia(_sugerencias[i]),
                  color: c,
                  indice: i,
                  reducido: reducido,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Frase lista para usar: pastilla que encoge al pulsar.
class _Sugerencia extends StatelessWidget {
  const _Sugerencia({
    required this.texto,
    required this.onTap,
    required this.color,
    required this.indice,
    required this.reducido,
  });

  final String texto;
  final VoidCallback onTap;
  final ColoresPrevia color;
  final int indice;
  final bool reducido;

  static const _entrada = Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context) {
    final pastilla = Semantics(
      button: true,
      label: texto,
      hint: 'Escribe esta frase en el mensaje',
      excludeSemantics: true,
      child: Pulsable(
        escala: 0.97,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: EspaciadoPrevia.m,
            vertical: EspaciadoPrevia.s + 2,
          ),
          decoration: BoxDecoration(
            color: color.superficie,
            borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
            border: Border.all(color: color.borde),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  texto,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color.texto,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (reducido) return pastilla;
    return pastilla
        .animate(delay: MovimientoPrevia.retrasoDe(indice + 1))
        .fadeIn(duration: _entrada, curve: MovimientoPrevia.curva)
        .moveY(begin: 12, end: 0, duration: _entrada, curve: MovimientoPrevia.curva);
  }
}
