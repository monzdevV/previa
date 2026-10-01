import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/tema.dart';
import 'modelo_juegos.dart';
import 'motor/partida.dart';
import 'repositorio_retos.dart';

/// Partida en curso: carta, turno, botones, marcador, pausas y final.
class PantallaPartida extends StatefulWidget {
  const PantallaPartida({
    super.key,
    required this.config,
    this.retos,
    this.duracionPausa = const Duration(seconds: 60),
  });

  final ConfiguracionPartida config;

  /// Solo para tests: cartas concretas en lugar del repositorio.
  final List<Reto>? retos;

  /// Duración de la pausa obligatoria; configurable solo para poder probarla.
  final Duration duracionPausa;

  @override
  State<PantallaPartida> createState() => _PantallaPartidaState();
}

class _PantallaPartidaState extends State<PantallaPartida> {
  late Partida _p;
  Timer? _reloj;
  int _segundos = 0;

  @override
  void initState() {
    super.initState();
    _p = _nuevaPartida();
  }

  Partida _nuevaPartida() => Partida(
    config: widget.config,
    retos: widget.retos ?? retosPara(widget.config.juego, widget.config.nivel),
  );

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  void _responder(Respuesta r) {
    // Háptica sutil y distinta según el resultado, sin vibrar de más.
    switch (r) {
      case Respuesta.cumplido:
        HapticFeedback.lightImpact();
      case Respuesta.noHayHuevos:
        HapticFeedback.mediumImpact();
      case Respuesta.pasar:
        HapticFeedback.selectionClick();
    }
    setState(() {
      _p.responder(r);
      if (_p.pausaPendiente) _iniciarPausa();
    });
  }

  void _iniciarPausa() {
    _reloj?.cancel();
    _segundos = widget.duracionPausa.inSeconds;
    _reloj = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_segundos > 0) _segundos--;
        if (_segundos <= 0) {
          t.cancel();
          HapticFeedback.selectionClick();
        }
      });
    });
  }

  void _seguirTrasPausa() {
    _reloj?.cancel();
    setState(_p.terminarPausa);
  }

  Future<void> _parar() async {
    final terminar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Parar la partida'),
        content: const Text(
          'Sin problema, no hace falta dar explicaciones. '
          'Nadie está obligado a beber ni a hacer nada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir jugando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
            child: const Text('Terminar aquí'),
          ),
        ],
      ),
    );
    if (terminar != true || !mounted) return;
    _reloj?.cancel();
    setState(_p.parar);
  }

  void _mostrarMarcador() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HojaMarcador(partida: _p),
    );
  }

  void _otraPartida() {
    setState(() => _p = _nuevaPartida());
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    if (_p.terminada) {
      return _PantallaFinal(
        partida: _p,
        onOtraPartida: _otraPartida,
        onSalir: () => Navigator.of(context).pop(),
      );
    }
    final rondas = widget.config.rondas;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config.juego.titulo),
        actions: [
          // Siempre visible y sin dramatismo: parar es una opción normal.
          TextButton.icon(
            onPressed: _parar,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Parar'),
          ),
          const SizedBox(width: EspaciadoPrevia.xs),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, caja) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              EspaciadoPrevia.m,
              0,
              EspaciadoPrevia.m,
              EspaciadoPrevia.m,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: caja.maxHeight - EspaciadoPrevia.m,
              ),
              child: _p.pausaPendiente
                  ? _Pausa(
                      segundos: _segundos,
                      total: widget.duracionPausa.inSeconds,
                      onSeguir: _seguirTrasPausa,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CabeceraTurno(
                          partida: _p,
                          rondas: rondas,
                          onMarcador: _mostrarMarcador,
                        ),
                        const SizedBox(height: EspaciadoPrevia.m),
                        _ZonaCarta(
                          partida: _p,
                          sinAlcohol: widget.config.sinAlcohol,
                          onContactoOk: () {
                            HapticFeedback.selectionClick();
                            setState(_p.confirmarContacto);
                          },
                          onContactoNo: () => setState(_p.saltar),
                        ),
                        const SizedBox(height: EspaciadoPrevia.m),
                        if (!_p.contactoPendiente)
                          _Botonera(
                            partida: _p,
                            sinAlcohol: widget.config.sinAlcohol,
                            onResponder: _responder,
                          ),
                        const SizedBox(height: EspaciadoPrevia.m),
                        Text(
                          'Nadie está obligado a beber ni a hacer nada.',
                          style: texto.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String _etiquetaCumplido(TipoJuego j) =>
    j == TipoJuego.verdadOReto ? 'Hecho' : 'Cumplido';
String _etiquetaRechazo(TipoJuego j) =>
    j == TipoJuego.verdadOReto ? 'Paso' : 'No hay huevos';

String _textoCastigo(Partida p, bool sinAlcohol) {
  final n = p.sorbosActuales;
  final sorbos = n == 1 ? '1 sorbo' : '$n sorbos';
  return sinAlcohol
      ? 'cualquier bebida ($sorbos) o una prenda suave'
      : 'bebe $sorbos';
}

class _CabeceraTurno extends StatelessWidget {
  const _CabeceraTurno({
    required this.partida,
    required this.rondas,
    required this.onMarcador,
  });

  final Partida partida;
  final int? rondas;
  final VoidCallback onMarcador;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final jugador = partida.jugadorEnTurno;
    final juega = partida.config.juego.puntua;
    final etiqueta = juega ? 'Te toca' : 'Lee la carta';
    final cuenta = rondas == null
        ? 'Carta ${partida.ronda}'
        : 'Carta ${partida.ronda} de $rondas';
    final cabecera = Semantics(
      liveRegion: true,
      container: true,
      label: '$etiqueta, ${jugador.nombre}. $cuenta.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          decoration: BoxDecoration(
            color: context.colores.superficieAlta,
            borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
            border: Border.all(color: context.colores.primarioTexto, width: 2),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: context.colores.primario,
                child: Text(
                  jugador.nombre.characters.first.toUpperCase(),
                  style: TextStyle(
                    color: context.colores.sobrePrimario,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: EspaciadoPrevia.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etiqueta, style: texto.bodyMedium),
                    Text(jugador.nombre, style: texto.headlineMedium),
                    Text(cuenta, style: texto.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!juega) return cabecera;
    // El boton va fuera de la caja de semantica (que se lee como una sola
    // frase) y debajo, para que con texto grande el nombre tenga todo el ancho.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cabecera,
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onMarcador,
            child: const Text('Marcador'),
          ),
        ),
      ],
    );
  }
}

/// Carta con giro al cambiar. Con "reducir movimiento" el cambio es directo.
class _ZonaCarta extends StatelessWidget {
  const _ZonaCarta({
    required this.partida,
    required this.sinAlcohol,
    required this.onContactoOk,
    required this.onContactoNo,
  });

  final Partida partida;
  final bool sinAlcohol;
  final VoidCallback onContactoOk;
  final VoidCallback onContactoNo;

  @override
  Widget build(BuildContext context) {
    final reducir = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reducir ? Duration.zero : const Duration(milliseconds: 420),
      transitionBuilder: (child, anim) => AnimatedBuilder(
        animation: anim,
        child: child,
        builder: (context, hijo) {
          // De canto (pi/2) a de frente (0); la saliente hace el camino
          // inverso porque AnimatedSwitcher reproduce su animación al revés.
          final ang = (1 - anim.value) * math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(ang),
            child: hijo,
          );
        },
      ),
      child: KeyedSubtree(
        key: ValueKey(partida.version),
        child: partida.contactoPendiente
            ? _CartaContacto(
                nombre: partida.jugadorEnTurno.nombre,
                onOk: onContactoOk,
                onNo: onContactoNo,
              )
            : _CartaReto(partida: partida, sinAlcohol: sinAlcohol),
      ),
    );
  }
}

BoxDecoration _decoracionCarta(List<Color> cols) => BoxDecoration(
  borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: cols,
  ),
  // Sombra propia: la app local no tiene tokens de elevación y la carta
  // necesita despegarse del fondo en oscuro y en claro.
  boxShadow: const [
    BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10)),
  ],
);

const _coloresNivel = {
  NivelReto.suave: [Color(0xFF1F6F5C), Color(0xFF174F44)],
  NivelReto.atrevido: [Color(0xFFB8324B), Color(0xFF8A2238)],
  NivelReto.sinFiltro: [Color(0xFF6A1B4D), Color(0xFF3E1030)],
};

class _CartaReto extends StatelessWidget {
  const _CartaReto({required this.partida, required this.sinAlcohol});

  final Partida partida;
  final bool sinAlcohol;

  @override
  Widget build(BuildContext context) {
    final reto = partida.retoActual;
    final juego = partida.config.juego;
    final castigo = juego.puntua
        ? 'Si no: ${_textoCastigo(partida, sinAlcohol)}'
        : (juego == TipoJuego.yoNunca
              ? 'Quien lo haya hecho: ${_textoCastigo(partida, sinAlcohol)}'
              : 'El más votado: ${_textoCastigo(partida, sinAlcohol)}');
    return Semantics(
      container: true,
      liveRegion: true,
      label:
          'Carta ${reto.nivel.etiqueta}. ${partida.textoMostrado}. $castigo.',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 280),
          padding: const EdgeInsets.all(EspaciadoPrevia.l),
          decoration: _decoracionCarta(_coloresNivel[reto.nivel]!),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: EspaciadoPrevia.m,
                    vertical: EspaciadoPrevia.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    reto.nivel.etiqueta.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: EspaciadoPrevia.m),
              Text(
                partida.textoMostrado,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: EspaciadoPrevia.m),
              Text(
                castigo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaContacto extends StatelessWidget {
  const _CartaContacto({
    required this.nombre,
    required this.onOk,
    required this.onNo,
  });

  final String nombre;
  final VoidCallback onOk;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.all(EspaciadoPrevia.l),
      decoration: _decoracionCarta(const [
        Color(0xFF3E1030),
        Color(0xFF14110F),
      ]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: const Text(
              'Esta carta implica contacto físico.\n¿Estáis todos de acuerdo?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: EspaciadoPrevia.l),
          FilledButton(onPressed: onOk, child: const Text('Sí, adelante')),
          const SizedBox(height: EspaciadoPrevia.s),
          OutlinedButton(
            onPressed: onNo,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('No, otra carta'),
          ),
        ],
      ),
    );
  }
}

class _Botonera extends StatelessWidget {
  const _Botonera({
    required this.partida,
    required this.sinAlcohol,
    required this.onResponder,
  });

  final Partida partida;
  final bool sinAlcohol;
  final void Function(Respuesta) onResponder;

  @override
  Widget build(BuildContext context) {
    final juego = partida.config.juego;
    if (!juego.puntua) {
      return FilledButton(
        onPressed: () => onResponder(Respuesta.pasar),
        child: const Text('Siguiente carta'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => onResponder(Respuesta.cumplido),
          icon: const Icon(Icons.check_rounded),
          label: Text(_etiquetaCumplido(juego)),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        OutlinedButton(
          onPressed: () => onResponder(Respuesta.noHayHuevos),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(60),
            padding: const EdgeInsets.symmetric(
              horizontal: EspaciadoPrevia.m,
              vertical: EspaciadoPrevia.s,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_etiquetaRechazo(juego)),
              Text(
                _textoCastigo(partida, sinAlcohol),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.colores.textoSuave,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pausa obligatoria: no se puede saltar hasta que acabe la cuenta atrás.
class _Pausa extends StatelessWidget {
  const _Pausa({
    required this.segundos,
    required this.total,
    required this.onSeguir,
  });

  final int segundos;
  final int total;
  final VoidCallback onSeguir;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final lista = segundos <= 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: EspaciadoPrevia.xl),
        Icon(
          Icons.water_drop_outlined,
          size: 64,
          color: context.colores.acento,
        ),
        const SizedBox(height: EspaciadoPrevia.m),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            'Agua y respira 1 minuto',
            textAlign: TextAlign.center,
            style: texto.headlineMedium,
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        Text(
          'Bebe un poco de agua, come algo y respira hondo. '
          'Cuidarse también forma parte de la previa.',
          textAlign: TextAlign.center,
          style: texto.bodyMedium,
        ),
        const SizedBox(height: EspaciadoPrevia.l),
        Semantics(
          label: lista
              ? 'Pausa terminada'
              : 'Quedan $segundos segundos de pausa',
          child: ExcludeSemantics(
            child: Column(
              children: [
                Text(
                  lista ? '0' : '$segundos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    color: context.colores.texto,
                  ),
                ),
                const SizedBox(height: EspaciadoPrevia.s),
                // Barra determinada: una animación infinita no dejaría
                // asentarse a los tests ni descansaría la vista.
                LinearProgressIndicator(
                  value: total == 0 ? 1 : 1 - segundos / total,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.l),
        FilledButton(
          onPressed: lista ? onSeguir : null,
          child: Text(lista ? 'Seguir jugando' : 'Espera a que termine'),
        ),
      ],
    );
  }
}

class _InsigniaTitulo extends StatelessWidget {
  const _InsigniaTitulo({
    required this.titulo,
    required this.nombre,
    required this.icono,
    required this.color,
  });

  final String titulo;
  final String nombre;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$titulo: $nombre',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          decoration: BoxDecoration(
            color: context.colores.superficieAlta,
            borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
            border: Border.all(color: color, width: 2),
          ),
          child: Row(
            children: [
              Icon(icono, color: color, size: 32),
              const SizedBox(width: EspaciadoPrevia.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: texto.bodyMedium),
                    Text(nombre, style: texto.titleLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<Widget> _titulos(BuildContext context, Partida p) => [
  if (p.valiente != null)
    _InsigniaTitulo(
      titulo: 'Valiente del día',
      nombre: p.valiente!.nombre,
      icono: Icons.local_fire_department,
      color: context.colores.aviso,
    ),
  if (p.gallina != null)
    _InsigniaTitulo(
      titulo: 'La gallina de la noche',
      nombre: p.gallina!.nombre,
      icono: Icons.egg_alt_outlined,
      color: context.colores.primarioTexto,
    ),
];

class _FilaRanking extends StatelessWidget {
  const _FilaRanking({required this.posicion, required this.jugador});

  final int posicion;
  final Jugador jugador;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label:
          'Puesto $posicion, ${jugador.nombre}: ${jugador.puntos} puntos, '
          '${jugador.cumplidos} cumplidos, ${jugador.rechazos} veces no hay huevos',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: EspaciadoPrevia.s),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text('$posicion', style: texto.titleLarge),
              ),
              Expanded(child: Text(jugador.nombre, style: texto.titleMedium)),
              Text(
                '${jugador.puntos} pts · ${jugador.rechazos} sin huevos',
                style: texto.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HojaMarcador extends StatelessWidget {
  const _HojaMarcador({required this.partida});

  final Partida partida;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final ranking = partida.ranking;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(EspaciadoPrevia.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Marcador', style: texto.headlineMedium),
            ),
            const SizedBox(height: EspaciadoPrevia.m),
            for (final t in _titulos(context, partida)) ...[
              t,
              const SizedBox(height: EspaciadoPrevia.s),
            ],
            for (var i = 0; i < ranking.length; i++)
              _FilaRanking(posicion: i + 1, jugador: ranking[i]),
            const SizedBox(height: EspaciadoPrevia.s),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PantallaFinal extends StatelessWidget {
  const _PantallaFinal({
    required this.partida,
    required this.onOtraPartida,
    required this.onSalir,
  });

  final Partida partida;
  final VoidCallback onOtraPartida;
  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final ranking = partida.ranking;
    final puntua = partida.config.juego.puntua;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Fin de la partida'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          children: [
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                puntua ? '¡Vaya noche!' : '¡Buena previa!',
                style: texto.displaySmall,
              ),
            ),
            const SizedBox(height: EspaciadoPrevia.xs),
            Text(
              'Se han jugado ${partida.resueltas} cartas.',
              style: texto.bodyMedium,
            ),
            const SizedBox(height: EspaciadoPrevia.l),
            if (puntua) ...[
              _Podio(ranking: ranking.take(3).toList()),
              const SizedBox(height: EspaciadoPrevia.l),
              for (final t in _titulos(context, partida)) ...[
                t,
                const SizedBox(height: EspaciadoPrevia.s),
              ],
              const SizedBox(height: EspaciadoPrevia.s),
              for (var i = 0; i < ranking.length; i++)
                _FilaRanking(posicion: i + 1, jugador: ranking[i]),
            ],
            const SizedBox(height: EspaciadoPrevia.l),
            FilledButton(
              onPressed: onOtraPartida,
              child: const Text('Otra partida'),
            ),
            const SizedBox(height: EspaciadoPrevia.s),
            OutlinedButton(
              onPressed: onSalir,
              child: const Text('Volver a los juegos'),
            ),
            const SizedBox(height: EspaciadoPrevia.m),
            Text(
              'Nadie está obligado a beber ni a hacer nada. '
              'Y si sales, vuelve a casa sano y salvo.',
              style: texto.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Podio clásico: el primero en el centro, más alto. Se dibuja con barras de
/// color (sin assets) y se anuncia como una lista para lectores de pantalla.
class _Podio extends StatelessWidget {
  const _Podio({required this.ranking});

  final List<Jugador> ranking;

  @override
  Widget build(BuildContext context) {
    // Orden visual 2º - 1º - 3º; con menos de 3 jugadores se adapta.
    final orden = <int>[
      if (ranking.length > 1) 1,
      0,
      if (ranking.length > 2) 2,
    ];
    const altos = [120.0, 88.0, 64.0];
    final colores = [
      context.colores.aviso,
      Color(0xFFC9C2BB),
      Color(0xFFC98A5B),
    ];
    return Semantics(
      container: true,
      label:
          'Podio. ${[for (var i = 0; i < ranking.length; i++) 'Puesto ${i + 1}: ${ranking[i].nombre}, ${ranking[i].puntos} puntos'].join('. ')}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final i in orden)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ranking[i].nombre,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${ranking[i].puntos} pts',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: EspaciadoPrevia.xs),
                      Container(
                        height: altos[i],
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: EspaciadoPrevia.s),
                        decoration: BoxDecoration(
                          color: colores[i],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Color(0xFF14110F),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
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
