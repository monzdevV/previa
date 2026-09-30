import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_previas.dart';
import 'componentes_previa.dart';
import 'estados_pantalla.dart';

/// Hoja para pedir plaza. Devuelve true si la solicitud se ha enviado.
Future<bool?> mostrarHojaSolicitarPlaza(
  BuildContext context, {
  required String previaId,
  required int plazasLibres,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: ColoresPrevia.fondo,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(EspaciadoPrevia.radioGrande),
      ),
    ),
    builder: (_) =>
        _HojaSolicitarPlaza(previaId: previaId, plazasLibres: plazasLibres),
  );
}

class _HojaSolicitarPlaza extends ConsumerStatefulWidget {
  const _HojaSolicitarPlaza({
    required this.previaId,
    required this.plazasLibres,
  });

  final String previaId;
  final int plazasLibres;

  @override
  ConsumerState<_HojaSolicitarPlaza> createState() =>
      _HojaSolicitarPlazaState();
}

class _HojaSolicitarPlazaState extends ConsumerState<_HojaSolicitarPlaza> {
  final _mensaje = TextEditingController();
  int _grupo = 1;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _mensaje.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      await ref
          .read(repositorioPreviasProvider)
          .solicitarPlaza(
            previaId: widget.previaId,
            tamanoGrupo: _grupo,
            mensaje: _mensaje.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Solicitud enviada.')));
    } on ErrorPrevia catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    // Con muchas plazas un grupo enorme no es realista: tope de 10.
    final tope = widget.plazasLibres.clamp(1, 10);
    final restantes = widget.plazasLibres - _grupo;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        // Scroll: con teclado abierto o texto grande la hoja no debe recortarse.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(EspaciadoPrevia.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Cuántos vais?', style: textos.headlineMedium),
              const SizedBox(height: EspaciadoPrevia.s),
              Text(
                'Se pide plaza para todo el grupo de golpe. Quedan '
                '${widget.plazasLibres} '
                '${widget.plazasLibres == 1 ? "plaza" : "plazas"}.',
                style: textos.bodyMedium,
              ),
              const SizedBox(height: EspaciadoPrevia.l),

              _SelectorGrupo(
                valor: _grupo,
                tope: tope,
                onCambio: (n) => setState(() => _grupo = n),
              ),
              const SizedBox(height: EspaciadoPrevia.m),
              // Muestra el efecto de tu petición sobre el aforo: hace tangible
              // que pedir más plazas deja menos sitio a los demás.
              BarraPlazas(libres: restantes < 0 ? 0 : restantes),
              const SizedBox(height: EspaciadoPrevia.xs),
              Text(
                _grupo >= tope && tope < widget.plazasLibres
                    ? 'Máximo por solicitud: $tope personas.'
                    : (restantes <= 0
                          ? 'Os quedaríais con las últimas plazas.'
                          : 'Quedarían $restantes ${restantes == 1 ? "plaza" : "plazas"} '
                                'para los demás.'),
                style: textos.bodyMedium?.copyWith(fontSize: 12),
              ),

              const SizedBox(height: EspaciadoPrevia.l),
              TextField(
                controller: _mensaje,
                maxLines: 3,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Preséntate (opcional)',
                  hintText:
                      'Somos dos, venimos de cenar por la zona. '
                      'Llevamos bebida.',
                  alignLabelWithHint: true,
                ),
              ),

              Text(
                'Un mensaje con algo de contexto multiplica las opciones '
                'de que te acepten.',
                style: textos.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: ColoresPrevia.textoTenue,
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: EspaciadoPrevia.m),
                AvisoError(_error!),
              ],

              const SizedBox(height: EspaciadoPrevia.l),
              FilledButton(
                onPressed: _enviando ? null : _enviar,
                child: _enviando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                          semanticsLabel: 'Enviando solicitud',
                        ),
                      )
                    : Text(
                        _grupo == 1 ? 'Pedir mi plaza' : 'Pedir $_grupo plazas',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selector de tamaño de grupo con - / +.
///
/// Dos botones grandes (56 dp) y un número central reemplazan a una fila de
/// chips: es más rápido con el pulgar y escala mejor con texto grande. El
/// número es una región viva para que el lector anuncie el cambio.
class _SelectorGrupo extends StatelessWidget {
  const _SelectorGrupo({
    required this.valor,
    required this.tope,
    required this.onCambio,
  });

  final int valor;
  final int tope;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final estiloBoton = IconButton.styleFrom(minimumSize: const Size(56, 56));

    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Una persona menos',
          style: estiloBoton,
          onPressed: valor > 1 ? () => onCambio(valor - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            label: valor == 1 ? '1 persona' : '$valor personas',
            excludeSemantics: true,
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (hijo, anim) => ScaleTransition(
                    scale: anim,
                    child: FadeTransition(opacity: anim, child: hijo),
                  ),
                  child: Text(
                    '$valor',
                    key: ValueKey(valor),
                    style: textos.displaySmall?.copyWith(
                      color: ColoresPrevia.acento,
                    ),
                  ),
                ),
                Text(
                  valor == 1 ? 'persona' : 'personas',
                  style: textos.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Una persona más',
          style: estiloBoton,
          onPressed: valor < tope ? () => onCambio(valor + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
