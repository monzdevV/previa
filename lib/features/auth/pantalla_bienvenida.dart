import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../onboarding/ilustraciones.dart';
import '../party/estados_pantalla.dart';
import 'aparece.dart';

class PantallaBienvenida extends StatelessWidget {
  const PantallaBienvenida({super.key});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1030), ColoresPrevia.fondo],
          ),
        ),
        child: SafeArea(
          // Con scroll y altura mínima: con el tamaño de letra del sistema muy
          // grande el contenido no cabe y antes se cortaba. Con letra normal
          // se comporta igual que antes (los Spacer reparten el hueco).
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(EspaciadoPrevia.l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Aparece(child: _Logotipo()),
                      const Spacer(),

                      // Composición gráfica: da personalidad a la primera
                      // pantalla y cuenta "gente cerca" sin leer nada.
                      const Aparece(
                        orden: 1,
                        child: Ilustracion(
                          tipo: TipoIlustracion.previa,
                          descripcion:
                              'Una chincheta de mapa rodeada de personas',
                          altura: 210,
                        ),
                      ),

                      const Spacer(),

                      Aparece(
                        orden: 2,
                        child: Semantics(
                          header: true,
                          child: Text(
                            'La noche empieza antes',
                            style: textos.displaySmall,
                          ),
                        ),
                      ),
                      const SizedBox(height: EspaciadoPrevia.s),
                      Aparece(
                        orden: 3,
                        child: Text(
                          'Encuentra previas cerca de ti, o abre la tuya y '
                          'conoce gente nueva antes de salir.',
                          style: textos.bodyLarge?.copyWith(
                            color: ColoresPrevia.textoSuave,
                          ),
                        ),
                      ),

                      const SizedBox(height: EspaciadoPrevia.xl),

                      // Una acción primaria clara; la secundaria, con menos peso.
                      Aparece(
                        orden: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton(
                              onPressed: () => context.push(Rutas.registro),
                              child: const Text('Crear cuenta'),
                            ),
                            const SizedBox(height: EspaciadoPrevia.s),
                            OutlinedButton(
                              onPressed: () => context.push(Rutas.entrar),
                              child: const Text('Ya tengo cuenta'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: EspaciadoPrevia.l),
                      Aparece(
                        orden: 5,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const ExcludeSemantics(
                              child: Icon(
                                Icons.verified_user_outlined,
                                size: 15,
                                color: ColoresPrevia.textoTenue,
                              ),
                            ),
                            const SizedBox(width: EspaciadoPrevia.xs),
                            Flexible(
                              child: Text(
                                mensajeResponsable,
                                style: textos.bodyMedium?.copyWith(
                                  color: ColoresPrevia.textoTenue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: EspaciadoPrevia.s),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logotipo extends StatelessWidget {
  const _Logotipo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [ColoresPrevia.primario, ColoresPrevia.acento],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(EspaciadoPrevia.radio * 0.75),
          ),
          child: const ExcludeSemantics(
            child: Icon(Icons.location_on, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(width: EspaciadoPrevia.m - 4),
        Flexible(
          child: Text(
            'Previa',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontSize: 26, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
