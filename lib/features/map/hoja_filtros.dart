import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema.dart';
import 'proveedores_mapa.dart';

Future<void> mostrarHojaFiltros(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: ColoresPrevia.fondo,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(EspaciadoPrevia.radioGrande),
      ),
    ),
    builder: (_) => const _HojaFiltros(),
  );
}

class _HojaFiltros extends ConsumerWidget {
  const _HojaFiltros();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(filtrosProvider);
    final notificador = ref.read(filtrosProvider.notifier);
    final textos = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(EspaciadoPrevia.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Filtros', style: textos.headlineMedium),
                const Spacer(),
                if (!filtros.sonLosPorDefecto)
                  TextButton(
                    onPressed: notificador.restablecer,
                    child: const Text('Restablecer'),
                  ),
              ],
            ),
            const SizedBox(height: EspaciadoPrevia.l),

            _Etiqueta('Distancia', filtros.radioLegible),
            Slider(
              value: filtros.radioMetros.toDouble(),
              min: 500,
              max: 20000,
              divisions: 39,
              activeColor: ColoresPrevia.primario,
              onChanged: (v) => notificador.fijarRadio(v.round()),
            ),

            const SizedBox(height: EspaciadoPrevia.m),
            _Etiqueta(
              'Empieza en las próximas',
              filtros.horas == 1 ? '1 hora' : '${filtros.horas} horas',
            ),
            Slider(
              value: filtros.horas.toDouble(),
              min: 1,
              max: 24,
              divisions: 23,
              activeColor: ColoresPrevia.primario,
              onChanged: (v) => notificador.fijarHoras(v.round()),
            ),

            const SizedBox(height: EspaciadoPrevia.m),
            Text('Somos', style: textos.titleLarge),
            const SizedBox(height: EspaciadoPrevia.s),
            Text(
              'Solo verás previas con sitio para todo el grupo.',
              style: textos.bodyMedium,
            ),
            const SizedBox(height: EspaciadoPrevia.m),
            Wrap(
              spacing: EspaciadoPrevia.s,
              children: [
                for (final n in [1, 2, 3, 4, 5, 6])
                  ChoiceChip(
                    label: Text('$n'),
                    selected: filtros.plazasMinimas == n,
                    selectedColor: ColoresPrevia.primario,
                    onSelected: (_) => notificador.fijarPlazas(n),
                  ),
              ],
            ),

            const SizedBox(height: EspaciadoPrevia.xl),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Ver resultados'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.titulo, this.valor);
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleLarge),
        Text(
          valor,
          style: const TextStyle(
            color: ColoresPrevia.primarioSuave,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
