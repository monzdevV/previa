import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../feed/pantalla_feed.dart';
import '../profile/pantalla_perfil.dart';
import '../social/pantalla_locales.dart';
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
          const PantallaFeed(),
          PantallaMapa(
            onCrearPrevia: () => context.push(Rutas.crearPrevia),
            onAbrirPrevia: (previa) =>
                context.push('${Rutas.previa}/${previa.id}'),
          ),
          const PantallaLocales(),
          const PantallaPerfil(),
        ],
      ),
      // La linea superior separa la barra del contenido, que casi siempre es
      // una foto a sangre. Los colores los pone el tema.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colores.borde)),
        ),
        child: NavigationBar(
          selectedIndex: _pestana,
          onDestinationSelected: (i) {
            if (i != _pestana) HapticFeedback.selectionClick();
            setState(() => _pestana = i);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: _IconoActivo(Icons.home_rounded),
              label: 'Feed',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: _IconoActivo(Icons.map_rounded),
              label: 'Mapa',
            ),
            NavigationDestination(
              icon: Icon(Icons.nightlife_outlined),
              selectedIcon: _IconoActivo(Icons.nightlife),
              label: 'Noche',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: _IconoActivo(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

/// La pestaña activa: el icono relleno con un punto amarillo debajo.
///
/// Las etiquetas van ocultas, asi que el punto es lo que dice donde estas
/// sin gastar el amarillo en todo el icono.
class _IconoActivo extends StatelessWidget {
  const _IconoActivo(this.icono);

  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono),
        const SizedBox(height: 3),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: context.colores.primarioTexto,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );

    if (MovimientoPrevia.reducido(context)) return contenido;
    return contenido.animate().scale(
      begin: const Offset(.85, .85),
      duration: MovimientoPrevia.normal,
      curve: Curves.easeOutBack,
    );
  }
}
