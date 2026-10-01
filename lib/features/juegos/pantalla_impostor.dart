import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/tema.dart';
import 'motor/impostor.dart';

enum _Fase { repartir, debate, votar, resultado }

/// El impostor con un solo móvil: se reparte en secreto pasándolo de mano en
/// mano, se debate con una cuenta atrás y se vota en voz alta.
class PantallaImpostor extends StatefulWidget {
  const PantallaImpostor({
    super.key,
    required this.jugadores,
    this.categoria,
    this.duracionDebate = const Duration(minutes: 3),
  });

  final List<String> jugadores;

  /// `null` = una categoría al azar en cada ronda.
  final CategoriaImpostor? categoria;
  final Duration duracionDebate;

  @override
  State<PantallaImpostor> createState() => _PantallaImpostorState();
}

class _PantallaImpostorState extends State<PantallaImpostor> {
  final _azar = Random();
  late RondaImpostor _ronda;
  _Fase _fase = _Fase.repartir;

  /// A quién le toca mirar su palabra, y si ya la está viendo.
  int _turno = 0;
  bool _viendo = false;

  int? _acusado;
  Timer? _reloj;
  int _quedan = 0;

  @override
  void initState() {
    super.initState();
    _ronda = _nuevaRonda();
  }

  RondaImpostor _nuevaRonda({String? evitar}) => RondaImpostor(
    jugadores: widget.jugadores,
    categoria:
        widget.categoria ??
        categoriasImpostor[_azar.nextInt(categoriasImpostor.length)],
    azar: _azar,
    evitar: evitar,
  );

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  void _siguienteReparto() {
    HapticFeedback.selectionClick();
    if (_turno + 1 >= widget.jugadores.length) {
      _empezarDebate();
      return;
    }
    setState(() {
      _viendo = false;
      _turno++;
    });
  }

  void _empezarDebate() {
    _quedan = widget.duracionDebate.inSeconds;
    _reloj?.cancel();
    _reloj = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_quedan <= 1) {
        t.cancel();
        // Se acaba el tiempo: toca votar aunque nadie lo pida.
        if (mounted) _irAVotar();
        return;
      }
      setState(() => _quedan--);
    });
    setState(() => _fase = _Fase.debate);
  }

  void _irAVotar() {
    _reloj?.cancel();
    HapticFeedback.mediumImpact();
    setState(() => _fase = _Fase.votar);
  }

  void _votar(int i) {
    HapticFeedback.heavyImpact();
    setState(() {
      _acusado = i;
      _fase = _Fase.resultado;
    });
  }

  void _otraRonda() {
    setState(() {
      _ronda = _nuevaRonda(evitar: _ronda.palabra);
      _fase = _Fase.repartir;
      _turno = 0;
      _viendo = false;
      _acusado = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('El impostor')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          child: switch (_fase) {
            _Fase.repartir => _Repartir(
              ronda: _ronda,
              turno: _turno,
              viendo: _viendo,
              alVer: () => setState(() => _viendo = true),
              alPasar: _siguienteReparto,
            ),
            _Fase.debate => _Debate(
              ronda: _ronda,
              quedan: _quedan,
              alVotar: _irAVotar,
            ),
            _Fase.votar => _Votar(ronda: _ronda, alElegir: _votar),
            _Fase.resultado => _Resultado(
              ronda: _ronda,
              acusado: _acusado!,
              alRepetir: _otraRonda,
            ),
          },
        ),
      ),
    );
  }
}

class _Repartir extends StatelessWidget {
  const _Repartir({
    required this.ronda,
    required this.turno,
    required this.viendo,
    required this.alVer,
    required this.alPasar,
  });

  final RondaImpostor ronda;
  final int turno;
  final bool viendo;
  final VoidCallback alVer;
  final VoidCallback alPasar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final nombre = ronda.jugadores[turno];
    final esImpostor = ronda.esImpostor(turno);
    final ultimo = turno + 1 >= ronda.jugadores.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Categoría: ${ronda.categoria.nombre}',
          style: texto.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        if (!viendo) ...[
          Titular('Pásale el móvil a $nombre', tamano: 30),
          const SizedBox(height: EspaciadoPrevia.s),
          Text('Que nadie más mire la pantalla.', style: texto.bodyMedium),
        ] else
          Semantics(
            liveRegion: true,
            container: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  nombre,
                  style: texto.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: EspaciadoPrevia.m),
                Container(
                  padding: const EdgeInsets.all(EspaciadoPrevia.l),
                  decoration: BoxDecoration(
                    color: esImpostor
                        ? const Color(0xFF8A2238)
                        : context.colores.superficieAlta,
                    borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
                  ),
                  child: Column(
                    children: [
                      Text(
                        esImpostor ? 'Eres el IMPOSTOR' : 'La palabra es',
                        style: texto.titleMedium?.copyWith(
                          color: esImpostor ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: EspaciadoPrevia.s),
                      Text(
                        esImpostor ? ronda.categoria.nombre : ronda.palabra,
                        textAlign: TextAlign.center,
                        style: texto.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: esImpostor ? Colors.white : null,
                        ),
                      ),
                      if (esImpostor) ...[
                        const SizedBox(height: EspaciadoPrevia.s),
                        Text(
                          'Solo sabes la categoría. Disimula.',
                          textAlign: TextAlign.center,
                          style: texto.bodyMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
        if (!viendo)
          FilledButton(onPressed: alVer, child: const Text('Ver mi palabra'))
        else
          FilledButton(
            onPressed: alPasar,
            child: Text(ultimo ? 'Ocultar y empezar' : 'Ocultar y pasar'),
          ),
        const SizedBox(height: EspaciadoPrevia.s),
        Text(
          'Jugador ${turno + 1} de ${ronda.jugadores.length}',
          style: texto.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Debate extends StatelessWidget {
  const _Debate({
    required this.ronda,
    required this.quedan,
    required this.alVotar,
  });

  final RondaImpostor ronda;
  final int quedan;
  final VoidCallback alVotar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final min = quedan ~/ 60;
    final seg = (quedan % 60).toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Text(
          'Empieza ${ronda.jugadores[ronda.primero]}',
          style: texto.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        Text(
          'Por turnos, decid algo de la palabra sin nombrarla. '
          'El impostor intenta pasar desapercibido.',
          style: texto.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: EspaciadoPrevia.l),
        Semantics(
          label: 'Quedan $min minutos y $seg segundos',
          child: ExcludeSemantics(
            child: Text(
              '$min:$seg',
              textAlign: TextAlign.center,
              style: texto.displayLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const Spacer(),
        FilledButton(onPressed: alVotar, child: const Text('Votar ya')),
      ],
    );
  }
}

class _Votar extends StatelessWidget {
  const _Votar({required this.ronda, required this.alElegir});

  final RondaImpostor ronda;
  final void Function(int) alElegir;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return ListView(
      children: [
        Semantics(
          header: true,
          child: const Titular('¿Quién es el impostor?', tamano: 28),
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        Text(
          'Votad en voz alta y tocad al más señalado.',
          style: texto.bodyMedium,
        ),
        const SizedBox(height: EspaciadoPrevia.m),
        for (var i = 0; i < ronda.jugadores.length; i++) ...[
          OutlinedButton(
            onPressed: () => alElegir(i),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: Text(ronda.jugadores[i]),
          ),
          const SizedBox(height: EspaciadoPrevia.s),
        ],
      ],
    );
  }
}

class _Resultado extends StatelessWidget {
  const _Resultado({
    required this.ronda,
    required this.acusado,
    required this.alRepetir,
  });

  final RondaImpostor ronda;
  final int acusado;
  final VoidCallback alRepetir;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final acierto = ronda.acierta(acusado);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Semantics(
          liveRegion: true,
          child: Titular(
            acierto ? '¡Lo habéis pillado!' : '¡Se ha escapado!',
            tamano: 34,
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.m),
        Text(
          acierto
              ? '${ronda.nombreImpostor} era el impostor.'
              : 'Habéis acusado a ${ronda.jugadores[acusado]}, pero el '
                    'impostor era ${ronda.nombreImpostor}.',
          style: texto.titleMedium,
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        Text('La palabra era: ${ronda.palabra}.', style: texto.titleMedium),
        const SizedBox(height: EspaciadoPrevia.m),
        Text(
          acierto
              ? 'Última oportunidad: si adivina la palabra, gana él.'
              : 'Gana el impostor.',
          style: texto.bodyMedium,
        ),
        const Spacer(),
        FilledButton(onPressed: alRepetir, child: const Text('Otra ronda')),
        const SizedBox(height: EspaciadoPrevia.s),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Salir'),
        ),
      ],
    );
  }
}
