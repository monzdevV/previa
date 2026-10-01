import 'package:flutter/material.dart';

import '../../app/tema.dart';
import 'almacen_jugadores.dart';
import 'modelo_juegos.dart';
import 'motor/partida.dart';
import 'pantalla_partida.dart';

/// Preparación: quién juega, qué intensidad, cuántas cartas y si hay alcohol.
class PantallaPreparacion extends StatefulWidget {
  const PantallaPreparacion({
    super.key,
    required this.juego,
    this.jugadoresIniciales = const [],
  });

  final TipoJuego juego;
  final List<String> jugadoresIniciales;

  @override
  State<PantallaPreparacion> createState() => _PantallaPreparacionState();
}

class _PantallaPreparacionState extends State<PantallaPreparacion> {
  final _campo = TextEditingController();
  final _foco = FocusNode();
  List<String> _jugadores = [];
  NivelReto _nivel = NivelReto.suave;
  int? _rondas = 10;
  bool _sinAlcohol = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _jugadores = limpiarNombres(widget.jugadoresIniciales);
    _cargar();
  }

  Future<void> _cargar() async {
    final guardados = await AlmacenJugadores.leerJugadores();
    final nivel = await AlmacenJugadores.leerNivel();
    if (!mounted) return;
    setState(() {
      // Lo que llega de la previa manda sobre lo recordado.
      if (_jugadores.isEmpty) _jugadores = guardados;
      if (nivel != null) _nivel = nivel;
    });
  }

  @override
  void dispose() {
    _campo.dispose();
    _foco.dispose();
    super.dispose();
  }

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
    // Se mantiene el foco para añadir a varios seguidos sin tocar de nuevo.
    _foco.requestFocus();
  }

  void _quitar(String nombre) {
    setState(() {
      _jugadores = _jugadores.where((j) => j != nombre).toList();
      _error = null;
    });
  }

  bool get _listo => _jugadores.length >= minJugadores;

  Future<void> _empezar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _DialogoConfirmacion(),
    );
    if (ok != true || !mounted) return;
    await AlmacenJugadores.guardar(_jugadores, _nivel);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaPartida(
          config: ConfiguracionPartida(
            juego: widget.juego,
            jugadores: _jugadores,
            nivel: _nivel,
            rondas: _rondas,
            sinAlcohol: _sinAlcohol,
          ),
        ),
      ),
    );
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
              Text(
                'Aún no hay nadie. Añade al menos $minJugadores.',
                style: texto.bodySmall,
              )
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
            const SizedBox(height: EspaciadoPrevia.l),
            Semantics(
              header: true,
              child: Text('Nivel', style: texto.titleLarge),
            ),
            const SizedBox(height: EspaciadoPrevia.s),
            for (final n in NivelReto.values) ...[
              _OpcionNivel(
                nivel: n,
                seleccionado: n == _nivel,
                onTap: () => setState(() => _nivel = n),
              ),
              const SizedBox(height: EspaciadoPrevia.s),
            ],
            Text('Cada nivel incluye los anteriores.', style: texto.bodySmall),
            const SizedBox(height: EspaciadoPrevia.l),
            Semantics(
              header: true,
              child: Text('Cartas', style: texto.titleLarge),
            ),
            const SizedBox(height: EspaciadoPrevia.s),
            Wrap(
              spacing: EspaciadoPrevia.s,
              runSpacing: EspaciadoPrevia.s,
              children: [
                for (final r in const [10, 20, null])
                  ChoiceChip(
                    label: Text(r == null ? 'Sin fin' : '$r'),
                    selected: _rondas == r,
                    onSelected: (_) => setState(() => _rondas = r),
                    // Con la selección a coral el check blanco es redundante
                    // con el color, pero ayuda a quien no distingue colores.
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    labelStyle: TextStyle(
                      color: _rondas == r
                          ? context.colores.sobrePrimario
                          : context.colores.texto,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: EspaciadoPrevia.m),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sin alcohol'),
              subtitle: const Text('Vale cualquier bebida o una prenda suave.'),
              value: _sinAlcohol,
              onChanged: (v) => setState(() => _sinAlcohol = v),
            ),
            const SizedBox(height: EspaciadoPrevia.m),
            FilledButton(
              onPressed: _listo ? _empezar : null,
              child: const Text('Empezar'),
            ),
            if (!_listo) ...[
              const SizedBox(height: EspaciadoPrevia.s),
              Text(
                'Hacen falta al menos $minJugadores jugadores.',
                style: texto.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: EspaciadoPrevia.m),
            Text(
              'Nadie está obligado a beber ni a hacer nada.',
              style: texto.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionNivel extends StatelessWidget {
  const _OpcionNivel({
    required this.nivel,
    required this.seleccionado,
    required this.onTap,
  });

  final NivelReto nivel;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: seleccionado,
      inMutuallyExclusiveGroup: true,
      label: '${nivel.etiqueta}. ${nivel.descripcion}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: seleccionado
            ? context.colores.primario.withValues(alpha: 0.22)
            : context.colores.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
          side: BorderSide(
            color: seleccionado
                ? context.colores.primarioTexto
                : context.colores.borde,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(EspaciadoPrevia.m),
              child: Row(
                children: [
                  Icon(
                    seleccionado
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: seleccionado
                        ? context.colores.primarioTexto
                        : context.colores.textoSuave,
                  ),
                  const SizedBox(width: EspaciadoPrevia.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nivel.etiqueta, style: texto.titleMedium),
                        Text(nivel.descripcion, style: texto.bodyMedium),
                      ],
                    ),
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

/// Confirmación obligatoria antes de empezar: edad y consumo responsable.
class _DialogoConfirmacion extends StatelessWidget {
  const _DialogoConfirmacion();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Antes de empezar'),
      content: const SingleChildScrollView(
        child: Text(
          'Este juego es solo para mayores de 18 años.\n\n'
          'Bebe con cabeza: nunca más de 3 sorbos por carta, y si no te '
          'apetece, pasa. Nadie está obligado a beber ni a hacer nada.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
          child: const Text('Tengo +18 y bebo con cabeza'),
        ),
      ],
    );
  }
}
