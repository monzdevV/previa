import 'package:flutter/material.dart';

import '../../app/tema.dart';
import 'almacen_jugadores.dart';
import 'editor_jugadores.dart';
import 'modelo_juegos.dart';
import 'motor/impostor.dart';
import 'motor/palabra_prohibida.dart';
import 'motor/partida.dart';
import 'motor/reyes.dart';
import 'pantalla_impostor.dart';
import 'pantalla_palabra_prohibida.dart';
import 'pantalla_reyes.dart';
import 'pantalla_ruleta.dart';

/// Preparación de los minijuegos: jugadores y, según el juego, sus opciones.
class PantallaPreparacionMini extends StatefulWidget {
  const PantallaPreparacionMini({
    super.key,
    required this.juego,
    this.jugadoresIniciales = const [],
  });

  final MiniJuego juego;
  final List<String> jugadoresIniciales;

  @override
  State<PantallaPreparacionMini> createState() =>
      _PantallaPreparacionMiniState();
}

class _PantallaPreparacionMiniState extends State<PantallaPreparacionMini> {
  List<String> _jugadores = [];
  List<String> _recordados = [];

  /// Índice de la categoría elegida; `null` = una al azar en cada ronda.
  int? _categoria;
  bool _sinAlcohol = false;
  int _rondas = rondasPorDefectoTabu;

  @override
  void initState() {
    super.initState();
    _jugadores = limpiarNombres(widget.jugadoresIniciales);
    _cargar();
  }

  Future<void> _cargar() async {
    final guardados = await AlmacenJugadores.leerJugadores();
    if (!mounted) return;
    setState(() {
      // Lo que llega de la previa manda sobre lo recordado.
      if (_jugadores.isEmpty) {
        _jugadores = guardados;
        _recordados = guardados;
      }
    });
  }

  int get _minimo => switch (widget.juego) {
    MiniJuego.impostor => minJugadoresImpostor,
    MiniJuego.palabraProhibida => minJugadoresTabu,
    MiniJuego.reyes => minJugadoresReyes,
    MiniJuego.ruleta => minJugadores,
  };

  bool get _listo => _jugadores.length >= _minimo;

  Future<void> _empezar() async {
    final nivel = await AlmacenJugadores.leerNivel() ?? NivelReto.suave;
    await AlmacenJugadores.guardar(_jugadores, nivel);
    if (!mounted) return;
    final destino = switch (widget.juego) {
      MiniJuego.impostor => PantallaImpostor(
        jugadores: _jugadores,
        categoria: _categoria == null ? null : categoriasImpostor[_categoria!],
      ),
      MiniJuego.ruleta => PantallaRuleta(
        jugadores: _jugadores,
        sinAlcohol: _sinAlcohol,
      ),
      MiniJuego.reyes => PantallaReyes(
        jugadores: _jugadores,
        sinAlcohol: _sinAlcohol,
      ),
      MiniJuego.palabraProhibida => PantallaPalabraProhibida(
        jugadores: _jugadores,
        rondas: _rondas,
      ),
    };
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => destino));
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.juego.titulo)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          children: [
            Text(widget.juego.descripcion, style: texto.bodyMedium),
            const SizedBox(height: EspaciadoPrevia.l),
            EditorJugadores(
              iniciales: _jugadores.isEmpty ? _recordados : _jugadores,
              alCambiar: (l) => setState(() => _jugadores = l),
            ),
            const SizedBox(height: EspaciadoPrevia.l),
            if (widget.juego == MiniJuego.impostor) ...[
              Semantics(
                header: true,
                child: Text('Categoría', style: texto.titleLarge),
              ),
              const SizedBox(height: EspaciadoPrevia.s),
              Wrap(
                spacing: EspaciadoPrevia.s,
                runSpacing: EspaciadoPrevia.s,
                children: [
                  ChoiceChip(
                    label: const Text('Al azar'),
                    selected: _categoria == null,
                    onSelected: (_) => setState(() => _categoria = null),
                  ),
                  for (var i = 0; i < categoriasImpostor.length; i++)
                    ChoiceChip(
                      label: Text(categoriasImpostor[i].nombre),
                      selected: _categoria == i,
                      onSelected: (_) => setState(() => _categoria = i),
                    ),
                ],
              ),
            ] else if (widget.juego == MiniJuego.palabraProhibida) ...[
              Semantics(
                header: true,
                child: Text('Rondas', style: texto.titleLarge),
              ),
              const SizedBox(height: EspaciadoPrevia.s),
              Text(
                'Dos equipos al azar. Cada ronda juega un turno de 60 s '
                'cada equipo.',
                style: texto.bodyMedium,
              ),
              const SizedBox(height: EspaciadoPrevia.s),
              Wrap(
                spacing: EspaciadoPrevia.s,
                runSpacing: EspaciadoPrevia.s,
                children: [
                  for (final n in const [1, 2, 3, 4, 5])
                    ChoiceChip(
                      label: Text('$n'),
                      selected: _rondas == n,
                      onSelected: (_) => setState(() => _rondas = n),
                    ),
                ],
              ),
            ] else
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sin alcohol'),
                subtitle: const Text('Vale cualquier bebida.'),
                value: _sinAlcohol,
                onChanged: (v) => setState(() => _sinAlcohol = v),
              ),
            const SizedBox(height: EspaciadoPrevia.l),
            FilledButton(
              onPressed: _listo ? _empezar : null,
              child: const Text('Empezar'),
            ),
            if (!_listo) ...[
              const SizedBox(height: EspaciadoPrevia.s),
              Text(
                'Hacen falta al menos $_minimo jugadores.',
                style: texto.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
