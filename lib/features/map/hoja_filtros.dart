import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema.dart';
import '../../core/ambientes.dart';
import 'filtros_rapidos.dart';
import 'proveedores_mapa.dart';

Future<void> mostrarHojaFiltros(BuildContext context) {
  return mostrarHoja<void>(context, builder: (_) => const _HojaFiltros());
}

class _HojaFiltros extends ConsumerWidget {
  const _HojaFiltros();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(filtrosProvider);
    final notificador = ref.read(filtrosProvider.notifier);
    final textos = Theme.of(context).textTheme;

    // Con desplazamiento: en un movil de 640 de alto la hoja entera no cabe
    // y el boton de ver resultados quedaba cortado.
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          EspaciadoPrevia.l,
          0,
          EspaciadoPrevia.l,
          EspaciadoPrevia.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Semantics(
                  header: true,
                  child: const Titular('Filtros', tamano: 30),
                ),
                const Spacer(),
                if (!filtros.sonLosPorDefecto)
                  TextButton(
                    onPressed: notificador.restablecer,
                    child: const Text('Restablecer'),
                  ),
              ],
            ),
            const SizedBox(height: EspaciadoPrevia.m),
            // Lo mas pedido, a un toque, antes que los deslizadores.
            const FiltrosRapidos(),
            const SizedBox(height: EspaciadoPrevia.l),

            _Etiqueta('Distancia', filtros.radioLegible),
            Slider(
              value: filtros.radioMetros.toDouble(),
              min: Filtros.radioMinimoMetros.toDouble(),
              max: Filtros.radioMaximoMetros.toDouble(),
              divisions: 39,
              activeColor: context.colores.primario,
              semanticFormatterCallback: (v) =>
                  Filtros(radioMetros: v.round()).radioLegible,
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
              activeColor: context.colores.primario,
              semanticFormatterCallback: (v) =>
                  v.round() == 1 ? '1 hora' : '${v.round()} horas',
              onChanged: (v) => notificador.fijarHoras(v.round()),
            ),

            const SizedBox(height: EspaciadoPrevia.m),
            Semantics(
              header: true,
              child: Text('Somos', style: textos.titleLarge),
            ),
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
                    tooltip: n == 1 ? 'Solo yo' : 'Somos $n',
                    selected: filtros.plazasMinimas == n,
                    selectedColor: context.colores.primario,
                    onSelected: (_) => notificador.fijarPlazas(n),
                  ),
              ],
            ),

            const SizedBox(height: EspaciadoPrevia.l),
            Semantics(
              header: true,
              child: Text('Ambiente', style: textos.titleLarge),
            ),
            const SizedBox(height: EspaciadoPrevia.s),
            Text(
              filtros.ambiente.isEmpty
                  ? 'Sin marcar nada, te salen todas.'
                  : 'Verás previas con al menos una de estas.',
              style: textos.bodyMedium,
            ),
            const SizedBox(height: EspaciadoPrevia.m),
            Wrap(
              spacing: EspaciadoPrevia.s,
              runSpacing: EspaciadoPrevia.s,
              children: [
                for (final etiqueta in ambientesDisponibles)
                  FilterChip(
                    label: Text(etiqueta),
                    selected: filtros.ambiente.contains(etiqueta),
                    selectedColor: context.colores.primario,
                    checkmarkColor: context.colores.sobrePrimario,
                    onSelected: (_) => notificador.alternarAmbiente(etiqueta),
                  ),
              ],
            ),

            const SizedBox(height: EspaciadoPrevia.xl),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('VER RESULTADOS'),
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
        Semantics(
          header: true,
          child: Text(titulo, style: Theme.of(context).textTheme.titleLarge),
        ),
        Text(
          valor,
          style: TextStyle(
            // primarioTexto y no el amarillo: sobre la hoja clara el amarillo
            // no se lee.
            color: context.colores.primarioTexto,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
