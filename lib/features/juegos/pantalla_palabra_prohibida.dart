import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/tema.dart';
import 'motor/palabra_prohibida.dart';

enum _Fase { preparar, jugando, resumen, final_ }

const _nombresEquipo = ['Equipo A', 'Equipo B'];

/// Palabra prohibida con un solo móvil: el equipo que juega describe la
/// palabra sin decir las prohibidas y el otro equipo vigila.
class PantallaPalabraProhibida extends StatefulWidget {
  const PantallaPalabraProhibida({
    super.key,
    required this.jugadores,
    this.rondas = rondasPorDefectoTabu,
    this.duracionTurno = const Duration(seconds: segundosTurnoTabu),
    this.azar,
  });

  final List<String> jugadores;
  final int rondas;
  final Duration duracionTurno;

  /// Solo para las pruebas.
  final Random? azar;

  @override
  State<PantallaPalabraProhibida> createState() =>
      _PantallaPalabraProhibidaState();
}

class _PantallaPalabraProhibidaState extends State<PantallaPalabraProhibida> {
  late PartidaTabu _partida = _nueva();
  _Fase _fase = _Fase.preparar;
  Timer? _reloj;
  int _quedan = 0;

  PartidaTabu _nueva() => PartidaTabu(
    jugadores: widget.jugadores,
    rondas: widget.rondas,
    azar: widget.azar,
  );

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  void _empezarTurno() {
    HapticFeedback.mediumImpact();
    _partida.empezarTurno();
    _quedan = widget.duracionTurno.inSeconds;
    _reloj?.cancel();
    _reloj = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_quedan <= 1) {
        _terminarTurno();
        return;
      }
      setState(() => _quedan--);
    });
    setState(() => _fase = _Fase.jugando);
  }

  void _terminarTurno() {
    _reloj?.cancel();
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    setState(() => _fase = _Fase.resumen);
  }

  void _siguiente() {
    _partida.terminarTurno();
    setState(() => _fase = _partida.terminada ? _Fase.final_ : _Fase.preparar);
  }

  void _otraPartida() {
    setState(() {
      _partida = _nueva();
      _fase = _Fase.preparar;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Palabra prohibida')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          child: switch (_fase) {
            _Fase.preparar => _Preparar(
              partida: _partida,
              alEmpezar: _empezarTurno,
            ),
            _Fase.jugando => _Jugando(
              partida: _partida,
              quedan: _quedan,
              alAcierto: () => setState(_partida.acierto),
              alPasar: () => setState(_partida.pasar),
              alTabu: () {
                HapticFeedback.vibrate();
                setState(_partida.tabu);
              },
            ),
            _Fase.resumen => _Resumen(partida: _partida, alSeguir: _siguiente),
            _Fase.final_ => _Final(partida: _partida, alRepetir: _otraPartida),
          },
        ),
      ),
    );
  }
}

/// Marcador de los dos equipos, siempre a la vista entre turnos.
class _Marcador extends StatelessWidget {
  const _Marcador({required this.partida});
  final PartidaTabu partida;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label:
          'Marcador. ${_nombresEquipo[0]} ${partida.puntos[0]} puntos. '
          '${_nombresEquipo[1]} ${partida.puntos[1]} puntos.',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var e = 0; e < 2; e++)
            Expanded(
              child: Container(
                margin: EdgeInsets.only(left: e == 1 ? EspaciadoPrevia.s : 0),
                padding: const EdgeInsets.all(EspaciadoPrevia.s),
                decoration: BoxDecoration(
                  color: context.colores.superficieAlta,
                  borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
                ),
                child: Column(
                  children: [
                    Text(_nombresEquipo[e], style: texto.bodyMedium),
                    Text(
                      '${partida.puntos[e]}',
                      style: texto.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
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

class _Preparar extends StatelessWidget {
  const _Preparar({required this.partida, required this.alEmpezar});
  final PartidaTabu partida;
  final VoidCallback alEmpezar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final e = partida.equipoActual;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Marcador(partida: partida),
        const SizedBox(height: EspaciadoPrevia.m),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text(
                  'Ronda ${partida.ronda} de ${partida.rondas}',
                  style: texto.titleMedium,
                ),
                const SizedBox(height: EspaciadoPrevia.m),
                Semantics(
                  header: true,
                  child: Titular('Turno del ${_nombresEquipo[e]}', tamano: 30),
                ),
                const SizedBox(height: EspaciadoPrevia.m),
                Text(
                  'Describe: ${partida.describe}',
                  style: texto.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: EspaciadoPrevia.s),
                Text(
                  'Jugadores: ${partida.equipos[e].join(', ')}.',
                  style: texto.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: EspaciadoPrevia.s),
                Text(
                  'Solo mira la pantalla quien describe. El otro equipo '
                  'vigila y grita «¡Tabú!» si oye una palabra prohibida.',
                  style: texto.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.m),
        FilledButton(onPressed: alEmpezar, child: const Text('Empezar turno')),
      ],
    );
  }
}

class _Jugando extends StatelessWidget {
  const _Jugando({
    required this.partida,
    required this.quedan,
    required this.alAcierto,
    required this.alPasar,
    required this.alTabu,
  });

  final PartidaTabu partida;
  final int quedan;
  final VoidCallback alAcierto;
  final VoidCallback alPasar;
  final VoidCallback alTabu;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final carta = partida.carta!;
    // Los tres botones comparten estilo de tamaño: 56 dp de alto, por encima
    // de los 48 dp mínimos.
    const alto = Size.fromHeight(56);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // El tiempo se anuncia con una etiqueta fija y no segundo a segundo:
        // un lector de pantalla hablando cada segundo taparía al grupo.
        Semantics(
          label:
              'Quedan $quedan segundos. '
              'Aciertos ${partida.aciertosTurno}.',
          child: ExcludeSemantics(
            child: Text(
              '$quedan s · ${_nombresEquipo[partida.equipoActual]} · '
              '${partida.aciertosTurno} aciertos',
              style: texto.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.m),
        Expanded(
          child: SingleChildScrollView(
            child: Semantics(
              liveRegion: true,
              container: true,
              child: Container(
                padding: const EdgeInsets.all(EspaciadoPrevia.l),
                decoration: BoxDecoration(
                  color: context.colores.superficieAlta,
                  borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
                ),
                child: Column(
                  children: [
                    Text(
                      carta.objetivo,
                      textAlign: TextAlign.center,
                      style: texto.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: EspaciadoPrevia.m),
                    Text('No puedes decir:', style: texto.bodyMedium),
                    const SizedBox(height: EspaciadoPrevia.s),
                    for (final p in carta.prohibidas)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          p,
                          style: texto.titleMedium?.copyWith(
                            color: const Color(0xFFFF8A80),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.m),
        FilledButton(
          onPressed: alAcierto,
          style: FilledButton.styleFrom(minimumSize: alto),
          child: const Text('Acierto'),
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: alPasar,
                style: OutlinedButton.styleFrom(minimumSize: alto),
                child: const Text('Pasar'),
              ),
            ),
            const SizedBox(width: EspaciadoPrevia.s),
            Expanded(
              child: OutlinedButton(
                onPressed: alTabu,
                style: OutlinedButton.styleFrom(minimumSize: alto),
                child: const Text('Tabú'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.partida, required this.alSeguir});
  final PartidaTabu partida;
  final VoidCallback alSeguir;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final ultimoTurno = partida.esUltimoTurno;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Marcador(partida: partida),
        Expanded(
          child: SingleChildScrollView(
            child: Semantics(
              liveRegion: true,
              container: true,
              child: Column(
                children: [
                  const SizedBox(height: EspaciadoPrevia.l),
                  const Titular('¡Tiempo!', tamano: 34),
                  const SizedBox(height: EspaciadoPrevia.m),
                  Text(
                    '${partida.aciertosTurno} '
                    '${partida.aciertosTurno == 1 ? 'acierto' : 'aciertos'} · '
                    '${partida.tabusTurno} tabús · '
                    '${partida.pasadasTurno} pasadas',
                    style: texto.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        FilledButton(
          onPressed: alSeguir,
          child: Text(ultimoTurno ? 'Ver resultado' : 'Siguiente'),
        ),
      ],
    );
  }
}

class _Final extends StatelessWidget {
  const _Final({required this.partida, required this.alRepetir});
  final PartidaTabu partida;
  final VoidCallback alRepetir;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final g = partida.ganador;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Marcador(partida: partida),
        Expanded(
          child: SingleChildScrollView(
            child: Semantics(
              liveRegion: true,
              container: true,
              child: Column(
                children: [
                  const SizedBox(height: EspaciadoPrevia.l),
                  Titular(
                    g == null ? '¡Empate!' : '¡Gana el ${_nombresEquipo[g]}!',
                    tamano: 34,
                  ),
                  const SizedBox(height: EspaciadoPrevia.m),
                  if (g != null)
                    Text(
                      partida.equipos[g].join(', '),
                      style: texto.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ),
        FilledButton(onPressed: alRepetir, child: const Text('Otra partida')),
        const SizedBox(height: EspaciadoPrevia.s),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Salir'),
        ),
      ],
    );
  }
}
