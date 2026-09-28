import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import 'pantalla_avisos.dart';
import 'pantalla_mensajes.dart';

/// Mensajes y avisos juntos, en una pestaña.
///
/// Eran dos iconos en la cabecera del feed, junto a buscar y publicar: cuatro
/// botones compitiendo arriba del todo, lejos del pulgar. Las dos cosas
/// responden a la misma pregunta, "¿que me ha pasado?", asi que viven juntas
/// y se cambia de una a otra sin salir.
class PantallaBuzon extends ConsumerStatefulWidget {
  const PantallaBuzon({super.key});

  @override
  ConsumerState<PantallaBuzon> createState() => _PantallaBuzonState();
}

class _PantallaBuzonState extends ConsumerState<PantallaBuzon> {
  bool _avisos = false;

  void _cambiar(bool avisos) {
    if (avisos == _avisos) return;
    HapticFeedback.selectionClick();
    // Al entrar en avisos se piden de nuevo: la lista se cacheo la primera
    // vez y los nuevos solo se ven en la chincheta.
    if (avisos) ref.invalidate(avisosProvider);
    setState(() => _avisos = avisos);
  }

  @override
  Widget build(BuildContext context) {
    final sinLeer = ref.watch(sinLeerProvider).valueOrNull ?? 0;
    final mensajesSinLeer =
        ref
            .watch(conversacionesProvider)
            .valueOrNull
            ?.fold<int>(0, (total, c) => total + c.sinLeer) ??
        0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: EspaciadoPrevia.m,
        title: const Text('BUZÓN'),
        actions: [
          IconButton(
            tooltip: 'Buscar gente',
            icon: const Icon(Icons.person_search_rounded, size: 27),
            onPressed: () => context.push(Rutas.buscar),
          ),
          const SizedBox(width: EspaciadoPrevia.s),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              EspaciadoPrevia.m,
              EspaciadoPrevia.xs,
              EspaciadoPrevia.m,
              EspaciadoPrevia.s,
            ),
            child: _Conmutador(
              avisos: _avisos,
              onCambiar: _cambiar,
              sinLeerMensajes: mensajesSinLeer,
              sinLeerAvisos: sinLeer,
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: MovimientoPrevia.rapido,
              switchInCurve: MovimientoPrevia.curva,
              child: _avisos
                  ? const ListaAvisos(key: ValueKey('avisos'))
                  : const ListaConversaciones(key: ValueKey('mensajes')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dos pastillas con un fondo que se desliza a la elegida.
///
/// El fondo se mueve en vez de aparecer: asi se ve de donde viene y a donde
/// va, que es lo que dice "esto es un interruptor" sin tener que leerlo.
class _Conmutador extends StatelessWidget {
  const _Conmutador({
    required this.avisos,
    required this.onCambiar,
    required this.sinLeerMensajes,
    required this.sinLeerAvisos,
  });

  final bool avisos;
  final ValueChanged<bool> onCambiar;
  final int sinLeerMensajes;
  final int sinLeerAvisos;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final reducido = MovimientoPrevia.reducido(context);

    Widget opcion(String texto, bool esAvisos, int pendientes) {
      final activa = avisos == esAvisos;
      return Expanded(
        child: Semantics(
          button: true,
          selected: activa,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onCambiar(esAvisos),
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: MovimientoPrevia.rapido,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      fontFamily: LetraPrevia.titular,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: activa ? c.sobrePrimario : c.textoSuave,
                    ),
                    child: Text(texto.toUpperCase()),
                  ),
                  if (pendientes > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: activa ? c.sobrePrimario : c.error,
                        borderRadius: BorderRadius.circular(
                          EspaciadoPrevia.pastilla,
                        ),
                      ),
                      child: Text(
                        pendientes > 9 ? '9+' : '$pendientes',
                        style: TextStyle(
                          color: activa ? c.primario : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.superficieAlta,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: avisos ? Alignment.centerRight : Alignment.centerLeft,
            duration: reducido ? Duration.zero : MovimientoPrevia.normal,
            curve: MovimientoPrevia.curva,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: c.primario,
                  borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
                ),
              ),
            ),
          ),
          Row(
            children: [
              opcion('Mensajes', false, sinLeerMensajes),
              opcion('Avisos', true, sinLeerAvisos),
            ],
          ),
        ],
      ),
    );
  }
}
