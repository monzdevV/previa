import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/tema.dart';
import '../../data/repositories/repositorio_social.dart';

final _misNochesProvider = FutureProvider<Map<DateTime, List<String>>>(
  (ref) => ref.watch(repositorioSocialProvider).misNoches(),
);

/// Las noches que has salido.
///
/// Es el registro que nadie lleva y todo el mundo intenta reconstruir al dia
/// siguiente. Se dibuja como calendario y no como lista porque lo que se
/// quiere ver de un golpe es el ritmo: cuantos findes seguidos, que meses.
class PantallaMisNoches extends ConsumerWidget {
  const PantallaMisNoches({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noches = ref.watch(_misNochesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis noches')),
      body: noches.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ColoresPrevia.primario),
        ),
        error: (e, _) => const _Mensaje(texto: 'No se ha podido cargar.'),
        data: (mapa) {
          if (mapa.isEmpty) {
            return const _Mensaje(
              texto: 'Todavía no has salido con Previa.\n'
                  'Di que vas a algún sitio y empezará a contar.',
            );
          }

          // Se agrupan por mes de mas reciente a mas antiguo.
          final meses = <DateTime, List<DateTime>>{};
          for (final dia in mapa.keys) {
            meses.putIfAbsent(DateTime(dia.year, dia.month), () => []).add(dia);
          }
          final ordenados = meses.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView(
            padding: const EdgeInsets.all(EspaciadoPrevia.m),
            children: [
              _Resumen(total: mapa.length),
              const SizedBox(height: EspaciadoPrevia.l),
              for (final mes in ordenados) ...[
                _Mes(mes: mes, noches: mapa),
                const SizedBox(height: EspaciadoPrevia.l),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(EspaciadoPrevia.l),
    decoration: BoxDecoration(
      gradient: ColoresPrevia.degradado,
      borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$total',
          style: const TextStyle(
            color: ColoresPrevia.sobrePrimario,
            fontSize: 48,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.xs),
        Text(
          total == 1 ? 'noche registrada' : 'noches registradas',
          style: const TextStyle(
            color: ColoresPrevia.sobrePrimario,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _Mes extends StatelessWidget {
  const _Mes({required this.mes, required this.noches});

  final DateTime mes;
  final Map<DateTime, List<String>> noches;

  @override
  Widget build(BuildContext context) {
    final diasDelMes = DateUtils.getDaysInMonth(mes.year, mes.month);

    // En España la semana empieza en lunes, y DateTime da 1 para lunes.
    final primerDia = DateTime(mes.year, mes.month, 1).weekday;
    final huecos = primerDia - 1;

    final nombre = DateFormat('MMMM yyyy', 'es_ES').format(mes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${nombre[0].toUpperCase()}${nombre.substring(1)}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: EspaciadoPrevia.s + EspaciadoPrevia.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: EspaciadoPrevia.xs + 2,
            crossAxisSpacing: EspaciadoPrevia.xs + 2,
          ),
          itemCount: huecos + diasDelMes,
          itemBuilder: (_, i) {
            if (i < huecos) return const SizedBox.shrink();

            final numero = i - huecos + 1;
            final dia = DateTime(mes.year, mes.month, numero);
            final sitios = noches[dia];

            return _Dia(numero: numero, sitios: sitios);
          },
        ),
      ],
    );
  }
}

class _Dia extends StatelessWidget {
  const _Dia({required this.numero, required this.sitios});

  final int numero;
  final List<String>? sitios;

  @override
  Widget build(BuildContext context) {
    final salio = sitios != null && sitios!.isNotEmpty;

    final celda = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: salio ? ColoresPrevia.primario : ColoresPrevia.superficie,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.s + EspaciadoPrevia.xs),
      ),
      child: Text(
        '$numero',
        style: TextStyle(
          color: salio ? ColoresPrevia.sobrePrimario : ColoresPrevia.textoTenue,
          fontWeight: salio ? FontWeight.w800 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );

    if (!salio) return celda;

    return Tooltip(
      message: sitios!.join(', '),
      child: celda,
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
