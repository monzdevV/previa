import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_previas.dart';
import '../auth/piezas_acceso.dart' show AvisoError;
import 'componentes_previa.dart';

/// Hoja para pedir plaza. Devuelve true si la solicitud se ha enviado.
Future<bool?> mostrarHojaSolicitarPlaza(
  BuildContext context, {
  required String previaId,
  required int plazasLibres,
}) {
  // La misma hoja que el resto de la app: mismo asa, misma forma.
  return mostrarHoja<bool>(
    context,
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
  int _grupo = 1;
  bool _enviando = false;
  String? _error;

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
          );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Solicitud enviada.')));
    } on ErrorPrevia catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      // Un fallo de red no puede dejar el boton girando sin explicacion.
      if (mounted) {
        setState(
          () => _error = 'No se ha podido enviar. Comprueba tu conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    // Un grupo de quince pidiendo de golpe no es realista: tope de 10.
    final tope = widget.plazasLibres.clamp(1, 10);
    final restantes = widget.plazasLibres - _grupo;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        // Con el teclado abierto o la letra grande la hoja no se recorta.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            EspaciadoPrevia.l,
            0,
            EspaciadoPrevia.l,
            EspaciadoPrevia.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Titular('¿Cuántos vais?', tamano: 30),
              ),
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
                onCambio: (n) {
                  HapticFeedback.selectionClick();
                  setState(() => _grupo = n);
                },
              ),
              const SizedBox(height: EspaciadoPrevia.m),
              // El efecto de tu peticion sobre el aforo: hace tangible que
              // pedir mas plazas deja menos sitio a los demas.
              BarraPlazas(libres: restantes < 0 ? 0 : restantes),
              const SizedBox(height: EspaciadoPrevia.s),
              Text(
                _grupo >= tope && tope < widget.plazasLibres
                    ? 'Máximo por solicitud: $tope personas.'
                    : (restantes <= 0
                          ? 'Os quedaríais con las últimas plazas.'
                          : 'Quedarían $restantes '
                                '${restantes == 1 ? "plaza" : "plazas"} '
                                'para los demás.'),
                style: textos.bodyMedium?.copyWith(fontSize: 13),
              ),

              // Sin mensaje libre a propósito: antes de aceptar, el anfitrión solo
              // ve cuántos sois. Un texto de desconocidos es un canal de acoso y
              // obliga a moderar; el contexto llega ya dentro del chat.
              if (_error != null) ...[
                const SizedBox(height: EspaciadoPrevia.m),
                AvisoError(_error!),
              ],

              const SizedBox(height: EspaciadoPrevia.l),
              FilledButton(
                onPressed: _enviando ? null : _enviar,
                child: _enviando
                    ? SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: context.colores.sobrePrimario,
                          semanticsLabel: 'Enviando solicitud',
                        ),
                      )
                    : Text(
                        _grupo == 1 ? 'PEDIR MI PLAZA' : 'PEDIR $_grupo PLAZAS',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selector del tamaño del grupo con - / +.
///
/// Dos botones grandes (56 dp) y el numero en medio sustituyen a una fila de
/// chips: es mas rapido con el pulgar y aguanta mejor la letra grande. El
/// numero es una region viva para que el lector anuncie el cambio.
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

    return Row(
      children: [
        BotonPaso(
          icono: Icons.remove,
          tooltip: 'Una persona menos',
          onPressed: valor > 1 ? () => onCambio(valor - 1) : null,
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            label: valor == 1 ? '1 persona' : '$valor personas',
            excludeSemantics: true,
            child: Column(
              children: [
                CifraAnimada(
                  valor: valor,
                  estilo: textos.displaySmall?.copyWith(
                    color: context.colores.primarioTexto,
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
        BotonPaso(
          icono: Icons.add,
          tooltip: 'Una persona más',
          onPressed: valor < tope ? () => onCambio(valor + 1) : null,
        ),
      ],
    );
  }
}
