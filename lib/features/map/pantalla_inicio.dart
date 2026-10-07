import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../feed/pantalla_feed.dart';
import '../profile/pantalla_perfil.dart';
import '../social/pantalla_avisos.dart';
import '../social/pantalla_buzon.dart';
import '../social/pantalla_locales.dart';
import '../social/pantalla_mensajes.dart';
import 'pantalla_mapa.dart';

/// Las cinco pestañas de la app.
///
/// Cinco y no mas, y cada una es un sitio, no una accion: Inicio (lo que
/// pasa), Mapa (previas cerca), ¿Vas? (quien sale esta noche), Buzon
/// (mensajes y avisos) y Tu. Crear algo es una accion y vive en el "+" de
/// arriba; lo que se usa una vez al mes vive en Ajustes.
///
/// ¿Vas? va en el centro y distinta porque es lo que se hace cada noche: el
/// pulgar llega al centro sin estirarse.
class PantallaInicio extends ConsumerStatefulWidget {
  const PantallaInicio({super.key});

  @override
  ConsumerState<PantallaInicio> createState() => _PantallaInicioState();
}

enum _Pestana { inicio, mapa, vas, buzon, tu }

class _PantallaInicioState extends ConsumerState<PantallaInicio> {
  _Pestana _pestana = _Pestana.inicio;

  void _ir(_Pestana destino) {
    if (destino == _pestana) return;
    HapticFeedback.selectionClick();
    // El buzon se mantiene vivo en la pila; al volver a el se pide de nuevo
    // para no enseñar conversaciones de hace un rato.
    if (destino == _Pestana.buzon) ref.invalidate(conversacionesProvider);
    setState(() => _pestana = destino);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // La barra flota encima: el feed y el mapa pasan por debajo del vidrio.
      extendBody: true,
      body: IndexedStack(
        index: _pestana.index,
        children: [
          const PantallaFeed(),
          PantallaMapa(
            onCrearPrevia: () => context.push(Rutas.crearPrevia),
            onAbrirPrevia: (previa) =>
                context.push('${Rutas.previa}/${previa.id}'),
          ),
          const PantallaLocales(),
          const PantallaBuzon(),
          const PantallaPerfil(),
        ],
      ),
      bottomNavigationBar: _BarraDePestanas(actual: _pestana, onIr: _ir),
    );
  }
}

class _BarraDePestanas extends ConsumerWidget {
  const _BarraDePestanas({required this.actual, required this.onIr});

  final _Pestana actual;
  final ValueChanged<_Pestana> onIr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avisos = ref.watch(sinLeerProvider).valueOrNull ?? 0;
    final mensajes =
        ref
            .watch(conversacionesProvider)
            .valueOrNull
            ?.fold<int>(0, (total, c) => total + c.sinLeer) ??
        0;
    final yo = ref.watch(miPerfilProvider).valueOrNull;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: EspaciadoPrevia.s + 4),
        child: SizedBox(
          height: 68,
          child: Cristal(
            radio: 30,
            child: Row(
              children: [
                _Hueco(
                  etiqueta: 'Inicio',
                  activo: actual == _Pestana.inicio,
                  onTap: () => onIr(_Pestana.inicio),
                  icono: Icons.home_outlined,
                  iconoActivo: Icons.home_rounded,
                ),
                _Hueco(
                  etiqueta: 'Mapa',
                  activo: actual == _Pestana.mapa,
                  onTap: () => onIr(_Pestana.mapa),
                  icono: Icons.map_outlined,
                  iconoActivo: Icons.map_rounded,
                ),
                Expanded(
                  child: _BotonVas(
                    activo: actual == _Pestana.vas,
                    onTap: () => onIr(_Pestana.vas),
                  ),
                ),
                _Hueco(
                  etiqueta: 'Buzón',
                  activo: actual == _Pestana.buzon,
                  onTap: () => onIr(_Pestana.buzon),
                  icono: Icons.chat_bubble_outline_rounded,
                  iconoActivo: Icons.chat_bubble_rounded,
                  pendientes: avisos + mensajes,
                ),
                _Hueco(
                  etiqueta: 'Tú',
                  activo: actual == _Pestana.tu,
                  onTap: () => onIr(_Pestana.tu),
                  icono: Icons.person_outline_rounded,
                  iconoActivo: Icons.person_rounded,
                  // Tu cara en lugar de un muñeco: es lo que hace cualquier red
                  // social y dice "esto eres tu" sin etiqueta.
                  cara: yo == null
                      ? null
                      : (bool activo) => AvatarPerfil(
                          url: yo.avatarUrl,
                          inicial: yo.nombre,
                          lado: activo ? 24 : 26,
                          anillo: activo ? context.colores.texto : null,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Una pestaña normal: icono, etiqueta corta y un punto de pendientes.
class _Hueco extends StatelessWidget {
  const _Hueco({
    required this.etiqueta,
    required this.activo,
    required this.onTap,
    required this.icono,
    required this.iconoActivo,
    this.pendientes = 0,
    this.cara,
  });

  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;
  final IconData icono;
  final IconData iconoActivo;
  final int pendientes;
  final Widget Function(bool activo)? cara;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final color = activo ? c.texto : c.textoTenue;

    Widget simbolo = cara != null
        ? cara!(activo)
        : AnimatedSwitcher(
            duration: MovimientoPrevia.rapido,
            transitionBuilder: (hijo, animacion) => ScaleTransition(
              scale: Tween(begin: 0.8, end: 1.0).animate(animacion),
              child: FadeTransition(opacity: animacion, child: hijo),
            ),
            child: Icon(
              activo ? iconoActivo : icono,
              key: ValueKey(activo),
              size: 25,
              color: color,
            ),
          );

    if (pendientes > 0) {
      simbolo = Stack(
        clipBehavior: Clip.none,
        children: [
          simbolo,
          Positioned(
            top: -3,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 17),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.error,
                borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
                border: Border.all(color: c.fondo, width: 1.5),
              ),
              child: Text(
                pendientes > 9 ? '9+' : '$pendientes',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Expanded(
      child: Semantics(
        button: true,
        selected: activo,
        label: pendientes > 0 ? '$etiqueta, $pendientes sin leer' : etiqueta,
        excludeSemantics: true,
        child: Pulsable(
          onTap: onTap,
          vibrar: false,
          escala: 0.9,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 28, child: Center(child: simbolo)),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: MovimientoPrevia.rapido,
                // Desde el estilo del tema y no uno suelto: este widget
                // sustituye el estilo heredado entero, cara incluida.
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  fontSize: 10.5,
                  fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                  letterSpacing: 0.1,
                ),
                child: Text(etiqueta, maxLines: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El boton del centro: la pregunta misma escrita en el disco amarillo.
///
/// Un icono de copa diria "bares"; la pregunta dice que hacer. Es el unico
/// sitio de la barra con el amarillo de marca, asi que el ojo va ahi primero.
class _BotonVas extends StatelessWidget {
  const _BotonVas({required this.activo, required this.onTap});

  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Semantics(
      button: true,
      selected: activo,
      label: '¿Vas? Quién sale esta noche',
      excludeSemantics: true,
      child: Pulsable(
        onTap: onTap,
        vibrar: false,
        escala: 0.9,
        child: Center(
          child: AnimatedScale(
            scale: activo ? 1.06 : 1,
            duration: MovimientoPrevia.normal,
            curve: MovimientoPrevia.curva,
            child: AnimatedContainer(
              duration: MovimientoPrevia.normal,
              curve: MovimientoPrevia.curva,
              width: 58,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primario,
                borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
                border: Border.all(
                  color: activo ? c.texto : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: c.primario.withValues(alpha: activo ? 0.45 : 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                '¿VAS?',
                style: TextStyle(
                  fontFamily: LetraPrevia.titular,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: -0.4,
                  color: c.sobrePrimario,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
