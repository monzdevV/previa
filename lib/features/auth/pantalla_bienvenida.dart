import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';

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
          child: Padding(
            padding: const EdgeInsets.all(EspaciadoPrevia.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),

                const _Logotipo(),
                const SizedBox(height: EspaciadoPrevia.l),

                Text('La noche empieza antes', style: textos.displaySmall),
                const SizedBox(height: EspaciadoPrevia.s),
                Text(
                  'Encuentra previas cerca de ti, o abre la tuya y conoce '
                  'gente nueva antes de salir.',
                  style: textos.bodyLarge?.copyWith(
                    color: ColoresPrevia.textoSuave,
                  ),
                ),

                const Spacer(flex: 3),

                FilledButton(
                  onPressed: () => context.push(Rutas.registro),
                  child: const Text('Crear cuenta'),
                ),
                const SizedBox(height: EspaciadoPrevia.s),
                OutlinedButton(
                  onPressed: () => context.push(Rutas.entrar),
                  child: const Text('Ya tengo cuenta'),
                ),

                const SizedBox(height: EspaciadoPrevia.l),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 15,
                      color: ColoresPrevia.textoTenue,
                    ),
                    const SizedBox(width: EspaciadoPrevia.xs),
                    Text(
                      'Solo para mayores de 18 años',
                      style: textos.bodyMedium?.copyWith(
                        color: ColoresPrevia.textoTenue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: EspaciadoPrevia.s),
              ],
            ),
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
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [ColoresPrevia.primario, ColoresPrevia.acento],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 30),
        ),
        const SizedBox(width: EspaciadoPrevia.m),
        Text(
          'Previa',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}
