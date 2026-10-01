import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/tema.dart';
import 'motor/reyes.dart';

/// Reyes con un solo móvil: se roba una carta por turno y cada valor tiene su
/// regla. La partida acaba al salir el cuarto rey.
class PantallaReyes extends StatefulWidget {
  const PantallaReyes({
    super.key,
    required this.jugadores,
    this.sinAlcohol = false,
    this.azar,
  });

  final List<String> jugadores;
  final bool sinAlcohol;

  /// Solo para las pruebas: permite una baraja predecible.
  final Random? azar;

  @override
  State<PantallaReyes> createState() => _PantallaReyesState();
}

class _PantallaReyesState extends State<PantallaReyes> {
  late PartidaReyes _partida = _nueva();

  PartidaReyes _nueva() =>
      PartidaReyes(jugadores: widget.jugadores, azar: widget.azar);

  void _robar() {
    HapticFeedback.mediumImpact();
    setState(_partida.robar);
  }

  void _otraPartida() => setState(() => _partida = _nueva());

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final carta = _partida.actual;
    return Scaffold(
      appBar: AppBar(title: const Text('Reyes')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Con texto grande el contenido puede no caber: todo menos los
              // botones se desplaza en vez de recortarse.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Text(
                        'Reyes: ${_partida.reyesSalidos} de 4 · '
                        'quedan ${_partida.cartasRestantes} cartas',
                        style: texto.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: EspaciadoPrevia.m),
                      Semantics(
                        liveRegion: true,
                        container: true,
                        child: carta == null
                            ? _Inicio(texto: texto)
                            : _Carta(
                                carta: carta,
                                jugador: _partida.jugadorActual,
                                regla: _partida.reglaActual,
                                sinAlcohol: widget.sinAlcohol,
                                ultima: _partida.terminada,
                              ),
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
              const SizedBox(height: EspaciadoPrevia.m),
              if (_partida.terminada) ...[
                FilledButton(
                  onPressed: _otraPartida,
                  child: const Text('Otra partida'),
                ),
                const SizedBox(height: EspaciadoPrevia.s),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Salir'),
                ),
              ] else
                FilledButton(
                  onPressed: _robar,
                  child: Text(
                    carta == null ? 'Robar carta' : 'Siguiente carta',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Inicio extends StatelessWidget {
  const _Inicio({required this.texto});
  final TextTheme texto;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: EspaciadoPrevia.l),
        const Titular('Reyes', tamano: 34),
        const SizedBox(height: EspaciadoPrevia.m),
        Text(
          'Se roba una carta por turno y cada valor tiene su regla. '
          'Cuando salga el cuarto rey, se acaba.',
          style: texto.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Carta extends StatelessWidget {
  const _Carta({
    required this.carta,
    required this.jugador,
    required this.regla,
    required this.sinAlcohol,
    required this.ultima,
  });

  final CartaReyes carta;
  final String jugador;
  final ReglaRey regla;
  final bool sinAlcohol;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    // Rojo y negro como en la baraja; sobre fondo blanco ambos contrastan.
    final rojo = carta.palo == 1 || carta.palo == 2;
    final tinta = rojo ? const Color(0xFFB3261E) : const Color(0xFF1B1B1F);
    return Column(
      children: [
        Semantics(
          label: carta.nombreLeido,
          excludeSemantics: true,
          child: Container(
            width: 150,
            padding: const EdgeInsets.all(EspaciadoPrevia.s),
            constraints: const BoxConstraints(minHeight: 210),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
              border: Border.all(color: context.colores.borde, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  carta.nombreValor,
                  style: TextStyle(
                    color: tinta,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                Text(
                  carta.simboloPalo,
                  style: TextStyle(color: tinta, fontSize: 56, height: 1.1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.m),
        Text('Le toca a $jugador', style: texto.titleMedium),
        const SizedBox(height: EspaciadoPrevia.s),
        Titular(regla.titulo, tamano: 28),
        const SizedBox(height: EspaciadoPrevia.s),
        Text(
          regla.texto(sinAlcohol: sinAlcohol),
          style: texto.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (ultima) ...[
          const SizedBox(height: EspaciadoPrevia.m),
          const Titular('¡Han salido los 4 reyes!', tamano: 24),
        ],
      ],
    );
  }
}
