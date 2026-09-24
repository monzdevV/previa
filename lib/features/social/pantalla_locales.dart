import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        title: const Text('ESTA NOCHE'),
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
          Marquesina(texto: '¿A dónde vas? · $ciudad · Sala abierta'),
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
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: context.colores.primarioTexto,
                ),
              ),
              error: (e, _) =>
                  const _Mensaje(texto: 'No se ha podido cargar la noche.'),
              data: (lista) => lista.isEmpty
                  ? const _Mensaje(
                      texto:
                          'Todavía no hay sitios en esta ciudad.\n'
                          'Añade el primero con el botón de arriba.',
                    )
                  : RefreshIndicator(
                      color: context.colores.primario,
                      backgroundColor: context.colores.superficie,
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
                        itemBuilder: (_, i) => _FichaLocal(
                          key: ValueKey(lista[i].id),
                          local: lista[i],
                          color: BloquesPrevia.deIndice(i),
                        ),
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
        instagram: instagram.text.isEmpty ? null : instagram.text,
      );
  ref.invalidate(localesProvider);
}

class _FichaLocal extends ConsumerStatefulWidget {
  const _FichaLocal({super.key, required this.local, required this.color});

  final Local local;

  /// Cada local es un cartel de un color; rotan para que dos seguidos no se
  /// confundan.
  final Color color;

  @override
  ConsumerState<_FichaLocal> createState() => _FichaLocalState();
}

class _FichaLocalState extends ConsumerState<_FichaLocal> {
  late Local _l = widget.local;

  /// Mientras la peticion no vuelve se ignoran los toques: dos seguidos
  /// descuadrarian el contador de gente, que se calcula en local.
  bool _enCurso = false;

  @override
  void didUpdateWidget(covariant _FichaLocal anterior) {
    super.didUpdateWidget(anterior);
    // Al recargar la lista manda lo que dice el servidor, no la copia que se
    // tomo la primera vez que se pinto la ficha.
    if (!_enCurso && anterior.local != widget.local) _l = widget.local;
  }

  Future<void> _alternarVoy() async {
    if (_enCurso) return;
    HapticFeedback.selectionClick();
    final antes = _l;
    setState(() {
      _enCurso = true;
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
    } finally {
      if (mounted) setState(() => _enCurso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const tinta = BloquesPrevia.tintaSobreBloque;
    final textos = Theme.of(context).textTheme;

    final van = _l.van == 0
        ? 'Nadie ha dicho que va'
        : _l.van == 1
        ? '1 persona va'
        : '${_l.van} personas van';

    return Pulsable(
      onTap: () => _verQuienVa(context, ref, _l),
      escala: 0.98,
      child: Container(
        padding: const EdgeInsets.all(EspaciadoPrevia.m + 4),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Titular(
                    _l.nombre,
                    tamano: 34,
                    color: tinta,
                    lineas: 2,
                  ),
                ),
                const SizedBox(width: EspaciadoPrevia.s),
                _BotonVoy(voy: _l.voy, onTap: _alternarVoy),
              ],
            ),
            if (_l.zona != null && _l.zona!.isNotEmpty) ...[
              const SizedBox(height: EspaciadoPrevia.xs),
              Text(
                _l.zona!,
                style: textos.bodyMedium?.copyWith(
                  color: tinta.withValues(alpha: .75),
                ),
              ),
            ],
            const SizedBox(height: EspaciadoPrevia.m),
            Text(
              van.toUpperCase(),
              style: textos.labelLarge?.copyWith(
                color: tinta,
                fontSize: 13,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: EspaciadoPrevia.m),
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
                      minimumSize: const Size.fromHeight(46),
                      backgroundColor: tinta,
                      foregroundColor: widget.color,
                    ),
                    icon: const Icon(Icons.forum_rounded, size: 19),
                    label: const Text('SALA'),
                  ),
                ),
                if (_l.tieneEntradas) ...[
                  const SizedBox(width: EspaciadoPrevia.s),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _abrir(_l.urlEntradas!),
                      icon: const Icon(Icons.local_activity_rounded, size: 19),
                      label: const Text('ENTRADA'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        foregroundColor: tinta,
                        side: const BorderSide(color: tinta, width: 2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
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
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(EspaciadoPrevia.xl),
                    child: CircularProgressIndicator(
                      color: context.colores.primarioTexto,
                    ),
                  ),
                )
              else if (gente.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: EspaciadoPrevia.xl),
                  child: _Mensaje(
                    texto:
                        'Nadie lo ha dicho todavía.\n'
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
                        ? Icon(
                            Icons.how_to_reg_rounded,
                            color: context.colores.disponible,
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

  // Va encima de un bloque de color que cambia de un local a otro, asi que
  // no puede usar ningun color de marca: blanco relleno si vas, contorno
  // negro si no.
  @override
  Widget build(BuildContext context) {
    const tinta = BloquesPrevia.tintaSobreBloque;
    return voy
        ? FilledButton.icon(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              minimumSize: const Size(96, 40),
              backgroundColor: Colors.white,
              foregroundColor: tinta,
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('VOY'),
          )
        : OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(96, 40),
              foregroundColor: tinta,
              side: const BorderSide(color: tinta, width: 2),
            ),
            child: const Text('VOY'),
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
