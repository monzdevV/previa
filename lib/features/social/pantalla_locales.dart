import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/tema.dart';
import '../../data/models/local.dart';
import '../../data/models/publicacion.dart';
import '../../data/repositories/repositorio_social.dart';
import '../feed/pantalla_feed.dart' show AvatarPerfil;
import '../profile/proveedores_perfil.dart';
import 'pantalla_sala.dart';

/// Ciudad que se esta mirando. Se queda fijada mientras dure la sesion.
class CiudadDeLaNoche extends Notifier<String> {
  @override
  String build() => 'Zaragoza';

  void fijar(String ciudad) => state = ciudad.trim();
}

final ciudadDeLaNocheProvider = NotifierProvider<CiudadDeLaNoche, String>(
  CiudadDeLaNoche.new,
);

final localesProvider = FutureProvider<List<Local>>((ref) async {
  final ciudad = ref.watch(ciudadDeLaNocheProvider);
  return ref.watch(repositorioSocialProvider).localesDeLaNoche(ciudad);
});

/// A donde va la gente esta noche.
///
/// La gracia no es el listado de discotecas, que eso ya existe: es ver quien
/// va. Saber que alguien conocido estara en un sitio es lo que decide la
/// noche, y de ahi sale tambien el enlace a comprar la entrada.
class PantallaLocales extends ConsumerWidget {
  const PantallaLocales({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locales = ref.watch(localesProvider);
    final ciudad = ref.watch(ciudadDeLaNocheProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('¿A dónde vas?'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_outlined),
            tooltip: 'Añadir un sitio',
            onPressed: () => _proponerLocal(context, ref, ciudad),
          ),
          const SizedBox(width: EspaciadoPrevia.s),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(EspaciadoPrevia.m),
            child: TextFormField(
              initialValue: ciudad,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_city_rounded),
                labelText: 'Ciudad',
              ),
              onFieldSubmitted: (v) =>
                  ref.read(ciudadDeLaNocheProvider.notifier).fijar(v),
            ),
          ),
          Expanded(
            child: locales.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: ColoresPrevia.primario,
                ),
              ),
              error: (e, _) => const _Mensaje(
                texto: 'No se ha podido cargar la noche.',
              ),
              data: (lista) => lista.isEmpty
                  ? const _Mensaje(
                      texto: 'Todavía no hay sitios en esta ciudad.\n'
                          'Añade el primero con el botón de arriba.',
                    )
                  : RefreshIndicator(
                      color: ColoresPrevia.primario,
                      backgroundColor: ColoresPrevia.superficie,
                      onRefresh: () async =>
                          ref.refresh(localesProvider.future),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          EspaciadoPrevia.m,
                          0,
                          EspaciadoPrevia.m,
                          EspaciadoPrevia.xxl,
                        ),
                        itemCount: lista.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: EspaciadoPrevia.s + 4),
                        itemBuilder: (_, i) => _FichaLocal(local: lista[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _proponerLocal(
  BuildContext context,
  WidgetRef ref,
  String ciudad,
) async {
  final nombre = TextEditingController();
  final urlEntradas = TextEditingController();
  final instagram = TextEditingController();

  final creado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (contexto) => Padding(
      padding: EdgeInsets.fromLTRB(
        EspaciadoPrevia.m,
        EspaciadoPrevia.m,
        EspaciadoPrevia.m,
        MediaQuery.viewInsetsOf(contexto).bottom + EspaciadoPrevia.m,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Añadir un sitio en $ciudad',
            style: Theme.of(contexto).textTheme.titleLarge,
          ),
          const SizedBox(height: EspaciadoPrevia.m),
          TextField(
            controller: nombre,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre del sitio'),
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          TextField(
            controller: urlEntradas,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Enlace de entradas',
              hintText: 'https://…',
            ),
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          TextField(
            controller: instagram,
            decoration: const InputDecoration(
              labelText: 'Instagram',
              prefixText: '@',
            ),
          ),
          const SizedBox(height: EspaciadoPrevia.m),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Añadir'),
          ),
        ],
      ),
    ),
  );

  if (creado != true || nombre.text.trim().length < 2) return;

  await ref
      .read(repositorioSocialProvider)
      .crearLocal(
        nombre: nombre.text,
        ciudad: ciudad,
        urlEntradas: urlEntradas.text.isEmpty ? null : urlEntradas.text,
        instagram: instagram.text.isEmpty ? null : instagram.text,
      );
  ref.invalidate(localesProvider);
}

class _FichaLocal extends ConsumerStatefulWidget {
  const _FichaLocal({required this.local});

  final Local local;

  @override
  ConsumerState<_FichaLocal> createState() => _FichaLocalState();
}

class _FichaLocalState extends ConsumerState<_FichaLocal> {
  late Local _l = widget.local;

  Future<void> _alternarVoy() async {
    final antes = _l;
    setState(() {
      _l = _l.copiarCon(
        voy: !antes.voy,
        van: antes.voy ? antes.van - 1 : antes.van + 1,
      );
    });
    try {
      await ref
          .read(repositorioSocialProvider)
          .alternarVoy(antes.id, yaIba: antes.voy);
      // Decir que vas cuenta como noche, asi que mueve la racha, el
      // calendario y las salidas del perfil.
      refrescarPerfil(ref);
    } catch (_) {
      if (mounted) setState(() => _l = antes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Material(
      color: ColoresPrevia.superficie,
      borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
      child: InkWell(
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        onTap: () => _verQuienVa(context, ref, _l),
        child: Padding(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _l.nombre,
                      style: textos.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: EspaciadoPrevia.s),
                  _BotonVoy(voy: _l.voy, onTap: _alternarVoy),
                ],
              ),
              const SizedBox(height: EspaciadoPrevia.xs + 2),
              Row(
                children: [
                  Icon(
                    Icons.people_alt_rounded,
                    size: 16,
                    color: _l.van > 0
                        ? ColoresPrevia.disponible
                        : ColoresPrevia.textoTenue,
                  ),
                  const SizedBox(width: EspaciadoPrevia.xs + 2),
                  Text(
                    _l.van == 0
                        ? 'Nadie ha dicho que va todavía'
                        : _l.van == 1
                        ? '1 persona va esta noche'
                        : '${_l.van} personas van esta noche',
                    style: textos.bodyMedium?.copyWith(
                      color: _l.van > 0
                          ? ColoresPrevia.disponible
                          : ColoresPrevia.textoTenue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: EspaciadoPrevia.s + 4),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PantallaSala(
                            localId: _l.id,
                            nombreLocal: _l.nombre,
                          ),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        backgroundColor: ColoresPrevia.superficieActiva,
                        foregroundColor: ColoresPrevia.texto,
                      ),
                      icon: const Icon(Icons.forum_outlined, size: 19),
                      label: const Text('Sala de esta noche'),
                    ),
                  ),
                  if (_l.tieneEntradas) ...[
                    const SizedBox(width: EspaciadoPrevia.s),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _abrir(_l.urlEntradas!),
                        icon: const Icon(
                          Icons.local_activity_outlined,
                          size: 19,
                        ),
                        label: const Text('Entrada'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _abrir(String url) async {
  final destino = Uri.tryParse(url);
  if (destino == null) return;
  await launchUrl(destino, mode: LaunchMode.externalApplication);
}

Future<void> _verQuienVa(BuildContext context, WidgetRef ref, Local local) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (contexto) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, controlador) => FutureBuilder<List<PerfilResumen>>(
        future: ref.read(repositorioSocialProvider).quienVa(local.id),
        builder: (_, resultado) {
          final gente = resultado.data ?? const <PerfilResumen>[];

          return ListView(
            controller: controlador,
            padding: const EdgeInsets.all(EspaciadoPrevia.m),
            children: [
              Text(
                local.nombre,
                style: Theme.of(contexto).textTheme.headlineMedium,
              ),
              Text(
                'Quién va esta noche',
                style: Theme.of(contexto).textTheme.bodyMedium,
              ),
              const SizedBox(height: EspaciadoPrevia.m),

              if (resultado.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(EspaciadoPrevia.xl),
                    child: CircularProgressIndicator(
                      color: ColoresPrevia.primario,
                    ),
                  ),
                )
              else if (gente.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: EspaciadoPrevia.xl),
                  child: _Mensaje(
                    texto: 'Nadie lo ha dicho todavía.\n'
                        'Di que vas y que te vean.',
                  ),
                )
              else
                for (final p in gente)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AvatarPerfil(
                      url: p.avatar,
                      inicial: p.nombre,
                      lado: 44,
                    ),
                    title: Text(p.nombre),
                    subtitle: p.usuario == null ? null : Text('@${p.usuario}'),
                    trailing: p.leSigo
                        ? const Icon(
                            Icons.how_to_reg_rounded,
                            color: ColoresPrevia.disponible,
                          )
                        : null,
                  ),
            ],
          );
        },
      ),
    ),
  );
}

class _BotonVoy extends StatelessWidget {
  const _BotonVoy({required this.voy, required this.onTap});

  final bool voy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => voy
      ? FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            minimumSize: const Size(96, 38),
            backgroundColor: ColoresPrevia.disponible,
            foregroundColor: ColoresPrevia.sobrePrimario,
          ),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Voy'),
        )
      : OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(minimumSize: const Size(96, 38)),
          child: const Text('Voy'),
        );
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
