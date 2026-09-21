import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/tema.dart';
import '../../data/models/publicacion.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_social.dart';

final reportesProvider = FutureProvider<List<Reporte>>(
  (ref) => ref.watch(repositorioSocialProvider).reportesPendientes(),
);

final soyModeradorProvider = FutureProvider<bool>((ref) async {
  final perfil = await ref.watch(miPerfilProvider.future);
  return perfil?.esModerador ?? false;
});

/// La bandeja de moderacion.
///
/// Hasta ahora se podia denunciar contenido y el aviso se quedaba en la tabla
/// para siempre. Una aplicacion con contenido subido por gente necesita que
/// alguien mire, aunque ese alguien seas tu.
class PantallaModeracion extends ConsumerWidget {
  const PantallaModeracion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportes = ref.watch(reportesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Moderación')),
      body: reportes.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ColoresPrevia.primario),
        ),
        error: (e, _) => const _Mensaje(
          texto: 'No se ha podido cargar. ¿Tienes permiso de moderación?',
        ),
        data: (lista) => lista.isEmpty
            ? const _Mensaje(texto: 'No hay nada reportado. Buena señal.')
            : RefreshIndicator(
                color: ColoresPrevia.primario,
                backgroundColor: ColoresPrevia.superficie,
                onRefresh: () async => ref.refresh(reportesProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(EspaciadoPrevia.m),
                  itemCount: lista.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: EspaciadoPrevia.m),
                  itemBuilder: (_, i) => _FichaReporte(reporte: lista[i]),
                ),
              ),
      ),
    );
  }
}

class _FichaReporte extends ConsumerStatefulWidget {
  const _FichaReporte({required this.reporte});

  final Reporte reporte;

  @override
  ConsumerState<_FichaReporte> createState() => _FichaReporteState();
}

class _FichaReporteState extends ConsumerState<_FichaReporte> {
  bool _ocupado = false;

  Future<void> _hacer(Future<void> Function() accion) async {
    setState(() => _ocupado = true);
    try {
      await accion();
      ref.invalidate(reportesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido completar.')),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reporte;
    final textos = Theme.of(context).textTheme;
    final repo = ref.read(repositorioSocialProvider);
    final abierto = r.estado == 'abierto';

    return Container(
      decoration: BoxDecoration(
        color: ColoresPrevia.superficie,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        border: Border.all(
          color: abierto ? ColoresPrevia.error : ColoresPrevia.borde,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.postUrl != null)
            AspectRatio(
              aspectRatio: 16 / 10,
              child: CachedNetworkImage(
                imageUrl: r.postUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    const ColoredBox(color: ColoresPrevia.superficieAlta),
                errorWidget: (_, _, _) =>
                    const ColoredBox(color: ColoresPrevia.superficieAlta),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(EspaciadoPrevia.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: EspaciadoPrevia.s,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: abierto
                            ? ColoresPrevia.error
                            : ColoresPrevia.superficieActiva,
                        borderRadius: BorderRadius.circular(
                          EspaciadoPrevia.pastilla,
                        ),
                      ),
                      child: Text(
                        r.motivo.replaceAll('_', ' '),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: abierto
                              ? Colors.white
                              : ColoresPrevia.textoSuave,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('d MMM · HH:mm', 'es_ES').format(r.creadoEn),
                      style: textos.labelMedium,
                    ),
                  ],
                ),

                const SizedBox(height: EspaciadoPrevia.s),
                Text(
                  '${r.denunciante ?? 'Alguien'} ha reportado a '
                  '${r.denunciado ?? 'alguien'}',
                  style: textos.titleMedium,
                ),

                if (r.detalles != null && r.detalles!.isNotEmpty) ...[
                  const SizedBox(height: EspaciadoPrevia.xs),
                  Text(r.detalles!, style: textos.bodyMedium),
                ],
                if (r.postTexto != null && r.postTexto!.isNotEmpty) ...[
                  const SizedBox(height: EspaciadoPrevia.xs),
                  Text('«${r.postTexto}»', style: textos.bodyMedium),
                ],
                if (r.partyTitulo != null) ...[
                  const SizedBox(height: EspaciadoPrevia.xs),
                  Text('Previa: ${r.partyTitulo}', style: textos.bodyMedium),
                ],

                if (abierto) ...[
                  const SizedBox(height: EspaciadoPrevia.m),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _ocupado
                              ? null
                              : () => _hacer(
                                  () => repo.resolverReporte(
                                    r.id,
                                    estado: 'revisado',
                                  ),
                                ),
                          child: const Text('Está bien'),
                        ),
                      ),
                      if (r.postId != null) ...[
                        const SizedBox(width: EspaciadoPrevia.s),
                        Expanded(
                          child: FilledButton(
                            onPressed: _ocupado
                                ? null
                                : () => _hacer(
                                    () => repo.retirarPublicacion(r.id),
                                  ),
                            style: FilledButton.styleFrom(
                              backgroundColor: ColoresPrevia.error,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retirar'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: EspaciadoPrevia.s),
                    child: Text(
                      r.estado == 'cerrado'
                          ? 'Contenido retirado'
                          : 'Revisado, sin acción',
                      style: textos.labelMedium,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(EspaciadoPrevia.xl),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}
