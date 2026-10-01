import 'package:flutter/material.dart';

import '../../app/tema.dart';
import 'motor/partida.dart';

/// Campo de nombres con fichas, para los minijuegos. La preparación de los
/// juegos de cartas lleva su propia copia porque comparte estado con el nivel
/// y las rondas; aquí solo hace falta la lista.
class EditorJugadores extends StatefulWidget {
  const EditorJugadores({
    super.key,
    required this.iniciales,
    required this.alCambiar,
  });

  final List<String> iniciales;
  final ValueChanged<List<String>> alCambiar;

  @override
  State<EditorJugadores> createState() => _EditorJugadoresState();
}

class _EditorJugadoresState extends State<EditorJugadores> {
  final _campo = TextEditingController();
  final _foco = FocusNode();
  late List<String> _jugadores = limpiarNombres(widget.iniciales);
  String? _error;

  @override
  void didUpdateWidget(EditorJugadores old) {
    super.didUpdateWidget(old);
    // Los nombres recordados llegan de forma asíncrona tras el primer frame.
    if (_jugadores.isEmpty && widget.iniciales.isNotEmpty) {
      _jugadores = limpiarNombres(widget.iniciales);
    }
  }

  @override
  void dispose() {
    _campo.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _publicar() => widget.alCambiar(List.unmodifiable(_jugadores));

  void _anadir() {
    final nombre = _campo.text.trim();
    if (nombre.isEmpty) return;
    if (_jugadores.length >= maxJugadores) {
      setState(() => _error = 'Máximo $maxJugadores jugadores.');
      return;
    }
    if (_jugadores.any((j) => j.toLowerCase() == nombre.toLowerCase())) {
      setState(() => _error = 'Ya hay alguien que se llama $nombre.');
      return;
    }
    setState(() {
      _jugadores = limpiarNombres([..._jugadores, nombre]);
      _campo.clear();
      _error = null;
    });
    _publicar();
    _foco.requestFocus();
  }

  void _quitar(String nombre) {
    setState(() {
      _jugadores = _jugadores.where((j) => j != nombre).toList();
      _error = null;
    });
    _publicar();
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('¿Quién juega?', style: texto.titleLarge),
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _campo,
                focusNode: _foco,
                maxLength: maxLongitudNombre,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _anadir(),
                decoration: InputDecoration(
                  labelText: 'Nombre del jugador',
                  errorText: _error,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: EspaciadoPrevia.s),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: IconButton.filled(
                onPressed: _anadir,
                tooltip: 'Añadir jugador',
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  minimumSize: const Size(56, 56),
                  backgroundColor: context.colores.primario,
                  foregroundColor: context.colores.sobrePrimario,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        if (_jugadores.isEmpty)
          Text('Aún no hay nadie.', style: texto.bodySmall)
        else
          Wrap(
            spacing: EspaciadoPrevia.s,
            runSpacing: EspaciadoPrevia.s,
            children: [
              for (final j in _jugadores)
                InputChip(
                  label: Text(j),
                  onDeleted: () => _quitar(j),
                  deleteButtonTooltipMessage: 'Quitar a $j',
                ),
            ],
          ),
        const SizedBox(height: EspaciadoPrevia.xs),
        Text(
          '${_jugadores.length} de $maxJugadores jugadores',
          style: texto.bodySmall,
        ),
      ],
    );
  }
}
