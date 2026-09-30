import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/tema.dart';
import '../../data/models/previa.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_previas.dart';
import '../../data/repositories/repositorio_seguridad.dart';
import '../party/estados_pantalla.dart';
import '../juegos/juegos.dart';
import '../safety/acciones_seguridad.dart';

/// Mensajes en vivo. Supabase Realtime empuja cada insercion por WebSocket,
/// asi que no hay que refrescar ni sondear.
final mensajesProvider = StreamProvider.family<List<Mensaje>, String>(
  (ref, previaId) => ref.watch(repositorioPreviasProvider).mensajesDe(previaId),
);

/// Quien va, para poder poner nombre a cada mensaje.
final miembrosProvider = FutureProvider.family<Map<String, String>, String>((
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
  bool _primeraCarga = true;

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

  /// Menu de seguridad del chat: todo lo importante a un toque desde la
  /// cabecera, sin tener que buscar en los ajustes.
  Future<void> _abrirSeguridad(Map<String, String> nombres, String? yo) async {
    final esAnfitrion =
        ref.read(_soyAnfitrionProvider(widget.previaId)).valueOrNull ?? false;
    final otros = nombres.entries.where((e) => e.key != yo).toList();
    final contextoPantalla = context;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ColoresPrevia.fondo,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(EspaciadoPrevia.radioGrande),
        ),
      ),
      builder: (contexto) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: EspaciadoPrevia.l),
              Text('Seguridad', style: Theme.of(contexto).textTheme.titleLarge),
              const SizedBox(height: EspaciadoPrevia.s),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Reportar esta previa'),
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
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text('Reportar o bloquear a ${o.value}'),
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
                ListTile(
                  leading: const Icon(Icons.logout, color: ColoresPrevia.error),
                  title: const Text(
                    'Salir de la previa',
                    style: TextStyle(color: ColoresPrevia.error),
                  ),
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
              const SizedBox(height: EspaciadoPrevia.s),
            ],
          ),
        ),
      ),
    );
  }

  /// Baja al último mensaje.
  ///
  /// Se comprueba el scroll DESPUÉS del frame (la lista puede no existir aún al
  /// llegar el primer dato). Si quien lee está subido mirando mensajes viejos,
  /// un mensaje ajeno nuevo no le arrastra al final: se le respeta la lectura.
  /// [forzar] sí baja siempre (mis propios mensajes y la primera carga).
  void _alFinal({bool forzar = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      final cerca = pos.maxScrollExtent - pos.pixels < 200;
      if (!forzar && !cerca) return;
      if (_primeraCarga) {
        _primeraCarga = false;
        _scroll.jumpTo(pos.maxScrollExtent);
      } else {
        _scroll.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mensajes = ref.watch(mensajesProvider(widget.previaId));
    final nombres =
        ref.watch(miembrosProvider(widget.previaId)).valueOrNull ?? {};
    final yo = ref.watch(repositorioAuthProvider).usuarioActual?.id;

    ref.listen(mensajesProvider(widget.previaId), (_, nuevo) {
      // La primera carga siempre baja al final; después, solo si procede.
      _alFinal(forzar: _primeraCarga);
    });

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Juegos de previa',
            icon: const Icon(Icons.casino_outlined),
            // Llevamos los nombres del chat para no teclearlos otra vez.
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
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.titulo ?? 'Chat'),
            Text(
              nombres.isEmpty
                  ? 'Cargando…'
                  : '${nombres.length} ${nombres.length == 1 ? "persona" : "personas"}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: ColoresPrevia.textoSuave,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            // AnimatedSwitcher: pasar de vacío a lista (al llegar el primer
            // mensaje) se funde en vez de saltar.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: mensajes.when(
                loading: () => const IndicadorCarga(key: ValueKey('carga')),
                error: (e, _) => EstadoError(
                  key: const ValueKey('error'),
                  mensaje: 'No se ha podido abrir el chat',
                  detalle: 'Comprueba tu conexión e inténtalo otra vez.',
                  onReintentar: () =>
                      ref.invalidate(mensajesProvider(widget.previaId)),
                ),
                data: (lista) => lista.isEmpty
                    ? _ChatVacio(
                        key: const ValueKey('vacio'),
                        onSugerencia: (t) {
                          _texto.text = t;
                          _texto.selection = TextSelection.collapsed(
                            offset: t.length,
                          );
                        },
                      )
                    : _ListaMensajes(
                        key: const ValueKey('lista'),
                        controlador: _scroll,
                        mensajes: lista,
                        yo: yo,
                        nombres: nombres,
                        onLongPress: (m) => mostrarHojaPersona(
                          context,
                          ref,
                          perfilId: m.autorId,
                          nombre: nombres[m.autorId] ?? 'Alguien',
                          previaId: widget.previaId,
                          mensajeId: m.id,
                        ),
                      ),
              ),
            ),
          ),

          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(EspaciadoPrevia.s + 2),
              decoration: const BoxDecoration(
                color: ColoresPrevia.superficie,
                border: Border(top: BorderSide(color: ColoresPrevia.borde)),
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
                  IconButton.filled(
                    tooltip: 'Enviar mensaje',
                    onPressed: _enviando ? null : _enviar,
                    style: IconButton.styleFrom(
                      backgroundColor: ColoresPrevia.primario,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
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

/// Lista de mensajes con separadores de día, aviso del sistema y agrupación
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

  /// Dos mensajes seguidos del mismo autor se agrupan si están en el mismo día
  /// y a menos de este tiempo: una conversación retomada horas después
  /// merece volver a mostrar el nombre.
  static const _ventanaAgrupacion = Duration(minutes: 5);

  static bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _agrupados(Mensaje a, Mensaje b) =>
      a.autorId == b.autorId &&
      _mismoDia(a.enviadoEn, b.enviadoEn) &&
      b.enviadoEn.difference(a.enviadoEn).abs() < _ventanaAgrupacion;

  @override
  Widget build(BuildContext context) {
    final elementos = <Widget>[
      // Mensaje del sistema fijo al principio: orienta y apunta al escudo de
      // seguridad sin que nadie tenga que buscarlo.
      const _MensajeSistema(
        icono: Icons.shield_outlined,
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

      final primero = anterior == null || !_agrupados(anterior, m);
      final ultimo = siguiente == null || !_agrupados(m, siguiente);
      final esMio = m.autorId == yo;

      elementos.add(
        _Burbuja(
          mensaje: m,
          esMio: esMio,
          nombre: esMio ? 'Tú' : (nombres[m.autorId] ?? 'Alguien'),
          primeroDelGrupo: primero,
          ultimoDelGrupo: ultimo,
          // Pulsación larga en un mensaje ajeno: reportarlo o bloquear a su
          // autor (exigido por las tiendas).
          onLongPress: esMio ? null : () => onLongPress(m),
        ),
      );
    }

    return ListView(
      controller: controlador,
      padding: const EdgeInsets.all(EspaciadoPrevia.m),
      children: elementos,
    );
  }
}

/// Mensaje del sistema: centrado, sin burbuja de autor, tono neutro.
class _MensajeSistema extends StatelessWidget {
  const _MensajeSistema({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EspaciadoPrevia.s),
      child: Container(
        padding: const EdgeInsets.all(EspaciadoPrevia.m),
        decoration: BoxDecoration(
          color: ColoresPrevia.superficie,
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
          border: Border.all(color: ColoresPrevia.borde),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(icono, size: 18, color: ColoresPrevia.primarioSuave),
            ),
            const SizedBox(width: EspaciadoPrevia.s),
            Expanded(
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Separador con el día ("Hoy", "Ayer" o "lunes 5 de mayo").
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EspaciadoPrevia.m),
      child: Center(
        child: Semantics(
          header: true,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: EspaciadoPrevia.m,
              vertical: EspaciadoPrevia.xs,
            ),
            decoration: BoxDecoration(
              color: ColoresPrevia.superficieAlta,
              borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
            ),
            child: Text(
              _etiqueta(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ColoresPrevia.textoSuave,
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
    required this.mensaje,
    required this.esMio,
    required this.nombre,
    required this.primeroDelGrupo,
    required this.ultimoDelGrupo,
    this.onLongPress,
  });

  final VoidCallback? onLongPress;

  final Mensaje mensaje;
  final bool esMio;
  final String nombre;

  /// Primer mensaje de una ráfaga del mismo autor: lleva el nombre y más aire.
  final bool primeroDelGrupo;

  /// Último de la ráfaga: redondea la esquina de "cola" de la burbuja.
  final bool ultimoDelGrupo;

  @override
  Widget build(BuildContext context) {
    final hora = DateFormat('HH:mm').format(mensaje.enviadoEn);
    const grande = Radius.circular(EspaciadoPrevia.radio);
    const pequeno = Radius.circular(4);

    // Las esquinas del lado del autor se aplanan entre mensajes agrupados,
    // para que se lean como un solo bloque.
    final radio = BorderRadius.only(
      topLeft: esMio ? grande : (primeroDelGrupo ? grande : pequeno),
      topRight: esMio ? (primeroDelGrupo ? grande : pequeno) : grande,
      bottomLeft: esMio ? grande : (ultimoDelGrupo ? grande : pequeno),
      bottomRight: esMio ? (ultimoDelGrupo ? grande : pequeno) : grande,
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: ultimoDelGrupo ? EspaciadoPrevia.xs : 2,
        top: primeroDelGrupo ? EspaciadoPrevia.s : 0,
      ),
      // Una sola frase para el lector: quién, qué y cuándo. La pulsación
      // larga se expone como acción para que no sea solo un gesto táctil.
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
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ColoresPrevia.textoSuave,
                  ),
                ),
              ),
            GestureDetector(
              onLongPress: onLongPress,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: EspaciadoPrevia.m,
                  vertical: EspaciadoPrevia.s + 2,
                ),
                decoration: BoxDecoration(
                  color: esMio
                      ? ColoresPrevia.primario
                      : ColoresPrevia.superficieAlta,
                  borderRadius: radio,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      mensaje.texto,
                      style: TextStyle(
                        color: esMio ? Colors.white : ColoresPrevia.texto,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hora,
                      style: TextStyle(
                        fontSize: 10,
                        color: esMio
                            ? Colors.white.withValues(alpha: 0.7)
                            : ColoresPrevia.textoTenue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado vacío del chat: invita a hablar y ofrece frases para empezar.
class _ChatVacio extends StatelessWidget {
  const _ChatVacio({super.key, required this.onSugerencia});

  /// Rellena el campo de texto (no envía): quien escribe decide si la manda.
  final ValueChanged<String> onSugerencia;

  static const _sugerencias = [
    '¡Hola a todos! Ya tengo ganas.',
    '¿Llevamos algo de beber o de picar?',
    'Llegamos a la hora, ¡hasta ahora!',
  ];

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(EspaciadoPrevia.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.ac_unit,
                size: 40,
                color: ColoresPrevia.primarioSuave,
              ),
            ),
            const SizedBox(height: EspaciadoPrevia.m),
            Semantics(
              header: true,
              child: Text('Rompe el hielo', style: textos.titleLarge),
            ),
            const SizedBox(height: EspaciadoPrevia.xs),
            Text(
              'Todavía no ha escrito nadie. Di quién eres y a qué hora llegáis.',
              textAlign: TextAlign.center,
              style: textos.bodyMedium,
            ),
            const SizedBox(height: EspaciadoPrevia.m),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: EspaciadoPrevia.s,
              runSpacing: EspaciadoPrevia.s,
              children: [
                for (final t in _sugerencias)
                  ActionChip(
                    label: Text(t),
                    tooltip: 'Usar esta frase',
                    onPressed: () => onSugerencia(t),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
