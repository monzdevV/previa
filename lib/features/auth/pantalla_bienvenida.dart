import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../party/estados_pantalla.dart' show mensajeResponsable;
import 'aparece.dart';
import 'piezas_acceso.dart';

/// La entrada: un cartel amarillo a sangre.
///
/// Es la unica pantalla donde el amarillo es el fondo entero. Aqui aun no hay
/// contenido de nadie que pueda perder protagonismo, y el primer golpe de
/// vista tiene que decir "esto es la noche", no "esto es un formulario".
///
/// Un titular, una frase y un boton. Todo lo que se explicaba aqui antes se
/// entiende mejor dentro de la app que leido en la puerta.
class PantallaBienvenida extends StatelessWidget {
  const PantallaBienvenida({super.key});

  static const _amarillo = BloquesPrevia.amarillo;
  static const _tinta = BloquesPrevia.tintaSobreBloque;

  @override
  Widget build(BuildContext context) {
    final reducido = MovimientoPrevia.reducido(context);

    Widget entrar(Widget hijo, int orden) => Aparece(orden: orden, child: hijo);

    // Las pegatinas caen despues del titular y con un pequeño rebote: es lo
    // unico de la pantalla que se permite jugar.
    Widget pegar(Widget hijo, int orden) => reducido
        ? hijo
        : hijo
              .animate(delay: MovimientoPrevia.escalon * (orden * 2))
              .fadeIn(duration: MovimientoPrevia.rapido)
              .scaleXY(
                begin: 0.7,
                end: 1,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
              );

    // Con letra normal todo cabe en una pantalla y el titular encoge para
    // repartirse el hueco. Con la letra del sistema muy grande eso ya no
    // basta: el titular se queda a su tamaño y la pantalla se desplaza.
    final letraGrande = MediaQuery.textScalerOf(context).scale(10) > 13;
    Widget hueco(Widget hijo) => letraGrande
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: EspaciadoPrevia.l),
            child: hijo,
          )
        : Expanded(child: hijo);
    Widget desplazable(Widget hijo) =>
        letraGrande ? SingleChildScrollView(child: hijo) : hijo;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Iconos de la barra de estado en negro sobre el amarillo.
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _amarillo,
        body: SafeArea(
          child: desplazable(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    EspaciadoPrevia.l,
                    EspaciadoPrevia.m,
                    EspaciadoPrevia.l,
                    0,
                  ),
                  child: Titular('Previa', tamano: 26, color: _tinta),
                ),

                hueco(
                  Padding(
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
                              Semantics(
                                header: true,
                                child: const Titular(
                                  'La noche\nempieza\nantes',
                                  tamano: 80,
                                  color: _tinta,
                                ),
                              ),
                              1,
                            ),
                          ),
                        ),
                        Positioned(
                          top: EspaciadoPrevia.l,
                          right: 0,
                          child: pegar(
                            const Pegatina('🌙', tamano: 64, giro: 0.3),
                            3,
                          ),
                        ),
                        Positioned(
                          bottom: EspaciadoPrevia.l,
                          right: EspaciadoPrevia.m,
                          child: pegar(
                            const Pegatina('🥚', tamano: 56, giro: -0.25),
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
                      entrar(
                        Text(
                          'Previas con sitio y gente con la que salir, '
                          'esta misma noche.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: _tinta,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                        ),
                        2,
                      ),
                      const SizedBox(height: EspaciadoPrevia.l),
                      BotonAcceso(
                        texto: 'Empezar',
                        fondo: _tinta,
                        tinta: _amarillo,
                        onPressed: () => context.push(Rutas.registro),
                      ),
                      const SizedBox(height: EspaciadoPrevia.xs),
                      TextButton(
                        onPressed: () => context.push(Rutas.entrar),
                        style: TextButton.styleFrom(
                          foregroundColor: _tinta,
                          minimumSize: const Size.fromHeight(48),
                          textStyle: Theme.of(context).textTheme.labelLarge,
                        ),
                        child: const Text('Ya tengo cuenta'),
                      ),
                      const SizedBox(height: EspaciadoPrevia.xs),
                      // Mismo aviso que el registro y el mapa. La tinta entera
                      // y no rebajada: sobre el amarillo, el negro al 65 % se
                      // quedaba corto de contraste para un texto tan pequeño.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const ExcludeSemantics(
                            child: Icon(
                              Icons.verified_user_outlined,
                              size: 14,
                              color: _tinta,
                            ),
                          ),
                          const SizedBox(width: EspaciadoPrevia.xs),
                          Flexible(
                            child: Text(
                              mensajeResponsable,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _tinta,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: EspaciadoPrevia.m),
                    ],
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
