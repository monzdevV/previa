import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema.dart';
import '../../data/models/oferta.dart';
import '../../data/repositories/repositorio_auth.dart' show ErrorPrevia;
import '../../data/repositories/repositorio_ofertas.dart';

/// Panel minimo del local: lanzar una oferta en vivo y ver como va.
///
/// Solo hay plantillas, sin texto libre: cada una esta revisada contra las
/// restricciones legales del proyecto (nada de barra libre, 2x1 ni "bebe
/// mas"; solo entradas, servicios, comida, zonas, fotos, guardarropa y
/// experiencias), asi que un descuido a media noche no acaba en una promocion
/// de alcohol. La oferta es solo para mayores de 18.
class PantallaLanzarOferta extends ConsumerStatefulWidget {
  const PantallaLanzarOferta({
    super.key,
    required this.localId,
    required this.nombreLocal,
    this.ahora = DateTime.now,
  });

  final String localId;
  final String nombreLocal;
  final DateTime Function() ahora;

  @override
  ConsumerState<PantallaLanzarOferta> createState() =>
      _PantallaLanzarOfertaState();
}

class _PantallaLanzarOfertaState extends ConsumerState<PantallaLanzarOferta> {
  PlantillaOferta _plantilla = PlantillaOferta.todas.first;
  Duration _duracion = duracionesDeOferta[1];
  late int _cupos = _plantilla.cuposSugeridos;
  bool _enCurso = false;

  void _elegir(PlantillaOferta p) => setState(() {
    _plantilla = p;
    _cupos = p.cuposSugeridos;
  });

  void _cambiarCupos(int delta) => setState(
    () => _cupos = (_cupos + delta).clamp(cuposMinimos, cuposMaximos),
  );

  Future<void> _lanzar() async {
    if (_enCurso) return;
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _enCurso = true);
    try {
      await ref
          .read(repositorioOfertasProvider)
          .lanzar(
            localId: widget.localId,
            plantilla: _plantilla,
            duracion: _duracion,
            cupos: _cupos,
          );
      // Si la pantalla se cerró durante el envío, el ref ya no es válido y
      // la oferta sí está creada: no se debe mostrar un error ni dejar que
      // un reintento la duplique.
      if (mounted) {
        ref.invalidate(ofertasDelLocalProvider(widget.localId));
        ref.invalidate(ofertasActivasProvider(widget.localId));
      }
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('Oferta lanzada. Ya la ve quien está dentro.'),
        ),
      );
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            e is ErrorPrevia ? e.mensaje : 'No se ha podido lanzar la oferta.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _enCurso = false);
    }
  }

  Future<void> _cancelar(Oferta o) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(repositorioOfertasProvider).cancelar(o.id);
      ref.invalidate(ofertasDelLocalProvider(widget.localId));
      ref.invalidate(ofertasActivasProvider(widget.localId));
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            e is ErrorPrevia ? e.mensaje : 'No se ha podido cancelar.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final propias = ref.watch(ofertasDelLocalProvider(widget.localId));
    final ahora = widget.ahora();
    final c = context.colores;

    return Scaffold(
      appBar: AppBar(title: const Text('Lanzar oferta')),
      body: ListView(
        padding: const EdgeInsets.all(EspaciadoPrevia.m),
        children: [
          Titular(widget.nombreLocal, tamano: 28, lineas: 2),
          const SizedBox(height: EspaciadoPrevia.s),
          Text(
            'Una oferta de tiempo limitado para quien está dentro ahora. '
            'Solo mayores de 18.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: EspaciadoPrevia.l),
          Text('¿Qué ofreces?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: EspaciadoPrevia.s),
          RadioGroup<PlantillaOferta>(
            groupValue: _plantilla,
            onChanged: (p) {
              if (p != null) _elegir(p);
            },
            child: Column(
              children: [
                for (final p in PlantillaOferta.todas)
                  Card(
                    margin: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
                    child: RadioListTile<PlantillaOferta>(
                      value: p,
                      minVerticalPadding: EspaciadoPrevia.s,
                      title: Text('${p.categoria.pegatina}  ${p.titulo}'),
                      subtitle: Text(p.detalle),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: EspaciadoPrevia.m),
          Text('Duración', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: EspaciadoPrevia.s),
          Wrap(
            spacing: EspaciadoPrevia.s,
            runSpacing: EspaciadoPrevia.s,
            children: [
              for (final d in duracionesDeOferta)
                ChoiceChip(
                  label: Text('${d.inMinutes} min'),
                  selected: d == _duracion,
                  onSelected: (_) => setState(() => _duracion = d),
                ),
            ],
          ),
          const SizedBox(height: EspaciadoPrevia.m),
          Text('Cupos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: EspaciadoPrevia.xs),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Menos cupos',
                onPressed: _cupos > cuposMinimos
                    ? () => _cambiarCupos(-10)
                    : null,
                icon: const Icon(Icons.remove_rounded),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  label: '$_cupos cupos',
                  excludeSemantics: true,
                  child: Text(
                    '$_cupos',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Más cupos',
                onPressed: _cupos < cuposMaximos
                    ? () => _cambiarCupos(10)
                    : null,
                icon: const Icon(Icons.add_rounded),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
          const SizedBox(height: EspaciadoPrevia.l),
          FilledButton(
            onPressed: _enCurso ? null : _lanzar,
            style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
            child: const Text('LANZAR AHORA'),
          ),
          const SizedBox(height: EspaciadoPrevia.xl),
          Text(
            'Tus ofertas de esta noche',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          propias.when(
            loading: () => const Cargando(),
            error: (_, _) => const Text('No se han podido cargar tus ofertas.'),
            data: (lista) {
              if (lista.isEmpty) {
                return Text(
                  'Aún no has lanzado ninguna.',
                  style: TextStyle(color: c.textoTenue),
                );
              }
              return Column(
                children: [
                  for (final o in lista)
                    _FilaPropia(
                      oferta: o,
                      activa: o.activa(ahora),
                      onCancelar: () => _cancelar(o),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilaPropia extends StatelessWidget {
  const _FilaPropia({
    required this.oferta,
    required this.activa,
    required this.onCancelar,
  });

  final Oferta oferta;
  final bool activa;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final estado = oferta.cancelada
        ? 'Cancelada'
        : activa
        ? 'Activa'
        : 'Terminada';
    return Card(
      margin: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
      child: Padding(
        padding: const EdgeInsets.all(EspaciadoPrevia.m),
        child: Semantics(
          container: true,
          label:
              '${oferta.titulo}. $estado. ${oferta.canjes} canjes de '
              '${oferta.cupos}.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Text(
                  oferta.titulo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ExcludeSemantics(
                child: Text(
                  '$estado · ${oferta.canjes} / ${oferta.cupos} canjes',
                ),
              ),
              if (activa)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: onCancelar,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
