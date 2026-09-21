import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_previas.dart';

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
    final tope = widget.plazasLibres.clamp(1, 10);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
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

              Wrap(
                spacing: EspaciadoPrevia.s,
                runSpacing: EspaciadoPrevia.s,
                children: [
                  for (var n = 1; n <= tope; n++)
                    ChoiceChip(
                      label: Text('$n'),
                      selected: _grupo == n,
                      selectedColor: ColoresPrevia.primario,
                      onSelected: (_) => setState(() => _grupo = n),
                    ),
                ],
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
                Container(
                  padding: const EdgeInsets.all(EspaciadoPrevia.m),
                  decoration: BoxDecoration(
                    color: ColoresPrevia.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
                    border: Border.all(
                      color: ColoresPrevia.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: ColoresPrevia.error),
                  ),
                ),
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
