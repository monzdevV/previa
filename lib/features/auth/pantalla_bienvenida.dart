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
      backgroundColor: ColoresPrevia.fondo,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            EspaciadoPrevia.l,
            EspaciadoPrevia.l,
            EspaciadoPrevia.l,
            EspaciadoPrevia.l,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              const _Marca(),
              const SizedBox(height: EspaciadoPrevia.xl),

              Text(
                'La noche\nempieza antes.',
                style: textos.displaySmall?.copyWith(fontSize: 40),
              ),
              const SizedBox(height: EspaciadoPrevia.m),
              Text(
                'Encuentra previas con sitio cerca de ti, '
                'pide plaza para tu grupo y conoce gente antes de salir.',
                style: textos.bodyLarge?.copyWith(
                  color: ColoresPrevia.textoSuave,
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 3),

              _BotonDeMarca(
                texto: 'Crear cuenta',
                onPressed: () => context.push(Rutas.registro),
              ),
              const SizedBox(height: EspaciadoPrevia.s + EspaciadoPrevia.xs),
              OutlinedButton(
                onPressed: () => context.push(Rutas.entrar),
                child: const Text('Ya tengo cuenta'),
              ),

              const SizedBox(height: EspaciadoPrevia.l),
              Text(
                'Solo para mayores de 18 · Tu ubicación exacta nunca es pública',
                textAlign: TextAlign.center,
                style: textos.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: ColoresPrevia.textoTenue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: ColoresPrevia.degradado,
            borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
          ),
          child: const Icon(
            Icons.local_fire_department_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: EspaciadoPrevia.s + EspaciadoPrevia.xs),
        Text(
          'Previa',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Accion principal con el degradado de marca.
///
/// Es el unico sitio donde el degradado cubre un boton entero: en las
/// referencias tambien esta reservado a la accion que abre la aplicacion.
class _BotonDeMarca extends StatelessWidget {
  const _BotonDeMarca({required this.texto, required this.onPressed});

  final String texto;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: ColoresPrevia.degradado,
      borderRadius: BorderRadius.circular(EspaciadoPrevia.radio - 4),
    ),
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      child: Text(texto),
    ),
  );
}
