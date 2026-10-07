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
            child: Conmutador(
              opciones: const ['Mensajes', 'Avisos'],
              elegida: _avisos ? 1 : 0,
              onElegir: (i) => _cambiar(i == 1),
              pendientes: [mensajesSinLeer, sinLeer],
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
