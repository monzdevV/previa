import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema.dart';
import '../../core/entorno.dart';
import 'proveedores_mapa.dart';

/// Atajos para lo que mas se pide: "que hay ya" y "que hay aqui al lado".
///
/// Viven arriba de la hoja de filtros y no sobre el mapa: el mapa tiene una
/// sola pastilla y un carrusel, y no se vuelve a llenar de botones. Un toque
/// los pone y otro los quita, volviendo al valor por defecto.
///
/// Son `FilterChip` de Material para heredar `selected` en la semantica, el
/// foco de teclado y el area tactil de 48 dp.
class FiltrosRapidos extends ConsumerWidget {
  const FiltrosRapidos({super.key});

  /// "Ahora": previas que empiezan en las proximas 2 horas.
  static const horasAhora = 2;

  /// "A pie": ~1 km, un paseo de diez minutos.
  static const radioAPie = 1000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(filtrosProvider);
    final notificador = ref.read(filtrosProvider.notifier);
    final ahora = filtros.horas == horasAhora;
    final aPie = filtros.radioMetros == radioAPie;

    return Wrap(
      spacing: EspaciadoPrevia.s,
      runSpacing: EspaciadoPrevia.s,
      children: [
        _Atajo(
          etiqueta: 'Ahora',
          detalle: 'empiezan en menos de 2 horas',
          icono: Icons.bolt_rounded,
          activo: ahora,
          onTap: () => notificador.fijarHoras(
            ahora ? Entorno.horasPorDefecto : horasAhora,
          ),
        ),
        _Atajo(
          etiqueta: 'A pie',
          detalle: 'a menos de 1 km',
          icono: Icons.directions_walk_rounded,
          activo: aPie,
          onTap: () => notificador.fijarRadio(
            aPie ? Entorno.radioBusquedaPorDefecto : radioAPie,
          ),
        ),
      ],
    );
  }
}

class _Atajo extends StatelessWidget {
  const _Atajo({
    required this.etiqueta,
    required this.detalle,
    required this.icono,
    required this.activo,
    required this.onTap,
  });

  final String etiqueta;

  /// Lo que significa el atajo, para el lector de pantalla.
  final String detalle;
  final IconData icono;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Semantics(
      hint: 'Previas que $detalle',
      child: FilterChip(
        label: Text(etiqueta),
        avatar: Icon(
          icono,
          size: 18,
          color: activo ? c.sobrePrimario : c.primarioTexto,
        ),
        selected: activo,
        onSelected: (_) => onTap(),
        // Sin marca: el relleno amarillo ya dice "activo", y la marca
        // ensancharia el chip al cambiar, empujando al de al lado.
        showCheckmark: false,
        selectedColor: c.primario,
      ),
    );
  }
}
