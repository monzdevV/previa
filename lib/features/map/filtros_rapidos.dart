import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema.dart';
import '../../core/ambientes.dart';
import '../../core/entorno.dart';
import 'proveedores_mapa.dart';

/// Fila de chips de filtro rapido sobre el mapa: "Ahora", "Cerca" y los
/// ambientes mas habituales.
///
/// Por que existen ademas de la hoja de filtros: el caso de uso mas comun
/// ("que hay ya, aqui al lado") debe ser un toque, sin abrir nada. Son
/// FilterChip de Material (no chips a mano) para heredar `selected` en la
/// semantica, foco de teclado y el area tactil de 48 dp del tema.
class FiltrosRapidos extends ConsumerWidget {
  const FiltrosRapidos({super.key});

  /// "Ahora": previas que empiezan en las proximas 2 horas.
  static const horasAhora = 2;

  /// "Cerca": a pie, ~1 km.
  static const radioCerca = 1000;

  /// Cuantos ambientes caben como atajo; el resto, en la hoja de filtros.
  static const _ambientesRapidos = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(filtrosProvider);
    final notificador = ref.read(filtrosProvider.notifier);

    final ahora = filtros.horas == horasAhora;
    final cerca = filtros.radioMetros == radioCerca;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: EspaciadoPrevia.m),
      child: Row(
        children: [
          _Atajo(
            etiqueta: 'Ahora',
            icono: Icons.bolt,
            activo: ahora,
            onTap: () => notificador.fijarHoras(
              ahora ? Entorno.horasPorDefecto : horasAhora,
            ),
          ),
          const SizedBox(width: EspaciadoPrevia.s),
          _Atajo(
            etiqueta: 'Cerca',
            icono: Icons.directions_walk,
            activo: cerca,
            onTap: () => notificador.fijarRadio(
              cerca ? Entorno.radioBusquedaPorDefecto : radioCerca,
            ),
          ),
          for (final etiqueta in ambientesDisponibles.take(
            _ambientesRapidos,
          )) ...[
            const SizedBox(width: EspaciadoPrevia.s),
            _Atajo(
              etiqueta: etiqueta,
              activo: filtros.ambiente.contains(etiqueta),
              onTap: () => notificador.alternarAmbiente(etiqueta),
            ),
          ],
        ],
      ),
    );
  }
}

class _Atajo extends StatelessWidget {
  const _Atajo({
    required this.etiqueta,
    required this.activo,
    required this.onTap,
    this.icono,
  });

  final String etiqueta;
  final IconData? icono;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(etiqueta),
      avatar: icono == null
          ? null
          : Icon(
              icono,
              size: 16,
              color: activo ? Colors.white : ColoresPrevia.textoSuave,
            ),
      selected: activo,
      onSelected: (_) => onTap(),
      // Sin marca de verificacion: el relleno de color ya indica "activo" y
      // la marca ensancharia el chip al cambiar, moviendo los vecinos.
      showCheckmark: false,
      // Fondo opaco: flota sobre el mapa y debe leerse sobre cualquier tesela.
      backgroundColor: ColoresPrevia.superficie,
      elevation: 2,
      shadowColor: Colors.black,
      pressElevation: 0,
    );
  }
}
