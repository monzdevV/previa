import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../profile/pantalla_perfil.dart';
import 'pantalla_mapa.dart';

/// Contenedor principal con la navegación inferior.
class PantallaInicio extends ConsumerStatefulWidget {
  const PantallaInicio({super.key});

  @override
  ConsumerState<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends ConsumerState<PantallaInicio> {
  int _pestana = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _pestana,
        children: [
          PantallaMapa(
            onCrearPrevia: () => context.push(Rutas.crearPrevia),
            onAbrirPrevia: (previa) =>
                context.push('${Rutas.previa}/${previa.id}'),
          ),
          const PantallaPerfil(),
        ],
      ),
      // El filete superior separa la navegacion de la lamina igual que un
      // filete separa dos bandas del indice. Los colores y la pestaña activa
      // los pone el tema: aqui no se sobrescribe ninguno.
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: ColoresPrevia.borde)),
        ),
        child: NavigationBar(
          selectedIndex: _pestana,
          onDestinationSelected: (i) => setState(() => _pestana = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'MAPA',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'PERFIL',
            ),
          ],
        ),
      ),
    );
  }
}
