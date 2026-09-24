import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';

/// La entrada: un cartel amarillo a sangre.
///
/// Es la unica pantalla donde el amarillo es el fondo entero. Aqui aun no hay
/// contenido de nadie que pueda perder protagonismo, y el primer golpe de
/// vista tiene que decir "esto es la noche", no "esto es un formulario".
class PantallaBienvenida extends StatelessWidget {
  const PantallaBienvenida({super.key});

  static const _amarillo = BloquesPrevia.amarillo;
  static const _tinta = BloquesPrevia.tintaSobreBloque;

  @override
  Widget build(BuildContext context) {
    final reducido = MovimientoPrevia.reducido(context);

    Widget entrar(Widget hijo, int orden) => reducido
        ? hijo
        : hijo
              .animate(delay: MovimientoPrevia.escalon * (orden * 2))
              .fadeIn(duration: MovimientoPrevia.normal)
              .moveY(begin: 24, end: 0, curve: MovimientoPrevia.curva);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Iconos de la barra de estado en negro sobre el amarillo.
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _amarillo,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  EspaciadoPrevia.l,
                  EspaciadoPrevia.m,
                  EspaciadoPrevia.l,
                  0,
                ),
                child: Row(
                  children: [
                    Titular('Previa', tamano: 26, color: _tinta),
                    Spacer(),
                    Titular('¿Salimos?', tamano: 16, color: _tinta),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: EspaciadoPrevia.l,
                  ),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: entrar(
                            const Titular(
                              'La noche\nempieza\nantes',
                              tamano: 76,
                              color: _tinta,
                            ),
                            1,
                          ),
                        ),
                      ),
                      Positioned(
                        top: EspaciadoPrevia.xl,
                        right: 0,
                        child: entrar(
                          const Pegatina('🌙', tamano: 64, giro: 0.3),
                          2,
                        ),
                      ),
                      Positioned(
                        bottom: EspaciadoPrevia.xl,
                        right: EspaciadoPrevia.l,
                        child: entrar(
                          const Pegatina('🥚', tamano: 56, giro: -0.25),
                          3,
                        ),
                      ),
                      Positioned(
                        bottom: EspaciadoPrevia.s,
                        left: 0,
                        child: entrar(
                          const Pegatina('✨', tamano: 40, giro: 0.1),
                          4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Marquesina(
                texto: 'Previas cerca · Quién va esta noche · No hay huevos',
                fondo: _tinta,
                tinta: _amarillo,
                inclinacion: -0.03,
              ),
              const SizedBox(height: EspaciadoPrevia.l),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: EspaciadoPrevia.l,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Encuentra previas con sitio cerca, di a qué local vas '
                      'y conoce gente antes de salir.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: _tinta,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: EspaciadoPrevia.l),
                    FilledButton(
                      onPressed: () => context.push(Rutas.registro),
                      style: FilledButton.styleFrom(
                        backgroundColor: _tinta,
                        foregroundColor: _amarillo,
                      ),
                      child: const Text('CREAR CUENTA'),
                    ),
                    const SizedBox(
                      height: EspaciadoPrevia.s + EspaciadoPrevia.xs,
                    ),
                    OutlinedButton(
                      onPressed: () => context.push(Rutas.entrar),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _tinta,
                        side: const BorderSide(color: _tinta, width: 2),
                      ),
                      child: const Text('YA TENGO CUENTA'),
                    ),
                    const SizedBox(height: EspaciadoPrevia.m),
                    Text(
                      'Solo para mayores de 18 · Tu ubicación exacta nunca es pública',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: _tinta.withValues(alpha: .7),
                      ),
                    ),
                    const SizedBox(height: EspaciadoPrevia.m),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
